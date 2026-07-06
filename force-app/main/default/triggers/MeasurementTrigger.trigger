/**
 * MeasurementTrigger
 * ===================
 * After-insert: flags pressure anomalies (>1500 psi or <100 psi) by creating
 * HSE_Observation__c records linked to the pipeline.
 *
 * Used by: SCADAIngestionAPI (anomaly detection moved here for trigger safety)
 */
trigger MeasurementTrigger on Measurement__c (after insert) {

    if (Trigger.isAfter && Trigger.isInsert) {
        List<Measurement__c> anomalous = new List<Measurement__c>();
        for (Measurement__c m : Trigger.new) {
            if (m.Pipeline__c != null && (m.Pressure__c > 1500 || m.Pressure__c < 100)) {
                anomalous.add(m);
            }
        }

        if (!anomalous.isEmpty()) {
            List<HSE_Observation__c> observations = new List<HSE_Observation__c>();
            for (Measurement__c m : anomalous) {
                observations.add(new HSE_Observation__c(
                    Observation_Type__c = 'Unsafe',
                    Category__c = 'Pressure Anomaly',
                    Pipeline__c = m.Pipeline__c,
                    Description__c = 'Pressure reading: ' + m.Pressure__c + ' psi',
                    Status__c = 'Open'
                ));
            }
            insert observations;
        }
    }
}
