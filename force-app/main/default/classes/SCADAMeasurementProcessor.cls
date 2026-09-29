/**
 * SCADAMeasurementProcessor
 * =========================
 * Queueable that bulk-upserts SCADA/PI measurements into Measurement__c by
 * External_Key__c, making bridge retries idempotent.
 *
 * Each job receive at most SCADAIngestionAPI.CHUNK_SIZE records: SCADAIngestionAPI
 * pre-chunks the request payload before enqueue, so this class only needs to
 * perform a single bulk upsert (no SOQL-in-loop, no self-chaining).
 *
 * Used by: SCADAIngestionAPI (REST ingestion layer).
 */
public class SCADAMeasurementProcessor implements Queueable {

    private final List<Measurement__c> measurements;

    public SCADAMeasurementProcessor(List<Measurement__c> measurements) {
        this.measurements = measurements;
    }

    public void execute(QueueableContext ctx) {
        if (measurements == null || measurements.isEmpty()) {
            return;
        }

        // Bulk upsert (no SOQL-in-loop): idempotent on External_Key__c for the
        // PI source. Records lacking an External_Key__c are simply inserted.
        upsert measurements External_Key__c;
    }
}
