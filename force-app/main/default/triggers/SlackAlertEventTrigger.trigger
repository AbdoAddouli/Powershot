trigger SlackAlertEventTrigger on Slack_Alert__e (after insert) {
    for (Slack_Alert__e event : Trigger.new) {
        if (event.Incident_Id__c != null) {
            System.enqueueJob(new SlackAlertQueueable(event.Incident_Id__c));
        }
    }
}
