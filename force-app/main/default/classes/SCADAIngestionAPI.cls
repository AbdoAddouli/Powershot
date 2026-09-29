/**
 * SCADAIngestionAPI
 * ==================
 * REST endpoint for SCADA/PI bridge to push real-time well and pipeline
 * telemetry. Accepts an HMAC-signed POST envelope of readings, resolves PI
 * tags to Well/Pipeline records, maps them to Measurement__c, and queues the
 * records for bulk upsert by External_Key__c (idempotent across bridge retries).
 *
 * Business Process: SCADA/PI Telemetry Ingestion (Midstream)
 *   PI Bridge → HMAC-signed POST → tag resolution → Measurement upsert
 *
 * Endpoint: POST /services/apexrest/api/scada/measurements
 *
 * New payload contract (envelope):
 *   {
 *     "readings": [
 *       {
 *         "tag": "WELL-123.OIL_FLOW",
 *         "timestamp": "2026-08-27T10:15:00Z",
 *         "value": 184.2,
 *         "pressure": 1220,
 *         "temperature": 41.5,
 *         "measurementType": "Oil Flow",
 *         "quality": "Good"
 *       }
 *     ]
 *   }
 *
 * Backward compatible: a bare array using the legacy
 * {pipelineId, timestamp, flowRate, pressure, temperature} contract is also
 * accepted.
 */
@RestResource(urlMapping='/api/scada/measurements')
global with sharing class SCADAIngestionAPI {

    private static final String SIGNATURE_HEADER = 'X-SCADA-Signature';
    private static final String HMAC_ALGORITHM = 'HmacSHA256';
    private static final String SOURCE_PI_HISTORIAN = 'PI Historian';
    private static final String SOURCE_SCADA = 'SCADA';

    /** Maximum readings processed per enqueued Queueable chunk. */
    public static final Integer CHUNK_SIZE = 5000;

    @HttpPost
    global static String ingest() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // Fail closed: reject before touching any data unless the caller can
        // prove it shares the configured secret and ingestion is enabled.
        String rawBody = req.requestBody == null ? '' : req.requestBody.toString();
        SCADA_Config__c config = SCADA_Config__c.getInstance();

        if (config == null || String.isBlank(config.Shared_Secret__c) || !config.Enabled__c) {
            res.statusCode = 401;
            return JSON.serialize(new Map<String, Object>{
                'status' => 'unauthorized',
                'message' => 'Ingestion not configured or disabled.'
            });
        }

        String signature = req.headers.get(SIGNATURE_HEADER);
        if (String.isBlank(signature)
            || !isSignatureValid(signature, rawBody, config.Shared_Secret__c)) {
            res.statusCode = 401;
            return JSON.serialize(new Map<String, Object>{
                'status' => 'unauthorized',
                'message' => 'Invalid signature.'
            });
        }

        // Parse the envelope (or the legacy bare-array contract for back-compat).
        List<SCADAReading> readings = parseReadings(rawBody);
        if (readings == null || readings.isEmpty()) {
            res.statusCode = 400;
            return JSON.serialize(new Map<String, Object>{
                'status' => 'error',
                'message' => 'No readings supplied.'
            });
        }

        // Resolve PI tags to Well/Pipeline and map onto Measurement__c, setting
        // External_Key__c and deduping in-memory with a Set.
        IngestionResult result = buildMeasurements(readings);

        // Enqueue the upsert, splitting the payload into CHUNK_SIZE batches so
        // each Queueable stays within its row limits. A single job receiving the
        // whole (potentially >5000) list would exceed transaction limits before
        // it could split itself, so chunking happens here, before enqueue.
        List<Id> jobIds = new List<Id>();
        List<Measurement__c> measurements = result.measurements;
        for (Integer i = 0; i < measurements.size(); i += CHUNK_SIZE) {
            Integer endIdx = Math.min(i + CHUNK_SIZE, measurements.size());
            List<Measurement__c> chunk = new List<Measurement__c>();
            for (Integer j = i; j < endIdx; j++) {
                chunk.add(measurements[j]);
            }
            jobIds.add(System.enqueueJob(new SCADAMeasurementProcessor(chunk)));
        }
        if (!jobIds.isEmpty()) {
            result.jobId = jobIds[0];
        }

        res.statusCode = 200;
        return JSON.serialize(new Map<String, Object>{
            'status' => 'accepted',
            'jobId' => result.jobId,
            'jobCount' => jobIds.size(),
            'measurementsQueued' => result.measurements.size(),
            'unmatchedTags' => result.unmatchedTags,
            'chunked' => jobIds.size() > 1
        });
    }

    /**
     * Parses the request body into readings, handling both the new envelope
     * ({"readings":[...]}) and the legacy bare-array contract.
     */
    private static List<SCADAReading> parseReadings(String rawBody) {
        try {
            SCADAIngestionRequest request = (SCADAIngestionRequest)
                JSON.deserialize(rawBody, SCADAIngestionRequest.class);
            if (request != null && request.readings != null) {
                return request.readings;
            }
        } catch (Exception e) {
            // Fall through to legacy array parsing.
        }

        try {
            return (List<SCADAReading>) JSON.deserialize(
                rawBody, List<SCADAReading>.class);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Resolves PI tags to Well/Pipeline records (two SOQL calls, cached for the
     * request) and maps each reading to a Measurement__c. Unmatched tags are
     * reported per-reading and skipped, not fatal.
     */
    private static IngestionResult buildMeasurements(List<SCADAReading> readings) {
        Map<String, Id> wellTagToId = new Map<String, Id>();
        for (Well__c w : [SELECT Id, PI_Tag__c FROM Well__c WHERE PI_Tag__c != null]) {
            wellTagToId.put(w.PI_Tag__c, w.Id);
        }

        Map<String, Id> pipelineTagToId = new Map<String, Id>();
        for (Pipeline__c p : [SELECT Id, PI_Tag__c FROM Pipeline__c WHERE PI_Tag__c != null]) {
            pipelineTagToId.put(p.PI_Tag__c, p.Id);
        }

        List<Measurement__c> measurements = new List<Measurement__c>();
        List<String> unmatchedTags = new List<String>();
        Set<String> seenKeys = new Set<String>();

        for (SCADAReading r : readings) {
            String sourceSystem = SOURCE_PI_HISTORIAN;
            String piTag = r.tag;
            Id wellId;
            Id pipelineId = r.pipelineId;

            if (String.isNotBlank(r.tag)) {
                // New contract: resolve by PI tag.
                wellId = wellTagToId.get(r.tag);
                pipelineId = pipelineTagToId.get(r.tag);

                if (wellId == null && pipelineId == null) {
                    unmatchedTags.add(r.tag);
                    continue;
                }
            } else if (pipelineId == null) {
                // Nothing to link the reading to.
                unmatchedTags.add('(no tag / pipelineId)');
                continue;
            } else {
                // Legacy contract: direct pipelineId, source is SCADA.
                sourceSystem = SOURCE_SCADA;
            }

            // The External_Key must uniquely identify a reading for idempotent
            // upsert across bridge retries. Use the PI tag when present (new
            // contract); fall back to the pipelineId for legacy bare-array
            // readings so two pipelines sharing a timestamp never collide.
            String keyRef = String.isNotBlank(piTag) ? piTag : pipelineId;
            String externalKey = sourceSystem + '|' + keyRef + '|' + r.timestamp;
            if (keyRef == null) {
                unmatchedTags.add('(no tag / pipelineId)');
                continue;
            }
            if (!seenKeys.add(externalKey)) {
                continue; // duplicate within this request
            }

            Measurement__c m = new Measurement__c(
                Well__c = wellId,
                Pipeline__c = pipelineId,
                PI_Tag__c = piTag,
                Reading_DateTime__c = r.timestamp,
                Measurement_Type__c = r.measurementType,
                Source_System__c = sourceSystem,
                External_Key__c = externalKey
            );

            // value is the primary measured value; pressure/temperature are
            // optional secondary readings.
            if (r.value != null) {
                if ('Pressure'.equalsIgnoreCase(r.measurementType)) {
                    m.Pressure__c = r.value;
                } else if ('Temperature'.equalsIgnoreCase(r.measurementType)) {
                    m.Temperature__c = r.value;
                } else {
                    // Flow types (and 'Other') land in Gross_Volume__c.
                    m.Gross_Volume__c = r.value;
                }
            }

            if (r.pressure != null) {
                m.Pressure__c = r.pressure;
            }
            if (r.temperature != null) {
                m.Temperature__c = r.temperature;
            }
            if (r.flowRate != null) {
                m.Gross_Volume__c = r.flowRate;
            }

            measurements.add(m);
        }

        return new IngestionResult(measurements, unmatchedTags);
    }

    /**
     * Validates the X-SCADA-Signature header against an HMAC-SHA256 digest of
     * the raw request body computed with the configured shared secret. Comparison
     * is constant-time-ish via full-string equality on the hex digest.
     *
     * @param signature  The raw header value (hex digest, no prefix)
     * @param body  The exact request body bytes as a string
     * @param sharedSecret  The secret from SCADA_Config__c
     * @return  true when the signature matches, false otherwise
     */
    private static Boolean isSignatureValid(String signature, String body, String sharedSecret) {
        Blob hmacDigest = Crypto.generateMac(
            HMAC_ALGORITHM,
            Blob.valueOf(body),
            Blob.valueOf(sharedSecret)
        );

        String expected = EncodingUtil.convertToHex(hmacDigest);
        return expected.equalsIgnoreCase(signature.trim());
    }

    /** Result of resolving/mapping readings to measurements. */
    private class IngestionResult {
        public List<Measurement__c> measurements;
        public List<String> unmatchedTags;
        public Id jobId;

        public IngestionResult(List<Measurement__c> measurements, List<String> unmatchedTags) {
            this.measurements = measurements;
            this.unmatchedTags = unmatchedTags;
        }
    }

    global class SCADAIngestionRequest {
        global List<SCADAReading> readings;
    }

    global class SCADAReading {
        // New contract
        global String tag;
        global DateTime timestamp;
        global Decimal value;
        global String measurementType;
        global String quality;
        // Legacy contract
        global String pipelineId;
        global Decimal flowRate;
        // Shared secondary readings
        global Decimal pressure;
        global Decimal temperature;
    }
}
