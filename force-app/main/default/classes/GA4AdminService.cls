/**
 * GA4AdminService
 * ================
 * Low-level GA4 Admin API operations.
 *
 * Handles HTTP callouts to the Google Analytics Admin API:
 * creating GA4 properties and web data streams.
 *
 * All methods use the GA4_Admin named credential (OAuth 2.0).
 * The GA4 Account ID is read from GTM_Config__c.GA4_Account_ID__c.
 */
public with sharing class GA4AdminService {

    private static final Integer TIMEOUT_MS = 30000;

    /** Reads the GA4 Account ID from the custom setting. Throws if not configured. */
    private static String getAccountId() {
        GTM_Config__c config = GTM_Config__c.getInstance();
        if (config == null || String.isBlank(config.GA4_Account_ID__c)) {
            throw new AuraHandledException('GA4 Account ID not configured in GTM_Config__c custom setting.');
        }
        return config.GA4_Account_ID__c;
    }

    /** Verifies the GA4_Admin named credential is reachable. Throws AuraHandledException on failure. */
    public static void validateCredential() {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:GA4_Admin/v1beta/properties');
            req.setMethod('GET');
            req.setTimeout(10000);
            new Http().send(req);
        } catch (Exception e) {
            throw new AuraHandledException('GA4_Admin named credential is not configured or unreachable: ' + e.getMessage());
        }
    }

    // =========================================================================
    // GA4 Property & Data Stream
    // =========================================================================

    /**
     * Creates a GA4 property + web data stream via the GA4 Admin API.
     *
     * Step 1: POST /v1beta/properties (creates the property under the configured account)
     * Step 2: POST /v1beta/properties/{name}/dataStreams (creates a web data stream with the website URL)
     *
     * @param propertyName Display name for the property (typically the store name).
     * @param websiteUrl   The store's website URL (used as the data stream's defaultUri).
     * @return ProvisionResult with ga4PropertyId (numeric) and measurementId (G-XXXXXXXX).
     */
    public static ProvisioningService.ProvisionResult createPropertyAndStream(String propertyName, String websiteUrl) {
        ProvisioningService.ProvisionResult result = new ProvisioningService.ProvisionResult();

        try {
            HttpRequest propReq = new HttpRequest();
            propReq.setEndpoint('callout:GA4_Admin/v1beta/properties');
            propReq.setMethod('POST');
            propReq.setHeader('Content-Type', 'application/json');
            propReq.setTimeout(TIMEOUT_MS);

            JSONGenerator gen = JSON.createGenerator(false);
            gen.writeStartObject();
            gen.writeStringField('displayName', propertyName + ' - Website');
            gen.writeStringField('parent', 'accounts/' + getAccountId());
            gen.writeStringField('timeZone', 'Etc/UTC');
            gen.writeStringField('currencyCode', 'USD');
            gen.writeEndObject();
            propReq.setBody(gen.getAsString());

            Http http = new Http();
            HttpResponse propRes = http.send(propReq);

            if (propRes.getStatusCode() != 200 && propRes.getStatusCode() != 201) {
                result.success = false;
                result.message = 'GA4 Admin API error creating property (HTTP ' + propRes.getStatusCode() + '): ' + GTMService.extractErrorMessage(propRes.getBody());
                return result;
            }

            Map<String, Object> propMap = (Map<String, Object>) JSON.deserializeUntyped(propRes.getBody());
            String propertyNamePath = (String) propMap.get('name');
            if (String.isNotBlank(propertyNamePath)) {
                result.ga4PropertyId = propertyNamePath.substringAfter('properties/');
            }

            if (String.isBlank(result.ga4PropertyId)) {
                result.success = false;
                result.message = 'GA4 property created but property ID could not be extracted from response.';
                return result;
            }

            HttpRequest streamReq = new HttpRequest();
            streamReq.setEndpoint('callout:GA4_Admin/v1beta/' + propertyNamePath + '/dataStreams');
            streamReq.setMethod('POST');
            streamReq.setHeader('Content-Type', 'application/json');
            streamReq.setTimeout(TIMEOUT_MS);

            JSONGenerator streamGen = JSON.createGenerator(false);
            streamGen.writeStartObject();
            streamGen.writeStringField('type', 'WEB_DATA_STREAM');
            streamGen.writeStringField('displayName', 'Website');
            streamGen.writeFieldName('webStreamData');
            streamGen.writeStartObject();
            streamGen.writeStringField('defaultUri', websiteUrl);
            streamGen.writeEndObject();
            streamGen.writeEndObject();
            streamReq.setBody(streamGen.getAsString());

            HttpResponse streamRes = http.send(streamReq);

            if (streamRes.getStatusCode() != 200 && streamRes.getStatusCode() != 201) {
                result.message = 'Data stream creation failed (HTTP ' + streamRes.getStatusCode() + '), but property was created. Measurement ID: ' + extractMeasurementIdFallback(streamRes.getBody());
                result.measurementId = extractMeasurementIdFallback(streamRes.getBody());
                return result;
            }

            Map<String, Object> streamMap = (Map<String, Object>) JSON.deserializeUntyped(streamRes.getBody());
            if (streamMap.containsKey('webStreamData')) {
                Map<String, Object> webData = (Map<String, Object>) streamMap.get('webStreamData');
                result.measurementId = (String) webData.get('measurementId');
            }

            result.success = true;
            return result;

        } catch (Exception e) {
            result.success = false;
            result.message = 'Error provisioning GA4: ' + e.getMessage();
            return result;
        }
    }

    // =========================================================================
    // Utilities
    // =========================================================================

    /**
     * Attempts to extract a measurementId from a GA4 API response body,
     * even when the HTTP status code indicates an error.
     * This provides a fallback when the stream was actually created but the
     * API returned a non-200 status for other reasons.
     */
    private static String extractMeasurementIdFallback(String body) {
        try {
            Map<String, Object> mapData = (Map<String, Object>) JSON.deserializeUntyped(body);
            if (mapData.containsKey('webStreamData')) {
                Map<String, Object> webData = (Map<String, Object>) mapData.get('webStreamData');
                if (webData.containsKey('measurementId')) {
                    return (String) webData.get('measurementId');
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'extractMeasurementIdFallback failed: ' + e.getMessage());
        }
        return '';
    }
}