/**
 * EIAPricingService
 * ==================
 * Integrates with the U.S. Energy Information Administration (EIA) API
 * (https://www.eia.gov/opendata/) to fetch weekly retail fuel prices and
 * national inventory stock levels.
 *
 * Retail Prices (pri/gnd):
 *   Maps Supply_Agreement__c.Commodity_v2__c ('Refined', 'Gas') to EIA product
 *   code EPM0 (Total Gasoline) and updates Current_Price__c.
 *
 * Inventory Stocks (stoc/wstk):
 *   Maps Fuel_Inventory__c.Product__c / Product_Type__c to EIA product codes
 *   (EPC0=Crude, EPM0=Gasoline, EPDXL0=Diesel, EPJK=Jet Fuel, EPN0=NGL)
 *   and writes national ending-stock benchmarks to EIA_National_Stock__c.
 *
 * Business Process: Commodity Pricing & Inventory (Commercial / Downstream)
 *   Weekly Sync → Fetch Retail Prices + National Stocks → Update Records
 *
 * CSP Trusted Site required: https://api.eia.gov
 *
 * EIA API Docs: https://www.eia.gov/opendata/bulk-data.php
 */
public with sharing class EIAPricingService {

    private static final String BASE_URL = 'callout:EIA_API/v2';

    private static final Map<String, String> STOCK_PRODUCT_MAP = new Map<String, String>{
        'Crude' => 'EPC0',
        'Crude Oil' => 'EPC0',
        'Gasoline' => 'EPM0',
        'Diesel' => 'EPDXL0',
        'Jet Fuel' => 'EPJK',
        'NGL' => 'EPN0'
    };

    private static final Map<String, String> PRICE_PRODUCT_MAP = new Map<String, String>{
        'Refined' => 'EPM0',
        'Gas' => 'EPM0'
    };

    @future(callout=true)
    public static void syncPrices(Set<Id> agreementIds) {
        processPriceSync(agreementIds);
    }

    @future(callout=true)
    public static void syncStocks(Set<Id> inventoryIds) {
        processStockSync(inventoryIds);
    }

    public static void processPriceSync(Set<Id> agreementIds) {
        List<Supply_Agreement__c> agreements = [
            SELECT Id, Commodity_v2__c, Current_Price__c
            FROM Supply_Agreement__c
            WHERE Id IN :agreementIds AND Commodity_v2__c != NULL
        ];

        if (agreements.isEmpty()) return;

        Map<String, Decimal> priceByCommodity = new Map<String, Decimal>();

        Set<String> commodities = new Set<String>();
        for (Supply_Agreement__c ag : agreements) {
            commodities.add(ag.Commodity_v2__c);
        }

        for (String commodity : commodities) {
            String productCode = PRICE_PRODUCT_MAP.get(commodity);
            if (productCode == null) continue;

            Decimal price = fetchRetailPrice(productCode);
            if (price != null) {
                priceByCommodity.put(commodity, price);
            }
        }

        List<Supply_Agreement__c> updates = new List<Supply_Agreement__c>();
        for (Supply_Agreement__c ag : agreements) {
            if (priceByCommodity.containsKey(ag.Commodity_v2__c)) {
                ag.Current_Price__c = priceByCommodity.get(ag.Commodity_v2__c);
                updates.add(ag);
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public static void processStockSync(Set<Id> inventoryIds) {
        List<Fuel_Inventory__c> inventories = [
            SELECT Id, Product__c, Product_Type__c, Current_Volume__c, EIA_National_Stock__c
            FROM Fuel_Inventory__c
            WHERE Id IN :inventoryIds
        ];

        if (inventories.isEmpty()) return;

        Map<String, Decimal> stockByProduct = new Map<String, Decimal>();

        Set<String> products = new Set<String>();
        for (Fuel_Inventory__c inv : inventories) {
            String product = inv.Product__c != null ? inv.Product__c : inv.Product_Type__c;
            if (product != null) {
                products.add(product);
            }
        }

        for (String product : products) {
            String productCode = STOCK_PRODUCT_MAP.get(product);
            if (productCode == null) continue;

            Decimal stock = fetchNationalStock(productCode);
            if (stock != null) {
                stockByProduct.put(product, stock);
            }
        }

        List<Fuel_Inventory__c> updates = new List<Fuel_Inventory__c>();
        for (Fuel_Inventory__c inv : inventories) {
            String product = inv.Product__c != null ? inv.Product__c : inv.Product_Type__c;
            if (product != null && stockByProduct.containsKey(product)) {
                inv.EIA_National_Stock__c = stockByProduct.get(product);
                updates.add(inv);
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static Decimal fetchRetailPrice(String productCode) {
        String endpoint = BASE_URL + '/petroleum/pri/gnd/data/';
        String params = 'frequency=weekly'
            + '&data[0]=value'
            + '&facets[product][]=' + productCode
            + '&facets[duoarea][]=NUS'
            + '&facets[process][]=PTE'
            + '&sort[0][column]=period&sort[0][direction]=desc'
            + '&length=1';

        List<Map<String, Object>> data = callEIA(endpoint, params);
        if (data == null || data.isEmpty()) return null;

        String valStr = (String) data[0].get('value');
        if (valStr == null) return null;

        return Decimal.valueOf(valStr);
    }

    private static Decimal fetchNationalStock(String productCode) {
        String endpoint = BASE_URL + '/petroleum/stoc/wstk/data/';
        String params = 'frequency=weekly'
            + '&data[0]=value'
            + '&facets[product][]=' + productCode
            + '&facets[duoarea][]=NUS'
            + '&facets[process][]=SAE'
            + '&sort[0][column]=period&sort[0][direction]=desc'
            + '&length=1';

        List<Map<String, Object>> data = callEIA(endpoint, params);
        if (data == null || data.isEmpty()) return null;

        String valStr = (String) data[0].get('value');
        if (valStr == null) return null;

        return Decimal.valueOf(valStr);
    }

    private static List<Map<String, Object>> callEIA(String endpoint, String params) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint + '?' + params);
        req.setMethod('GET');
        req.setHeader('X-Api-Key', '{!$Credential.Password}');
        req.setTimeout(15000);

        try {
            HttpResponse res = http.send(req);
            return parseResponse(res);
        } catch (Exception e) {
            System.debug('EIA API call failed: ' + e.getMessage());
            return null;
        }
    }

    @TestVisible
    private static List<Map<String, Object>> parseResponse(HttpResponse res) {
        if (res.getStatusCode() != 200) {
            System.debug('EIA API error: ' + res.getStatusCode() + ' ' + res.getBody());
            return null;
        }

        try {
            Map<String, Object> responseMap = (Map<String, Object>)
                JSON.deserializeUntyped(res.getBody());

            Map<String, Object> response = (Map<String, Object>) responseMap.get('response');
            if (response == null) return null;

            List<Object> rawData = (List<Object>) response.get('data');
            if (rawData == null) return null;

            List<Map<String, Object>> result = new List<Map<String, Object>>();
            for (Object item : rawData) {
                result.add((Map<String, Object>) item);
            }
            return result;
        } catch (Exception e) {
            System.debug('EIA response parse failed: ' + e.getMessage());
            return null;
        }
    }

    public static void syncPricesForAgreements(List<Supply_Agreement__c> agreements) {
        Set<Id> ids = new Set<Id>();
        for (Supply_Agreement__c ag : agreements) {
            ids.add(ag.Id);
        }
        if (!ids.isEmpty()) {
            syncPrices(ids);
        }
    }

    public static void syncStocksForInventories(List<Fuel_Inventory__c> inventories) {
        Set<Id> ids = new Set<Id>();
        for (Fuel_Inventory__c inv : inventories) {
            ids.add(inv.Id);
        }
        if (!ids.isEmpty()) {
            syncStocks(ids);
        }
    }
}
