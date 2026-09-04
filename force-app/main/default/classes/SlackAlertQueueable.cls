public class SlackAlertQueueable implements Queueable, Database.AllowsCallouts {
    private final Id incidentId;

    public SlackAlertQueueable(Id incidentId) {
        this.incidentId = incidentId;
    }

    public void execute(QueueableContext context) {
        List<HSE_Incident__c> incidents = [
            SELECT Id, Name, Incident_Type__c, Location__c, Incident_Date__c,
                   Severity__c, Description__c, Spill_Volume__c, CreatedBy.Name
            FROM HSE_Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];

        if (incidents.isEmpty()) return;

        HSE_Incident__c inc = incidents[0];

        String recordUrl = Url.getOrgDomainUrl().toExternalForm() + '/' + inc.Id;
        String slackText = buildSlackMessage(inc, recordUrl);

        Map<String, Object> message = new Map<String, Object>();
        message.put('channel', '#hse-emergency');

        Map<String, Object> textBlock = new Map<String, Object>();
        textBlock.put('type', 'mrkdwn');
        textBlock.put('text', slackText);

        Map<String, Object> section = new Map<String, Object>();
        section.put('type', 'section');
        section.put('text', textBlock);

        message.put('blocks', new List<Object>{section});

        sendToSlack(inc.Id, JSON.serialize(message));
    }

    private static String buildSlackMessage(HSE_Incident__c inc, String recordUrl) {
        return
            '*🚨 CRITICAL HSE INCIDENT*\n' +
            '*Type:* ' + inc.Incident_Type__c + '\n' +
            '*Location:* ' + inc.Location__c + '\n' +
            '*Date:* ' + inc.Incident_Date__c + '\n' +
            '*Reported by:* ' + inc.CreatedBy.Name + '\n' +
            '<' + recordUrl + '|View in Salesforce>';
    }

    private static void sendToSlack(Id incidentId, String messageJson) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Slack_HSE_Webhook');
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
