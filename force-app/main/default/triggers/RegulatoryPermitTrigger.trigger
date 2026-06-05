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

        if (!expiringPermitIds.isEmpty()) {
            List<Regulatory_Permit__c> expiringPermits = [
                SELECT Id, Name, Permit_Type__c, Expiration_Date__c,
                       Responsible_Party__c, Compliance_Status__c
                FROM Regulatory_Permit__c
                WHERE Id IN :expiringPermitIds
            ];

            List<Regulatory_Permit__c> toUpdate = new List<Regulatory_Permit__c>();

            for (Regulatory_Permit__c permit : expiringPermits) {
                if (permit.Expiration_Date__c <= Date.today()) {
                    permit.Compliance_Status__c = 'Expired';
                } else if (permit.Expiration_Date__c <= Date.today().addDays(30)) {
                    permit.Compliance_Status__c = 'Critical - Expiring Soon';
                } else {
                    permit.Compliance_Status__c = 'Approaching Expiration';
                }
                toUpdate.add(permit);
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
        }

        if (!statusChangedPermitIds.isEmpty()) {
            List<Regulatory_Permit__c> statusChanged = [
                SELECT Id, Name, Status__c, Compliance_Status__c
                FROM Regulatory_Permit__c
                WHERE Id IN :statusChangedPermitIds
            ];

            List<Regulatory_Permit__c> toUpdate = new List<Regulatory_Permit__c>();

            for (Regulatory_Permit__c permit : statusChanged) {
                if (permit.Status__c == 'Active' || permit.Status__c == 'Approved') {
                    permit.Compliance_Status__c = 'Compliant';
                } else if (permit.Status__c == 'Expired') {
                    permit.Compliance_Status__c = 'Expired';
                } else if (permit.Status__c == 'Suspended' || permit.Status__c == 'Revoked') {
                    permit.Compliance_Status__c = 'Non-Compliant';
                }
                toUpdate.add(permit);
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
        }
    }
}
