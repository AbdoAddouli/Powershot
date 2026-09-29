/**
 * TestPhase2Wrappers
 * ===================
 * Tests the Phase 2 invocable wrapper classes and the new service methods they
 * delegate to: ProductionHistoryWrapper, PipelineIntegrityStatusWrapper (+ new
 * PipelineIntegrityService.getPipelineIntegrityStatus), and RoyaltyCalculationWrapper
 * (+ new RoyaltyCalculationService.getRoyaltySummary).
 */
@IsTest
public with sharing class TestPhase2Wrappers {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Test Operator');
        insert acct;

        Account partner = new Account(Name = 'JV Partner');
        insert partner;

        Lease__c lease = new Lease__c(
            Account__c = acct.Id,
            Status__c = 'Active',
            Royalty_Percent__c = 12.5,
            Working_Interest_Percent__c = 75,
            Revenue_Interest_Percent__c = 80
        );
        insert lease;

        Joint_Venture__c jv = new Joint_Venture__c(
            Account__c = acct.Id,
            Operator__c = partner.Id,
            Status__c = 'Active',
            Working_Interest_Percent__c = 25,
            Revenue_Interest_Percent__c = 20
        );
        insert jv;

        Well__c well = new Well__c(
            Name = 'Test Well',
            Lease__c = lease.Id,
            Account__c = acct.Id,
            Status__c = 'Producing',
            API_Number__c = '42-123-45678'
        );
        insert well;

        Production_Allocation__c alloc = new Production_Allocation__c(
            Well__c = well.Id,
            Lease__c = lease.Id,
            Period_Start__c = Date.today().addMonths(-1),
            Period_End__c = Date.today(),
            Oil_Volume_bbls__c = 1000,
            Gas_Volume_MCF__c = 5000,
            Water_Volume_bbls__c = 200,
            Allocated_Revenue__c = 50000,
            Working_Interest_Share__c = 25,
            Net_Revenue_Interest_Share__c = 30
        );
        insert alloc;

        Pipeline__c pipeline = new Pipeline__c(
            Name = 'Test Pipeline',
            Status__c = 'Active',
            Compliance_Status__c = 'Compliant',
            Last_Inspection_Date__c = Date.today().addMonths(-6),
            Required_Inspection_Interval_Months__c = 12,
            Diameter_inches__c = 24,
            Capacity_bpd__c = 10000
        );
        insert pipeline;
    }

    @IsTest
    static void testProductionHistoryWrapperReturnsAllocations() {
        Well__c well = [SELECT Id FROM Well__c LIMIT 1];

        ProductionHistoryWrapper.ProductionHistoryRequest req =
            new ProductionHistoryWrapper.ProductionHistoryRequest();
        req.wellId = well.Id;
        req.months = 12;

        Test.startTest();
        List<ProductionHistoryWrapper.ProductionHistoryResult> results =
            ProductionHistoryWrapper.getProductionHistory(new List<ProductionHistoryWrapper.ProductionHistoryRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].success);
        Assert.isFalse(results[0].allocations.isEmpty());
        Assert.areEqual(1000, results[0].allocations[0].Oil_Volume_bbls__c);
    }

    @IsTest
    static void testProductionHistoryWrapperRequiresWellId() {
        ProductionHistoryWrapper.ProductionHistoryRequest req =
            new ProductionHistoryWrapper.ProductionHistoryRequest();
        req.wellId = null;

        List<ProductionHistoryWrapper.ProductionHistoryResult> results =
            ProductionHistoryWrapper.getProductionHistory(new List<ProductionHistoryWrapper.ProductionHistoryRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.isFalse(results[0].success);
        Assert.isNotNull(results[0].message);
    }

    @IsTest
    static void testPipelineIntegrityStatusWrapperCompliant() {
        Pipeline__c pipeline = [SELECT Id FROM Pipeline__c LIMIT 1];

        PipelineIntegrityStatusWrapper.PipelineIntegrityStatusRequest req =
            new PipelineIntegrityStatusWrapper.PipelineIntegrityStatusRequest();
        req.pipelineId = pipeline.Id;

        Test.startTest();
        List<PipelineIntegrityStatusWrapper.PipelineIntegrityStatusResult> results =
            PipelineIntegrityStatusWrapper.getPipelineIntegrityStatuses(
                new List<PipelineIntegrityStatusWrapper.PipelineIntegrityStatusRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].success);
        Assert.isTrue(results[0].isCompliant);
        Assert.areEqual('Compliant', results[0].complianceStatus);
        Assert.isNotNull(results[0].nextInspectionDueDate);
    }

    @IsTest
    static void testPipelineIntegrityStatusWrapperNotCompliant() {
        Pipeline__c pipeline = [SELECT Id FROM Pipeline__c LIMIT 1];
        pipeline.Last_Inspection_Date__c = Date.today().addMonths(-18);
        update pipeline;

        PipelineIntegrityStatusWrapper.PipelineIntegrityStatusRequest req =
            new PipelineIntegrityStatusWrapper.PipelineIntegrityStatusRequest();
        req.pipelineId = pipeline.Id;

        List<PipelineIntegrityStatusWrapper.PipelineIntegrityStatusResult> results =
            PipelineIntegrityStatusWrapper.getPipelineIntegrityStatuses(
                new List<PipelineIntegrityStatusWrapper.PipelineIntegrityStatusRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].success);
        Assert.isFalse(results[0].isCompliant);
    }

    @IsTest
    static void testPipelineIntegrityStatusWrapperRequiresPipelineId() {
        PipelineIntegrityStatusWrapper.PipelineIntegrityStatusRequest req =
            new PipelineIntegrityStatusWrapper.PipelineIntegrityStatusRequest();
        req.pipelineId = null;

        List<PipelineIntegrityStatusWrapper.PipelineIntegrityStatusResult> results =
            PipelineIntegrityStatusWrapper.getPipelineIntegrityStatuses(
                new List<PipelineIntegrityStatusWrapper.PipelineIntegrityStatusRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.isFalse(results[0].success);
    }

    @IsTest
    static void testRoyaltyCalculationWrapperSummary() {
        Lease__c lease = [SELECT Id FROM Lease__c LIMIT 1];

        RoyaltyCalculationWrapper.RoyaltyCalculationRequest req =
            new RoyaltyCalculationWrapper.RoyaltyCalculationRequest();
        req.leaseId = lease.Id;
        req.periodStart = Date.today().addMonths(-2);
        req.periodEnd = Date.today();

        Test.startTest();
        List<RoyaltyCalculationWrapper.RoyaltyCalculationResult> results =
            RoyaltyCalculationWrapper.calculateRoyalties(
                new List<RoyaltyCalculationWrapper.RoyaltyCalculationRequest>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].success);
        Assert.areEqual(50000, results[0].totalAllocatedRevenue);
        Assert.areEqual(12.5, results[0].royaltyRatePercent);
        Assert.areEqual(6250, results[0].totalRoyalty);
    }

    @IsTest
    static void testRoyaltyCalculationWrapperRequiresLeaseId() {
        RoyaltyCalculationWrapper.RoyaltyCalculationRequest req =
            new RoyaltyCalculationWrapper.RoyaltyCalculationRequest();
        req.leaseId = null;

        List<RoyaltyCalculationWrapper.RoyaltyCalculationResult> results =
            RoyaltyCalculationWrapper.calculateRoyalties(
                new List<RoyaltyCalculationWrapper.RoyaltyCalculationRequest>{ req });

        Assert.areEqual(1, results.size());
        Assert.isFalse(results[0].success);
    }

    @IsTest
    static void testPipelineIntegrityServiceGetStatus() {
        Pipeline__c pipeline = [SELECT Id FROM Pipeline__c LIMIT 1];

        Test.startTest();
        PipelineIntegrityService.PipelineIntegrityStatus status =
            PipelineIntegrityService.getPipelineIntegrityStatus(pipeline.Id);
        Test.stopTest();

        Assert.areEqual(pipeline.Id, status.pipelineId);
        Assert.areEqual('Compliant', status.complianceStatus);
        Assert.isTrue(status.isCompliant);
        Assert.areEqual(12, status.requiredIntervalMonths);
    }

    @IsTest
    static void testRoyaltyCalculationServiceGetSummaryPartners() {
        Lease__c lease = [SELECT Id FROM Lease__c LIMIT 1];

        Test.startTest();
        RoyaltyCalculationService.RoyaltySummary summary =
            RoyaltyCalculationService.getRoyaltySummary(lease.Id, Date.today().addMonths(-2), Date.today());
        Test.stopTest();

        Assert.areEqual(50000, summary.totalAllocatedRevenue);
        Assert.areEqual(12.5, summary.royaltyRatePercent);
        Assert.areEqual(6250, summary.totalRoyalty);
        Assert.areEqual(1, summary.partnerShares.size());
        Assert.areEqual(20, summary.partnerShares[0].revenueInterestPercent);
        Assert.areEqual(1250, summary.partnerShares[0].payment);
    }
}
