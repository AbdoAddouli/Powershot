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
        if (Trigger.isInsert) {
            for (Well__c well : Trigger.new) {
                if (well.Status__c != 'Permitted') {
                    WellStatusService.createWellOperationOnStatusChange(well.Id, well.Status__c);
                }
            }
        }

        if (Trigger.isUpdate) {
            for (Well__c well : Trigger.new) {
                Well__c oldWell = Trigger.oldMap.get(well.Id);
                if (well.Status__c != oldWell.Status__c) {
                    WellStatusService.createWellOperationOnStatusChange(well.Id, well.Status__c);
                }
            }
        }
    }
}
