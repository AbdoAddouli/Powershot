public class RenewalReminderQueueable implements Queueable {
    public void execute(QueueableContext ctx) {
        ComplianceDueDateService.sendRenewalReminders();
    }
}
