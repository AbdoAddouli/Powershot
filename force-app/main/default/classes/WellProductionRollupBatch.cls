public without sharing class WellProductionRollupBatch implements Database.Batchable<SObject> {

    private Date startDate;

    public WellProductionRollupBatch() {
        this.startDate = Date.today().addMonths(-12);
    }

    public WellProductionRollupBatch(Date startDate) {
        this.startDate = startDate;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM Well__c
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Well__c> wells) {
        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        for (Well__c w : wells) {
            totals.put(w.Id, 0);
        }

        for (List<Production_Allocation__c> allocs : [
            SELECT Well__c, Oil_Volume_bbls__c
            FROM Production_Allocation__c
            WHERE Well__c IN :wells
              AND Period_End__c >= :startDate
              AND Oil_Volume_bbls__c != null
        ]) {
            for (Production_Allocation__c a : allocs) {
                totals.put(a.Well__c, totals.get(a.Well__c) + a.Oil_Volume_bbls__c);
            }
        }

        List<Well__c> toUpdate = new List<Well__c>();
        for (Well__c w : wells) {
            w.Total_Oil_Volume_12M__c = totals.get(w.Id);
            toUpdate.add(w);
        }
        update toUpdate;
    }

    public void finish(Database.BatchableContext bc) {
    }
}
