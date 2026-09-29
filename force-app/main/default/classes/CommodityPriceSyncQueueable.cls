public class CommodityPriceSyncQueueable implements Queueable, Database.AllowsCallouts {
    private final Set<Id> agreementIds;

    public CommodityPriceSyncQueueable(Set<Id> agreementIds) {
        this.agreementIds = agreementIds;
    }

    public void execute(QueueableContext ctx) {
        CommodityPricingService.processPriceSync(agreementIds);
    }
}
