/**
 * ProductionAllocationTrigger
 * ============================
 * Before-insert defaults numeric volume / interest fields to 0, then validates
 * that working interest across all allocations for the same well stays ≤ 100 %.
 * Before-update enforces that WI + NRI does not exceed 200 %.
 *
 * Used by: ProductionAllocationService
 */
trigger ProductionAllocationTrigger on Production_Allocation__c (before insert, before update) {

    if (Trigger.isBefore) {
        for (Production_Allocation__c alloc : Trigger.new) {
            if (alloc.Oil_Volume_bbls__c == null) {
                alloc.Oil_Volume_bbls__c = 0;
            }
            if (alloc.Gas_Volume_MCF__c == null) {
                alloc.Gas_Volume_MCF__c = 0;
            }
            if (alloc.Water_Volume_bbls__c == null) {
                alloc.Water_Volume_bbls__c = 0;
            }
            if (alloc.Working_Interest_Share__c == null) {
                alloc.Working_Interest_Share__c = 0;
            }
            if (alloc.Net_Revenue_Interest_Share__c == null) {
                alloc.Net_Revenue_Interest_Share__c = 0;
            }
            if (alloc.Days_On_Production__c == null) {
                alloc.Days_On_Production__c = 0;
            }
        }

        if (Trigger.isInsert) {
            ProductionAllocationService.validateWorkingInterest(Trigger.new);
        }

        if (Trigger.isUpdate) {
            for (Production_Allocation__c alloc : Trigger.new) {
                Production_Allocation__c oldAlloc = Trigger.oldMap.get(alloc.Id);
                if (alloc.Working_Interest_Share__c != oldAlloc.Working_Interest_Share__c ||
                    alloc.Net_Revenue_Interest_Share__c != oldAlloc.Net_Revenue_Interest_Share__c) {
                    if (alloc.Working_Interest_Share__c + alloc.Net_Revenue_Interest_Share__c > 200) {
                        alloc.addError(
                            'Combined Working Interest and Net Revenue Interest cannot exceed 200%.'
                        );
                    }
                }
            }
        }
    }
}
