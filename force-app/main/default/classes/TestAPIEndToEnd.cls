public with sharing class TestAPIEndToEnd {
    private static final String COMMODITY_URL = 'callout:CommodityPricing/prices/latest?by_code=WTI_USD';
    private static final String EIA_PRICE_URL = 'callout:EIA_API/v2/petroleum/pri/gnd/data/';
    private static final String EIA_STOCK_URL = 'callout:EIA_API/v2/petroleum/stoc/wstk/data/';

    @future(callout=true)
    public static void testAllAPIs() {
        System.debug('=== TestAPIEndToEnd Starting ===');
        testCommodityCallout();
        testEIACallouts();
        System.debug('=== TestAPIEndToEnd Complete ===');
    }

    @future(callout=true)
    public static void testCommodityAPI() {
        System.debug('=== Commodity API Test ===');
        testCommodityCallout();
    }

    @future(callout=true)
    public static void testEIAAPI() {
        System.debug('=== EIA API Test ===');
        testEIACallouts();
    }

    private static void testCommodityCallout() {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(COMMODITY_URL);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Token {!$Credential.Password}');
        req.setTimeout(10000);

        try {
            HttpResponse res = http.send(req);
            System.debug('*** Commodity API Status: ' + res.getStatusCode());
            if (res.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Object> data = (Map<String, Object>) body.get('data');
                System.debug('*** SUCCESS: Commodity Price = ' + data.get('price') + ' ' + data.get('formatted'));
            }
        } catch (Exception e) {
            System.debug('*** ERROR: Commodity API failed: ' + e.getMessage());
        }
    }

    private static void testEIACallouts() {
        Http http = new Http();

        // Test Price API
        HttpRequest priceReq = new HttpRequest();
        String priceEndpoint = EIA_PRICE_URL + '?frequency=weekly&data[0]=value&facets[product][]=EPM0'
            + '&facets[duoarea][]=NUS&facets[process][]=PTE'
            + '&sort[0][column]=period&sort[0][direction]=desc&length=1';
        priceReq.setEndpoint(priceEndpoint);
        priceReq.setMethod('GET');
        priceReq.setHeader('X-Api-Key', '{!$Credential.Password}');
        priceReq.setTimeout(15000);

        try {
            HttpResponse res = http.send(priceReq);
            System.debug('*** EIA Price API Status: ' + res.getStatusCode());
            if (res.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Object> response = (Map<String, Object>) body.get('response');
                List<Object> data = (List<Object>) response.get('data');
                if (data != null && !data.isEmpty()) {
                    Map<String, Object> row = (Map<String, Object>) data[0];
                    System.debug('*** SUCCESS: EIA Price = ' + row.get('value') + ' ' + row.get('units'));
                } else {
                    System.debug('*** NOTE: EIA Price returned no data rows');
                }
            }
        } catch (Exception e) {
            System.debug('*** ERROR: EIA Price API failed: ' + e.getMessage());
        }

        // Test Stock API
        HttpRequest stockReq = new HttpRequest();
        String stockEndpoint = EIA_STOCK_URL + '?frequency=weekly&data[0]=value&facets[product][]=EPC0'
            + '&facets[duoarea][]=NUS&facets[process][]=SAE'
            + '&sort[0][column]=period&sort[0][direction]=desc&length=1';
        stockReq.setEndpoint(stockEndpoint);
        stockReq.setMethod('GET');
        stockReq.setHeader('X-Api-Key', '{!$Credential.Password}');
        stockReq.setTimeout(15000);

        try {
            HttpResponse res = http.send(stockReq);
            System.debug('*** EIA Stock API Status: ' + res.getStatusCode());
            if (res.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Object> response = (Map<String, Object>) body.get('response');
                List<Object> data = (List<Object>) response.get('data');
                if (data != null && !data.isEmpty()) {
                    Map<String, Object> row = (Map<String, Object>) data[0];
                    System.debug('*** SUCCESS: EIA Stock = ' + row.get('value') + ' ' + row.get('units'));
                } else {
                    System.debug('*** NOTE: EIA Stock returned no data rows');
                }
            }
        } catch (Exception e) {
            System.debug('*** ERROR: EIA Stock API failed: ' + e.getMessage());
        }
    }
}
