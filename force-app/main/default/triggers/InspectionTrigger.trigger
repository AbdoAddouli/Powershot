/**
 * InspectionTrigger
 * ==================
 * After-insert / after-update: collects completed inspections, then updates
 * Last_Inspection_Date__c on parent Assets and Pipelines, and creates
 * recurring follow-up Inspection__c records when Is_Recurring__c is true.
 *
 * Used by: InspectionService
 */
trigger InspectionTrigger on Inspection__c (after insert, after update) {

    if (Trigger.isAfter) {
        List<Inspection__c> completedInspections = new List<Inspection__c>();

        for (Inspection__c inspection : Trigger.new) {
            if (inspection.Status__c == 'Completed' &&
                inspection.Inspection_Date__c != null) {
                completedInspections.add(inspection);
            }
        }

        if (completedInspections.isEmpty()) return;

        InspectionService.updateParentInspectionDates(completedInspections);
        InspectionService.createRecurringInspections(completedInspections);
    }
}
