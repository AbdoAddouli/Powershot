public with sharing class SlackAlertService {
    private static final String SLACK_NAMED_CRED = 'callout:Slack_HSE_Webhook';

    @InvocableMethod(label='Send HSE Slack Alert' description='Sends HSE critical incident alert to Slack #hse-emergency')
    public static void sendAlert(List<Id> recordIds) {
        List<HSE_Incident__c> incidents = [
            SELECT Id, Name, Incident_Type__c, Location__c, Incident_Date__c,
                   Severity__c, Description__c, Spill_Volume__c, CreatedBy.Name
            FROM HSE_Incident__c
            WHERE Id IN :recordIds
        ];

        for (HSE_Incident__c inc : incidents) {
            sendAlertAsync(inc.Id, inc.Incident_Type__c, inc.Location__c,
                inc.Incident_Date__c, inc.CreatedBy.Name);
        }
    }

    @future(callout=true)
    private static void sendAlertAsync(Id incidentId, String incidentType,
            String location, Date incidentDate, String reportedBy) {
        String recordUrl = Url.getOrgDomainUrl().toExternalForm() + '/' + incidentId;
        String slackText =
            '*🚨 CRITICAL HSE INCIDENT*\n' +
            '*Type:* ' + incidentType + '\n' +
            '*Location:* ' + location + '\n' +
            '*Date:* ' + incidentDate + '\n' +
            '*Reported by:* ' + reportedBy + '\n' +
            '<' + recordUrl + '|View in Salesforce>';

        Map<String, Object> message = new Map<String, Object>();
        message.put('channel', '#hse-emergency');

        Map<String, Object> textBlock = new Map<String, Object>();
        textBlock.put('type', 'mrkdwn');
        textBlock.put('text', slackText);

        Map<String, Object> section = new Map<String, Object>();
        section.put('type', 'section');
        section.put('text', textBlock);

        message.put('blocks', new List<Object>{section});

        sendToSlack(incidentId, JSON.serialize(message));
    }

    private static void sendToSlack(Id incidentId, String messageJson) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(SLACK_NAMED_CRED);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(messageJson);
        req.setTimeout(10000);

        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug('Slack alert sent successfully: ' + res.getStatusCode());
            } else {
                createErrorTask(incidentId, 'Slack returned HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        } catch (Exception e) {
            createErrorTask(incidentId, 'Failed to send Slack alert: ' + e.getMessage());
        }
    }

    private static void createErrorTask(Id incidentId, String errorMessage) {
        try {
            insert new Task(
                Subject = 'Slack Alert Failed',
                Description = errorMessage,
                Priority = 'High',
                Status = 'Not Started',
                WhatId = incidentId
            );
        } catch (Exception e) {
            System.debug('Failed to create error task: ' + e.getMessage());
        }
    }
}
