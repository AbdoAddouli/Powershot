public with sharing class SlackAlertService {
    @InvocableMethod(label='Send HSE Slack Alert' description='Sends HSE critical incident alert to Slack #hse-emergency')
    public static void sendAlert(List<Id> recordIds) {
        List<Slack_Alert__e> events = new List<Slack_Alert__e>();
        for (Id recordId : recordIds) {
            events.add(new Slack_Alert__e(Incident_Id__c = recordId));
        }
        List<Database.SaveResult> results = EventBus.publish(events);
        for (Database.SaveResult result : results) {
            if (!result.isSuccess()) {
                System.debug('Failed to publish Slack alert event: ' + result.getErrors());
            }
        }
    }
}
