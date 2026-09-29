/**
 * ProvisioningService
 * ====================
 * Provisioning orchestrator — the main entry point for the store provisioning flow.
 *
 * Called from the storeProvisioning LWC to kick off async provisioning.
 * Delegates to GTMService, GA4AdminService, and GTMPixelBuilder for
 * the actual API operations.
 *
 * Also exposes LWC-facing methods for polling provisioning status,
 * cancelling pending provisioning, and building/splitting GTM snippets.
 */
public with sharing class ProvisioningService {

    /**
     * Main entry point, callable from LWC.
     * Validates credentials, creates a Store__c record, and enqueues
     * async provisioning via ProvisioningQueueable.
     *
     * @param name       Store name (becomes the GTM container and GA4 property display name).
     * @param storeType  "TikTok", "Snap", "Meta", "Shopify", "LinkedIn", or "Other".
     * @param websiteUrl The store's website URL (used for GA4 web data stream).
     * @return The new Store__c record Id.
     */
    @AuraEnabled
    public static String provisionStore(String name, String storeType, String websiteUrl) {
        if (String.isBlank(name) || String.isBlank(websiteUrl)) {
            throw new AuraHandledException('Store name and website URL are required.');
        }

        GTMService.validateCredential();
        GA4AdminService.validateCredential();

        Store__c store = new Store__c(
            Name = name,
            Store_Type__c = storeType,
            Website_URL__c = websiteUrl,
            Active__c = false,
            Provisioning_Status__c = 'Pending'
        );
        insert store;

        System.enqueueJob(new ProvisioningQueueable(store.Id, name, storeType, websiteUrl));

        return store.Id;
    }

    /**
     * Polled by the LWC to check provisioning progress.
     * Returns the current status and result once complete.
     * Supports backward compatibility with old records missing workspaceId/gtmContainerId.
     */
    @AuraEnabled(cacheable=true)
    public static ProvisionResult getProvisioningStatus(Id storeId) {
        Store__c store = [
            SELECT Id, Name, Provisioning_Status__c, Provisioning_Result__c,
                   GTM_Container_ID__c, GTM_Numeric_ID__c,
                   GA4_Property_ID__c, Measurement_ID__c, Active__c
            FROM Store__c
            WHERE Id = :storeId
        ];

        ProvisionResult result = new ProvisionResult();
        result.status = store.Provisioning_Status__c;
        result.storeId = store.Id;

        if (store.Provisioning_Status__c == 'Complete' && String.isNotBlank(store.Provisioning_Result__c)) {
            ProvisionResult saved = (ProvisionResult) JSON.deserialize(
                store.Provisioning_Result__c, ProvisionResult.class
            );
            result.success = true;
            result.gtmPublicId = saved.gtmPublicId;
            result.gtmContainerId = saved.gtmContainerId;
            result.gtmSnippet = saved.gtmSnippet;
            result.ga4PropertyId = saved.ga4PropertyId;
            result.measurementId = saved.measurementId;
            result.workspaceId = saved.workspaceId;
            result.message = saved.message;

            if (String.isBlank(result.gtmContainerId) && String.isNotBlank(store.GTM_Numeric_ID__c)) {
                result.gtmContainerId = store.GTM_Numeric_ID__c;
            }

            if (String.isNotBlank(result.gtmSnippet)) {
                if (String.isNotBlank(saved.gtmHeadSnippet) && String.isNotBlank(saved.gtmBodySnippet)) {
                    result.gtmHeadSnippet = saved.gtmHeadSnippet;
                    result.gtmBodySnippet = saved.gtmBodySnippet;
                } else {
                    splitSnippet(result);
                }
            }
        } else if (store.Provisioning_Status__c == 'Failed') {
            result.success = false;
            result.message = store.Provisioning_Result__c;
        }

        return result;
    }

    // =========================================================================
    // Workspace & Trigger Setup (shared by addPlatformTag and setupGA4Tracking)
    // =========================================================================

    /**
     * Gets or creates the default workspace and "All Pages" trigger for a container.
     * Used by ProvisioningQueueable to share one workspace+trigger across both
     * addPlatformTag and setupGA4Tracking calls.
     *
     * @return Map with keys 'workspaceId' and 'triggerId', or null on failure.
     */
    public static Map<String, String> setupWorkspaceAndAllPagesTrigger(String containerId) {
        Http http = new Http();
        String workspaceId = GTMService.getDefaultWorkspace(http, containerId);
        if (String.isBlank(workspaceId)) return null;
        String triggerId = GTMService.createAllPagesTrigger(http, containerId, workspaceId);
        if (String.isBlank(triggerId)) return null;
        return new Map<String, String>{'workspaceId' => workspaceId, 'triggerId' => triggerId};
    }

    // =========================================================================
    // Platform Pixel Tag
    // =========================================================================

    /**
     * Adds a platform-specific pixel tag to the GTM container as a Custom HTML tag.
     * The pixel type is chosen based on storeType:
     *   "TikTok" → TikTok Pixel, "Snap" → Snapchat Pixel, else → LinkedIn Insight Tag.
     * Pixel IDs are read from GTM_Config__c custom setting.
     *
     * Steps: getWorkspace → create All Pages trigger → create Custom HTML tag → create version → publish.
     *
     * @return true if all steps succeeded, false if any step failed.
     */
    public static Boolean addPlatformTag(String containerId, String storeType) {
        GTM_Config__c config = GTM_Config__c.getInstance();

        String pixelId;
        String tagName;
        String html;

        if (storeType == 'TikTok' && String.isNotBlank(config.TikTok_Pixel_ID__c)) {
            pixelId = config.TikTok_Pixel_ID__c;
            tagName = 'TikTok Pixel';
            html = GTMPixelBuilder.buildTikTokPixelHtml(pixelId);
        } else if (storeType == 'Snap' && String.isNotBlank(config.Snapchat_Pixel_ID__c)) {
            pixelId = config.Snapchat_Pixel_ID__c;
            tagName = 'Snapchat Pixel';
            html = GTMPixelBuilder.buildSnapchatPixelHtml(pixelId);
        } else if (String.isNotBlank(config.LinkedIn_Partner_ID__c)) {
            pixelId = config.LinkedIn_Partner_ID__c;
            tagName = 'LinkedIn Insight Tag';
            html = GTMPixelBuilder.buildLinkedInInsightHtml(pixelId);
        } else {
            return true;
        }

        Http http = new Http();

        String workspaceId = GTMService.getDefaultWorkspace(http, containerId);
        if (String.isBlank(workspaceId)) return false;

        String triggerId = GTMService.createAllPagesTrigger(http, containerId, workspaceId);
        if (String.isBlank(triggerId)) return false;

        if (!GTMService.createCustomHtmlTag(http, containerId, workspaceId, tagName, html, triggerId)) return false;

        GTMService.createContainerVersion(http, containerId, workspaceId);
        GTMService.publishContainer(http, containerId);
        return true;
    }

    /**
     * Overloaded version that reuses an existing workspace and "All Pages" trigger.
     * Skips getDefaultWorkspace / createAllPagesTrigger — used by ProvisioningQueueable
     * to avoid duplicate trigger creation when addPlatformTag and setupGA4Tracking run together.
     *
     * @return true if all steps succeeded, false if any step failed.
     */
    public static Boolean addPlatformTag(String containerId, String storeType, String workspaceId, String allPagesTriggerId) {
        GTM_Config__c config = GTM_Config__c.getInstance();

        String pixelId;
        String tagName;
        String html;

        if (storeType == 'TikTok' && String.isNotBlank(config.TikTok_Pixel_ID__c)) {
            pixelId = config.TikTok_Pixel_ID__c;
            tagName = 'TikTok Pixel';
            html = GTMPixelBuilder.buildTikTokPixelHtml(pixelId);
        } else if (storeType == 'Snap' && String.isNotBlank(config.Snapchat_Pixel_ID__c)) {
            pixelId = config.Snapchat_Pixel_ID__c;
            tagName = 'Snapchat Pixel';
            html = GTMPixelBuilder.buildSnapchatPixelHtml(pixelId);
        } else if (String.isNotBlank(config.LinkedIn_Partner_ID__c)) {
            pixelId = config.LinkedIn_Partner_ID__c;
            tagName = 'LinkedIn Insight Tag';
            html = GTMPixelBuilder.buildLinkedInInsightHtml(pixelId);
        } else {
            return true;
        }

        Http http = new Http();
        if (!GTMService.createCustomHtmlTag(http, containerId, workspaceId, tagName, html, allPagesTriggerId)) return false;

        GTMService.createContainerVersion(http, containerId, workspaceId);
        GTMService.publishContainer(http, containerId);
        return true;
    }

    // =========================================================================
    // GA4 Tracking Setup
    // =========================================================================

    /**
     * Sets up GA4 tracking + click event tracking in the GTM container.
     * Called after addPlatformTag() during provisioning.
     *
     * Creates:
     *   1. Google Tag (GA4 config with measurement ID)
     *   2. Enables built-in click variables (Click Text, Click URL, etc.)
     *   3. Click - All Elements trigger
     *   4. GA4 Event - Click tag (fires on clicks, sends "click" event with params)
     *   5. New container version + publish
     *
     * @return true if all steps succeeded, false if any step failed.
     */
    public static Boolean setupGA4Tracking(String containerId, String ga4MeasurementId) {
        if (String.isBlank(ga4MeasurementId)) return true;

        Http http = new Http();
        String workspaceId = GTMService.getDefaultWorkspace(http, containerId);
        if (String.isBlank(workspaceId)) return false;

        String allPagesTriggerId = GTMService.createAllPagesTrigger(http, containerId, workspaceId);
        if (String.isBlank(allPagesTriggerId)) return false;

        String googleTagId = GTMService.createGoogleTag(http, containerId, workspaceId, ga4MeasurementId, allPagesTriggerId);
        if (String.isBlank(googleTagId)) return false;

        if (!GTMService.enableClickBuiltInVariables(http, containerId, workspaceId)) return false;

        String clickTriggerId = GTMService.createClickTrigger(http, containerId, workspaceId);
        if (String.isBlank(clickTriggerId)) return false;

        if (!GTMService.createClickEventTag(http, containerId, workspaceId, clickTriggerId, ga4MeasurementId)) return false;

        GTMService.createContainerVersion(http, containerId, workspaceId);
        GTMService.publishContainer(http, containerId);
        return true;
    }

    /**
     * Overloaded version that reuses an existing workspace and "All Pages" trigger.
     * Skips getDefaultWorkspace / createAllPagesTrigger — used by ProvisioningQueueable
     * to avoid duplicate trigger creation when addPlatformTag and setupGA4Tracking run together.
     *
     * @return true if all steps succeeded, false if any step failed.
     */
    public static Boolean setupGA4Tracking(String containerId, String ga4MeasurementId, String workspaceId, String allPagesTriggerId) {
        if (String.isBlank(ga4MeasurementId)) return true;

        Http http = new Http();

        String googleTagId = GTMService.createGoogleTag(http, containerId, workspaceId, ga4MeasurementId, allPagesTriggerId);
        if (String.isBlank(googleTagId)) return false;

        if (!GTMService.enableClickBuiltInVariables(http, containerId, workspaceId)) return false;

        String clickTriggerId = GTMService.createClickTrigger(http, containerId, workspaceId);
        if (String.isBlank(clickTriggerId)) return false;

        if (!GTMService.createClickEventTag(http, containerId, workspaceId, clickTriggerId, ga4MeasurementId)) return false;

        GTMService.createContainerVersion(http, containerId, workspaceId);
        GTMService.publishContainer(http, containerId);
        return true;
    }

    // =========================================================================
    // Cancellation
    // =========================================================================

    /**
     * Cancels a pending provisioning by deleting the store record.
     * Called from the LWC when the user cancels during progress polling.
     */
    @AuraEnabled
    public static void cancelProvisioning(Id storeId) {
        Store__c store = [SELECT Id, Provisioning_Status__c FROM Store__c WHERE Id = :storeId];
        if (store.Provisioning_Status__c == 'Pending' || store.Provisioning_Status__c == 'In Progress') {
            delete store;
        }
    }

    // =========================================================================
    // Snippet Utilities
    // =========================================================================

    /**
     * Generates the standard GTM container snippet (script + noscript iframe).
     * This is the code that gets placed in the <head> of the website.
     *
     * @param publicId The GTM-XXXXXX public container identifier.
     */
    public static String buildGTMSnippet(String publicId) {
        String script = '<!-- Google Tag Manager -->\n' +
            '<script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({\'gtm.start\':\n' +
            'new Date().getTime(),event:\'gtm.js\'});var f=d.getElementsByTagName(s)[0],\n' +
            'j=d.createElement(s),dl=l!=\'dataLayer\'?\'&l=\'+l:\'\';j.async=true;j.src=\n' +
            '\'https://www.googletagmanager.com/gtm.js?id=\'+i+dl;f.parentNode.insertBefore(j,f);\n' +
            '})(window,document,\'script\',\'dataLayer\',\'' + publicId + '\');</script>\n' +
            '<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=' + publicId + '"\n' +
            'height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>\n' +
            '<!-- End Google Tag Manager -->';
        return script;
    }

    /**
     * Splits the full GTM snippet into head and body parts.
     * - Head part (goes in <head>): <!-- Google Tag Manager --><script>...</script>
     * - Body part (goes after <body>): <noscript>...</noscript><!-- End Google Tag Manager -->
     */
    public static void splitSnippet(ProvisionResult result) {
        String snippet = result.gtmSnippet;
        if (String.isBlank(snippet)) return;

        if (snippet.contains('</script>')) {
            result.gtmHeadSnippet = snippet.substringBefore('</script>') + '</script>';
            result.gtmBodySnippet = snippet.substringAfter('</script>\n');
        } else {
            result.gtmHeadSnippet = snippet;
            result.gtmBodySnippet = '';
        }
    }

    // =========================================================================
    // Inner Classes
    // =========================================================================

    /**
     * Result object returned to the LWC after provisioning.
     * Contains all generated IDs and the GTM snippet for installation.
     * Serialized to JSON and stored in Store__c.Provisioning_Result__c.
     */
    public class ProvisionResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String storeId { get; set; }
        @AuraEnabled public String gtmContainerId { get; set; }
        @AuraEnabled public String gtmPublicId { get; set; }
        @AuraEnabled public String gtmSnippet { get; set; }
        @AuraEnabled public String gtmHeadSnippet { get; set; }
        @AuraEnabled public String gtmBodySnippet { get; set; }
        @AuraEnabled public String workspaceId { get; set; }
        @AuraEnabled public String ga4PropertyId { get; set; }
        @AuraEnabled public String measurementId { get; set; }

        public ProvisionResult() {
            this.success = false;
        }
    }
}