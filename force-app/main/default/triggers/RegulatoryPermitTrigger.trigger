/**
 * RegulatoryPermitTrigger
 * ========================
 * After-insert / after-update: passes expiring and status-changed permit IDs
 * to ComplianceDueDateService.updateComplianceStatuses(), which sets the
 * Compliance_Status__c field (Compliant / Expired / Non-Compliant).
 *
 * Used by: ComplianceDueDateService
 */
trigger RegulatoryPermitTrigger on Regulatory_Permit__c (after insert, after update) {

    if (Trigger.isAfter) {
        Set<Id> expiringPermitIds = new Set<Id>();
        Set<Id> statusChangedPermitIds = new Set<Id>();

        if (Trigger.isInsert) {
            for (Regulatory_Permit__c permit : Trigger.new) {
                if (permit.Expiration_Date__c != null &&
                    permit.Expiration_Date__c <= Date.today().addDays(90)) {
                    expiringPermitIds.add(permit.Id);
                }
            }
        }

        if (Trigger.isUpdate) {
            for (Regulatory_Permit__c permit : Trigger.new) {
                Regulatory_Permit__c old = Trigger.oldMap.get(permit.Id);

                if (permit.Status__c != old.Status__c) {
                    statusChangedPermitIds.add(permit.Id);
                }

                if (permit.Expiration_Date__c != old.Expiration_Date__c &&
                    permit.Expiration_Date__c != null &&
                    permit.Expiration_Date__c <= Date.today().addDays(90)) {
                    expiringPermitIds.add(permit.Id);
                }
            }
        }

        ComplianceDueDateService.updateComplianceStatuses(expiringPermitIds, statusChangedPermitIds);
    }
}
