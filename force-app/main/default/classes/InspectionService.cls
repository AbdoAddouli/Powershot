/**
 * InspectionService
 * ==================
 * Handles inspection checklist retrieval, submission, parent asset/pipeline
 * date rollups, and recurring inspection creation. Supports both LWC
 * (getChecklistItems, submitChecklist) and trigger-based operations.
 *
 * Business Process: Inspection Management (Downstream / Cross-Domain)
 *   Schedule → Conduct → Submit Results → Update Parent Dates
 *   → Create Recurring (if applicable) → Compliance Review
 */
public with sharing class InspectionService {

    /**
     * @AuraEnabled LWC-facing method returning inspections for a given parent
     * record (Asset, Pipeline, Terminal, etc.).
     * @param parentId  The parent record Id
     * @param type  Inspection type filter (unused in SOQL, reserved for future)
     * @return  Inspections ordered by scheduled date
     */
    @AuraEnabled(cacheable=true)
    public static List<Inspection__c> getChecklistItems(Id parentId, String type) {
        return [
            SELECT Id, Name, Inspection_Type__c, Status__c, Result__c,
                   Inspection_Date__c, Scheduled_Date__c, Completed_Date__c,
                   Findings__c, Inspector__c
            FROM Inspection__c
            WHERE Well__c = :parentId OR Pipeline__c = :parentId
               OR Terminal__c = :parentId OR Asset__c = :parentId
               OR Account__c = :parentId
            ORDER BY Scheduled_Date__c ASC
        ];
    }

    /**
     * @AuraEnabled LWC-facing method that accepts a JSON array of inspection
     * updates and marks them as Completed with findings.
     * @param checklistData  JSON string: [{"Id":"...","Status__c":"Completed","Comment__c":"..."}]
     * @param parentId  Unused parent Id (reserved)
     */
    @AuraEnabled
    public static void submitChecklist(String checklistData, Id parentId) {
        List<Object> itemsList = (List<Object>) JSON.deserializeUntyped(checklistData);
        List<Map<String, Object>> items = new List<Map<String, Object>>();
        for (Object obj : itemsList) {
            items.add((Map<String, Object>) obj);
        }
        List<Inspection__c> updates = new List<Inspection__c>();

        for (Map<String, Object> item : items) {
            String itemId = (String) item.get('Id');
            if (String.isBlank(itemId)) continue;

            String status = (String) item.get('Status__c');
            String comment = (String) item.get('Comment__c');

            Inspection__c insp = new Inspection__c(Id = itemId);
            if (status == 'Completed') {
                insp.Status__c = 'Completed';
                insp.Completed_Date__c = Date.today();
            }
            if (String.isNotBlank(comment)) {
                insp.Findings__c = comment;
            }
            updates.add(insp);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    /**
     * Rolls up the latest inspection date to parent Asset and Pipeline records.
     * Called by InspectionTrigger after completed inspections.
     * @param completedInspections  Inspections whose parent records need updating
     */
    public static void updateParentInspectionDates(List<Inspection__c> completedInspections) {
        Set<Id> parentAssetIds = new Set<Id>();
        Set<Id> parentPipelineIds = new Set<Id>();

        for (Inspection__c inspection : completedInspections) {
            if (inspection.Asset__c != null) {
                parentAssetIds.add(inspection.Asset__c);
            }
            if (inspection.Pipeline__c != null) {
                parentPipelineIds.add(inspection.Pipeline__c);
            }
        }

        if (!parentAssetIds.isEmpty()) {
            Map<Id, Date> latestInspectionByAsset = new Map<Id, Date>();
            for (Inspection__c insp : completedInspections) {
                if (insp.Asset__c != null) {
                    Date existing = latestInspectionByAsset.get(insp.Asset__c);
                    if (existing == null || insp.Inspection_Date__c > existing) {
                        latestInspectionByAsset.put(insp.Asset__c, insp.Inspection_Date__c);
                    }
                }
            }

            List<Asset> assetsToUpdate = new List<Asset>();
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
            Map<Id, Date> latestInspectionByPipeline = new Map<Id, Date>();
            for (Inspection__c insp : completedInspections) {
                if (insp.Pipeline__c != null) {
                    Date existing = latestInspectionByPipeline.get(insp.Pipeline__c);
                    if (existing == null || insp.Inspection_Date__c > existing) {
                        latestInspectionByPipeline.put(insp.Pipeline__c, insp.Inspection_Date__c);
                    }
                }
            }

            List<Pipeline__c> pipelinesToUpdate = new List<Pipeline__c>();
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
    }

    /**
     * Creates the next Inspection__c record for recurring inspections based on
     * Recurring_Interval_Days__c.
     * @param completedInspections  Inspections that were just completed
     */
    public static void createRecurringInspections(List<Inspection__c> completedInspections) {
        List<Inspection__c> nextInspections = new List<Inspection__c>();

        for (Inspection__c insp : completedInspections) {
            if (insp.Is_Recurring__c == true && insp.Recurring_Interval_Days__c != null) {
                Date nextDue = insp.Inspection_Date__c.addDays(
                    Integer.valueOf(insp.Recurring_Interval_Days__c)
                );

                nextInspections.add(new Inspection__c(
                    Asset__c = insp.Asset__c,
                    Pipeline__c = insp.Pipeline__c,
                    Inspection_Type__c = insp.Inspection_Type__c,
                    Scheduled_Date__c = nextDue,
                    Status__c = 'Scheduled',
                    Is_Recurring__c = true,
                    Recurring_Interval_Days__c = insp.Recurring_Interval_Days__c,
                    Parent_Inspection__c = insp.Id
                ));
            }
        }

        if (!nextInspections.isEmpty()) {
            insert nextInspections;
        }
    }
}
