/**
 * StoreController
 * ================
 * CRUD operations for Store__c records + per-store GA4 event data retrieval.
 *
 * This is the LWC-facing data layer for the storeManager component.
 * It handles:
 *   - Listing, creating/updating, and deleting stores
 *   - Querying GA4 event data scoped to a specific store via the GA4 Data API
 *
 * Each store has its own GA4_Property_ID__c. The controller reads it from
 * the Store__c record before querying the GA4 Data API.
 */
public with sharing class StoreController {

    private static final String BASE_ENDPOINT = 'callout:GTM_API/v1beta/properties';
    private static final Integer TIMEOUT_MS = 30000;

    /** Returns all stores, ordered by name, limited to 10000. Used by the storeManager datatable. */
    @AuraEnabled(cacheable=true)
    public static List<Store__c> getStores() {
        if (!Schema.sObjectType.Store__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to read Store records.');
        }
        return [
            SELECT Id, Name, Store_Type__c, Website_URL__c, Active__c,
                GA4_Property_ID__c, GTM_Container_ID__c, GTM_Numeric_ID__c,
                Provisioning_Status__c, Provisioning_Result__c
            FROM Store__c
            ORDER BY Name
            LIMIT 10000
        ];
    }

    /**
     * Returns GTM and GA4 account IDs from the custom setting.
     * Used by storeManager to build GTM/GA4 console URLs.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getGTMConfig() {
        GTM_Config__c config = GTM_Config__c.getInstance();
        return new Map<String, String>{
            'gtmAccountId' => config.GTM_Account_ID__c,
            'ga4AccountId' => config.GA4_Account_ID__c
        };
    }

    /** Deletes a store by its record Id. Checks delete permission before proceeding. */
    @AuraEnabled
    public static void deleteStore(Id storeId) {
        if (!Schema.sObjectType.Store__c.isDeletable()) {
            throw new AuraHandledException('Insufficient permissions to delete Store records.');
        }
        delete [SELECT Id FROM Store__c WHERE Id = :storeId];
    }

    /**
     * Fetches GA4 event data for a specific store using the store's own GA4 property.
     * Calls the GA4 Data API :runReport endpoint with that store's property ID.
     *
     * @param storeId   the Store__c record ID — used to look up the store's GA4_Property_ID__c.
     * @param startDate GA4 date string (defaults to "30daysAgo").
     * @param endDate   GA4 date string (defaults to "today").
     * @return StoreEventsResponse containing a list of StoreEventData rows.
     */
    @AuraEnabled
    public static StoreEventsResponse getStoreEvents(Id storeId, String startDate, String endDate) {
        Store__c store = [
            SELECT Id, GA4_Property_ID__c, Measurement_ID__c
            FROM Store__c
            WHERE Id = :storeId
            LIMIT 1
        ];

        if (String.isBlank(store.GA4_Property_ID__c)) {
            throw new AuraHandledException('Store "' + storeId + '" has no GA4 Property ID configured. Provision the store first.');
        }

        String sDate = String.isBlank(startDate) ? '30daysAgo' : startDate;
        String eDate = String.isBlank(endDate) ? 'today' : endDate;

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_ENDPOINT + '/' + store.GA4_Property_ID__c + ':runReport');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(TIMEOUT_MS);
            req.setBody(buildBody(sDate, eDate));

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                throw new AuraHandledException('GA4 API error: HTTP ' + res.getStatusCode() + ' - ' + res.getBody());
            }

            return parseEventsResponse(res.getBody());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching store events: ' + e.getMessage());
        }
    }

    /**
     * Builds the JSON body for the GA4 :runReport request.
     * Reports on eventCount and totalUsers, grouped by eventName.
     */
    private static String buildBody(String startDate, String endDate) {
        JSONGenerator gen = JSON.createGenerator(false);
        gen.writeStartObject();

        gen.writeFieldName('dateRanges');
        gen.writeStartArray();
        gen.writeStartObject();
        gen.writeStringField('startDate', startDate);
        gen.writeStringField('endDate', endDate);
        gen.writeEndObject();
        gen.writeEndArray();

        gen.writeFieldName('metrics');
        gen.writeStartArray();
        gen.writeStartObject();
        gen.writeStringField('name', 'eventCount');
        gen.writeEndObject();
        gen.writeStartObject();
        gen.writeStringField('name', 'totalUsers');
        gen.writeEndObject();
        gen.writeEndArray();

        gen.writeFieldName('dimensions');
        gen.writeStartArray();
        gen.writeStartObject();
        gen.writeStringField('name', 'eventName');
        gen.writeEndObject();
        gen.writeEndArray();

        gen.writeEndObject();
        return gen.getAsString();
    }

    /**
     * Parses the GA4 API response JSON into a StoreEventsResponse.
     * Each row becomes a StoreEventData with eventName, eventCount, and totalUsers.
     */
    private static StoreEventsResponse parseEventsResponse(String responseBody) {
        StoreEventsResponse resp = new StoreEventsResponse();

        Map<String, Object> mapData = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        if (mapData.containsKey('rows')) {
            List<Object> rows = (List<Object>) mapData.get('rows');

            for (Object rowObj : rows) {
                Map<String, Object> row = (Map<String, Object>) rowObj;

                StoreEventData event = new StoreEventData();

                if (row.containsKey('dimensionValues')) {
                    List<Object> dimValues = (List<Object>) row.get('dimensionValues');
                    if (dimValues.size() > 0) {
                        Map<String, Object> dv = (Map<String, Object>) dimValues.get(0);
                        event.eventName = (String) dv.get('value');
                    }
                }

                if (row.containsKey('metricValues')) {
                    List<Object> metricValues = (List<Object>) row.get('metricValues');
                    if (metricValues.size() > 0) {
                        Map<String, Object> mv0 = (Map<String, Object>) metricValues.get(0);
                        event.eventCount = Integer.valueOf((String) mv0.get('value'));
                    }
                    if (metricValues.size() > 1) {
                        Map<String, Object> mv1 = (Map<String, Object>) metricValues.get(1);
                        event.totalUsers = Integer.valueOf((String) mv1.get('value'));
                    }
                }

                resp.events.add(event);
            }
        }

        return resp;
    }

    /** Wrapper returned to LWC: list of per-store event data rows. */
    public class StoreEventsResponse {
        @AuraEnabled public List<StoreEventData> events { get; set; }

        public StoreEventsResponse() {
            this.events = new List<StoreEventData>();
        }
    }

    /** A single event row: name, count, and unique users. */
    public class StoreEventData {
        @AuraEnabled public String eventName { get; set; }
        @AuraEnabled public Integer eventCount { get; set; }
        @AuraEnabled public Integer totalUsers { get; set; }
    }
}