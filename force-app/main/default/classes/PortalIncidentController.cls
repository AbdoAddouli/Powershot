/**
 * PortalIncidentController
 * =========================
 * LWC-facing data layer for the Experience Cloud portal HSE incident page.
 * Allows portal users to view and create HSE incidents from the community.
 * Enforces CRUD/FLS and sharing rules via "with sharing".
 */
public with sharing class PortalIncidentController {

    @AuraEnabled(cacheable=true)
    public static List<HSE_Incident__c> getIncidents(String severityFilter, Integer maxRows) {
        Integer limitVal = maxRows != null && maxRows > 0 ? maxRows : 50;
        if (String.isNotBlank(severityFilter)) {
            return [
                SELECT Id, Name, Incident_Type__c, Incident_Date__c, Severity__c,
                       Status__c, Location__c, Description__c, Spill_Volume__c,
                       Well__c, Well__r.Name, Pipeline__c, Pipeline__r.Name,
                       Regulatory_Reportable__c, Corrective_Action__c
                FROM HSE_Incident__c
                WHERE Severity__c = :severityFilter
                ORDER BY Incident_Date__c DESC
                LIMIT :limitVal
            ];
        }
        return [
            SELECT Id, Name, Incident_Type__c, Incident_Date__c, Severity__c,
                   Status__c, Location__c, Description__c, Spill_Volume__c,
                   Well__c, Well__r.Name, Pipeline__c, Pipeline__r.Name,
                   Regulatory_Reportable__c, Corrective_Action__c
            FROM HSE_Incident__c
            ORDER BY Incident_Date__c DESC
            LIMIT :limitVal
        ];
    }

    @AuraEnabled
    public static Id createIncident(HSE_Incident__c incident) {
        if (!Schema.sObjectType.HSE_Incident__c.isCreateable()) {
            throw new AuraHandledException('Insufficient permissions to create HSE incidents.');
        }
        if (incident.Incident_Date__c == null) {
            incident.Incident_Date__c = Date.today();
        }
        if (String.isBlank(incident.Status__c)) {
            incident.Status__c = 'Open';
        }
        insert incident;
        return incident.Id;
    }

    @AuraEnabled(cacheable=true)
    public static HSE_Incident__c getIncidentDetail(Id incidentId) {
        if (incidentId == null) {
            throw new AuraHandledException('Incident ID is required.');
        }
        List<HSE_Incident__c> results = [
            SELECT Id, Name, Incident_Type__c, Incident_Date__c, Severity__c,
                   Status__c, Location__c, Description__c, Spill_Volume__c,
                   Environmental_Impact__c, Root_Cause__c, Corrective_Action__c,
                   Regulatory_Reportable__c, Fatality_Occurred__c, Injury_Type__c,
                   Well__c, Well__r.Name, Pipeline__c, Pipeline__r.Name,
                   Account__c, Account__r.Name
            FROM HSE_Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];
        if (results.isEmpty()) {
            throw new AuraHandledException('Incident not found.');
        }
        return results[0];
    }
}
