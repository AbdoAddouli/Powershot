public without sharing class PipelineIntegrityBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Last_Inspection_Date__c, Required_Inspection_Interval_Months__c,
                   Compliance_Status__c
            FROM Pipeline__c
            ORDER BY Last_Inspection_Date__c ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Pipeline__c> pipelines) {
        List<Pipeline__c> toUpdate = new List<Pipeline__c>();

        for (Pipeline__c pipeline : pipelines) {
            Boolean compliant;
            if (pipeline.Last_Inspection_Date__c == null) {
                compliant = false;
            } else if (pipeline.Required_Inspection_Interval_Months__c == null) {
                compliant = true;
            } else {
                Date nextDueDate = pipeline.Last_Inspection_Date__c.addMonths(
                    Integer.valueOf(pipeline.Required_Inspection_Interval_Months__c)
                );
                compliant = nextDueDate >= Date.today();
            }

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

    public void finish(Database.BatchableContext bc) {
    }
}
