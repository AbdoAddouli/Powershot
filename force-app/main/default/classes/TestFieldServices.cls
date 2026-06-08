/**
 * TestFieldServices
 * ==================
 * Tests inspection checklist operations (getChecklistItems, submitChecklist),
 * inspection trigger (asset date rollup, recurring creation), pipeline integrity
 * compliance checks, and Permit-to-Work validation rules (isolation, gas test,
 * authorization chain, missing requirements).
 */
@IsTest
public with sharing class TestFieldServices {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Test Operator');
        insert acct;

        Asset asset = new Asset(
            Name = 'Test Pump',
            AccountId = acct.Id,
            Last_Inspection_Date__c = Date.today().addDays(-30),
            Inspection_Frequency_Days__c = 90
        );
        insert asset;

        Inspection__c inspection = new Inspection__c(
            Asset__c = asset.Id,
            Inspection_Type__c = 'Safety',
            Status__c = 'Scheduled',
            Scheduled_Date__c = Date.today(),
            Is_Recurring__c = true,
            Recurring_Interval_Days__c = 90
        );
        insert inspection;

        Permit_to_Work__c ptw = new Permit_to_Work__c(
            Permit_Type__c = 'Hot Work',
            Status__c = 'Issued',
            Risk_Level__c = 'Medium',
            Start_DateTime__c = DateTime.now(),
            End_DateTime__c = DateTime.now().addHours(8)
        );
        insert ptw;

        WorkOrder wo = new WorkOrder(
            Subject = 'Test Work',
            Permit_to_Work__c = ptw.Id,
            Status = 'New'
        );
        insert wo;

        Pipeline__c pipeline = new Pipeline__c(
            Name = 'Test Pipeline',
            Status__c = 'Active',
            Compliance_Status__c = 'Compliant',
            Last_Inspection_Date__c = Date.today().addMonths(-6),
            Required_Inspection_Interval_Months__c = 12
        );
        insert pipeline;

        Inspection__c pipelineInsp = new Inspection__c(
            Pipeline__c = pipeline.Id,
            Inspection_Type__c = 'Integrity',
            Status__c = 'Completed',
            Scheduled_Date__c = Date.today().addDays(-30),
            Inspection_Date__c = Date.today().addDays(-30),
            Is_Recurring__c = true,
            Recurring_Interval_Days__c = 180
        );
        insert pipelineInsp;
    }

    @IsTest
    static void testInspectionServiceGetChecklistItems() {
        Asset asset = [SELECT Id FROM Asset LIMIT 1];
        Test.startTest();
        List<Inspection__c> items = InspectionService.getChecklistItems(asset.Id, 'Safety');
        Test.stopTest();
        Assert.isFalse(items.isEmpty());
    }

    @IsTest
    static void testInspectionServiceSubmitChecklist() {
        Inspection__c inspection = [SELECT Id FROM Inspection__c WHERE Inspection_Type__c = 'Safety' LIMIT 1];

        String jsonData = '[{"Id":"' + inspection.Id + '","Status__c":"Completed","Comment__c":"All good"}]';
        Test.startTest();
        InspectionService.submitChecklist(jsonData, null);
        Test.stopTest();

        Inspection__c updated = [SELECT Id, Status__c, Completed_Date__c, Findings__c FROM Inspection__c WHERE Id = :inspection.Id];
        Assert.areEqual('Completed', updated.Status__c);
        Assert.areEqual(Date.today(), updated.Completed_Date__c);
        Assert.areEqual('All good', updated.Findings__c);
    }

    @IsTest
    static void testInspectionTriggerUpdatesAsset() {
        Inspection__c inspection = [SELECT Id, Asset__c FROM Inspection__c WHERE Asset__c != NULL LIMIT 1];
        inspection.Status__c = 'Completed';
        inspection.Completed_Date__c = Date.today();
        inspection.Inspection_Date__c = Date.today();

        Test.startTest();
        update inspection;
        Test.stopTest();

        Asset asset = [SELECT Id, Last_Inspection_Date__c FROM Asset WHERE Id = :inspection.Asset__c];
        Assert.areEqual(Date.today(), asset.Last_Inspection_Date__c);
    }

    @IsTest
    static void testInspectionTriggerCreatesRecurring() {
        Inspection__c inspection = [SELECT Id, Is_Recurring__c, Recurring_Interval_Days__c FROM Inspection__c WHERE Is_Recurring__c = true LIMIT 1];
        inspection.Status__c = 'Completed';
        inspection.Inspection_Date__c = Date.today();
        update inspection;

        Test.startTest();
        inspection.Status__c = 'Completed';
        inspection.Inspection_Date__c = Date.today();
        update inspection;
        Test.stopTest();

        List<Inspection__c> nextInspections = [SELECT Id, Parent_Inspection__c, Status__c, Scheduled_Date__c FROM Inspection__c WHERE Parent_Inspection__c != NULL];
        Assert.isFalse(nextInspections.isEmpty());
    }

    @IsTest
    static void testPipelineIntegrityIsCompliant() {
        Pipeline__c pipeline = [SELECT Id FROM Pipeline__c LIMIT 1];
        Test.startTest();
        Boolean compliant = PipelineIntegrityService.isInspectionCompliant(pipeline.Id);
        Test.stopTest();
        Assert.isTrue(compliant);
    }

    @IsTest
    static void testPipelineIntegrityIsNotCompliant() {
        Pipeline__c pipeline = [SELECT Id FROM Pipeline__c LIMIT 1];
        pipeline.Last_Inspection_Date__c = Date.today().addMonths(-18);
        update pipeline;

        Test.startTest();
        Boolean compliant = PipelineIntegrityService.isInspectionCompliant(pipeline.Id);
        Test.stopTest();
        Assert.isFalse(compliant);
    }

    @IsTest
    static void testPipelineIntegrityFlagNonCompliant() {
        Pipeline__c pipeline = [SELECT Id FROM Pipeline__c LIMIT 1];
        pipeline.Last_Inspection_Date__c = Date.today().addMonths(-18);
        update pipeline;

        Test.startTest();
        PipelineIntegrityService.flagNonCompliantPipelines();
        Test.stopTest();

        Pipeline__c updated = [SELECT Id, Compliance_Status__c FROM Pipeline__c WHERE Id = :pipeline.Id];
        Assert.areEqual('Non-Compliant', updated.Compliance_Status__c);
    }

    @IsTest
    static void testPipelineIntegrityCalculateNextDue() {
        Pipeline__c pipeline = [SELECT Id FROM Pipeline__c LIMIT 1];
        pipeline.Last_Inspection_Date__c = Date.today().addMonths(-6);
        update pipeline;

        Test.startTest();
        Date nextDue = PipelineIntegrityService.calculateNextInspectionDueDate(pipeline.Id);
        Test.stopTest();

        Assert.areEqual(Date.today().addMonths(6), nextDue);
    }

    @IsTest
    static void testPermitValidationIsolation() {
        Permit_to_Work__c ptw = [SELECT Id FROM Permit_to_Work__c LIMIT 1];
        ptw.Isolation_Required__c = true;
        ptw.Isolation_Verified__c = true;
        ptw.Lockout_Tagout_Completed__c = true;
        ptw.Zero_Energy_State_Verified__c = true;
        update ptw;

        Test.startTest();
        Boolean valid = PermitToWorkValidationService.validateIsolationRequirements(ptw.Id);
        Test.stopTest();
        Assert.isTrue(valid);
    }

    @IsTest
    static void testPermitValidationIsolationFailsWhenNotVerified() {
        Permit_to_Work__c ptw = [SELECT Id FROM Permit_to_Work__c LIMIT 1];
        ptw.Isolation_Required__c = true;
        ptw.Isolation_Verified__c = false;
        update ptw;

        Test.startTest();
        Boolean valid = PermitToWorkValidationService.validateIsolationRequirements(ptw.Id);
        Test.stopTest();
        Assert.isFalse(valid);
    }

    @IsTest
    static void testPermitValidationGasTest() {
        Permit_to_Work__c ptw = [SELECT Id FROM Permit_to_Work__c LIMIT 1];
        ptw.Gas_Test_Required__c = true;
        ptw.Gas_Test_Completed__c = true;
        ptw.Oxygen_Level_Pct__c = 20.9;
        ptw.LEL_Pct__c = 5;
        ptw.H2S_Level_Ppm__c = 0;
        ptw.CO_Level_Ppm__c = 0;
        update ptw;

        Test.startTest();
        Boolean valid = PermitToWorkValidationService.validateGasTestResults(ptw.Id);
        Test.stopTest();
        Assert.isTrue(valid);
    }

    @IsTest
    static void testPermitValidationGasTestFails() {
        Permit_to_Work__c ptw = [SELECT Id FROM Permit_to_Work__c LIMIT 1];
        ptw.Gas_Test_Required__c = true;
        ptw.Gas_Test_Completed__c = true;
        ptw.LEL_Pct__c = 15;
        update ptw;

        Test.startTest();
        Boolean valid = PermitToWorkValidationService.validateGasTestResults(ptw.Id);
        Test.stopTest();
        Assert.isFalse(valid);
    }

    @IsTest
    static void testPermitValidationAuthorization() {
        Permit_to_Work__c ptw = [SELECT Id FROM Permit_to_Work__c LIMIT 1];
        ptw.Risk_Level__c = 'Low';
        ptw.Permit_Type__c = 'Work at Height';
        ptw.Authorizer__c = UserInfo.getUserId();
        ptw.Authorization_Date__c = Date.today();
        update ptw;

        Test.startTest();
        Boolean valid = PermitToWorkValidationService.validateAuthorizationChain(ptw.Id);
        Test.stopTest();
        Assert.isTrue(valid);
    }

    @IsTest
    static void testPermitValidationAuthorizationFails() {
        Permit_to_Work__c ptw = [SELECT Id FROM Permit_to_Work__c LIMIT 1];
        ptw.Risk_Level__c = 'High';
        ptw.Authorizer__c = null;
        update ptw;

        Test.startTest();
        Boolean valid = PermitToWorkValidationService.validateAuthorizationChain(ptw.Id);
        Test.stopTest();
        Assert.isFalse(valid);
    }

    @IsTest
    static void testGetMissingRequirements() {
        Permit_to_Work__c ptw = [SELECT Id FROM Permit_to_Work__c LIMIT 1];
        ptw.Scope_of_Work__c = 'Short';
        ptw.Valid_From__c = null;
        ptw.PTW_Number__c = null;
        ptw.Issuing_Authority__c = null;
        update ptw;

        Test.startTest();
        List<String> missing = PermitToWorkValidationService.getMissingRequirements(ptw.Id);
        Test.stopTest();

        Assert.isTrue(missing.size() >= 3);
    }
}
