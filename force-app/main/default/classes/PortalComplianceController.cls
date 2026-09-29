/**
 * PortalComplianceController
 * ===========================
 * LWC-facing data layer for the Experience Cloud portal Compliance page.
 * Returns regulatory permits, compliance reports, and an upcoming-deadline
 * horizon — all scoped to the portal user's shared records via "with sharing".
 *
 * Data flows through the JV_Partner_Sharing Sharing Set keyed on Account__c,
 * so a JV-partner user only ever sees their own account's records.
 */
public with sharing class PortalComplianceController {

    @AuraEnabled(cacheable=true)
    public static List<Regulatory_Permit__c> getPermits(String statusFilter, Integer maxRows) {
        if (!Schema.sObjectType.Regulatory_Permit__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to view permits.');
        }
        Integer limitVal = maxRows != null && maxRows > 0 ? maxRows : 50;
        if (String.isNotBlank(statusFilter)) {
            return [
                SELECT Id, Name, Permit_Type__c, Status__c, Compliance_Status__c,
                       Issue_Date__c, Expiration_Date__c, Agency__c,
                       Facility__c, Well__c, Well__r.Name,
                       Account__c, Account__r.Name
                FROM Regulatory_Permit__c
                WHERE Status__c = :statusFilter
                ORDER BY Expiration_Date__c ASC NULLS LAST
                LIMIT :limitVal
            ];
        }
        return [
            SELECT Id, Name, Permit_Type__c, Status__c, Compliance_Status__c,
                   Issue_Date__c, Expiration_Date__c, Agency__c,
                   Facility__c, Well__c, Well__r.Name,
                   Account__c, Account__r.Name
            FROM Regulatory_Permit__c
            ORDER BY Expiration_Date__c ASC NULLS LAST
            LIMIT :limitVal
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Compliance_Report__c> getComplianceReports(String statusFilter, Integer maxRows) {
        if (!Schema.sObjectType.Compliance_Report__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to view compliance reports.');
        }
        Integer limitVal = maxRows != null && maxRows > 0 ? maxRows : 50;
        if (String.isNotBlank(statusFilter)) {
            return [
                SELECT Id, Name, Report_Type__c, Status__c, Due_Date__c,
                       Submitted_Date__c, Regulatory_Body__c, Reporting_Period__c,
                       Regulatory_Permit__c, Regulatory_Permit__r.Name,
                       Account__c, Account__r.Name
                FROM Compliance_Report__c
                WHERE Status__c = :statusFilter
                ORDER BY Due_Date__c ASC NULLS LAST
                LIMIT :limitVal
            ];
        }
        return [
            SELECT Id, Name, Report_Type__c, Status__c, Due_Date__c,
                   Submitted_Date__c, Regulatory_Body__c, Reporting_Period__c,
                   Regulatory_Permit__c, Regulatory_Permit__r.Name,
                   Account__c, Account__r.Name
            FROM Compliance_Report__c
            ORDER BY Due_Date__c ASC NULLS LAST
            LIMIT :limitVal
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getComplianceSummary() {
        Map<String, Object> result = new Map<String, Object>();

        if (!Schema.sObjectType.Regulatory_Permit__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to view permits.');
        }

        result.put('activePermits', [
            SELECT COUNT() FROM Regulatory_Permit__c WHERE Status__c = 'Active'
        ]);

        result.put('permitsExpiring30Days', [
            SELECT COUNT() FROM Regulatory_Permit__c
            WHERE Status__c = 'Active'
            AND Expiration_Date__c >= :Date.today()
            AND Expiration_Date__c <= :Date.today().addDays(30)
        ]);

        result.put('expiredPermits', [
            SELECT COUNT() FROM Regulatory_Permit__c
            WHERE Compliance_Status__c = 'Expired'
        ]);

        result.put('overdueReports', [
            SELECT COUNT() FROM Compliance_Report__c
            WHERE Due_Date__c < :Date.today()
            AND Status__c != 'Submitted'
        ]);

        result.put('submittedReports', [
            SELECT COUNT() FROM Compliance_Report__c WHERE Status__c = 'Submitted'
        ]);

        result.put('pendingReports', [
            SELECT COUNT() FROM Compliance_Report__c WHERE Status__c = 'Pending'
        ]);

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getUpcomingDeadlines(Integer maxRows) {
        Integer limitVal = maxRows != null && maxRows > 0 ? maxRows : 10;
        List<Map<String, Object>> permitDeadlines = new List<Map<String, Object>>();
        List<Map<String, Object>> reportDeadlines = new List<Map<String, Object>>();

        for (Regulatory_Permit__c permit : [
            SELECT Id, Name, Permit_Type__c, Status__c, Expiration_Date__c
            FROM Regulatory_Permit__c
            WHERE Status__c = 'Active'
            AND Expiration_Date__c >= :Date.today()
            ORDER BY Expiration_Date__c ASC
            LIMIT :limitVal
        ]) {
            permitDeadlines.add(new Map<String, Object>{
                'id'     => permit.Id,
                'title'  => permit.Name,
                'type'   => 'Permit',
                'dueDate'=> permit.Expiration_Date__c,
                'status' => permit.Status__c,
                'detail' => permit.Permit_Type__c
            });
        }

        for (Compliance_Report__c report : [
            SELECT Id, Name, Report_Type__c, Status__c, Due_Date__c
            FROM Compliance_Report__c
            WHERE Due_Date__c >= :Date.today()
            AND Status__c != 'Submitted'
            ORDER BY Due_Date__c ASC
            LIMIT :limitVal
        ]) {
            reportDeadlines.add(new Map<String, Object>{
                'id'     => report.Id,
                'title'  => report.Name,
                'type'   => 'Report',
                'dueDate'=> report.Due_Date__c,
                'status' => report.Status__c,
                'detail' => report.Report_Type__c
            });
        }

        // Both sub-lists are already sorted ascending by date — linear merge.
        List<Map<String, Object>> merged = new List<Map<String, Object>>();
        Integer p = 0;
        Integer r = 0;
        while (p < permitDeadlines.size() && r < reportDeadlines.size()) {
            Date permitDate = (Date) permitDeadlines[p].get('dueDate');
            Date reportDate = (Date) reportDeadlines[r].get('dueDate');
            if (permitDate <= reportDate) {
                merged.add(permitDeadlines[p]);
                p++;
            } else {
                merged.add(reportDeadlines[r]);
                r++;
            }
        }
        while (p < permitDeadlines.size()) {
            merged.add(permitDeadlines[p]);
            p++;
        }
        while (r < reportDeadlines.size()) {
            merged.add(reportDeadlines[r]);
            r++;
        }

        return merged;
    }
}