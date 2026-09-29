/**
 * TestWellLifecycle
 * ==================
 * Tests the well lifecycle state machine (WellStatusService) including valid
 * and invalid transitions, Well_Operation__c creation on status changes,
 * abandonment queries, and the WellTrigger / AssetTrigger field defaults.
 */
@IsTest
public with sharing class TestWellLifecycle {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Test Operator');
        insert acct;

        Lease__c lease = new Lease__c(
            Account__c = acct.Id,
            Status__c = 'Active',
            Royalty_Percent__c = 12.5,
            Working_Interest_Percent__c = 75,
            Revenue_Interest_Percent__c = 80,
            Lease_End_Date__c = Date.today().addYears(5)
        );
        insert lease;

        Well__c well = new Well__c(
            Name = 'Test Well',
            Lease__c = lease.Id,
            Account__c = acct.Id,
            Status__c = 'Permitted',
            API_Number__c = '42-123-45678'
        );
        insert well;

        Well__c shutInWell = new Well__c(
            Name = 'Shut-In Well',
            Lease__c = lease.Id,
            Account__c = acct.Id,
            Status__c = 'Shut-In',
            Status_Change_Date__c = Date.today().addMonths(-25),
            API_Number__c = '42-123-45679'
        );
        insert shutInWell;
    }

    @IsTest
    static void testValidTransition() {
        Well__c well = [SELECT Id, Status__c FROM Well__c WHERE Status__c = 'Permitted' LIMIT 1];
        Test.startTest();
        Boolean valid = WellStatusService.isValidTransition(well.Status__c, 'Drilling');
        Test.stopTest();
        Assert.isTrue(valid, 'Permitted -> Drilling should be valid');
    }

    @IsTest
    static void testInvalidTransition() {
        Well__c well = [SELECT Id, Status__c FROM Well__c WHERE Status__c = 'Permitted' LIMIT 1];
        Test.startTest();
        Boolean valid = WellStatusService.isValidTransition(well.Status__c, 'Abandoned');
        Test.stopTest();
        Assert.isFalse(valid, 'Permitted -> Abandoned should be invalid');
    }

    @IsTest
    static void testTransitionWellStatus() {
        Well__c well = [SELECT Id, Status__c FROM Well__c WHERE Status__c = 'Permitted' LIMIT 1];
        Test.startTest();
        WellStatusService.transitionWellStatus(well.Id, 'Drilling');
        Test.stopTest();

        Well__c updated = [SELECT Id, Status__c, Status_Change_Date__c FROM Well__c WHERE Id = :well.Id];
        Assert.areEqual('Drilling', updated.Status__c);
        Assert.areEqual(Date.today(), updated.Status_Change_Date__c);
    }

    @IsTest
    static void testInvalidTransitionThrows() {
        Well__c well = [SELECT Id, Status__c FROM Well__c WHERE Status__c = 'Permitted' LIMIT 1];
        Test.startTest();
        try {
            WellStatusService.transitionWellStatus(well.Id, 'Abandoned');
            Assert.fail('Should have thrown');
        } catch (WellStatusService.WellStatusException e) {
            Assert.isTrue(e.getMessage().contains('Invalid status transition'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testInvocableTransitionWellStatusSuccess() {
        Well__c well = [SELECT Id, Status__c FROM Well__c WHERE Status__c = 'Permitted' LIMIT 1];
        WellStatusService.WellStatusChangeRequest req = new WellStatusService.WellStatusChangeRequest();
        req.wellId = well.Id;
        req.newStatus = 'Drilling';

        Test.startTest();
        List<WellStatusService.WellStatusChangeResult> results =
            WellStatusService.transitionWellStatuses(new List<WellStatusService.WellStatusChangeRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].success);
        Assert.isTrue(results[0].message.contains('Drilling'));
        Well__c updated = [SELECT Id, Status__c FROM Well__c WHERE Id = :well.Id];
        Assert.areEqual('Drilling', updated.Status__c);
    }

    @IsTest
    static void testInvocableTransitionWellStatusInvalid() {
        Well__c well = [SELECT Id, Status__c FROM Well__c WHERE Status__c = 'Permitted' LIMIT 1];
        WellStatusService.WellStatusChangeRequest req = new WellStatusService.WellStatusChangeRequest();
        req.wellId = well.Id;
        req.newStatus = 'Abandoned';

        Test.startTest();
        List<WellStatusService.WellStatusChangeResult> results =
            WellStatusService.transitionWellStatuses(new List<WellStatusService.WellStatusChangeRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isFalse(results[0].success);
        Assert.isTrue(results[0].message.contains('Invalid status transition'));
    }

    @IsTest
    static void testCreateWellOperationOnStatusChange() {
        Well__c well = [SELECT Id, Name, Status__c, Status_Change_Date__c FROM Well__c WHERE Status__c = 'Permitted' LIMIT 1];
        well.Status__c = 'Drilling';
        Test.startTest();
        WellStatusService.createWellOperations(new List<Well__c>{ well });
        Test.stopTest();

        List<Well_Operation__c> ops = [SELECT Id, Well__c, Operation_Type__c, Status__c FROM Well_Operation__c WHERE Well__c = :well.Id];
        Assert.areEqual(1, ops.size());
        Assert.areEqual('Status Change', ops[0].Operation_Type__c);
        Assert.areEqual('Drilling', ops[0].Status__c);
        Assert.areEqual(well.Id, ops[0].Well__c);
    }

    @IsTest
    static void testGetWellsDueForAbandonment() {
        Well__c well = [SELECT Id FROM Well__c WHERE Status__c = 'Shut-In' LIMIT 1];

        Test.startTest();
        List<Well__c> due = WellStatusService.getWellsDueForAbandonment();
        Test.stopTest();

        Assert.areEqual(1, due.size());
        Assert.areEqual(well.Id, due[0].Id);
    }

    @IsTest
    static void testWellTriggerDefaultStatus() {
        Well__c well = new Well__c(
            Name = 'New Well',
            API_Number__c = '42-999-99999'
        );
        Test.startTest();
        insert well;
        Test.stopTest();

        Well__c inserted = [SELECT Id, Status__c, Status_Change_Date__c FROM Well__c WHERE Id = :well.Id];
        Assert.areEqual('Permitted', inserted.Status__c);
        Assert.areEqual(Date.today(), inserted.Status_Change_Date__c);
    }

    @IsTest
    static void testWellTriggerRejectsInvalidTransition() {
        Well__c well = [SELECT Id, Status__c FROM Well__c LIMIT 1];
        well.Status__c = 'Abandoned';

        Test.startTest();
        try {
            update well;
            Assert.fail('Should have thrown');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Invalid status transition'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testWellTriggerCreatesOperationOnInsert() {
        Well__c well = new Well__c(
            Name = 'Active Well',
            Status__c = 'Drilling',
            API_Number__c = '42-888-88888'
        );
        Test.startTest();
        insert well;
        Test.stopTest();

        List<Well_Operation__c> ops = [SELECT Id, Well__c FROM Well_Operation__c WHERE Well__c = :well.Id];
        Assert.isFalse(ops.isEmpty(), 'Should create operation on insert for non-Permitted status');
    }

    @IsTest
    static void testAssetTriggerCalcSchedule() {
        Account acct = new Account(Name = 'Asset Owner');
        insert acct;
        Asset asset = new Asset(
            Name = 'Test Pump',
            AccountId = acct.Id,
            Last_Inspection_Date__c = Date.today().addDays(-30),
            Inspection_Frequency_Days__c = 90
        );
        Test.startTest();
        insert asset;
        Test.stopTest();

        Asset inserted = [SELECT Id, Next_Inspection_Date__c, Maintenance_Schedule__c FROM Asset WHERE Id = :asset.Id];
        Assert.areEqual(Date.today().addDays(60), inserted.Next_Inspection_Date__c);
        Assert.areEqual('Quarterly', inserted.Maintenance_Schedule__c);
    }

    @IsTest
    static void testAssetTriggerBeyondLife() {
        Account acct = new Account(Name = 'Asset Owner 2');
        insert acct;
        Asset asset = new Asset(
            Name = 'Old Pump',
            AccountId = acct.Id,
            PurchaseDate = Date.today().addDays(-400),
            Expected_Lifespan_Days__c = 365
        );
        insert asset;

        Asset inserted = [SELECT Id, Status__c FROM Asset WHERE Id = :asset.Id];
        Assert.areEqual('Beyond Expected Life', inserted.Status__c);
    }

    @IsTest
    static void testAssetTriggerMonthly() {
        Account acct = new Account(Name = 'Asset Owner Monthly');
        insert acct;
        Asset asset = new Asset(
            Name = 'Monthly Pump',
            AccountId = acct.Id,
            Last_Inspection_Date__c = Date.today().addDays(-15),
            Inspection_Frequency_Days__c = 30
        );
        Test.startTest();
        insert asset;
        Test.stopTest();
        Asset inserted = [SELECT Id, Maintenance_Schedule__c FROM Asset WHERE Id = :asset.Id];
        Assert.areEqual('Monthly', inserted.Maintenance_Schedule__c);
    }

    @IsTest
    static void testAssetTriggerSemiAnnual() {
        Account acct = new Account(Name = 'Asset Owner SA');
        insert acct;
        Asset asset = new Asset(
            Name = 'SA Pump',
            AccountId = acct.Id,
            Last_Inspection_Date__c = Date.today().addDays(-120),
            Inspection_Frequency_Days__c = 120
        );
        Test.startTest();
        insert asset;
        Test.stopTest();
        Asset inserted = [SELECT Id, Maintenance_Schedule__c FROM Asset WHERE Id = :asset.Id];
        Assert.areEqual('Semi-Annual', inserted.Maintenance_Schedule__c);
    }

    @IsTest
    static void testAssetTriggerAnnual() {
        Account acct = new Account(Name = 'Asset Owner Annual');
        insert acct;
        Asset asset = new Asset(
            Name = 'Annual Pump',
            AccountId = acct.Id,
            Last_Inspection_Date__c = Date.today().addDays(-200),
            Inspection_Frequency_Days__c = 200
        );
        Test.startTest();
        insert asset;
        Test.stopTest();
        Asset inserted = [SELECT Id, Maintenance_Schedule__c FROM Asset WHERE Id = :asset.Id];
        Assert.areEqual('Annual', inserted.Maintenance_Schedule__c);
    }
}
