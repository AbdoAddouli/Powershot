/**
 * RoyaltyCalculationService
 * ==========================
 * Computes royalty payments from production allocation revenue for lease
 * partners (Joint Ventures), and generates Tasks to track pending payments.
 *
 * Business Process: Revenue / Royalty Management (Upstream / Commercial)
 *   Production Allocated → Revenue Calculated → Royalty Rate Applied
 *   → Partner Distribution → Payment Task Creation
 */
public with sharing class RoyaltyCalculationService {

    /**
     * Calculates the royalty payment for a single lease and allocation.
     * @param leaseId  The Lease__c Id
     * @param allocationId  The Production_Allocation__c Id
     * @return  Royalty amount (Allocated_Revenue__c * Royalty_Percent__c / 100)
     */
    public static Decimal calculateRoyaltyPayment(Id leaseId, Id allocationId) {
        Lease__c lease = [
            SELECT Id, Royalty_Percent__c, Lease_Type__c
            FROM Lease__c
            WHERE Id = :leaseId
            LIMIT 1
        ];

        Production_Allocation__c allocation = [
            SELECT Id, Allocated_Revenue__c, Oil_Volume_bbls__c, Well__c
            FROM Production_Allocation__c
            WHERE Id = :allocationId
            LIMIT 1
        ];

        if (lease.Royalty_Percent__c == null || allocation.Allocated_Revenue__c == null) {
            return 0;
        }

        return allocation.Allocated_Revenue__c * (lease.Royalty_Percent__c / 100);
    }

    /**
     * Calculates royalty payments for all active JV partners on a lease for
     * a given period, based on each partner's Revenue Interest percentage.
     * @param leaseId  The Lease__c Id
     * @param periodStart  Start of the period
     * @param periodEnd  End of the period
     * @return  Map of Joint_Venture__c Id to calculated payment amount
     */
    public static Map<Id, Decimal> calculateMonthlyRoyalties(Id leaseId, Date periodStart, Date periodEnd) {
        Lease__c lease = [
            SELECT Id, Royalty_Percent__c, Lease_Type__c, Account__c
            FROM Lease__c
            WHERE Id = :leaseId
            LIMIT 1
        ];

        List<Joint_Venture__c> partners = new List<Joint_Venture__c>();
        if (lease.Account__c != null) {
            partners = [
                SELECT Id, Name, Working_Interest_Percent__c, Revenue_Interest_Percent__c,
                       Account__c, Operator__c
                FROM Joint_Venture__c
                WHERE Account__c = :lease.Account__c
                    AND Status__c = 'Active'
            ];
        }

        List<Production_Allocation__c> allocations = [
            SELECT Id, Allocated_Revenue__c, Oil_Volume_bbls__c
            FROM Production_Allocation__c
            WHERE Lease__c = :leaseId
                AND Period_Start__c >= :periodStart
                AND Period_End__c <= :periodEnd
        ];

        Map<Id, Decimal> partnerPayments = new Map<Id, Decimal>();

        Decimal totalRevenue = 0;
        for (Production_Allocation__c alloc : allocations) {
            totalRevenue += alloc.Allocated_Revenue__c != null ? alloc.Allocated_Revenue__c : 0;
        }

        Decimal leaseRoyaltyRate = lease.Royalty_Percent__c != null ? lease.Royalty_Percent__c : 0;
        Decimal totalRoyalty = totalRevenue * (leaseRoyaltyRate / 100);

        for (Joint_Venture__c partner : partners) {
            Decimal partnerPct = partner.Revenue_Interest_Percent__c != null ? partner.Revenue_Interest_Percent__c : 0;
            Decimal payment = totalRoyalty * (partnerPct / 100);
            partnerPayments.put(partner.Id, payment);
        }

        return partnerPayments;
    }

    /**
     * Creates a Task for each JV partner documenting the calculated royalty
     * payment for the given period.
     * @param leaseId  The Lease__c Id
     * @param periodStart  Start of the royalty period
     * @param periodEnd  End of the royalty period
     */
    public static void generateRoyaltyStatements(Id leaseId, Date periodStart, Date periodEnd) {
        Lease__c lease = [
            SELECT Id, Name, Royalty_Percent__c, Account__c
            FROM Lease__c
            WHERE Id = :leaseId
            LIMIT 1
        ];

        List<Joint_Venture__c> partners = new List<Joint_Venture__c>();
        if (lease.Account__c != null) {
            partners = [
                SELECT Id, Name, Revenue_Interest_Percent__c
                FROM Joint_Venture__c
                WHERE Account__c = :lease.Account__c
                    AND Status__c = 'Active'
            ];
        }

        List<Production_Allocation__c> allocations = [
            SELECT Id, Allocated_Revenue__c
            FROM Production_Allocation__c
            WHERE Lease__c = :leaseId
                AND Period_Start__c >= :periodStart
                AND Period_End__c <= :periodEnd
        ];

        Decimal totalRevenue = 0;
        for (Production_Allocation__c alloc : allocations) {
            totalRevenue += alloc.Allocated_Revenue__c != null ? alloc.Allocated_Revenue__c : 0;
        }

        Decimal leaseRoyaltyRate = lease.Royalty_Percent__c != null ? lease.Royalty_Percent__c : 0;
        Decimal totalRoyalty = totalRevenue * (leaseRoyaltyRate / 100);

        List<Task> royaltyTasks = new List<Task>();
        for (Joint_Venture__c partner : partners) {
            Decimal partnerPct = partner.Revenue_Interest_Percent__c != null ? partner.Revenue_Interest_Percent__c : 0;
            Decimal payment = totalRoyalty * (partnerPct / 100);

            royaltyTasks.add(new Task(
                Subject = 'Royalty Payment - ' + lease.Name + ' - ' + partner.Name,
                Description = 'Royalty of $' + payment +
                              ' for period ' + periodStart + ' to ' + periodEnd,
                Status = 'Not Started',
                Priority = 'Normal',
                ActivityDate = Date.today(),
                WhatId = leaseId
            ));
        }

        if (!royaltyTasks.isEmpty()) {
            insert royaltyTasks;
        }
    }
}
