public with sharing class RoyaltyCalculationService {

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

    public static void generateRoyaltyStatements(Id leaseId, Date periodStart, Date periodEnd) {
        Lease__c lease = [
            SELECT Id, Name, Royalty_Percent__c, Account__c
            FROM Lease__c
            WHERE Id = :leaseId
            LIMIT 1
        ];

        Map<Id, Decimal> partnerPayments = calculateMonthlyRoyalties(leaseId, periodStart, periodEnd);
        List<Task> royaltyTasks = new List<Task>();

        for (Id partnerId : partnerPayments.keySet()) {
            Joint_Venture__c partner = [
                SELECT Id, Name, Account__c
                FROM Joint_Venture__c
                WHERE Id = :partnerId
                LIMIT 1
            ];

            Task t = new Task(
                Subject = 'Royalty Payment - ' + lease.Name + ' - ' + partner.Name,
                Description = 'Royalty of $' + partnerPayments.get(partnerId) +
                              ' for period ' + periodStart + ' to ' + periodEnd,
                Status = 'Not Started',
                Priority = 'Normal',
                ActivityDate = Date.today(),
                WhatId = leaseId
            );
            royaltyTasks.add(t);
        }

        if (!royaltyTasks.isEmpty()) {
            insert royaltyTasks;
        }
    }
}
