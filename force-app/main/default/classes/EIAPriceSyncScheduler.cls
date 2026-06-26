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
    // Schema refresh trigger

    public void execute(SchedulableContext ctx) {
        List<Supply_Agreement__c> agreements = [
            SELECT Id FROM Supply_Agreement__c
            WHERE Commodity_v2__c != NULL
        ];
        EIAPricingService.syncPricesForAgreements(agreements);

        List<Fuel_Inventory__c> inventories = [
            SELECT Id FROM Fuel_Inventory__c
            WHERE Product__c != NULL OR Product_Type__c != NULL
        ];
        EIAPricingService.syncStocksForInventories(inventories);
    }
}
