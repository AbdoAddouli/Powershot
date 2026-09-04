/**
 * PortalDashboardController
 * ==========================
 * LWC-facing data layer for the Experience Cloud portal dashboard page.
 * Returns aggregate summary data: well counts by status, recent HSE incidents,
 * upcoming compliance deadlines, and production totals — all scoped to the
 * portal user's shared records via "with sharing".
 */
public with sharing class PortalDashboardController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardSummary() {
        Map<String, Object> result = new Map<String, Object>();

        List<AggregateResult> wellCounts = [
            SELECT Status__c status, COUNT(Id) total
            FROM Well__c
            GROUP BY Status__c
            ORDER BY COUNT(Id) DESC
        ];
        List<Map<String, Object>> wells = new List<Map<String, Object>>();
        for (AggregateResult ar : wellCounts) {
            wells.add(new Map<String, Object>{
                'status' => (String) ar.get('status'),
                'count' => (Integer) ar.get('total')
            });
        }
        result.put('wellsByStatus', wells);

        result.put('totalWells', [SELECT COUNT() FROM Well__c]);

        result.put('activeIncidents', [
            SELECT COUNT() FROM HSE_Incident__c
            WHERE Status__c != 'Closed'
        ]);

        result.put('criticalIncidents', [
            SELECT COUNT() FROM HSE_Incident__c
            WHERE Severity__c = 'Critical' AND Status__c != 'Closed'
        ]);

        result.put('upcomingDeadlines', [
            SELECT COUNT() FROM Regulatory_Permit__c
            WHERE Status__c = 'Active'
            AND Expiration_Date__c <= :Date.today().addDays(60)
        ]);

        result.put('activePipelines', [SELECT COUNT() FROM Pipeline__c]);

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<HSE_Incident__c> getRecentIncidents(Integer maxRows) {
        Integer limitVal = maxRows != null && maxRows > 0 ? maxRows : 10;
        return [
            SELECT Id, Name, Incident_Type__c, Incident_Date__c, Severity__c,
                   Status__c, Location__c, Well__c, Well__r.Name
            FROM HSE_Incident__c
            ORDER BY Incident_Date__c DESC
            LIMIT :limitVal
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Regulatory_Permit__c> getUpcomingDeadlines(Integer maxRows) {
        Integer limitVal = maxRows != null && maxRows > 0 ? maxRows : 10;
        return [
            SELECT Id, Name, Status__c, Expiration_Date__c, Account__c, Account__r.Name
            FROM Regulatory_Permit__c
            WHERE Status__c = 'Active'
            AND Expiration_Date__c >= :Date.today()
            ORDER BY Expiration_Date__c ASC
            LIMIT :limitVal
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<AggregateResult> getProductionSummary(Integer monthsBack) {
        Integer months = monthsBack != null && monthsBack > 0 ? monthsBack : 6;
        Date startDate = Date.today().addMonths(-months);
        return [
            SELECT WELL__r.Name wellName,
                   SUM(Oil_Volume_bbls__c) oilBbls,
                   SUM(Gas_Volume_MCF__c) gasMcf
            FROM Production_Allocation__c
            WHERE Period_End__c >= :startDate
            GROUP BY WELL__r.Name
            ORDER BY SUM(Oil_Volume_bbls__c) DESC
            LIMIT 20
        ];
    }
}
