@isTest
private class RegulatoryFilingServiceTest {

    @isTest
    static void testSuccessfulSubmission() {
        Regulatory_Permit__c permit = new Regulatory_Permit__c(
            Permit_Type__c = 'Drilling',
            Expiration_Date__c = Date.today().addMonths(6)
        );
        insert permit;

        Compliance_Report__c report = new Compliance_Report__c(
            Report_Type__c = 'Environmental Impact',
            Reporting_Period__c = '2026-Q2',
            Due_Date__c = Date.today().addDays(-5),
            Regulatory_Body__c = 'EPA',
            Status__c = 'Submitted',
            Regulatory_Permit__c = permit.Id
        );
        insert report;

        Test.setMock(HttpCalloutMock.class, new EPASuccessMock());

        Test.startTest();
        RegulatoryFilingService.submitReports(new List<Id>{report.Id});
        Test.stopTest();

        Compliance_Report__c result = [SELECT Id, Status__c, Submitted_Date__c FROM Compliance_Report__c WHERE Id = :report.Id];
        System.assertEquals('Filed', result.Status__c);
        System.assertEquals(Date.today(), result.Submitted_Date__c);
    }

    @isTest
    static void testAPIFailure() {
        Compliance_Report__c report = new Compliance_Report__c(
            Report_Type__c = 'Safety Inspection',
            Due_Date__c = Date.today(),
            Regulatory_Body__c = 'EPA',
            Status__c = 'Submitted'
        );
        insert report;

        Test.setMock(HttpCalloutMock.class, new EPAFailureMock());

        Test.startTest();
        RegulatoryFilingService.submitReports(new List<Id>{report.Id});
        Test.stopTest();

        Compliance_Report__c result = [SELECT Id, Status__c FROM Compliance_Report__c WHERE Id = :report.Id];
        System.assertEquals('Submitted', result.Status__c, 'Should remain Submitted on failure');

        List<Task> tasks = [SELECT Subject, WhatId FROM Task WHERE WhatId = :report.Id];
        System.assertEquals(1, tasks.size());
        System.assertEquals('EPA Filing Failed', tasks[0].Subject);
    }

    @isTest
    static void testNonSubmittedReportSkipped() {
        Compliance_Report__c report = new Compliance_Report__c(
            Report_Type__c = 'Noise Monitoring',
            Due_Date__c = Date.today().addDays(30),
            Regulatory_Body__c = 'EPA',
            Status__c = 'Draft'
        );
        insert report;

        Test.setMock(HttpCalloutMock.class, new EPASuccessMock());

        Test.startTest();
        RegulatoryFilingService.submitReports(new List<Id>{report.Id});
        Test.stopTest();

        Compliance_Report__c result = [SELECT Id, Status__c FROM Compliance_Report__c WHERE Id = :report.Id];
        System.assertEquals('Draft', result.Status__c, 'Draft reports should not be filed');
    }

    private class EPASuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"status":"accepted","submissionId":"EPA-2026-12345"}');
            return res;
        }
    }

    private class EPAFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(400);
            res.setBody('{"error":"Invalid payload","details":[{"field":"reportType","message":"Required field missing"}]}');
            return res;
        }
    }
}
