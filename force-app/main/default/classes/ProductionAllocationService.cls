/**
 * ProductionAllocationService
 * ============================
 * Allocates oil / gas / water volumes to wells by period, calculates revenue
 * shares based on working/revenue interest, and enforces that total working
 * interest does not exceed 100 %. Used by ProductionAllocationTrigger and LWCs.
 *
 * Business Process: Production Allocation (Upstream)
 *   Production Measurement → Volume Allocation → Working Interest Validation
 *   → Revenue Calculation → Royalty Distribution
 */
public with sharing class ProductionAllocationService {

    /**
     * Creates a Production_Allocation__c record for the given well and period
     * if one does not already exist, copying working/revenue interest from the lease.
     * @param wellId  The Well__c Id
     * @param periodStart  Start of the allocation period
     * @param periodEnd  End of the allocation period
     */
    public static void calculateMonthlyAllocation(Id wellId, Date periodStart, Date periodEnd) {
        Well__c well = [
            SELECT Id, Lease__c, Lease__r.Working_Interest_Percent__c,
                   Lease__r.Revenue_Interest_Percent__c
            FROM Well__c
            WHERE Id = :wellId
            LIMIT 1
        ];

        List<Production_Allocation__c> allocations = [
            SELECT Id, Oil_Volume_bbls__c, Gas_Volume_MCF__c, Water_Volume_bbls__c,
                   Period_Start__c, Period_End__c
            FROM Production_Allocation__c
            WHERE Well__c = :wellId
                AND Period_Start__c >= :periodStart
                AND Period_End__c <= :periodEnd
        ];

        if (allocations.isEmpty()) {
            Production_Allocation__c alloc = new Production_Allocation__c(
                Well__c = wellId,
                Lease__c = well.Lease__c,
                Period_Start__c = periodStart,
                Period_End__c = periodEnd,
                Working_Interest_Share__c = well.Lease__r.Working_Interest_Percent__c,
                Net_Revenue_Interest_Share__c = well.Lease__r.Revenue_Interest_Percent__c
            );
            insert alloc;
        }
    }

    /**
     * Returns the Allocated_Revenue__c for a given allocation (or 0 if null).
     * @param allocationId  The Production_Allocation__c Id
     * @return  Allocated revenue amount
     */
    public static Decimal getAllocatedRevenue(Id allocationId) {
        Production_Allocation__c allocation = [
            SELECT Id, Allocated_Revenue__c
            FROM Production_Allocation__c
            WHERE Id = :allocationId
            LIMIT 1
        ];
        return allocation.Allocated_Revenue__c != null ? allocation.Allocated_Revenue__c : 0;
    }

    /**
     * Validates that the total Working Interest for a well does not exceed 100 %
     * for the same period. Adds an error on the record if violated.
     * @param newAllocations  The allocations being inserted
     */
    public static void validateWorkingInterest(List<Production_Allocation__c> newAllocations) {
        Set<Id> wellIds = new Set<Id>();
        for (Production_Allocation__c alloc : newAllocations) {
            if (alloc.Well__c != null) {
                wellIds.add(alloc.Well__c);
            }
        }

        if (wellIds.isEmpty()) return;

        Map<Id, List<Production_Allocation__c>> existingByWell = new Map<Id, List<Production_Allocation__c>>();
        for (Production_Allocation__c alloc : [
            SELECT Well__c, Working_Interest_Share__c, Period_Start__c, Period_End__c
            FROM Production_Allocation__c
            WHERE Well__c IN :wellIds
        ]) {
            if (!existingByWell.containsKey(alloc.Well__c)) {
                existingByWell.put(alloc.Well__c, new List<Production_Allocation__c>());
            }
            existingByWell.get(alloc.Well__c).add(alloc);
        }

        for (Production_Allocation__c alloc : newAllocations) {
            if (alloc.Well__c != null && existingByWell.containsKey(alloc.Well__c)) {
                Decimal totalWi = alloc.Working_Interest_Share__c != null ? alloc.Working_Interest_Share__c : 0;
                for (Production_Allocation__c ex : existingByWell.get(alloc.Well__c)) {
                    if (ex.Id == alloc.Id) continue;
                    if (periodsOverlap(alloc.Period_Start__c, alloc.Period_End__c, ex.Period_Start__c, ex.Period_End__c)) {
                        totalWi += ex.Working_Interest_Share__c != null ? ex.Working_Interest_Share__c : 0;
                    }
                }
                if (totalWi > 100) {
                    alloc.addError(
                        'Total Working Interest for well ' + alloc.Well__c +
                        ' exceeds 100% for this period. Current total: ' + totalWi + '%'
                    );
                }
            }
        }
    }

    private static Boolean periodsOverlap(Date startA, Date endA, Date startB, Date endB) {
        if (startA == null || endA == null || startB == null || endB == null) return true;
        return startA <= endB && endA >= startB;
    }

    /**
     * @AuraEnabled LWC-facing method returning production history for a well.
     * @param wellId  The Well__c Id
     * @param months  Look-back window in months
     * @return  Allocations ordered by period end descending
     */
    @AuraEnabled(cacheable=true)
    public static List<Production_Allocation__c> getProductionHistory(Id wellId, Integer months) {
        Date cutoffDate = Date.today().addMonths(-months);
        return [
            SELECT Id, Oil_Volume_bbls__c, Gas_Volume_MCF__c, Water_Volume_bbls__c,
                   Period_Start__c, Period_End__c, Allocated_Revenue__c,
                   Working_Interest_Share__c, Net_Revenue_Interest_Share__c
            FROM Production_Allocation__c
            WHERE Well__c = :wellId
                AND Period_End__c >= :cutoffDate
            ORDER BY Period_End__c DESC
        ];
    }
}
