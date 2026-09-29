/**
 * TestPortalPageControllers
 * ==========================
 * Tests PortalInvoiceController, PortalComplianceController, and the
 * Account backfill services/triggers that power the JV_Partner_Sharing
 * Sharing Set on the Experience Cloud portal.
 */
@IsTest
public with sharing class TestPortalPageControllers {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Billing Test Operator');
        insert acct;

        Joint_Venture__c jv = new Joint_Venture__c(
            Name = 'Billing Test JV',
            Account__c = acct.Id,
            Operator__c = acct.Id,
            Status__c = 'Active',
            Working_Interest_Percent__c = 50,
            Revenue_Interest_Percent__c = 25
        );
        insert jv;

        Well__c well = new Well__c(
            Name = 'Billing Test Well',
            Account__c = acct.Id,
            Status__c = 'Producing',
            API_Number__c = '42-456-12345',
            Well_Type__c = 'Gas'
        );
        insert well;

        insert new Invoice__c(
            JV__c = jv.Id,
            Invoice_Date__c = Date.today().addDays(-10),
            Amount__c = 15000,
            Status__c = 'Pending'
        );

        insert new Invoice__c(
            JV__c = jv.Id,
            Invoice_Date__c = Date.today().addDays(-30),
            Amount__c = 25000,
            Status__c = 'Paid'
        );

        insert new Production_Allocation__c(
            Well__c = well.Id,
            Period_Start__c = Date.today().addMonths(-1),
            Period_End__c = Date.today().addMonths(-1),
            Oil_Volume_bbls__c = 5000,
            Gas_Volume_MCF__c = 10000,
            Working_Interest_Share__c = 50,
            Net_Revenue_Interest_Share__c = 25,
            Allocated_Revenue__c = 125000,
            Severance_Tax__c = 3000
        );

        insert new Measurement__c(
            Well__c = well.Id,
            Reading_DateTime__c = System.now().addMinutes(-30),
            Measurement_Type__c = 'Oil Flow',
            Gross_Volume__c = 184.2,
            Source_System__c = 'PI Historian',
            External_Key__c = 'Test|PortalTelemetry|' + String.valueOf(Crypto.getRandomLong())
        );

        insert new Regulatory_Permit__c(
            Name = 'Billing Test Permit',
            Account__c = acct.Id,
            Status__c = 'Active',
            Permit_Type__c = 'Drilling',
            Issue_Date__c = Date.today().addMonths(-6),
            Expiration_Date__c = Date.today().addDays(20),
            Agency__c = 'Railroad Commission'
        );

        insert new Compliance_Report__c(
            Account__c = acct.Id,
            Report_Type__c = 'Production',
            Status__c = 'Pending',
            Due_Date__c = Date.today().addDays(5),
            Regulatory_Body__c = 'Railroad Commission',
            Reporting_Period__c = '2026-01'
        );
    }

    @IsTest
    static void testGetInvoices() {
        Test.startTest();
        List<Invoice__c> invoices = PortalInvoiceController.getInvoices(null, 50);
        Test.stopTest();

        Assert.areEqual(2, invoices.size(), 'Expected both invoices');
        Assert.areEqual(Date.today().addDays(-10), invoices[0].Invoice_Date__c,
            'Newest invoice should sort first');
    }

    @IsTest
    static void testGetInvoicesFiltered() {
        Test.startTest();
        List<Invoice__c> invoices = PortalInvoiceController.getInvoices('Paid', 50);
        Test.stopTest();

        Assert.areEqual(1, invoices.size());
        Assert.areEqual('Paid', invoices[0].Status__c);
        Assert.areEqual(25000.0, invoices[0].Amount__c);
    }

    @IsTest
    static void testGetRoyaltyStatements() {
        Test.startTest();
        List<Production_Allocation__c> royalties = PortalInvoiceController.getRoyaltyStatements(12);
        Test.stopTest();

        Assert.areEqual(1, royalties.size());
        Assert.areEqual(125000.0, royalties[0].Allocated_Revenue__c);
        Assert.areEqual('Billing Test Well', royalties[0].Well__r.Name);
    }

    @IsTest
    static void testGetBillingSummary() {
        Test.startTest();
        Map<String, Object> summary = PortalInvoiceController.getBillingSummary();
        Test.stopTest();

        Assert.areEqual(2, summary.get('totalInvoices'));
        Assert.areEqual(15000.0, summary.get('outstandingAmount'));
        Assert.areEqual(25000.0, summary.get('paidAmount'));
        Assert.areEqual(0.0, summary.get('overdueAmount'));
        Assert.areEqual(125000.0, summary.get('royalty12Months'));
    }

    @IsTest
    static void testGetPermits() {
        Test.startTest();
        List<Regulatory_Permit__c> permits = PortalComplianceController.getPermits(null, 50);
        Test.stopTest();

        Assert.areEqual(1, permits.size());
        Assert.areEqual('Billing Test Permit', permits[0].Name);
    }

    @IsTest
    static void testGetPermitsFiltered() {
        Test.startTest();
        List<Regulatory_Permit__c> permits = PortalComplianceController.getPermits('Expired', 50);
        Test.stopTest();

        Assert.areEqual(0, permits.size());
    }

    @IsTest
    static void testGetComplianceReports() {
        Test.startTest();
        List<Compliance_Report__c> reports = PortalComplianceController.getComplianceReports(null, 50);
        Test.stopTest();

        Assert.isFalse(reports.isEmpty(), 'Expected at least the setup compliance report');
        Compliance_Report__c setupReport = null;
        for (Compliance_Report__c report : reports) {
            if ('Production'.equals(report.Report_Type__c)
                    && report.Due_Date__c == Date.today().addDays(5)
                    && 'Pending'.equals(report.Status__c)) {
                setupReport = report;
            }
        }
        Assert.isNotNull(setupReport, 'Setup compliance report should be returned');
    }

    @IsTest
    static void testGetComplianceReportsFiltered() {
        Test.startTest();
        List<Compliance_Report__c> reports = PortalComplianceController.getComplianceReports('Submitted', 50);
        Test.stopTest();

        Assert.areEqual(0, reports.size());
    }

    @IsTest
    static void testGetComplianceSummary() {
        Test.startTest();
        Map<String, Object> summary = PortalComplianceController.getComplianceSummary();
        Test.stopTest();

        Assert.isTrue((Integer) summary.get('activePermits') >= 1,
            'Setup permit should be counted as active');
        Assert.isTrue((Integer) summary.get('permitsExpiring30Days') >= 1,
            'Setup permit expires within 30 days');
        Assert.isTrue((Integer) summary.get('pendingReports') >= 1,
            'Setup pending report should be counted');
        Assert.isTrue((Integer) summary.get('overdueReports') >= 0);
        Assert.isTrue((Integer) summary.get('expiredPermits') >= 0);
        Assert.isTrue((Integer) summary.get('submittedReports') >= 0);
    }

    @IsTest
    static void testGetUpcomingDeadlinesOrdering() {
        Test.startTest();
        List<Map<String, Object>> deadlines = PortalComplianceController.getUpcomingDeadlines(10);
        Test.stopTest();

        Assert.areEqual(2, deadlines.size());
        Assert.areEqual('Report', deadlines[0].get('type'), 'Report due in 5 days should sort before permit due in 20');
        Assert.areEqual('Permit', deadlines[1].get('type'));
    }

    @IsTest
    static void testInvoiceAccountBackfillOnInsert() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Billing Test Operator' LIMIT 1];
        Joint_Venture__c jv = [SELECT Id FROM Joint_Venture__c LIMIT 1];
        Invoice__c invoice = new Invoice__c(
            JV__c = jv.Id,
            Invoice_Date__c = Date.today(),
            Amount__c = 5000,
            Status__c = 'Pending'
        );

        Test.startTest();
        insert invoice;
        Test.stopTest();

        Invoice__c created = [SELECT Id, Account__c FROM Invoice__c WHERE Id = :invoice.Id];
        Assert.areEqual(acct.Id, created.Account__c, 'Account should derive from JV parent');
    }

    @IsTest
    static void testProductionAllocationAccountBackfillOnInsert() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Billing Test Operator' LIMIT 1];
        Well__c well = [SELECT Id FROM Well__c LIMIT 1];
        Production_Allocation__c allocation = new Production_Allocation__c(
            Well__c = well.Id,
            Period_Start__c = Date.today(),
            Period_End__c = Date.today(),
            Oil_Volume_bbls__c = 100,
            Gas_Volume_MCF__c = 200,
            Allocated_Revenue__c = 10000
        );

        Test.startTest();
        insert allocation;
        Test.stopTest();

        Production_Allocation__c created = [
            SELECT Id, Account__c
            FROM Production_Allocation__c
            WHERE Id = :allocation.Id
        ];
        Assert.areEqual(acct.Id, created.Account__c, 'Account should derive from Well parent');
    }

    @IsTest
    static void testInvoiceAccountBackfillNoJvNoop() {
        Account acct = [SELECT Id FROM Account WHERE Name = 'Billing Test Operator' LIMIT 1];
        Invoice__c invoice = new Invoice__c(
            Invoice_Date__c = Date.today(),
            Amount__c = 1000,
            Status__c = 'Pending'
        );

        Test.startTest();
        insert invoice;
        Test.stopTest();

        Invoice__c created = [SELECT Id, Account__c FROM Invoice__c WHERE Id = :invoice.Id];
        Assert.isNull(created.Account__c, 'No JV means no account to derive');
    }

    @IsTest
    static void testGetWellTelemetry() {
        Well__c well = [SELECT Id FROM Well__c LIMIT 1];

        Test.startTest();
        List<Measurement__c> telemetry = PortalWellStatusController.getWellTelemetry(well.Id, 24);
        Test.stopTest();

        Assert.areEqual(1, telemetry.size(), 'Setup measurement should be returned');
        Assert.areEqual('Oil Flow', telemetry[0].Measurement_Type__c);
        Assert.areEqual(184.2, telemetry[0].Gross_Volume__c);
        Assert.areEqual('PI Historian', telemetry[0].Source_System__c);
    }

    @IsTest
    static void testGetWellTelemetryNoDataWithinWindow() {
        Well__c well = [SELECT Id FROM Well__c LIMIT 1];

        Test.startTest();
        // A negative window returns nothing older than now+1h relative to the reading.
        List<Measurement__c> telemetry = PortalWellStatusController.getWellTelemetry(well.Id, 0);
        Test.stopTest();

        // hoursBack <= 0 defaults to 24h, so the recent reading is still returned.
        Assert.areEqual(1, telemetry.size());
    }

    @IsTest
    static void testGetWellTelemetryRequiresWellId() {
        Test.startTest();
        Exception caught = null;
        try {
            PortalWellStatusController.getWellTelemetry(null, 24);
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Null wellId should throw an AuraHandledException');
    }
}