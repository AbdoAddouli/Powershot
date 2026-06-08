/**
 * HSEIncidentTrigger
 * ===================
 * After-insert: classifies severity, notifies compliance for reportable
 * incidents, and escalates critical incidents. After-update: re-classifies
 * when incident details change, notifies on newly reportable status, and
 * escalates when severity becomes Critical.
 *
 * Used by: HSEIncidentService
 */
trigger HSEIncidentTrigger on HSE_Incident__c (after insert, after update) {

    if (Trigger.isAfter) {
        List<Id> classifyIds = new List<Id>();
        List<Id> notifyIds = new List<Id>();
        List<Id> escalateIds = new List<Id>();

        if (Trigger.isInsert) {
            for (HSE_Incident__c incident : Trigger.new) {
                classifyIds.add(incident.Id);

                if (incident.Regulatory_Reportable__c) {
                    notifyIds.add(incident.Id);
                }

                if (incident.Severity__c == 'Critical') {
                    escalateIds.add(incident.Id);
                }
            }
        }

        if (Trigger.isUpdate) {
            for (HSE_Incident__c incident : Trigger.new) {
                HSE_Incident__c old = Trigger.oldMap.get(incident.Id);

                if (incident.Incident_Type__c != old.Incident_Type__c ||
                    incident.Injury_Type__c != old.Injury_Type__c ||
                    incident.Environmental_Impact__c != old.Environmental_Impact__c ||
                    incident.Spill_Volume__c != old.Spill_Volume__c ||
                    incident.Fatality_Occurred__c != old.Fatality_Occurred__c) {
                    classifyIds.add(incident.Id);
                }

                if (incident.Regulatory_Reportable__c == true && old.Regulatory_Reportable__c == false) {
                    notifyIds.add(incident.Id);
                }

                if (incident.Severity__c != old.Severity__c && incident.Severity__c == 'Critical') {
                    escalateIds.add(incident.Id);
                }
            }
        }

        if (!classifyIds.isEmpty()) {
            HSEIncidentService.classifySeverities(classifyIds);
        }

        if (!notifyIds.isEmpty()) {
            HSEIncidentService.notifyComplianceTeams(notifyIds);
        }

        if (!escalateIds.isEmpty()) {
            HSEIncidentService.escalateIfCritical(escalateIds);
        }
    }
}
