public class EIAQueueable implements Queueable, Database.AllowsCallouts {
    private final Set<Id> recordIds;
    private final String syncType;

    public EIAQueueable(Set<Id> recordIds, String syncType) {
        this.recordIds = recordIds;
        this.syncType = syncType;
    }

    public void execute(QueueableContext ctx) {
        if (syncType == 'PRICE') {
            EIAPricingService.processPriceSync(recordIds);
        } else if (syncType == 'STOCK') {
            EIAPricingService.processStockSync(recordIds);
        }
    }
}
