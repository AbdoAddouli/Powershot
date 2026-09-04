/**
 * MarketDataController
 * ====================
 * LWC-facing data layer for the Experience Cloud home page market-data widget.
 * Returns the latest synced commodity prices (OilPriceAPI via
 * CommodityPricingService) and national inventory benchmarks (EIA via
 * EIAPricingService) stored on Supply_Agreement__c and Fuel_Inventory__c.
 *
 * Security: runs "with sharing" and applies field-level-security / CRUD checks
 * via Security.stripInaccessible so portal users only ever see data their
 * permission set allows. Never revert to "without sharing" for a cacheable
 * @AuraEnabled controller exposed on a partner/portal surface.
 */
public with sharing class MarketDataController {

    private static SObjectAccessDecision readGuard(List<SObject> records) {
        return Security.stripInaccessible(AccessType.READABLE, records);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getMarketData() {
        Map<String, Object> result = new Map<String, Object>();

        DateTime lastSync = null;

        List<Supply_Agreement__c> agreements = readGuard([
            SELECT Commodity_v2__c, Current_Price__c, LastModifiedDate
            FROM Supply_Agreement__c
            WHERE Commodity_v2__c != NULL AND Current_Price__c != NULL
            ORDER BY LastModifiedDate DESC
        ]).getRecords();

        Map<String, Decimal> priceByCommodity = new Map<String, Decimal>();
        for (Supply_Agreement__c ag : agreements) {
            if (!priceByCommodity.containsKey(ag.Commodity_v2__c)) {
                priceByCommodity.put(ag.Commodity_v2__c, ag.Current_Price__c);
            }
            if (lastSync == null || ag.LastModifiedDate > lastSync) {
                lastSync = ag.LastModifiedDate;
            }
        }

        List<Map<String, Object>> prices = new List<Map<String, Object>>();
        for (String commodity : priceByCommodity.keySet()) {
            prices.add(new Map<String, Object>{
                'commodity' => commodity,
                'price' => priceByCommodity.get(commodity)
            });
        }
        result.put('prices', prices);

        List<Fuel_Inventory__c> inventories = readGuard([
            SELECT Product__c, Product_Type__c, EIA_National_Stock__c, Current_Volume__c, LastModifiedDate
            FROM Fuel_Inventory__c
            WHERE EIA_National_Stock__c != NULL
            ORDER BY EIA_National_Stock__c DESC
        ]).getRecords();

        List<Map<String, Object>> stocks = new List<Map<String, Object>>();
        for (Fuel_Inventory__c inv : inventories) {
            stocks.add(new Map<String, Object>{
                'product' => inv.Product__c != null ? inv.Product__c : inv.Product_Type__c,
                'nationalStock' => inv.EIA_National_Stock__c,
                'localVolume' => inv.Current_Volume__c
            });
            if (lastSync == null || inv.LastModifiedDate > lastSync) {
                lastSync = inv.LastModifiedDate;
            }
        }
        result.put('stocks', stocks);

        result.put('asOf', lastSync);
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getSupplyAgreementPricing() {
        List<Supply_Agreement__c> agreements = readGuard([
            SELECT Name, Account__r.Name, Commodity_v2__c,
                   Current_Price__c, Previous_Price__c, Price_Change__c,
                   Price_Benchmark__c, Contract_Price__c, Price_Source__c,
                   Last_Sync_DateTime__c, Price_Variance_Limit__c
            FROM Supply_Agreement__c
            WHERE Commodity_v2__c != NULL AND Status__c != 'Expired'
            ORDER BY Commodity_v2__c, Name
        ]).getRecords();

        List<Supply_Agreement__c> spotRecords = readGuard([
            SELECT Commodity_v2__c, Current_Price__c
            FROM Supply_Agreement__c
            WHERE Commodity_v2__c != NULL AND Current_Price__c != NULL
        ]).getRecords();

        Map<String, Decimal> spotByCommodity = new Map<String, Decimal>();
        for (Supply_Agreement__c ag : spotRecords) {
            if (!spotByCommodity.containsKey(ag.Commodity_v2__c)) {
                spotByCommodity.put(ag.Commodity_v2__c, ag.Current_Price__c);
            }
        }

        Map<String, List<Map<String, Object>>> grouped = new Map<String, List<Map<String, Object>>>();
        for (Supply_Agreement__c ag : agreements) {
            String commodity = ag.Commodity_v2__c;
            if (!grouped.containsKey(commodity)) {
                grouped.put(commodity, new List<Map<String, Object>>());
            }

            Decimal spot = spotByCommodity.get(commodity);
            Decimal current = ag.Current_Price__c;
            Decimal variance = null;
            if (current != null && spot != null && spot > 0) {
                variance = ((current - spot) / spot * 100).setScale(2);
            }

            grouped.get(commodity).add(new Map<String, Object>{
                'id'             => ag.Id,
                'name'           => ag.Name,
                'account'        => ag.Account__r != null ? ag.Account__r.Name : null,
                'currentPrice'   => current,
                'previousPrice'  => ag.Previous_Price__c,
                'priceChange'    => ag.Price_Change__c,
                'benchmark'      => ag.Price_Benchmark__c,
                'contractPrice'  => ag.Contract_Price__c,
                'source'         => ag.Price_Source__c,
                'lastSync'       => ag.Last_Sync_DateTime__c,
                'varianceLimit'  => ag.Price_Variance_Limit__c,
                'variance'       => variance,
                'spotPrice'      => spot
            });
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (String commodity : grouped.keySet()) {
            result.add(new Map<String, Object>{
                'commodity'  => commodity,
                'spotPrice'  => spotByCommodity.get(commodity),
                'agreements' => grouped.get(commodity)
            });
        }

        return result;
    }
}
