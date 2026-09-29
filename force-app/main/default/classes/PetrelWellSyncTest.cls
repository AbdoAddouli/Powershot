/**
 * PetrelWellSyncTest
 * ===================
 * Test class for PetrelWellSync with HTTP callout mocking.
 */
@isTest
private class PetrelWellSyncTest {

    @isTest
    static void testSyncWells() {
        Test.setMock(HttpCalloutMock.class, new PetrelAPIMock());

        Test.startTest();
        PetrelWellSync.syncWells();
        Test.stopTest();

        List<Well__c> wells = [SELECT Id, Name, API_Number__c, Total_Depth__c,
                                      True_Vertical_Depth__c, Formation__c,
                                      Well_Type__c, Status__c
                               FROM Well__c];
        System.assertEquals(2, wells.size(), 'Should create 2 wells from mock data');

        Map<String, Well__c> wellsByApi = new Map<String, Well__c>();
        for (Well__c w : wells) {
            wellsByApi.put(w.API_Number__c, w);
        }

        System.assert(wellsByApi.containsKey('42001000010000'), 'Well 1 should exist');
        System.assertEquals('Well Alpha', wellsByApi.get('42001000010000').Name);
        System.assertEquals(12500, wellsByApi.get('42001000010000').Total_Depth__c);
        System.assertEquals(9800, wellsByApi.get('42001000010000').True_Vertical_Depth__c);
        System.assertEquals('Woodbine', wellsByApi.get('42001000010000').Formation__c);
        System.assertEquals('Oil', wellsByApi.get('42001000010000').Well_Type__c);
        System.assertEquals('Producing', wellsByApi.get('42001000010000').Status__c);
    }

    @isTest
    static void testSyncWellsUpsert() {
        insert new Well__c(
            Name = 'Existing Well',
            API_Number__c = '42001000010000',
            Total_Depth__c = 10000,
            Status__c = 'Drilling'
        );

        Test.setMock(HttpCalloutMock.class, new PetrelAPIMock());

        Test.startTest();
        PetrelWellSync.syncWells();
        Test.stopTest();

        List<Well__c> wells = [SELECT Id, Name, Total_Depth__c, Well_Type__c, Status__c
                               FROM Well__c ORDER BY Name];
        System.assertEquals(2, wells.size(), 'Should have 1 upserted + 1 new');

        Well__c existing = [SELECT Total_Depth__c, Well_Type__c, Status__c
                            FROM Well__c WHERE API_Number__c = '42001000010000'];
        System.assertEquals(12500, existing.Total_Depth__c, 'Should update depth');
        System.assertEquals('Oil', existing.Well_Type__c, 'Should update well type');
        System.assertEquals('Producing', existing.Status__c, 'Should update status');
    }

    @isTest
    static void testExecuteSchedulable() {
        Test.setMock(HttpCalloutMock.class, new PetrelAPIMock());

        Test.startTest();
        new PetrelWellSync().execute(null);
        Test.stopTest();

        List<Well__c> wells = [SELECT Id FROM Well__c];
        System.assertEquals(2, wells.size());
    }

    private class PetrelAPIMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('[{' +
                '"apiNumber": "42001000010000",' +
                '"wellName": "Well Alpha",' +
                '"totalDepth": 12500,' +
                '"tvd": 9800,' +
                '"formation": "Woodbine",' +
                '"wellType": "Oil",' +
                '"status": "Producing"' +
            '},{' +
                '"apiNumber": "42001000010001",' +
                '"wellName": "Well Beta",' +
                '"totalDepth": 15000,' +
                '"tvd": 12000,' +
                '"formation": "Eagle Ford",' +
                '"wellType": "Gas",' +
                '"status": "Drilling"' +
            '}]');
            return res;
        }
    }
}
