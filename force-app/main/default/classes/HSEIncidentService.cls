public with sharing class HSEIncidentService {

    private static final String CRITICAL = 'Critical';
    private static final String HIGH = 'High';
    private static final String MEDIUM = 'Medium';
    private static final String LOW = 'Low';

    public static void classifySeverity(Id incidentId) {
        HSE_Incident__c incident = [
            SELECT Id, Incident_Type__c, Environmental_Impact__c, Injury_Type__c,
                   Fatality_Occurred__c, Spill_Volume__c, Regulatory_Reportable__c
            FROM HSE_Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];

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
        update incident;
    }

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

    public static void notifyComplianceTeam(Id incidentId) {
        HSE_Incident__c incident = [
            SELECT Id, Name, Incident_Type__c, Severity__c, Location__c,
                   Incident_Date__c, Description__c
            FROM HSE_Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<GroupMember> complianceMembers = [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE Group.Name = 'HSE_Compliance_Team'
        ];
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

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

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

    public static void escalateIfCritical(Id incidentId) {
        HSE_Incident__c incident = [
            SELECT Id, Name, Incident_Type__c, Severity__c, Location__c,
                   Incident_Date__c, Description__c
            FROM HSE_Incident__c
            WHERE Id = :incidentId
            LIMIT 1
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<GroupMember> execMembers = [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE Group.Name = 'Executive_Leadership'
        ];
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

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }

        Task escalationTask = new Task(
            Subject = 'Critical Incident Escalation: ' + incident.Name,
            Description = 'Escalated to executive leadership for incident: ' + incident.Id,
            Priority = 'Highest',
            Status = 'Not Started',
            ActivityDate = Date.today(),
            WhatId = incidentId
        );
        insert escalationTask;
    }
}
