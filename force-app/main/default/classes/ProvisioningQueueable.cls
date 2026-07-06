/**
 * ProvisioningQueueable
 * ======================
 * Async orchestrator for the full provisioning pipeline.
 *
 * Executes asynchronously via System.enqueueJob to handle the multi-step
 * provisioning flow without blocking the LWC. Each step delegates to
 * the appropriate service class (GTMService, GA4AdminService, ProvisioningService).
 *
 * Provisioning flow:
 *   1. GTMService.createContainer()     — Creates a GTM web container
 *   2. GA4AdminService.createPropertyAndStream() — Creates GA4 property + web data stream
 *   3. ProvisioningService.setupWorkspaceAndAllPagesTrigger() — Gets workspace + All Pages trigger
 *   4. ProvisioningService.addPlatformTag() — Adds platform pixel (TikTok/Snap/LinkedIn)
 *   5. ProvisioningService.setupGA4Tracking() — Sets up Google Tag + click tracking
 *   6. Stores all generated IDs on the Store__c record
 *
 * On failure, the Store__c status is set to "Failed" and the error message is persisted.
 */
public class ProvisioningQueueable implements Queueable, Database.AllowsCallouts {

    private Id storeId;
    private String name;
    private String storeType;
    private String websiteUrl;

    public ProvisioningQueueable(Id storeId, String name, String storeType, String websiteUrl) {
        this.storeId = storeId;
        this.name = name;
        this.storeType = storeType;
        this.websiteUrl = websiteUrl;
    }

    public void execute(QueueableContext ctx) {
        try {
            String gtmContainerId;
            String gtmPublicId;
            String ga4PropertyId;
            String measurementId;

            ProvisioningService.ProvisionResult gtmResult = GTMService.createContainer(name);
            if (!gtmResult.success) {
                fail(gtmResult.message);
                return;
            }
            gtmContainerId = gtmResult.gtmContainerId;
            gtmPublicId = gtmResult.gtmPublicId;

            ProvisioningService.ProvisionResult ga4Result = GA4AdminService.createPropertyAndStream(name, websiteUrl);
            if (!ga4Result.success) {
                GTMService.deleteContainer(gtmContainerId);
                fail(ga4Result.message);
                return;
            }
            ga4PropertyId = ga4Result.ga4PropertyId;
            measurementId = ga4Result.measurementId;

            Map<String, String> ws = ProvisioningService.setupWorkspaceAndAllPagesTrigger(gtmContainerId);
            if (ws == null) {
                fail('Could not set up workspace or All Pages trigger');
                return;
            }

            if (!ProvisioningService.addPlatformTag(gtmContainerId, storeType, ws.get('workspaceId'), ws.get('triggerId'))) {
                fail('Failed to add platform pixel tag');
                return;
            }

            if (!ProvisioningService.setupGA4Tracking(gtmContainerId, measurementId, ws.get('workspaceId'), ws.get('triggerId'))) {
                fail('Failed to set up GA4 tracking tags');
                return;
            }

            String gtmSnippet = ProvisioningService.buildGTMSnippet(gtmPublicId);

            Store__c store = new Store__c(
                Id = storeId,
                Name = name,
                Store_Type__c = storeType,
                Website_URL__c = websiteUrl,
                GA4_Property_ID__c = ga4PropertyId,
                GTM_Container_ID__c = gtmPublicId,
                GTM_Numeric_ID__c = gtmContainerId,
                Measurement_ID__c = measurementId,
                Active__c = true,
                Provisioning_Status__c = 'Complete',
                Provisioning_Completed__c = System.now()
            );

            ProvisioningService.ProvisionResult result = new ProvisioningService.ProvisionResult();
            result.success = true;
            result.status = 'Complete';
            result.storeId = storeId;
            result.gtmPublicId = gtmPublicId;
            result.gtmSnippet = gtmSnippet;
            result.ga4PropertyId = ga4PropertyId;
            result.measurementId = measurementId;
            result.workspaceId = ws.get('workspaceId');
            ProvisioningService.splitSnippet(result);
            store.Provisioning_Result__c = JSON.serialize(result);

            update store;

        } catch (Exception e) {
            fail('Provisioning failed: ' + e.getMessage());
        }
    }

    /**
     * Sets the store's provisioning status to "Failed" with the given error message.
     * Used by all steps in execute() to report failures.
     */
    private void fail(String message) {
        try {
            update new Store__c(
                Id = storeId,
                Provisioning_Status__c = 'Failed',
                Provisioning_Result__c = message
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'fail() - unable to update store ' + storeId + ': ' + e.getMessage());
        }
    }
}