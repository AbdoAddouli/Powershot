/**
 * GTMService
 * ===========
 * Low-level Google Tag Manager API operations.
 *
 * Handles all direct HTTP callouts to the Tag Manager REST API:
 * container CRUD, workspace lookup, trigger creation, tag creation,
 * built-in variable enabling, version snapshotting, and publishing.
 *
 * All methods use the GTM_TagManager named credential (OAuth 2.0).
 * The GTM Account ID is read from GTM_Config__c.GTM_Account_ID__c.
 */
public with sharing class GTMService {

    private static final Integer TIMEOUT_MS = 30000;

    /** Reads the GTM Account ID from the custom setting. Throws if not configured. */
    private static String getAccountId() {
        GTM_Config__c config = GTM_Config__c.getInstance();
        if (config == null || String.isBlank(config.GTM_Account_ID__c)) {
            throw new AuraHandledException('GTM Account ID not configured in GTM_Config__c custom setting.');
        }
        return config.GTM_Account_ID__c;
    }

    /** Verifies the GTM_TagManager named credential is reachable. Throws AuraHandledException on failure. */
    public static void validateCredential() {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts');
            req.setMethod('GET');
            req.setTimeout(10000);
            new Http().send(req);
        } catch (Exception e) {
            throw new AuraHandledException('GTM_TagManager named credential is not configured or unreachable: ' + e.getMessage());
        }
    }

    // =========================================================================
    // Container
    // =========================================================================

    /**
     * Creates a GTM web container via the Tag Manager API.
     * POST /accounts/{id}/containers
     *
     * @param containerName Display name for the container (typically the store name).
     * @return ProvisionResult with gtmContainerId (numeric API ID) and gtmPublicId (GTM-XXXXXX).
     */
    public static ProvisioningService.ProvisionResult createContainer(String containerName) {
        ProvisioningService.ProvisionResult result = new ProvisioningService.ProvisionResult();

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_MS);

            JSONGenerator gen = JSON.createGenerator(false);
            gen.writeStartObject();
            gen.writeStringField('name', containerName);
            gen.writeFieldName('usageContext');
            gen.writeStartArray();
            gen.writeString('web');
            gen.writeEndArray();
            gen.writeEndObject();
            req.setBody(gen.getAsString());

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                result.success = true;
                result.gtmContainerId = (String) respMap.get('containerId');
                result.gtmPublicId = (String) respMap.get('publicId');

                if (String.isBlank(result.gtmPublicId)) {
                    result.success = false;
                    result.message = 'GTM container created but no public ID returned.';
                }
            } else {
                result.success = false;
                result.message = 'GTM API error (HTTP ' + res.getStatusCode() + '): ' + extractErrorMessage(res.getBody());
            }
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error creating GTM container: ' + e.getMessage();
        }

        return result;
    }

    /**
     * Deletes a GTM container by its numeric API ID.
     * Used for rollback when a downstream provisioning step fails.
     * DELETE /accounts/{id}/containers/{containerId}
     */
    public static void deleteContainer(String containerId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId);
            req.setMethod('DELETE');
            req.setTimeout(TIMEOUT_MS);
            new Http().send(req);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to delete GTM container ' + containerId + ': ' + e.getMessage());
        }
    }

    // =========================================================================
    // Workspace & Triggers
    // =========================================================================

    /**
     * @AuraEnabled wrapper so LWC can fetch the default workspace for a container.
     * Used for existing stores that didn't have workspaceId stored during provisioning.
     *
     * @param containerId Numeric GTM container ID.
     * @return The workspaceId string, or null on failure.
     */
    @AuraEnabled(cacheable=true)
    public static String getDefaultWorkspaceId(String containerId) {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + '/workspaces');
            req.setMethod('GET');
            req.setTimeout(TIMEOUT_MS);

            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> workspaces = (List<Object>) respMap.get('workspace');
                if (workspaces != null && !workspaces.isEmpty()) {
                    return (String) ((Map<String, Object>) workspaces.get(0)).get('workspaceId');
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'getDefaultWorkspaceId failed: ' + e.getMessage());
        }
        return null;
    }

    /**
     * Fetches the first (default) workspace for a GTM container.
     * GET /containers/{id}/workspaces → returns workspaceId.
     * Package-visible: called by ProvisioningService orchestration methods.
     */
    public static String getDefaultWorkspace(Http http, String containerId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + '/workspaces');
            req.setMethod('GET');
            req.setTimeout(TIMEOUT_MS);

            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> workspaces = (List<Object>) respMap.get('workspace');
                if (workspaces != null && !workspaces.isEmpty()) {
                    Map<String, Object> ws = (Map<String, Object>) workspaces.get(0);
                    return (String) ws.get('workspaceId');
                }
            }
            if (!Test.isRunningTest()) {
                System.debug(LoggingLevel.ERROR, 'getDefaultWorkspace HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'getDefaultWorkspace failed: ' + e.getMessage());
        }
        return null;
    }

    /**
     * Creates an "All Pages" trigger (type: pageview) in the specified workspace.
     * This trigger fires on every page load — used by pixel tags and the Google Tag.
     *
     * @return The triggerId string, or null on failure.
     */
    public static String createAllPagesTrigger(Http http, String containerId, String workspaceId) {
        try {
            HttpRequest listReq = new HttpRequest();
            listReq.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + '/workspaces/' + workspaceId + '/triggers');
            listReq.setMethod('GET');
            listReq.setTimeout(TIMEOUT_MS);
            HttpResponse listRes = http.send(listReq);
            if (listRes.getStatusCode() == 200) {
                Map<String, Object> listMap = (Map<String, Object>) JSON.deserializeUntyped(listRes.getBody());
                List<Object> triggers = (List<Object>) listMap.get('trigger');
                if (triggers != null) {
                    for (Object t : triggers) {
                        Map<String, Object> trg = (Map<String, Object>) t;
                        if ('All Pages'.equals(trg.get('name'))) {
                            return (String) trg.get('triggerId');
                        }
                    }
                }
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + '/workspaces/' + workspaceId + '/triggers');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_MS);

            JSONGenerator gen = JSON.createGenerator(false);
            gen.writeStartObject();
            gen.writeStringField('name', 'All Pages');
            gen.writeStringField('type', 'pageview');
            gen.writeFieldName('customEventFilter');
            gen.writeStartArray();
            gen.writeEndArray();
            gen.writeEndObject();
            req.setBody(gen.getAsString());

            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) respMap.get('triggerId');
            }
            if (!Test.isRunningTest()) {
                System.debug(LoggingLevel.ERROR, 'createAllPagesTrigger HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'createAllPagesTrigger failed: ' + e.getMessage());
        }
        return null;
    }

    /**
     * Creates a "Click - All Elements" trigger (type: click) in the workspace.
     * No filters = fires on every click event. Used by the GA4 click tracking tag.
     *
     * @return The triggerId string, or null on failure.
     */
    public static String createClickTrigger(Http http, String containerId, String workspaceId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + '/workspaces/' + workspaceId + '/triggers');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_MS);

            JSONGenerator gen = JSON.createGenerator(false);
            gen.writeStartObject();
            gen.writeStringField('name', 'Click - All Elements');
            gen.writeStringField('type', 'click');
            gen.writeFieldName('autoEventFilter');
            gen.writeStartArray();
            gen.writeEndArray();
            gen.writeFieldName('filter');
            gen.writeStartArray();
            gen.writeEndArray();
            gen.writeEndObject();

            req.setBody(gen.getAsString());

            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return String.valueOf(respMap.get('triggerId'));
            }
            if (!Test.isRunningTest()) {
                System.debug(LoggingLevel.ERROR, 'createClickTrigger HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'createClickTrigger failed: ' + e.getMessage());
        }
        return null;
    }

    // =========================================================================
    // Tags
    // =========================================================================

    /**
     * Creates a Custom HTML tag in GTM. Used for platform pixels (TikTok/Snap/LinkedIn).
     * Tag fires once per page via the specified trigger.
     *
     * @return true if the tag was created successfully, false otherwise.
     */
    public static Boolean createCustomHtmlTag(Http http, String containerId, String workspaceId, String tagName, String html, String triggerId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + '/workspaces/' + workspaceId + '/tags');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_MS);

            JSONGenerator gen = JSON.createGenerator(false);
            gen.writeStartObject();
            gen.writeStringField('name', tagName);
            gen.writeStringField('type', 'customHtml');
            gen.writeStringField('tagFiringOption', 'oncePerPage');

            gen.writeFieldName('parameter');
            gen.writeStartArray();

            gen.writeStartObject();
            gen.writeStringField('type', 'template');
            gen.writeStringField('key', 'html');
            gen.writeStringField('value', html);
            gen.writeEndObject();

            gen.writeStartObject();
            gen.writeStringField('type', 'boolean');
            gen.writeStringField('key', 'supportDocumentWrite');
            gen.writeStringField('value', 'false');
            gen.writeEndObject();

            gen.writeEndArray();

            gen.writeFieldName('firingTriggerId');
            gen.writeStartArray();
            gen.writeString(triggerId);
            gen.writeEndArray();

            gen.writeEndObject();
            req.setBody(gen.getAsString());

            HttpResponse res = http.send(req);
            return res.getStatusCode() == 200;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'createCustomHtmlTag failed: ' + e.getMessage());
            return false;
        }
    }

    /**
     * Creates a Google Tag (type: googtag) — the GA4 configuration tag.
     * Fires on the All Pages trigger, sets up gtag() with the measurement ID,
     * and enables GA4 event collection on the site.
     *
     * @return The numeric tagId of the created Google Tag, or null on failure.
     */
    public static String createGoogleTag(Http http, String containerId, String workspaceId, String measurementId, String triggerId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + '/workspaces/' + workspaceId + '/tags');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_MS);

            JSONGenerator gen = JSON.createGenerator(false);
            gen.writeStartObject();
            gen.writeStringField('name', 'Google Tag');
            gen.writeStringField('type', 'googtag');
            gen.writeFieldName('parameter');
            gen.writeStartArray();
            gen.writeStartObject();
            gen.writeStringField('type', 'template');
            gen.writeStringField('key', 'tagId');
            gen.writeStringField('value', measurementId);
            gen.writeEndObject();
            gen.writeEndArray();
            gen.writeFieldName('firingTriggerId');
            gen.writeStartArray();
            gen.writeString(triggerId);
            gen.writeEndArray();
            gen.writeStringField('tagFiringOption', 'oncePerLoad');
            gen.writeEndObject();

            req.setBody(gen.getAsString());

            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return String.valueOf(respMap.get('tagId'));
            }
            if (!Test.isRunningTest()) {
                System.debug(LoggingLevel.ERROR, 'createGoogleTag HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'createGoogleTag failed: ' + e.getMessage());
        }
        return null;
    }

    /**
     * Creates a GA4 Event tag (type: gaawe) that fires on every click.
     * Sends a "click" event to GA4 with rich contextual parameters:
     *   - click_text: the visible text of the clicked element
     *   - click_url:  the href/URL of the clicked element
     *   - click_element: the HTML tag name of the clicked element
     * Values reference GTM built-in variables ({{Click Text}}, {{Click URL}}, {{Click Element}}).
     *
     * @return true if the tag was created successfully, false otherwise.
     */
    public static Boolean createClickEventTag(Http http, String containerId, String workspaceId, String clickTriggerId, String measurementId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + '/workspaces/' + workspaceId + '/tags');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_MS);

            JSONGenerator gen = JSON.createGenerator(false);
            gen.writeStartObject();
            gen.writeStringField('name', 'GA4 Event - Click');
            gen.writeStringField('type', 'gaawe');
            gen.writeFieldName('parameter');
            gen.writeStartArray();

            gen.writeStartObject();
            gen.writeStringField('type', 'boolean');
            gen.writeStringField('key', 'sendEcommerceData');
            gen.writeStringField('value', 'false');
            gen.writeEndObject();

            gen.writeStartObject();
            gen.writeStringField('type', 'list');
            gen.writeStringField('key', 'eventSettingsTable');
            gen.writeFieldName('list');
            gen.writeStartArray();

            gen.writeStartObject();
            gen.writeStringField('type', 'map');
            gen.writeFieldName('map');
            gen.writeStartArray();
            gen.writeStartObject();
            gen.writeStringField('type', 'template');
            gen.writeStringField('key', 'parameter');
            gen.writeStringField('value', 'click_text');
            gen.writeEndObject();
            gen.writeStartObject();
            gen.writeStringField('type', 'template');
            gen.writeStringField('key', 'parameterValue');
            gen.writeStringField('value', '{{Click Text}}');
            gen.writeEndObject();
            gen.writeEndArray();
            gen.writeEndObject();

            gen.writeStartObject();
            gen.writeStringField('type', 'map');
            gen.writeFieldName('map');
            gen.writeStartArray();
            gen.writeStartObject();
            gen.writeStringField('type', 'template');
            gen.writeStringField('key', 'parameter');
            gen.writeStringField('value', 'click_url');
            gen.writeEndObject();
            gen.writeStartObject();
            gen.writeStringField('type', 'template');
            gen.writeStringField('key', 'parameterValue');
            gen.writeStringField('value', '{{Click URL}}');
            gen.writeEndObject();
            gen.writeEndArray();
            gen.writeEndObject();

            gen.writeStartObject();
            gen.writeStringField('type', 'map');
            gen.writeFieldName('map');
            gen.writeStartArray();
            gen.writeStartObject();
            gen.writeStringField('type', 'template');
            gen.writeStringField('key', 'parameter');
            gen.writeStringField('value', 'click_element');
            gen.writeEndObject();
            gen.writeStartObject();
            gen.writeStringField('type', 'template');
            gen.writeStringField('key', 'parameterValue');
            gen.writeStringField('value', '{{Click Element}}');
            gen.writeEndObject();
            gen.writeEndArray();
            gen.writeEndObject();

            gen.writeEndArray();
            gen.writeEndObject();

            gen.writeStartObject();
            gen.writeStringField('type', 'template');
            gen.writeStringField('key', 'eventName');
            gen.writeStringField('value', 'click');
            gen.writeEndObject();

            gen.writeStartObject();
            gen.writeStringField('type', 'template');
            gen.writeStringField('key', 'measurementIdOverride');
            gen.writeStringField('value', measurementId);
            gen.writeEndObject();

            gen.writeEndArray();

            gen.writeFieldName('firingTriggerId');
            gen.writeStartArray();
            gen.writeString(clickTriggerId);
            gen.writeEndArray();

            gen.writeStringField('tagFiringOption', 'oncePerEvent');
            gen.writeEndObject();

            req.setBody(gen.getAsString());

            HttpResponse res = http.send(req);
            return res.getStatusCode() == 200;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'createClickEventTag failed: ' + e.getMessage());
            return false;
        }
    }

    // =========================================================================
    // Built-In Variables
    // =========================================================================

    /**
     * Enables GTM built-in click variables so they can be used in tags/parameters.
     * Without this, {{Click Text}}, {{Click URL}}, etc. would resolve to empty values.
     *
     * Enables: clickText, clickUrl, clickElement, clickClasses
     *
     * @return true if all four variables were enabled, false if any failed.
     * POST /workspaces/{id}/built_in_variables for each type.
     */
    public static Boolean enableClickBuiltInVariables(Http http, String containerId, String workspaceId) {
        String baseUrl = 'callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + '/workspaces/' + workspaceId + '/built_in_variables';
        List<String> varTypes = new List<String>{'clickText', 'clickUrl', 'clickElement', 'clickClasses'};
        Boolean allSucceeded = true;

        for (String varType : varTypes) {
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(baseUrl);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(TIMEOUT_MS);
                req.setBody('{"type":"' + varType + '"}');
                HttpResponse res = http.send(req);
                if (res.getStatusCode() != 200) {
                    allSucceeded = false;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'enableClickBuiltInVariables failed for ' + varType + ': ' + e.getMessage());
                allSucceeded = false;
            }
        }

        return allSucceeded;
    }

    // =========================================================================
    // Version & Publishing
    // =========================================================================

    /**
     * Creates a container version from the current workspace state.
     * POST /workspaces/{id}:create_version
     * Snapshot: saves all workspace changes into an immutable version.
     *
     * @return The containerVersionId string, or null on failure.
     */
    public static String createContainerVersion(Http http, String containerId, String workspaceId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + '/workspaces/' + workspaceId + ':create_version');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_MS);

            JSONGenerator gen = JSON.createGenerator(false);
            gen.writeStartObject();
            gen.writeStringField('name', 'Initial setup with pixel tags');
            gen.writeStringField('notes', 'Auto-created by Salesforce provisioning');
            gen.writeEndObject();
            req.setBody(gen.getAsString());

            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                Map<String, Object> cv = (Map<String, Object>) respMap.get('containerVersion');
                if (cv != null) {
                    return (String) cv.get('containerVersionId');
                }
            }
            if (!Test.isRunningTest()) {
                System.debug(LoggingLevel.ERROR, 'createContainerVersion HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'createContainerVersion failed: ' + e.getMessage());
        }
        return null;
    }

    /**
     * Publishes the latest version of a GTM container.
     * POST /containers/{id}:publish
     * Makes the version live (visible to site visitors).
     *
     * @return true if the publish API returned 200, false otherwise.
     */
    public static Boolean publishContainer(Http http, String containerId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GTM_TagManager/tagmanager/v2/accounts/' + getAccountId() + '/containers/' + containerId + ':publish');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_MS);

            HttpResponse res = http.send(req);
            return res.getStatusCode() == 200;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'publishContainer failed: ' + e.getMessage());
            return false;
        }
    }

    // =========================================================================
    // Utilities
    // =========================================================================

    /**
     * Extracts the error message from a Google API JSON error response.
     * Handles the format: { error: { message: "..." } }
     * Falls back to the raw body string if parsing fails.
     */
    public static String extractErrorMessage(String body) {
        try {
            Map<String, Object> errorMap = (Map<String, Object>) JSON.deserializeUntyped(body);
            if (errorMap.containsKey('error')) {
                Map<String, Object> err = (Map<String, Object>) errorMap.get('error');
                if (err.containsKey('message')) {
                    return (String) err.get('message');
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'extractErrorMessage failed to parse: ' + e.getMessage());
        }
        return body;
    }
}