public with sharing class PipelineIntegrityService {

    public static List<Inspection__c> getOverdueInspections() {
        return [
            SELECT Id, Name, Pipeline__c, Pipeline__r.Name, Inspection_Type__c,
                   Scheduled_Date__c, Next_Due_Date__c, Status__c, Result__c,
                   Inspector__c, Inspection_Date__c
            FROM Inspection__c
            WHERE (Next_Due_Date__c < :Date.today()
                OR Scheduled_Date__c < :Date.today())
                AND Status__c != 'Completed'
                AND Status__c != 'Cancelled'
            ORDER BY Next_Due_Date__c ASC NULLS FIRST, Scheduled_Date__c ASC
        ];
    }

    public static Boolean isInspectionCompliant(Id pipelineId) {
        Pipeline__c pipeline = [
            SELECT Id, Required_Inspection_Interval_Months__c,
                   Last_Inspection_Date__c, Compliance_Status__c
            FROM Pipeline__c
            WHERE Id = :pipelineId
            LIMIT 1
        ];

        if (pipeline.Last_Inspection_Date__c == null) return false;
        if (pipeline.Required_Inspection_Interval_Months__c == null) return true;

        Date nextDueDate = pipeline.Last_Inspection_Date__c.addMonths(
            Integer.valueOf(pipeline.Required_Inspection_Interval_Months__c)
        );

        return nextDueDate >= Date.today();
    }

    public static void flagNonCompliantPipelines() {
        List<Pipeline__c> pipelines = [
            SELECT Id, Last_Inspection_Date__c, Required_Inspection_Interval_Months__c,
                   Compliance_Status__c
            FROM Pipeline__c
        ];

        List<Pipeline__c> toUpdate = new List<Pipeline__c>();

        for (Pipeline__c pipeline : pipelines) {
            Boolean compliant = isInspectionCompliant(pipeline.Id);

            String expectedStatus = compliant ? 'Compliant' : 'Non-Compliant';
            if (pipeline.Compliance_Status__c != expectedStatus) {
                pipeline.Compliance_Status__c = expectedStatus;
                toUpdate.add(pipeline);
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public static Date calculateNextInspectionDueDate(Id pipelineId) {
        Pipeline__c pipeline = [
            SELECT Id, Last_Inspection_Date__c, Required_Inspection_Interval_Months__c
            FROM Pipeline__c
            WHERE Id = :pipelineId
            LIMIT 1
        ];

        if (pipeline.Last_Inspection_Date__c == null) {
            return Date.today().addMonths(6);
        }

        Integer intervalMonths = pipeline.Required_Inspection_Interval_Months__c != null
            ? Integer.valueOf(pipeline.Required_Inspection_Interval_Months__c)
            : 12;

        Date nextDate = pipeline.Last_Inspection_Date__c.addMonths(intervalMonths);

        if (nextDate < Date.today()) {
            nextDate = Date.today().addMonths(intervalMonths);
        }

        return nextDate;
    }
}
