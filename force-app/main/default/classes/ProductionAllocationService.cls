public with sharing class ProductionAllocationService {

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

    public static Decimal getAllocatedRevenue(Id allocationId) {
        Production_Allocation__c allocation = [
            SELECT Id, Allocated_Revenue__c
            FROM Production_Allocation__c
            WHERE Id = :allocationId
            LIMIT 1
        ];
        return allocation.Allocated_Revenue__c != null ? allocation.Allocated_Revenue__c : 0;
    }

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
