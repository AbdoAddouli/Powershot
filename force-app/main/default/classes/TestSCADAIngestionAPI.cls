/**
 * TestSCADAIngestionAPI
 * =====================
 * Tests HMAC-SHA256 request authentication on the SCADA ingestion REST endpoint
 * (SCADAIngestionAPI). Covers fail-closed rejection when the signature is
 * missing/mismatched, when the config is absent, and when ingestion is disabled,
 * plus a successful authenticated push.
 */
@IsTest
public with sharing class TestSCADAIngestionAPI {

    private static final String TEST_SECRET = 's3cr3t-scada-shared-key';

    // =========================================================================
    // Test data helpers
    // =========================================================================

    /** Creates the hierarchy custom setting the endpoint reads its config from. */
    private static SCADA_Config__c createConfig(Boolean enabled) {
        SCADA_Config__c config = new SCADA_Config__c(
            SetupOwnerId = UserInfo.getUserId(),
            Enabled__c = enabled,
            Shared_Secret__c = TEST_SECRET
        );
        insert config;
        return config;
    }

    /** Builds a minimal legacy payload in the endpoint's expected shape. */
    private static String buildPayload(String pipelineId) {
        return JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'pipelineId' => pipelineId,
                'timestamp' => '2026-08-29T10:15:00Z',
                'flowRate' => 184.2,
                'pressure' => 1220,
                'temperature' => 41.5
            }
        });
    }

    /**
     * Builds the Phase 3 envelope payload from a list of readings.
     * @param readings  List of Maps with tag/timestamp/value/... keys
     */
    private static String buildEnvelopePayload(List<Object> readings) {
        return JSON.serialize(new Map<String, Object>{ 'readings' => readings });
    }

    private static Map<String, Object> reading(Map<String, Object> overrides) {
        Map<String, Object> base = new Map<String, Object>{
            'tag' => 'WELL-123.OIL_FLOW',
            'timestamp' => '2026-08-29T10:15:00Z',
            'value' => 184.2,
            'pressure' => 1220,
            'temperature' => 41.5,
            'measurementType' => 'Oil Flow',
            'quality' => 'Good'
        };
        base.putAll(overrides);
        return base;
    }

    /** Computes the X-SCADA-Signature header value for a given body. */
    private static String signBody(String body, String sharedSecret) {
        Blob hmac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(body),
            Blob.valueOf(sharedSecret)
        );
        return EncodingUtil.convertToHex(hmac);
    }

    /** Runs the ingest endpoint in an isolated REST context and returns its status. */
    private static Integer callIngest(String body, String signature) {
        Test.startTest();
        Integer status = runIngestRaw(body, signature);
        Test.stopTest();
        return status;
    }

    /** Executes the endpoint without starting/stopping a test block. */
    private static Integer runIngestRaw(String body, String signature) {
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        if (String.isNotBlank(signature)) {
            req.addHeader('X-SCADA-Signature', signature);
        }
        req.addHeader('Content-Type', 'application/json');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        SCADAIngestionAPI.ingest();
        return res.statusCode;
    }

    // =========================================================================
    // Fail-closed: no / bad config
    // =========================================================================

    @IsTest
    static void testIngestRejectsWhenNotConfigured() {
        String body = buildPayload('PIPE-1');

        Integer status = callIngest(body, signBody(body, TEST_SECRET));
        Assert.areEqual(401, status, 'Missing config must fail closed');
    }

    @IsTest
    static void testIngestRejectsWhenDisabled() {
        createConfig(false);
        String body = buildPayload('PIPE-1');

        Integer status = callIngest(body, signBody(body, TEST_SECRET));
        Assert.areEqual(401, status, 'Disabled ingestion must fail closed even with valid signature');
    }

    // =========================================================================
    // Fail-closed: signature validation
    // =========================================================================

    @IsTest
    static void testIngestRejectsMissingSignature() {
        createConfig(true);
        String body = buildPayload('PIPE-1');

        Integer status = callIngest(body, '');
        Assert.areEqual(401, status, 'Missing signature header must be rejected');
    }

    @IsTest
    static void testIngestRejectsInvalidSignature() {
        createConfig(true);
        String body = buildPayload('PIPE-1');

        Integer status = callIngest(body, 'deadbeefdeadbeef');
        Assert.areEqual(401, status, 'Tampered signature must be rejected');

        Assert.areEqual(
            0, [SELECT COUNT() FROM Measurement__c],
            'No measurement should be persisted when the signature is invalid'
        );
    }

    // =========================================================================
    // Happy path
    // =========================================================================

    @IsTest
    static void testIngestAcceptsValidSignature() {
        createConfig(true);

        Pipeline__c pipeline = new Pipeline__c(
            Name = 'Test Pipeline',
            Diameter_inches__c = 24,
            Capacity_bpd__c = 100000
        );
        insert pipeline;

        String body = buildPayload(String.valueOf(pipeline.Id));

        Integer status = callIngest(body, signBody(body, TEST_SECRET));
        Assert.areEqual(200, status, 'Valid signature should be accepted');

        List<Measurement__c> stored = [SELECT Pipeline__c, Reading_DateTime__c, Gross_Volume__c, External_Key__c FROM Measurement__c];
        Assert.areEqual(1, stored.size(), 'One measurement should be queued and inserted');
        Assert.areEqual(pipeline.Id, stored[0].Pipeline__c);
        Assert.isNotNull(stored[0].External_Key__c, 'External_Key should be populated for idempotency');
    }

    // =========================================================================
    // Phase 3: new envelope contract + PI tag resolution
    // =========================================================================

    @IsTest
    static void testIngestEnvelopeResolvesWellByTag() {
        createConfig(true);

        Well__c well = new Well__c(Name = 'WELL-123', PI_Tag__c = 'WELL-123.OIL_FLOW');
        insert well;

        String body = buildEnvelopePayload(new List<Object>{ reading(new Map<String, Object>()) });
        Integer status = callIngest(body, signBody(body, TEST_SECRET));
        Assert.areEqual(200, status, 'Valid signed envelope should be accepted');

        List<Measurement__c> stored = [
            SELECT Well__c, PI_Tag__c, External_Key__c, Measurement_Type__c,
                   Source_System__c, Gross_Volume__c, Reading_DateTime__c
            FROM Measurement__c
        ];
        Assert.areEqual(1, stored.size(), 'One measurement should be created');
        Assert.areEqual(well.Id, stored[0].Well__c, 'Should resolve the tag to the Well');
        Assert.areEqual('WELL-123.OIL_FLOW', stored[0].PI_Tag__c);
        Assert.areEqual('Oil Flow', stored[0].Measurement_Type__c);
        Assert.areEqual('PI Historian', stored[0].Source_System__c);
        Assert.areEqual(184.2, stored[0].Gross_Volume__c, 'Flow value should map to Gross_Volume');
        Assert.isNotNull(stored[0].External_Key__c, 'External_Key should be populated');
        Assert.isTrue(
            stored[0].External_Key__c.startsWith('PI Historian|WELL-123.OIL_FLOW|'),
            'External_Key must be prefixed with source|tag'
        );
        Assert.isNotNull(stored[0].Reading_DateTime__c);
    }

    @IsTest
    static void testIngestEnvelopeResolvesPipelineByTag() {
        createConfig(true);

        Pipeline__c pipeline = new Pipeline__c(
            Name = 'PIPE-TX-01',
            PI_Tag__c = 'PIPE-TX-01.OIL_FLOW',
            Diameter_inches__c = 24,
            Capacity_bpd__c = 100000
        );
        insert pipeline;

        String body = buildEnvelopePayload(new List<Object>{
            reading(new Map<String, Object>{ 'tag' => 'PIPE-TX-01.OIL_FLOW' })
        });
        Integer status = callIngest(body, signBody(body, TEST_SECRET));
        Assert.areEqual(200, status);

        List<Measurement__c> stored = [
            SELECT Pipeline__c, PI_Tag__c FROM Measurement__c
        ];
        Assert.areEqual(1, stored.size());
        Assert.areEqual(pipeline.Id, stored[0].Pipeline__c, 'Should resolve the tag to the Pipeline');
        Assert.areEqual('PIPE-TX-01.OIL_FLOW', stored[0].PI_Tag__c);
    }

    @IsTest
    static void testIngestEnvelopeSkipsUnmatchedTag() {
        createConfig(true);

        String body = buildEnvelopePayload(new List<Object>{
            reading(new Map<String, Object>{ 'tag' => 'UNKNOWN-TAG.XXX' })
        });
        Integer status = callIngest(body, signBody(body, TEST_SECRET));
        Assert.areEqual(200, status, 'Unmatched tags are skipped, not fatal');

        Assert.areEqual(
            0, [SELECT COUNT() FROM Measurement__c],
            'No measurement should be created for an unmatched tag'
        );
    }

    @IsTest
    static void testIngestEnvelopeDeduplicatesInternalKey() {
        createConfig(true);

        Well__c well = new Well__c(Name = 'WELL-123', PI_Tag__c = 'WELL-123.PRESS');
        insert well;

        // Two readings with the same tag + timestamp -> same External_Key.
        String body = buildEnvelopePayload(new List<Object>{
            reading(new Map<String, Object>{
                'tag' => 'WELL-123.PRESS',
                'measurementType' => 'Pressure',
                'value' => 1220
            }),
            reading(new Map<String, Object>{
                'tag' => 'WELL-123.PRESS',
                'measurementType' => 'Pressure',
                'value' => 1221
            })
        });
        Integer status = callIngest(body, signBody(body, TEST_SECRET));
        Assert.areEqual(200, status);

        Assert.areEqual(
            1, [SELECT COUNT() FROM Measurement__c],
            'Readings sharing an External_Key within a request should be deduped in-memory'
        );
    }

    @IsTest
    static void testIngestEnvelopePressureTypeMapsToPressureField() {
        createConfig(true);

        Well__c well = new Well__c(Name = 'WELL-P', PI_Tag__c = 'WELL-P.PRESS');
        insert well;

        String body = buildEnvelopePayload(new List<Object>{
            reading(new Map<String, Object>{
                'tag' => 'WELL-P.PRESS',
                'measurementType' => 'Pressure',
                'value' => 1220
            })
        });
        Integer status = callIngest(body, signBody(body, TEST_SECRET));
        Assert.areEqual(200, status);

        List<Measurement__c> stored = [SELECT Pressure__c, Gross_Volume__c FROM Measurement__c];
        Assert.areEqual(1, stored.size());
        Assert.areEqual(1220, stored[0].Pressure__c, 'Pressure-type value should map to Pressure__c');
        Assert.isNull(stored[0].Gross_Volume__c, 'Pressure value should not land in Gross_Volume');
    }

    @IsTest
    static void testIngestIsIdempotentAcrossRetries() {
        createConfig(true);

        Well__c well = new Well__c(Name = 'WELL-123', PI_Tag__c = 'WELL-123.OIL_FLOW');
        insert well;

        String body = buildEnvelopePayload(new List<Object>{ reading(new Map<String, Object>()) });

        // Both deliveries enqueued inside a single test block, then flushed.
        Test.startTest();
        Integer status1 = runIngestRaw(body, signBody(body, TEST_SECRET));
        Integer status2 = runIngestRaw(body, signBody(body, TEST_SECRET));
        Test.stopTest();
        Assert.areEqual(200, status1);
        Assert.areEqual(200, status2);

        Assert.areEqual(
            1, [SELECT COUNT() FROM Measurement__c],
            'Re-delivered reading with same External_Key must upsert, not duplicate'
        );
    }

    /**
     * Regression: legacy bare-array readings for two DIFFERENT pipelines at the
     * SAME timestamp must produce distinct External_Keys (the legacy path has no
     * PI tag, so the pipelineId is the only differentiator). Without it they
     * would collide on the unique External_Key field and one would be lost.
     */
    @IsTest
    static void testLegacyExternalKeyIncludesPipelineId() {
        createConfig(true);

        Pipeline__c p1 = new Pipeline__c(Name = 'PIPE-A', Diameter_inches__c = 24, Capacity_bpd__c = 1000);
        Pipeline__c p2 = new Pipeline__c(Name = 'PIPE-B', Diameter_inches__c = 30, Capacity_bpd__c = 2000);
        insert new List<Pipeline__c>{ p1, p2 };

        String body = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'pipelineId' => String.valueOf(p1.Id),
                'timestamp' => '2026-08-29T10:15:00Z',
                'flowRate' => 100
            },
            new Map<String, Object>{
                'pipelineId' => String.valueOf(p2.Id),
                'timestamp' => '2026-08-29T10:15:00Z',
                'flowRate' => 200
            }
        });

        Integer status = callIngest(body, signBody(body, TEST_SECRET));
        Assert.areEqual(200, status);

        List<Measurement__c> stored = [
            SELECT Pipeline__c, External_Key__c FROM Measurement__c ORDER BY Pipeline__c
        ];
        Assert.areEqual(2, stored.size(),
            'Same-timestamp readings for different pipelines must both persist');
        Assert.areNotEqual(stored[0].External_Key__c, stored[1].External_Key__c,
            'Legacy External_Key must differ across pipelines sharing a timestamp');
        Assert.isTrue(
            stored[0].External_Key__c.indexOf('PIPE-A') >= 0 ||
            stored[0].External_Key__c.indexOf('PIPE-B') >= 0 ||
            stored[0].External_Key__c.indexOf(String.valueOf(p1.Id)) >= 0,
            'Legacy External_Key should carry a pipeline reference'
        );
    }
}
