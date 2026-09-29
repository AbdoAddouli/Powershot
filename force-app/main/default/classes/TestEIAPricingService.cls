@IsTest
public with sharing class TestEIAPricingService {

    @IsTest
    static void testParseResponseReturnsData() {
        String json = '{"response":{"data":[{"period":"2026-06-15","value":"4.187","units":"$/GAL","product-name":"Total Gasoline"}]}}';
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody(json);

        List<Map<String, Object>> data = EIAPricingService.parseResponse(res);

        Assert.areEqual(1, data.size());
        Assert.areEqual('4.187', (String) data[0].get('value'));
        Assert.areEqual('$/GAL', (String) data[0].get('units'));
        Assert.areEqual('Total Gasoline', (String) data[0].get('product-name'));
        Assert.areEqual('2026-06-15', (String) data[0].get('period'));
    }

    @IsTest
    static void testParseResponseReturnsNullOnNon200() {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(401);
        res.setBody('{"error":"Unauthorized"}');

        List<Map<String, Object>> data = EIAPricingService.parseResponse(res);

        Assert.isNull(data);
    }

    @IsTest
    static void testParseResponseReturnsNullOnInvalidJson() {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('not valid json');

        List<Map<String, Object>> data = EIAPricingService.parseResponse(res);

        Assert.isNull(data);
    }

    @IsTest
    static void testParseResponseReturnsNullOnMissingResponse() {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"data":[{"value":"4.187"}]}');

        List<Map<String, Object>> data = EIAPricingService.parseResponse(res);

        Assert.isNull(data);
    }

    @IsTest
    static void testParseResponseReturnsNullOnNullBody() {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"response":null}');

        List<Map<String, Object>> data = EIAPricingService.parseResponse(res);

        Assert.isNull(data);
    }

    @IsTest
    static void testParseResponseHandlesEmptyData() {
        String json = '{"response":{"data":[]}}';
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody(json);

        List<Map<String, Object>> data = EIAPricingService.parseResponse(res);

        Assert.isNotNull(data);
        Assert.isTrue(data.isEmpty());
    }

    @IsTest
    static void testParseResponseHandlesMultipleRecords() {
        String json = '{"response":{"data":[{"value":"4.187"},{"value":"5.059"},{"value":"3.500"}]}}';
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody(json);

        List<Map<String, Object>> data = EIAPricingService.parseResponse(res);

        Assert.areEqual(3, data.size());
        Assert.areEqual('4.187', (String) data[0].get('value'));
        Assert.areEqual('5.059', (String) data[1].get('value'));
        Assert.areEqual('3.500', (String) data[2].get('value'));
    }

    @IsTest
    static void testProcessPriceSyncSkipsNullCommodity() {
        Account acct = new Account(Name = 'Test');
        insert acct;
        Supply_Agreement__c noCommodity = new Supply_Agreement__c(
            Account__c = acct.Id, Status__c = 'Active'
        );
        insert noCommodity;

        Test.startTest();
        EIAPricingService.processPriceSync(new Set<Id>{noCommodity.Id});
        Test.stopTest();

        Supply_Agreement__c updated = [SELECT Id, Current_Price__c FROM Supply_Agreement__c WHERE Id = :noCommodity.Id];
        Assert.isNull(updated.Current_Price__c);
    }

    @IsTest
    static void testProcessStockSyncSkipsNullProduct() {
        Account acct = new Account(Name = 'Test');
        insert acct;
        Terminal__c term = new Terminal__c(
            Account__c = acct.Id, Status__c = 'Operational', Storage_Capacity_bbls__c = 50000
        );
        insert term;
        Fuel_Inventory__c noProduct = new Fuel_Inventory__c(
            Terminal__c = term.Id, Current_Volume__c = 200,
            Maximum_Capacity__c = 5000, Minimum_Threshold__c = 500,
            Unit__c = 'Barrels', Storage_Location__c = 'Tank'
        );
        insert noProduct;

        Test.startTest();
        EIAPricingService.processStockSync(new Set<Id>{noProduct.Id});
        Test.stopTest();

        Fuel_Inventory__c updated = [SELECT Id, EIA_National_Stock__c FROM Fuel_Inventory__c WHERE Id = :noProduct.Id];
        Assert.isNull(updated.EIA_National_Stock__c);
    }

    @IsTest
    static void testProcessPriceSyncEmptySetDoesNothing() {
        Test.startTest();
        EIAPricingService.processPriceSync(new Set<Id>());
        Test.stopTest();
    }

    @IsTest
    static void testProcessStockSyncEmptySetDoesNothing() {
        Test.startTest();
        EIAPricingService.processStockSync(new Set<Id>());
        Test.stopTest();
    }

    @IsTest
    static void testSyncPricesForAgreementsPublicWrapper() {
        Account acct = new Account(Name = 'Test');
        insert acct;
        Supply_Agreement__c ag = new Supply_Agreement__c(
            Account__c = acct.Id,
            Commodity_v2__c = 'Refined', Status__c = 'Active'
        );
        insert ag;

        Test.startTest();
        EIAPricingService.syncPricesForAgreements(new List<Supply_Agreement__c>{ag});
        Test.stopTest();
    }

    @IsTest
    static void testSyncStocksForInventoriesPublicWrapper() {
        Account acct = new Account(Name = 'Test');
        insert acct;
        Terminal__c term = new Terminal__c(
            Account__c = acct.Id, Status__c = 'Operational', Storage_Capacity_bbls__c = 50000
        );
        insert term;
        Fuel_Inventory__c inv = new Fuel_Inventory__c(
            Terminal__c = term.Id, Product__c = 'Crude', Current_Volume__c = 500,
            Maximum_Capacity__c = 10000, Minimum_Threshold__c = 1000,
            Unit__c = 'Barrels', Storage_Location__c = 'Tank'
        );
        insert inv;

        Test.startTest();
        EIAPricingService.syncStocksForInventories(new List<Fuel_Inventory__c>{inv});
        Test.stopTest();
    }
}
