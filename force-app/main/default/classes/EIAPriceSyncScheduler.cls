/**
 * EIAPriceSyncScheduler
 * ======================
 * Scheduled job that runs weekly to sync EIA fuel prices and inventory stock
 * benchmarks to Supply_Agreement__c and Fuel_Inventory__c records.
 *
 * Business Process: Commodity Pricing & Inventory (Commercial / Downstream)
 *   Schedule Trigger → Query Records → Sync Prices → Sync Stocks
 *
 * Schedule (recommended — EIA data releases Wednesday at 10:30 AM ET):
 *   System.schedule('EIA Weekly Sync', '0 30 14 * * 3', new EIAPriceSyncScheduler());
 */
public with sharing class EIAPriceSyncScheduler implements Schedulable {

    public void execute(SchedulableContext ctx) {
        List<Supply_Agreement__c> agreements = [
            SELECT Id FROM Supply_Agreement__c
            WHERE Commodity_v2__c != NULL
            LIMIT 50000
        ];
        if (!agreements.isEmpty()) {
            Set<Id> agreementIds = (new Map<Id, Supply_Agreement__c>(agreements)).keySet();
            System.enqueueJob(new EIAQueueable(agreementIds, 'PRICE'));
        }

        List<Fuel_Inventory__c> inventories = [
            SELECT Id FROM Fuel_Inventory__c
            WHERE Product__c != NULL OR Product_Type__c != NULL
            LIMIT 50000
        ];
        if (!inventories.isEmpty()) {
            Set<Id> inventoryIds = (new Map<Id, Fuel_Inventory__c>(inventories)).keySet();
            System.enqueueJob(new EIAQueueable(inventoryIds, 'STOCK'));
        }
    }
}
