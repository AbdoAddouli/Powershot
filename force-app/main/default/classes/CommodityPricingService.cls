/**
 * CommodityPricingService
 * ========================
 * Fetches real-time commodity prices from OilPriceAPI (https://oilpriceapi.com)
 * and updates Supply_Agreement__c records with current market rates.
 *
 * Business Process: Commodity Pricing (Commercial)
 *   Daily Sync → Fetch WTI, Brent, Gas, etc. → Update Supply Agreements
 *
 * CSP Trusted Site required: https://api.oilpriceapi.com
 */
public with sharing class CommodityPricingService {

    private static final String BASE_URL = 'callout:CommodityPricing';

    private static final Map<String, String> COMMODITY_CODE_MAP = new Map<String, String>{
        'Crude' => 'WTI_USD',
        'Gas' => 'NATURAL_GAS_USD',
        'NGL' => 'BRENT_CRUDE_USD',
        'Refined' => 'GASOLINE_USD',
        'Diesel' => 'DIESEL_USD',
        'Jet Fuel' => 'JET_FUEL_USD',
        'Heating Oil' => 'HEATING_OIL_USD'
    };

    @future(callout=true)
    public static void syncPrices(Set<Id> agreementIds) {
        List<Supply_Agreement__c> agreements = [
            SELECT Id, Commodity__c, Current_Price__c
            FROM Supply_Agreement__c
            WHERE Id IN :agreementIds
        ];

        if (agreements.isEmpty()) return;

        Set<String> commodities = new Set<String>();
        for (Supply_Agreement__c ag : agreements) {
            if (ag.Commodity__c != null) {
                commodities.add(ag.Commodity__c);
            }
        }

        Map<String, Decimal> priceByCode = new Map<String, Decimal>();

        for (String commodity : commodities) {
            String apiCode = COMMODITY_CODE_MAP.get(commodity);
            if (apiCode == null) continue;

            Decimal price = fetchPrice(apiCode);
            if (price != null) {
                priceByCode.put(commodity, price);
            }
        }

        List<Supply_Agreement__c> updates = new List<Supply_Agreement__c>();
        for (Supply_Agreement__c ag : agreements) {
            if (priceByCode.containsKey(ag.Commodity__c)) {
                ag.Current_Price__c = priceByCode.get(ag.Commodity__c);
                updates.add(ag);
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static Decimal fetchPrice(String apiCode) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_URL + '/prices/latest?by_code=' + apiCode);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Token {!$Credential.Password}');
        req.setTimeout(10000);

        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() != 200) return null;

            Map<String, Object> responseMap = (Map<String, Object>)
                JSON.deserializeUntyped(res.getBody());

            Map<String, Object> data = (Map<String, Object>) responseMap.get('data');
            if (data == null) return null;

            Object priceObj = data.get('price');
            if (priceObj instanceof Decimal) {
                return (Decimal) priceObj;
            } else if (priceObj instanceof Integer) {
                return Decimal.valueOf((Integer) priceObj);
            } else if (priceObj instanceof Long) {
                return Decimal.valueOf((Long) priceObj);
            } else if (priceObj instanceof Double) {
                return Decimal.valueOf((Double) priceObj);
            }
        } catch (Exception e) {
            System.debug('Failed to fetch price for ' + apiCode + ': ' + e.getMessage());
        }

        return null;
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
}
