/**
 * SCADAIngestionAPI
 * ==================
 * REST endpoint for SCADA systems to push real-time pipeline measurements.
 * Accepts POST with JSON array of readings, inserts Measurement__c records,
 * and flags pressure anomalies by creating HSE_Observation__c records.
 *
 * Business Process: SCADA Pipeline Monitoring (Midstream)
 *   SCADA Push → REST Ingestion → Measurement Creation → Anomaly Detection
 *
 * Endpoint: POST /services/apexrest/api/scada/measurements
 */
@RestResource(urlMapping='/api/scada/measurements')
global with sharing class SCADAIngestionAPI {

    @HttpPost
    global static String ingest() {
        RestRequest req = RestContext.request;
        List<SCADAReading> readings = (List<SCADAReading>)
            JSON.deserialize(req.requestBody.toString(), List<SCADAReading>.class);

        List<Measurement__c> measurements = new List<Measurement__c>();
        for (SCADAReading r : readings) {
            measurements.add(new Measurement__c(
                Pipeline__c = r.pipelineId,
                Reading_DateTime__c = r.timestamp,
                Gross_Volume__c = r.flowRate,
                Pressure__c = r.pressure,
                Temperature__c = r.temperature
            ));
        }

        Id jobId = System.enqueueJob(new SCADAMeasurementProcessor(measurements));

        return JSON.serialize(new Map<String, Object>{
            'status' => 'accepted',
            'jobId' => jobId,
            'measurementsQueued' => measurements.size()
        });
    }

    global class SCADAReading {
        global String pipelineId;
        global DateTime timestamp;
        global Decimal flowRate;
        global Decimal pressure;
        global Decimal temperature;
    }
}
