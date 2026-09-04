/**
 * ProductionAllocationAccountService
 * ===================================
 * Keeps Production_Allocation__c.Account__c in sync with the parent Well__c
 * lookup (Well__r.Account__c). Invoked from ProductionAllocationTrigger
 * before insert/update.
 *
 * Account__c is the key on the JV_Partner_Sharing Sharing Set, so backfilling
 * this derived field is required for JV-partner portal users to see royalties,
 * production allocations, and per-well production data.
 *
 * Business Process: Production Allocation (UPSTREAM)
 *   Well Production → Monthly Allocation → Account Derivation → Portal Sharing
 */
public with sharing class ProductionAllocationAccountService {

    /**
     * Populates Account__c on each allocation from its Well__c parent.
     * No-op for allocations without a Well reference.
     * @param allocations  Trigger.new records (before insert / before update)
     */
    public static void populateAccount(List<Production_Allocation__c> allocations) {
        Set<Id> wellIds = new Set<Id>();
        for (Production_Allocation__c allocation : allocations) {
            if (allocation.Well__c != null) {
                wellIds.add(allocation.Well__c);
            }
        }

        if (wellIds.isEmpty()) {
            return;
        }

        Map<Id, Well__c> wellById = new Map<Id, Well__c>([
            SELECT Id, Account__c
            FROM Well__c
            WHERE Id IN :wellIds
        ]);

        for (Production_Allocation__c allocation : allocations) {
            Well__c well = allocation.Well__c != null ? wellById.get(allocation.Well__c) : null;
            if (well != null) {
                allocation.Account__c = well.Account__c;
            }
        }
    }
}