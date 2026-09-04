public with sharing class SlackAlertService {
    @InvocableMethod(label='Send HSE Slack Alert' description='Sends HSE critical incident alert to Slack #hse-emergency')
    public static void sendAlert(List<Id> recordIds) {
        for (Id recordId : recordIds) {
            System.enqueueJob(new SlackAlertQueueable(recordId));
        }
    }
}
