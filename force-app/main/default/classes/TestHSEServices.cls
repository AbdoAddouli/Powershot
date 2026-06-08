/**
 * TestHSEServices
 * =================
 * Tests HSE incident severity classification (Critical / High / Medium / Low),
 * regulatory reportability detection, HSE incident queries, compliance due-date
 * tracking (upcoming renewals, overdue reports, reminder emails), and the
 * RegulatoryPermitTrigger compliance status updates.
 */
@IsTest
public with sharing class TestHSEServices {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Test Operator');
        insert acct;

        Well__c well = new Well__c(
            Name = 'Test Well',
            Account__c = acct.Id,
            Status__c = 'Permitted',
            API_Number__c = '42-123-45678'
        );
        insert well;

        Contact contact = new Contact(FirstName = 'Test', LastName = 'Contact', Email = 'test@test.com');
        insert contact;

        HSE_Incident__c incident = new HSE_Incident__c(
            Incident_Type__c = 'Spill',
            Incident_Date__c = Date.today(),
            Well__c = well.Id,
            Fatality_Occurred__c = true,
            Regulatory_Reportable__c = true
        );
        insert incident;
    }

    @IsTest
    static void testClassifySeverityCriticalFatality() {
        HSE_Incident__c inc = [SELECT Id, Fatality_Occurred__c FROM HSE_Incident__c LIMIT 1];
        inc.Fatality_Occurred__c = true;
        inc.Injury_Type__c = null;
        inc.Environmental_Impact__c = null;
        inc.Spill_Volume__c = null;
        update inc;

        Test.startTest();
        HSEIncidentService.classifySeverity(inc.Id);
        Test.stopTest();

        HSE_Incident__c result = [SELECT Id, Severity__c FROM HSE_Incident__c WHERE Id = :inc.Id];
        Assert.areEqual('Critical', result.Severity__c);
    }

    @IsTest
    static void testClassifySeverityHighSpill() {
        HSE_Incident__c inc = [SELECT Id FROM HSE_Incident__c LIMIT 1];
        inc.Fatality_Occurred__c = false;
        inc.Injury_Type__c = null;
        inc.Environmental_Impact__c = null;
        inc.Spill_Volume__c = 5000;
        update inc;

        Test.startTest();
        HSEIncidentService.classifySeverity(inc.Id);
        Test.stopTest();

        HSE_Incident__c result = [SELECT Id, Severity__c FROM HSE_Incident__c WHERE Id = :inc.Id];
        Assert.areEqual('High', result.Severity__c);
    }

    @IsTest
    static void testClassifySeverityMedium() {
        HSE_Incident__c inc = [SELECT Id FROM HSE_Incident__c LIMIT 1];
        inc.Fatality_Occurred__c = false;
        inc.Injury_Type__c = 'Medical Treatment';
        inc.Environmental_Impact__c = null;
        inc.Spill_Volume__c = null;
        update inc;

        Test.startTest();
        HSEIncidentService.classifySeverity(inc.Id);
        Test.stopTest();

        HSE_Incident__c result = [SELECT Id, Severity__c FROM HSE_Incident__c WHERE Id = :inc.Id];
        Assert.areEqual('Medium', result.Severity__c);
    }

    @IsTest
    static void testClassifySeverityLow() {
        HSE_Incident__c inc = [SELECT Id FROM HSE_Incident__c LIMIT 1];
        inc.Fatality_Occurred__c = false;
        inc.Injury_Type__c = null;
        inc.Environmental_Impact__c = null;
        inc.Spill_Volume__c = null;
        update inc;

        Test.startTest();
        HSEIncidentService.classifySeverity(inc.Id);
        Test.stopTest();

        HSE_Incident__c result = [SELECT Id, Severity__c FROM HSE_Incident__c WHERE Id = :inc.Id];
        Assert.areEqual('Low', result.Severity__c);
    }

    @IsTest
    static void testIsRegulatoryReportable() {
        HSE_Incident__c inc = [SELECT Id FROM HSE_Incident__c LIMIT 1];
        inc.Fatality_Occurred__c = true;
        update inc;

        Test.startTest();
        Boolean reportable = HSEIncidentService.isRegulatoryReportable(inc.Id);
        Test.stopTest();

        Assert.isTrue(reportable);
    }

    @IsTest
    static void testIsRegulatoryReportableSpill() {
        HSE_Incident__c inc = [SELECT Id FROM HSE_Incident__c LIMIT 1];
        inc.Fatality_Occurred__c = false;
        inc.Spill_Volume__c = 100;
        inc.Severity__c = 'Medium';
        inc.Injury_Type__c = null;
        inc.Environmental_Impact__c = null;
        update inc;

        Test.startTest();
        Boolean reportable = HSEIncidentService.isRegulatoryReportable(inc.Id);
        Test.stopTest();

        Assert.isTrue(reportable, 'Spill >= 50 should be reportable');
    }

    @IsTest
    static void testGetHSEIncidents() {
        HSE_Incident__c inc = [SELECT Id, Well__c FROM HSE_Incident__c LIMIT 1];
        Test.startTest();
        List<HSE_Incident__c> results = HSEIncidentService.getHSEIncidents(inc.Well__c);
        Test.stopTest();
        Assert.isFalse(results.isEmpty());
    }

    @IsTest
    static void testComplianceDueDateServiceUpcomingRenewals() {
        Regulatory_Permit__c permit = new Regulatory_Permit__c(
            Name = 'Test Permit',
            Status__c = 'Active',
            Expiration_Date__c = Date.today().addDays(30)
        );
        insert permit;

        Test.startTest();
        List<Regulatory_Permit__c> renewals = ComplianceDueDateService.getUpcomingRenewals(60);
        Test.stopTest();

        Assert.isFalse(renewals.isEmpty());
        Assert.areEqual(permit.Id, renewals[0].Id);
    }

    @IsTest
    static void testComplianceDueDateServiceOverdueReports() {
        Compliance_Report__c report = new Compliance_Report__c(
            Due_Date__c = Date.today().addDays(-5),
            Status__c = 'Pending',
            Report_Type__c = 'Environmental'
        );
        insert report;

        Test.startTest();
        List<Compliance_Report__c> overdue = ComplianceDueDateService.getOverdueReports();
        Test.stopTest();

        Assert.isFalse(overdue.isEmpty());
        Assert.areEqual(report.Id, overdue[0].Id);
    }

    @IsTest
    static void testComplianceDueDateServiceSendReminders() {
        Regulatory_Permit__c permit = new Regulatory_Permit__c(
            Name = 'Test Permit',
            Status__c = 'Active',
            Expiration_Date__c = Date.today().addDays(30),
            Responsible_Party__c = UserInfo.getUserId()
        );
        insert permit;

        Test.startTest();
        ComplianceDueDateService.sendRenewalReminders();
        Test.stopTest();

        Regulatory_Permit__c updated = [SELECT Id, Renewal_Reminder_Sent__c FROM Regulatory_Permit__c WHERE Id = :permit.Id];
        Assert.isTrue(updated.Renewal_Reminder_Sent__c);
    }

    @IsTest
    static void testRegulatoryPermitTriggerComplianceOnExpiration() {
        Regulatory_Permit__c permit = new Regulatory_Permit__c(
            Name = 'Expiring Permit',
            Status__c = 'Active',
            Expiration_Date__c = Date.today().addDays(-1)
        );
        Test.startTest();
        insert permit;
        Test.stopTest();

        Regulatory_Permit__c result = [SELECT Id, Compliance_Status__c FROM Regulatory_Permit__c WHERE Id = :permit.Id];
        Assert.areEqual('Expired', result.Compliance_Status__c);
    }

    @IsTest
    static void testRegulatoryPermitTriggerComplianceOnStatusChange() {
        Regulatory_Permit__c permit = new Regulatory_Permit__c(
            Name = 'Status Permit',
            Status__c = 'Active',
            Expiration_Date__c = Date.today().addYears(1)
        );
        insert permit;

        permit.Status__c = 'Suspended';
        Test.startTest();
        update permit;
        Test.stopTest();

        Regulatory_Permit__c result = [SELECT Id, Compliance_Status__c FROM Regulatory_Permit__c WHERE Id = :permit.Id];
        Assert.areEqual('Non-Compliant', result.Compliance_Status__c);
    }

    @IsTest
    static void testClassifyCriticalByInjury() {
        HSE_Incident__c inc = [SELECT Id FROM HSE_Incident__c LIMIT 1];
        inc.Fatality_Occurred__c = false;
        inc.Injury_Type__c = 'Life-Threatening';
        inc.Environmental_Impact__c = null;
        inc.Spill_Volume__c = null;
        update inc;
        Test.startTest();
        HSEIncidentService.classifySeverity(inc.Id);
        Test.stopTest();
        HSE_Incident__c result = [SELECT Id, Severity__c FROM HSE_Incident__c WHERE Id = :inc.Id];
        Assert.areEqual('Critical', result.Severity__c);
    }

    @IsTest
    static void testClassifyHighByLostTime() {
        HSE_Incident__c inc = [SELECT Id FROM HSE_Incident__c LIMIT 1];
        inc.Fatality_Occurred__c = false;
        inc.Injury_Type__c = 'Lost Time';
        inc.Environmental_Impact__c = null;
        inc.Spill_Volume__c = null;
        update inc;
        Test.startTest();
        HSEIncidentService.classifySeverity(inc.Id);
        Test.stopTest();
        HSE_Incident__c result = [SELECT Id, Severity__c FROM HSE_Incident__c WHERE Id = :inc.Id];
        Assert.areEqual('High', result.Severity__c);
    }

    @IsTest
    static void testClassifyHighByModerate() {
        HSE_Incident__c inc = [SELECT Id FROM HSE_Incident__c LIMIT 1];
        inc.Fatality_Occurred__c = false;
        inc.Injury_Type__c = null;
        inc.Environmental_Impact__c = 'Moderate';
        inc.Spill_Volume__c = null;
        update inc;
        Test.startTest();
        HSEIncidentService.classifySeverity(inc.Id);
        Test.stopTest();
        HSE_Incident__c result = [SELECT Id, Severity__c FROM HSE_Incident__c WHERE Id = :inc.Id];
        Assert.areEqual('High', result.Severity__c);
    }

    @IsTest
    static void testIsNotRegulatoryReportable() {
        HSE_Incident__c inc = [SELECT Id FROM HSE_Incident__c LIMIT 1];
        inc.Fatality_Occurred__c = false;
        inc.Severity__c = 'Low';
        inc.Spill_Volume__c = 10;
        inc.Injury_Type__c = 'Medical Treatment';
        update inc;
        Test.startTest();
        Boolean reportable = HSEIncidentService.isRegulatoryReportable(inc.Id);
        Test.stopTest();
        Assert.isFalse(reportable);
    }

    @IsTest
    static void testComplianceDueDateGetUpcomingDeadlines() {
        Account acct = [SELECT Id FROM Account LIMIT 1];
        Regulatory_Permit__c permit = new Regulatory_Permit__c(
            Name = 'Deadline Permit',
            Status__c = 'Active',
            Expiration_Date__c = Date.today().addDays(45),
            Account__c = acct.Id
        );
        insert permit;
        Test.startTest();
        List<Regulatory_Permit__c> deadlines = ComplianceDueDateService.getUpcomingDeadlines(acct.Id);
        Test.stopTest();
        Assert.isFalse(deadlines.isEmpty());
        Assert.areEqual(permit.Id, deadlines[0].Id);
    }
}
