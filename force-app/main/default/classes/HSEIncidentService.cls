/**
 * HSEIncidentService
 * ===================
 * Manages Health, Safety & Environment incident classification, regulatory
 * reporting notifications, and executive escalation. Used by HSEIncidentTrigger
 * to provide bulk-safe severity classification and compliance communication.
 *
 * Business Process: HSE Incident Management (Cross-Domain)
 *   Incident Reported → Severity Classification → Regulatory Notification
 *   → Critical Escalation → Investigation → Remediation → Closure
 */
public with sharing class HSEIncidentService {

    private static final String CRITICAL = 'Critical';
    private static final String HIGH = 'High';
    private static final String MEDIUM = 'Medium';
    private static final String LOW = 'Low';

    /**
     * Single-record wrapper for classifySeverities.
     * @param incidentId  The HSE_Incident__c to classify
     */
    public static void classifySeverity(Id incidentId) {
        classifySeverities(new List<Id>{ incidentId });
    }

    /**
     * Bulk classifies HSE incidents by evaluating fatality, injury type,
     * environmental impact, and spill volume to determine severity (Critical / High / Medium / Low).
     * @param incidentIds  The HSE_Incident__c records to classify
     */
    public static void classifySeverities(List<Id> incidentIds) {
        List<HSE_Incident__c> incidents = [
            SELECT Id, Incident_Type__c, Environmental_Impact__c, Injury_Type__c,
                   Fatality_Occurred__c, Spill_Volume__c, Regulatory_Reportable__c
            FROM HSE_Incident__c
            WHERE Id IN :incidentIds
        ];

        for (HSE_Incident__c incident : incidents) {
            String severity = LOW;

            if (incident.Fatality_Occurred__c == true) {
                severity = CRITICAL;
            } else if (incident.Injury_Type__c == 'Life-Threatening' || incident.Injury_Type__c == 'Permanent Disability') {
                severity = CRITICAL;
            } else if (incident.Environmental_Impact__c == 'Major' || incident.Spill_Volume__c > 1000) {
                severity = HIGH;
            } else if (incident.Injury_Type__c == 'Lost Time' || incident.Environmental_Impact__c == 'Moderate') {
                severity = HIGH;
            } else if (incident.Injury_Type__c == 'Medical Treatment' || incident.Spill_Volume__c > 100) {
                severity = MEDIUM;
            }

            incident.Severity__c = severity;
        }

        if (!incidents.isEmpty()) {
            update incidents;
        }
    }

    /**
     * Determines whether an incident meets regulatory reporting thresholds
     * (fatality, Critical/High severity, spill >= 50 bbl, lost-time or life-threatening injury).
     * @param incidentId  The HSE_Incident__c to evaluate
     * @return true if the incident must be reported to regulators
     */
    public static Boolean isRegulatoryReportable(Id incidentId) {
        HSE_Incident__c incident = [
            SELECT Id, Incident_Type__c, Severity__c, Fatality_Occurred__c,
                   Injury_Type__c, Spill_Volume__c, Environmental_Impact__c
            FROM HSE_Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];

        if (incident.Fatality_Occurred__c == true) return true;
        if (incident.Severity__c == CRITICAL || incident.Severity__c == HIGH) return true;
        if (incident.Spill_Volume__c != null && incident.Spill_Volume__c >= 50) return true;
        if (incident.Injury_Type__c == 'Lost Time' || incident.Injury_Type__c == 'Life-Threatening') return true;

        return false;
    }

    /**
     * Single-record wrapper for notifyComplianceTeams.
     * @param incidentId  The HSE_Incident__c to notify about
     */
    public static void notifyComplianceTeam(Id incidentId) {
        notifyComplianceTeams(new List<Id>{ incidentId });
    }

    /**
     * Emails the HSE_Compliance_Team group and creates follow-up Tasks for
     * every regulatory-reportable incident.
     * @param incidentIds  The reportable incident IDs
     */
    public static void notifyComplianceTeams(List<Id> incidentIds) {
        List<HSE_Incident__c> incidents = [
            SELECT Id, Name, Incident_Type__c, Severity__c, Location__c,
                   Incident_Date__c, Description__c
            FROM HSE_Incident__c
            WHERE Id IN :incidentIds
        ];

        if (incidents.isEmpty()) return;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<GroupMember> complianceMembers = [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE Group.Name = 'HSE_Compliance_Team'
        ];
        List<Task> tasks = new List<Task>();

        for (HSE_Incident__c incident : incidents) {
            for (GroupMember gm : complianceMembers) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(gm.UserOrGroupId);
                mail.setSubject('Regulatory Reportable Incident: ' + incident.Name);
                mail.setPlainTextBody(
                    'A regulatory reportable incident has been reported.\n\n' +
                    'Incident: ' + incident.Name + '\n' +
                    'Type: ' + incident.Incident_Type__c + '\n' +
                    'Severity: ' + incident.Severity__c + '\n' +
                    'Location: ' + incident.Location__c + '\n' +
                    'Date: ' + incident.Incident_Date__c + '\n' +
                    'Description: ' + incident.Description__c + '\n\n' +
                    'Please review and take appropriate action.'
                );
                emails.add(mail);
            }

            tasks.add(new Task(
                Subject = 'Compliance Notification: ' + incident.Name,
                Description = 'Regulatory reportable incident requiring compliance review: ' + incident.Id,
                Priority = 'High',
                Status = 'Not Started',
                ActivityDate = Date.today(),
                WhatId = incident.Id
            ));
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }

        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }

    /**
     * @AuraEnabled LWC-facing method returning HSE incidents related to a well,
     * pipeline, or account.
     * @param recordId  The parent record Id
     * @return  HSE incidents ordered by incident date descending
     */
    @AuraEnabled(cacheable=true)
    public static List<HSE_Incident__c> getHSEIncidents(Id recordId) {
        return [
            SELECT Id, Name, Incident_Type__c, Severity__c, Status__c,
                   Incident_Date__c, Location__c, Description__c
            FROM HSE_Incident__c
            WHERE Well__c = :recordId OR Pipeline__c = :recordId
               OR Account__c = :recordId
            ORDER BY Incident_Date__c DESC
        ];
    }

    /**
     * Single-record wrapper for escalateIfCritical.
     * @param incidentId  The Critical HSE_Incident__c to escalate
     */
    public static void escalateIfCritical(Id incidentId) {
        escalateIfCritical(new List<Id>{ incidentId });
    }

    /**
     * Sends escalation emails to the Executive_Leadership group and creates
     * highest-priority Tasks for all Critical-severity incidents.
     * @param incidentIds  The Critical incident IDs
     */
    public static void escalateIfCritical(List<Id> incidentIds) {
        List<HSE_Incident__c> incidents = [
            SELECT Id, Name, Incident_Type__c, Severity__c, Location__c,
                   Incident_Date__c, Description__c
            FROM HSE_Incident__c
            WHERE Id IN :incidentIds
                AND Severity__c = 'Critical'
        ];

        if (incidents.isEmpty()) return;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<GroupMember> execMembers = [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE Group.Name = 'Executive_Leadership'
        ];
        List<Task> tasks = new List<Task>();

        for (HSE_Incident__c incident : incidents) {
            for (GroupMember gm : execMembers) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(gm.UserOrGroupId);
                mail.setSubject('CRITICAL INCIDENT ESCALATION: ' + incident.Name);
                mail.setPlainTextBody(
                    'A critical incident requires immediate executive attention.\n\n' +
                    'Incident: ' + incident.Name + '\n' +
                    'Type: ' + incident.Incident_Type__c + '\n' +
                    'Severity: ' + incident.Severity__c + '\n' +
                    'Location: ' + incident.Location__c + '\n' +
                    'Date: ' + incident.Incident_Date__c + '\n' +
                    'Description: ' + incident.Description__c + '\n\n' +
                    'Immediate escalation and response required.'
                );
                emails.add(mail);
            }

            tasks.add(new Task(
                Subject = 'Critical Incident Escalation: ' + incident.Name,
                Description = 'Escalated to executive leadership for incident: ' + incident.Id,
                Priority = 'Highest',
                Status = 'Not Started',
                ActivityDate = Date.today(),
                WhatId = incident.Id
            ));
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }

        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }
}
