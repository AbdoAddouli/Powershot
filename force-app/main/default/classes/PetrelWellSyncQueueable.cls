public class PetrelWellSyncQueueable implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext ctx) {
        PetrelWellSync.runSync();
    }
}
