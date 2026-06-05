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
            Set<Id> wellIds = new Set<Id>();
            for (Production_Allocation__c alloc : Trigger.new) {
                if (alloc.Well__c != null) {
                    wellIds.add(alloc.Well__c);
                }
            }

            if (!wellIds.isEmpty()) {
                Map<Id, List<Production_Allocation__c>> existingByWell = new Map<Id, List<Production_Allocation__c>>();
                for (Production_Allocation__c alloc : [
                    SELECT Well__c, Working_Interest_Share__c
                    FROM Production_Allocation__c
                    WHERE Well__c IN :wellIds
                ]) {
                    if (!existingByWell.containsKey(alloc.Well__c)) {
                        existingByWell.put(alloc.Well__c, new List<Production_Allocation__c>());
                    }
                    existingByWell.get(alloc.Well__c).add(alloc);
                }

                for (Production_Allocation__c alloc : Trigger.new) {
                    if (alloc.Well__c != null && existingByWell.containsKey(alloc.Well__c)) {
                        List<Production_Allocation__c> existing = existingByWell.get(alloc.Well__c);
                        Decimal totalWi = alloc.Working_Interest_Share__c != null ? alloc.Working_Interest_Share__c : 0;
                        for (Production_Allocation__c ex : existing) {
                            totalWi += ex.Working_Interest_Share__c != null ? ex.Working_Interest_Share__c : 0;
                        }
                        if (totalWi > 100) {
                            alloc.addError(
                                'Total Working Interest for well ' + alloc.Well__c +
                                ' exceeds 100%. Current total: ' + totalWi + '%'
                            );
                        }
                    }
                }
            }
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
