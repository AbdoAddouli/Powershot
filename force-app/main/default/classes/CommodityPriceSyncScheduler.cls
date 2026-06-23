/**
 * CommodityPriceSyncScheduler
 * ============================
 * Scheduled job that runs daily to sync current commodity prices from
 * OilPriceAPI to all active Supply_Agreement__c records via
 * CommodityPricingService.
 *
 * Business Process: Commodity Pricing (Commercial)
 *   Scheduled Trigger → Query Agreements → Sync Prices → Update Records
 *
 * Schedule (recommended):
 *   System.schedule('Commodity Price Sync', '0 0 8 * * ?', new CommodityPriceSyncScheduler());
 */
public with sharing class CommodityPriceSyncScheduler implements Schedulable {

    public void execute(SchedulableContext ctx) {
        List<Supply_Agreement__c> agreements = [
            SELECT Id FROM Supply_Agreement__c
            WHERE Commodity__c != NULL
        ];
        CommodityPricingService.syncPricesForAgreements(agreements);
    }
}
