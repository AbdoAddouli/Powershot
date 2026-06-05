trigger HSEIncidentTrigger on HSE_Incident__c (after insert, after update) {

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            for (HSE_Incident__c incident : Trigger.new) {
                HSEIncidentService.classifySeverity(incident.Id);

                if (incident.Regulatory_Reportable__c) {
                    HSEIncidentService.notifyComplianceTeam(incident.Id);
                }

                if (incident.Severity__c == 'Critical') {
                    HSEIncidentService.escalateIfCritical(incident.Id);
                }
            }
        }

        if (Trigger.isUpdate) {
            Set<Id> needsSeverityUpdate = new Set<Id>();

            for (HSE_Incident__c incident : Trigger.new) {
                HSE_Incident__c old = Trigger.oldMap.get(incident.Id);

                if (incident.Incident_Type__c != old.Incident_Type__c ||
                    incident.Injury_Type__c != old.Injury_Type__c ||
                    incident.Environmental_Impact__c != old.Environmental_Impact__c ||
                    incident.Spill_Volume__c != old.Spill_Volume__c ||
                    incident.Fatality_Occurred__c != old.Fatality_Occurred__c) {
                    needsSeverityUpdate.add(incident.Id);
                }

                if (incident.Regulatory_Reportable__c == true && old.Regulatory_Reportable__c == false) {
                    HSEIncidentService.notifyComplianceTeam(incident.Id);
                }
            }

            for (Id incidentId : needsSeverityUpdate) {
                HSEIncidentService.classifySeverity(incidentId);
            }

            for (HSE_Incident__c incident : Trigger.new) {
                HSE_Incident__c old = Trigger.oldMap.get(incident.Id);
                if (incident.Severity__c != old.Severity__c && incident.Severity__c == 'Critical') {
                    HSEIncidentService.escalateIfCritical(incident.Id);
                }
            }
        }
    }
}
