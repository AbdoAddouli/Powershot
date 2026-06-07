public with sharing class InspectionService {

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
}
