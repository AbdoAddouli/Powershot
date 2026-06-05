trigger InspectionTrigger on Inspection__c (after insert, after update) {

    if (Trigger.isAfter) {
        Set<Id> parentAssetIds = new Set<Id>();
        Set<Id> parentPipelineIds = new Set<Id>();
        List<Inspection__c> completedInspections = new List<Inspection__c>();

        for (Inspection__c inspection : Trigger.new) {
            if (inspection.Status__c == 'Completed' &&
                inspection.Inspection_Date__c != null) {
                completedInspections.add(inspection);

                if (inspection.Asset__c != null) {
                    parentAssetIds.add(inspection.Asset__c);
                }
                if (inspection.Pipeline__c != null) {
                    parentPipelineIds.add(inspection.Pipeline__c);
                }
            }
        }

        if (!parentAssetIds.isEmpty()) {
            List<Asset> assetsToUpdate = new List<Asset>();
            Map<Id, Date> latestInspectionByAsset = new Map<Id, Date>();

            for (Inspection__c insp : completedInspections) {
                if (insp.Asset__c != null) {
                    Date existing = latestInspectionByAsset.get(insp.Asset__c);
                    if (existing == null || insp.Inspection_Date__c > existing) {
                        latestInspectionByAsset.put(insp.Asset__c, insp.Inspection_Date__c);
                    }
                }
            }

            for (Id assetId : latestInspectionByAsset.keySet()) {
                assetsToUpdate.add(new Asset(
                    Id = assetId,
                    Last_Inspection_Date__c = latestInspectionByAsset.get(assetId)
                ));
            }

            if (!assetsToUpdate.isEmpty()) {
                update assetsToUpdate;
            }
        }

        if (!parentPipelineIds.isEmpty()) {
            List<Pipeline__c> pipelinesToUpdate = new List<Pipeline__c>();
            Map<Id, Date> latestInspectionByPipeline = new Map<Id, Date>();

            for (Inspection__c insp : completedInspections) {
                if (insp.Pipeline__c != null) {
                    Date existing = latestInspectionByPipeline.get(insp.Pipeline__c);
                    if (existing == null || insp.Inspection_Date__c > existing) {
                        latestInspectionByPipeline.put(insp.Pipeline__c, insp.Inspection_Date__c);
                    }
                }
            }

            for (Id pipelineId : latestInspectionByPipeline.keySet()) {
                pipelinesToUpdate.add(new Pipeline__c(
                    Id = pipelineId,
                    Last_Inspection_Date__c = latestInspectionByPipeline.get(pipelineId)
                ));
            }

            if (!pipelinesToUpdate.isEmpty()) {
                update pipelinesToUpdate;
            }
        }

        List<Inspection__c> recurringInspections = new List<Inspection__c>();
        for (Inspection__c inspection : completedInspections) {
            if (inspection.Is_Recurring__c == true && inspection.Recurring_Interval_Days__c != null) {
                recurringInspections.add(inspection);
            }
        }

        if (!recurringInspections.isEmpty()) {
            List<Inspection__c> nextInspections = new List<Inspection__c>();

            for (Inspection__c insp : recurringInspections) {
                Date nextDue = insp.Inspection_Date__c.addDays(
                    Integer.valueOf(insp.Recurring_Interval_Days__c)
                );

                Inspection__c nextInspection = new Inspection__c(
                    Asset__c = insp.Asset__c,
                    Pipeline__c = insp.Pipeline__c,
                    Inspection_Type__c = insp.Inspection_Type__c,
                    Scheduled_Date__c = nextDue,
                    Status__c = 'Scheduled',
                    Is_Recurring__c = true,
                    Recurring_Interval_Days__c = insp.Recurring_Interval_Days__c,
                    Parent_Inspection__c = insp.Id
                );
                nextInspections.add(nextInspection);
            }

            if (!nextInspections.isEmpty()) {
                insert nextInspections;
            }
        }
    }
}
