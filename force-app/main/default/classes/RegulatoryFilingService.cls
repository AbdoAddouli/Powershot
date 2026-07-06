public with sharing class RegulatoryFilingService {

    private static final String EPA_ENDPOINT = 'callout:EPA_CDX_API/submit';

    @InvocableMethod(
        label='Submit Compliance Report to EPA/CDX'
        description='Sends a submitted Compliance Report to the EPA CDX regulatory filing API and updates the record status.'
        category='Compliance'
    )
    public static void submitReports(List<Id> reportIds) {
        List<Compliance_Report__c> reports = [
            SELECT Id, Name, Report_Type__c, Reporting_Period__c, Due_Date__c,
                   Regulatory_Body__c, Notes__c, Status__c, Submitted_Date__c,
                   Account__c, Account__r.Name, Regulatory_Permit__c,
                   Regulatory_Permit__r.Permit_Type__c,
                   Regulatory_Permit__r.Expiration_Date__c
            FROM Compliance_Report__c
            WHERE Id IN :reportIds AND Status__c = 'Submitted'
        ];

        for (Compliance_Report__c report : reports) {
            submitSingleReport(report);
        }
    }

    private static void submitSingleReport(Compliance_Report__c report) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(EPA_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Auth-Token', '{!$Credential.Password}');
        req.setTimeout(30000);

        Map<String, Object> payload = new Map<String, Object>();
        payload.put('reportId', report.Id);
        payload.put('reportNumber', report.Name);
        payload.put('reportType', report.Report_Type__c);
        payload.put('reportingPeriod', report.Reporting_Period__c);
        payload.put('dueDate', report.Due_Date__c != null ? String.valueOf(report.Due_Date__c) : null);
        payload.put('regulatoryBody', report.Regulatory_Body__c);
        payload.put('notes', report.Notes__c);
        payload.put('accountName', report.Account__r?.Name);

        if (report.Regulatory_Permit__c != null) {
            Map<String, Object> permit = new Map<String, Object>();
            permit.put('permitId', report.Regulatory_Permit__c);
            permit.put('permitType', report.Regulatory_Permit__r.Permit_Type__c);
            permit.put('expirationDate', report.Regulatory_Permit__r.Expiration_Date__c != null
                ? String.valueOf(report.Regulatory_Permit__r.Expiration_Date__c) : null);
            payload.put('relatedPermit', permit);
        }

        req.setBody(JSON.serialize(payload));

        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                report.Status__c = 'Filed';
                report.Submitted_Date__c = Date.today();
                update report;
            } else {
                createFailureTask(report.Id,
                    'EPA CDX API returned HTTP ' + res.getStatusCode() + ': ' + res.getBody().left(1000));
            }
        } catch (Exception e) {
            createFailureTask(report.Id, 'Callout failed: ' + e.getMessage());
        }
    }

    private static void createFailureTask(Id reportId, String errorDetail) {
        insert new Task(
            Subject = 'EPA Filing Failed',
            Description = errorDetail,
            Priority = 'High',
            Status = 'Not Started',
            WhatId = reportId
        );
    }
}
