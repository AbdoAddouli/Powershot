/**
 * PortalWellStatusController
 * ===========================
 * LWC-facing data layer for the Experience Cloud portal well status page.
 * Returns well list views with status, type, location, and production data
 * scoped to the portal user's shared records via "with sharing".
 */
public with sharing class PortalWellStatusController {

    @AuraEnabled(cacheable=true)
    public static List<Well__c> getWells(String statusFilter, Integer maxRows) {
        Integer limitVal = maxRows != null && maxRows > 0 ? maxRows : 50;
        if (String.isNotBlank(statusFilter)) {
            return [
                SELECT Id, Name, API_Number__c, Status__c, Well_Type__c,
                       Account__c, Account__r.Name, Lease__c, Lease__r.Name,
                       Total_Depth__c, Status_Change_Date__c
                FROM Well__c
                WHERE Status__c = :statusFilter
                ORDER BY Name
                LIMIT :limitVal
            ];
        }
        return [
            SELECT Id, Name, API_Number__c, Status__c, Well_Type__c,
                   Account__c, Account__r.Name, Lease__c, Lease__r.Name,
                   Total_Depth__c, Status_Change_Date__c
            FROM Well__c
            ORDER BY Name
            LIMIT :limitVal
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Production_Allocation__c> getWellProduction(Id wellId, Integer monthsBack) {
        if (wellId == null) {
            throw new AuraHandledException('Well ID is required.');
        }
        Integer months = monthsBack != null && monthsBack > 0 ? monthsBack : 12;
        Date startDate = Date.today().addMonths(-months);
        return [
            SELECT Id, Name, Period_End__c, Oil_Volume_bbls__c,
                   Gas_Volume_MCF__c, Water_Volume_bbls__c
            FROM Production_Allocation__c
            WHERE Well__c = :wellId
            AND Period_End__c >= :startDate
            ORDER BY Period_End__c DESC
            LIMIT 100
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Measurement__c> getWellTelemetry(Id wellId, Integer hoursBack) {
        if (wellId == null) {
            throw new AuraHandledException('Well ID is required.');
        }
        Integer hours = hoursBack != null && hoursBack > 0 ? hoursBack : 24;
        DateTime since = System.now().addHours(-hours);
        return [
            SELECT Id, Reading_DateTime__c, Measurement_Type__c,
                   Gross_Volume__c, Pressure__c, Temperature__c, Source_System__c
            FROM Measurement__c
            WHERE Well__c = :wellId
            AND Reading_DateTime__c >= :since
            ORDER BY Reading_DateTime__c ASC
            LIMIT 500
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getWellStatusCounts() {
        Map<String, Object> result = new Map<String, Object>();

        List<AggregateResult> counts = [
            SELECT Status__c status, COUNT(Id) total
            FROM Well__c
            GROUP BY Status__c
            ORDER BY COUNT(Id) DESC
        ];
        List<Map<String, Object>> statusCounts = new List<Map<String, Object>>();
        for (AggregateResult ar : counts) {
            statusCounts.add(new Map<String, Object>{
                'status' => (String) ar.get('status'),
                'count' => (Integer) ar.get('total')
            });
        }
        result.put('byStatus', statusCounts);
        result.put('total', [SELECT COUNT() FROM Well__c]);

        return result;
    }
}
