/**
 * GAEventsController
 * ===================
 * Provides GA4 event data to Lightning Web Components via the Google Analytics Data API.
 *
 * This is the main analytics query layer for the global GA4 property
 * (configured in GTM_Config__c.GA4_Property_ID__c). It exposes AuraEnabled
 * methods that the storeManager LWC calls to display the "All Events" and
 * "Click Events" tabs and summary cards.
 *
 * Key capabilities:
 *   - getEventData()              → all events, last 30 days
 *   - getEventDataByDateRange()   → all events, custom date range
 *   - getClickEventData()         → click events only, last 30 days
 *
 * All methods call the GA4 Data API (:runReport) via the GTM_API named credential.
 */
public with sharing class GAEventsController {

    private static final String BASE_ENDPOINT = 'callout:GTM_API/v1beta/properties';
    private static final Integer TIMEOUT_MS = 30000;

    /** Reads the GA4 Property ID from the GTM_Config__c custom setting. */
    private static String getPropertyId() {
        GTM_Config__c config = GTM_Config__c.getInstance();
        if (config == null || String.isBlank(config.GA4_Property_ID__c)) {
            throw new AuraHandledException('GA4 Property ID not configured. Set it in GTM Config Custom Setting.');
        }
        return config.GA4_Property_ID__c;
    }

    /**
     * Fetches all GA4 events for the last 30 days.
     * Returns eventName, eventCount, and totalUsers per event.
     * Used by the storeManager LWC for the main "All Events" view.
     */
    @AuraEnabled
    public static EventsResponse getEventData() {
        try {
            HttpRequest req = buildRequest(
                new List<String>{'eventCount', 'totalUsers'},
                new List<String>{'eventName'},
                '30daysAgo',
                'today'
            );
            HttpResponse res = sendRequest(req);
            if (res.getStatusCode() != 200) {
                throw new GAEventsException('HTTP Error: ' + res.getStatusCode());
            }
            return parseResponse(res.getBody());
        } catch (Exception e) {
            throw new AuraHandledException('Events Error: ' + e.getMessage());
        }
    }

    /**
     * Fetches all GA4 events for a custom date range.
     * Accepts GA4 date strings (e.g., "7daysAgo", "2024-01-01").
     */
    @AuraEnabled
    public static EventsResponse getEventDataByDateRange(String startDate, String endDate) {
        try {
            if (String.isBlank(startDate) || String.isBlank(endDate)) {
                throw new GAEventsException('Start date and end date are required');
            }
            HttpRequest req = buildRequest(
                new List<String>{'eventCount', 'totalUsers'},
                new List<String>{'eventName'},
                startDate,
                endDate
            );
            HttpResponse res = sendRequest(req);
            if (res.getStatusCode() != 200) {
                throw new GAEventsException('HTTP Error: ' + res.getStatusCode());
            }
            return parseResponse(res.getBody());
        } catch (Exception e) {
            throw new AuraHandledException('Date Range Events Error: ' + e.getMessage());
        }
    }

    /**
     * Fetches only the "click" event data for the last 30 days.
     * Uses a dimensionFilter in the GA4 API query to filter by eventName = "click".
     * Used by the storeManager LWC for the Click Events tab and summary card.
     */
    @AuraEnabled
    public static EventsResponse getClickEventData() {
        try {
            HttpRequest req = buildRequest(
                new List<String>{'eventCount', 'totalUsers'},
                new List<String>{'eventName'},
                '30daysAgo',
                'today',
                'click'
            );
            HttpResponse res = sendRequest(req);
            if (res.getStatusCode() != 200) {
                throw new GAEventsException('HTTP Error: ' + res.getStatusCode());
            }
            return parseResponse(res.getBody());
        } catch (Exception e) {
            throw new AuraHandledException('Click Events Error: ' + e.getMessage());
        }
    }

    /** Builds an HttpRequest for the GA4 Data API — delegate without filter. */
    private static HttpRequest buildRequest(List<String> metrics, List<String> dimensions, String startDate, String endDate) {
        return buildRequest(metrics, dimensions, startDate, endDate, null);
    }

    /**
     * Builds an HttpRequest for the GA4 Data API :runReport endpoint.
     * Optionally includes a dimension filter to narrow results (e.g., only "click" events).
     *
     * @param metrics         list of metric names (e.g., eventCount, totalUsers)
     * @param dimensions      list of dimension names (e.g., eventName)
     * @param startDate       GA4 date string for range start
     * @param endDate         GA4 date string for range end
     * @param eventNameFilter if non-blank, filters the report to this exact event name
     */
    private static HttpRequest buildRequest(List<String> metrics, List<String> dimensions, String startDate, String endDate, String eventNameFilter) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BASE_ENDPOINT + '/' + getPropertyId() + ':runReport');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(TIMEOUT_MS);
        req.setBody(buildBody(metrics, dimensions, startDate, endDate, eventNameFilter));
        return req;
    }

    /** Builds the JSON body — delegate without filter. */
    private static String buildBody(List<String> metrics, List<String> dimensions, String startDate, String endDate) {
        return buildBody(metrics, dimensions, startDate, endDate, null);
    }

    /**
     * Builds the JSON body for the GA4 Data API :runReport request.
     * Structure:
     *   {
     *     dateRanges: [{ startDate, endDate }],
     *     metrics: [{ name }],
     *     dimensions: [{ name }],
     *     dimensionFilter: { ... }  // optional
     *   }
     */
    private static String buildBody(List<String> metrics, List<String> dimensions, String startDate, String endDate, String eventNameFilter) {
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
        for (String metric : metrics) {
            gen.writeStartObject();
            gen.writeStringField('name', metric);
            gen.writeEndObject();
        }
        gen.writeEndArray();

        gen.writeFieldName('dimensions');
        gen.writeStartArray();
        for (String dimension : dimensions) {
            gen.writeStartObject();
            gen.writeStringField('name', dimension);
            gen.writeEndObject();
        }
        gen.writeEndArray();

        if (String.isNotBlank(eventNameFilter)) {
            gen.writeFieldName('dimensionFilter');
            gen.writeStartObject();
            gen.writeFieldName('filter');
            gen.writeStartObject();
            gen.writeStringField('fieldName', 'eventName');
            gen.writeFieldName('stringFilter');
            gen.writeStartObject();
            gen.writeStringField('matchType', 'EXACT');
            gen.writeStringField('value', eventNameFilter);
            gen.writeEndObject();
            gen.writeEndObject();
            gen.writeEndObject();
        }

        gen.writeEndObject();
        return gen.getAsString();
    }

    /** Sends the HTTP request and returns the response. */
    private static HttpResponse sendRequest(HttpRequest req) {
        Http http = new Http();
        return http.send(req);
    }

    /**
     * Parses the GA4 Data API response JSON into an EventsResponse object.
     * Extracts dimensionValues (eventName) and metricValues (eventCount, totalUsers) from each row.
     */
    private static EventsResponse parseResponse(String responseBody) {
        EventsResponse resp = new EventsResponse();

        try {
            Map<String, Object> mapData = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            resp.rawResponse = responseBody;

            if (mapData.containsKey('rows')) {
                List<Object> rows = (List<Object>) mapData.get('rows');

                for (Object rowObj : rows) {
                    Map<String, Object> row = (Map<String, Object>) rowObj;

                    EventData event = new EventData();

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
        } catch (JSONException e) {
            throw new GAEventsException('Error parsing response: ' + e.getMessage());
        }

        return resp;
    }

    /** Custom exception for GA4 Data API errors. */
    public class GAEventsException extends Exception {}

    /** Wrapper for a list of EventData, returned to LWC via @AuraEnabled. */
    public class EventsResponse {
        @AuraEnabled
        public List<EventData> events { get; set; }
        @AuraEnabled
        public String rawResponse { get; set; }

        public EventsResponse() {
            this.events = new List<EventData>();
        }
    }

    /** A single event row from the GA4 report: name, count, and unique users. */
    public class EventData {
        @AuraEnabled
        public String eventName { get; set; }
        @AuraEnabled
        public Integer eventCount { get; set; }
        @AuraEnabled
        public Integer totalUsers { get; set; }
    }
}