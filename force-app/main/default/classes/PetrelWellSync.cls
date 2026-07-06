/**
 * PetrelWellSync
 * ===============
 * Scheduled job that calls the Petrel/EDM API to sync well data into
 * Well__c records using API_Number__c as the unique match key.
 *
 * Business Process: Drilling Data Integration (Drilling & Completions)
 *   Scheduled Trigger → Call Petrel API → Deserialize Wells → Upsert Well__c
 *
 * Schedule (recommended):
 *   System.schedule('Petrel Well Sync Daily', '0 0 6 * * ?', new PetrelWellSync());
 *
 * Prerequisites:
 *   - Named Credential "PetrelAPI" pointing to your Petrel/EDM endpoint
 *   - External Credential "PetrelAPI" with appropriate auth protocol
 *   - CSP Trusted Site for the API domain
 */
public with sharing class PetrelWellSync implements Schedulable {

    private static final String API_ENDPOINT = 'callout:PetrelAPI/wells?status=active';

    public void execute(SchedulableContext ctx) {
        System.enqueueJob(new PetrelWellSyncQueueable());
    }

    @future(callout=true)
    public static void syncWells() {
        runSync();
    }

    public static void runSync() {
        upsertWells(fetchWellsFromPetrel());
    }

    private static void upsertWells(List<Well__c> incoming) {
        if (incoming.isEmpty()) return;

        Set<String> apiNumbers = new Set<String>();
        for (Well__c w : incoming) {
            if (w.API_Number__c != null) {
                apiNumbers.add(w.API_Number__c);
            }
        }

        Map<String, Id> existingByApi = new Map<String, Id>();
        for (Well__c w : [SELECT Id, API_Number__c FROM Well__c WHERE API_Number__c IN :apiNumbers]) {
            existingByApi.put(w.API_Number__c, w.Id);
        }

        List<Well__c> toUpdate = new List<Well__c>();
        List<Well__c> toInsert = new List<Well__c>();
        for (Well__c w : incoming) {
            if (w.API_Number__c != null && existingByApi.containsKey(w.API_Number__c)) {
                w.Id = existingByApi.get(w.API_Number__c);
                toUpdate.add(w);
            } else {
                toInsert.add(w);
            }
        }

        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    private static List<Well__c> fetchWellsFromPetrel() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_ENDPOINT);
        req.setMethod('GET');
        req.setTimeout(30000);

        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() != 200) {
                System.debug('Petrel API returned status: ' + res.getStatusCode());
                return new List<Well__c>();
            }

            List<PetrelWell> petrelWells = (List<PetrelWell>)
                JSON.deserialize(res.getBody(), List<PetrelWell>.class);

            List<Well__c> wells = new List<Well__c>();
            for (PetrelWell pw : petrelWells) {
                wells.add(new Well__c(
                    Name = pw.wellName,
                    API_Number__c = pw.apiNumber,
                    Total_Depth__c = pw.totalDepth,
                    True_Vertical_Depth__c = pw.tvd,
                    Formation__c = pw.formation,
                    Well_Type__c = pw.wellType,
                    Status__c = pw.status
                ));
            }
            return wells;

        } catch (Exception e) {
            System.debug('Petrel API callout failed: ' + e.getMessage());
            return new List<Well__c>();
        }
    }

    public class PetrelWell {
        public String apiNumber;
        public String wellName;
        public Decimal totalDepth;
        public Decimal tvd;
        public String formation;
        public String wellType;
        public String status;
    }
}
