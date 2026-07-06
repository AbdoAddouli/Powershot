public class SCADAMeasurementProcessor implements Queueable {
    private List<Measurement__c> measurements;

    public SCADAMeasurementProcessor(List<Measurement__c> measurements) {
        this.measurements = measurements;
    }

    public void execute(QueueableContext ctx) {
        insert measurements;
    }
}
