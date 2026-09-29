/**
 * WellTrigger
 * ============
 * Before-insert defaults status to 'Permitted' and validates Name. Before-update
 * enforces valid lifecycle transitions via WellStatusService. After-insert/update
 * creates Well_Operation__c audit records for any non-default status changes.
 *
 * Used by: WellStatusService
 */
trigger WellTrigger on Well__c (before insert, before update, after insert, after update) {

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            for (Well__c well : Trigger.new) {
                if (String.isBlank(well.Name)) {
                    well.addError('Well Name is required.');
                }
                if (well.Status__c == null) {
                    well.Status__c = 'Permitted';
                }
                if (well.Status_Change_Date__c == null) {
                    well.Status_Change_Date__c = Date.today();
                }
            }
        }

        if (Trigger.isUpdate) {
            for (Well__c well : Trigger.new) {
                Well__c oldWell = Trigger.oldMap.get(well.Id);
                if (well.Status__c != oldWell.Status__c) {
                    if (!WellStatusService.isValidTransition(oldWell.Status__c, well.Status__c)) {
                        well.addError(
                            'Invalid status transition from "' + oldWell.Status__c +
                            '" to "' + well.Status__c + '".'
                        );
                    }
                    well.Status_Change_Date__c = Date.today();
                }
            }
        }
    }

    if (Trigger.isAfter) {
        List<Well__c> statusChangedWells = new List<Well__c>();

        if (Trigger.isInsert) {
            for (Well__c well : Trigger.new) {
                if (well.Status__c != 'Permitted') {
                    statusChangedWells.add(well);
                }
            }
        }

        if (Trigger.isUpdate) {
            for (Well__c well : Trigger.new) {
                Well__c oldWell = Trigger.oldMap.get(well.Id);
                if (well.Status__c != oldWell.Status__c) {
                    statusChangedWells.add(well);
                }
            }
        }

        if (!statusChangedWells.isEmpty()) {
            WellStatusService.createWellOperations(statusChangedWells);
        }
    }
}
