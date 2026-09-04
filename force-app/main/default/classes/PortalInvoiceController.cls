/**
 * PortalInvoiceController
 * ========================
 * LWC-facing data layer for the Experience Cloud portal Billing & Royalties
 * page. Returns invoices and royalty statements (production allocations with
 * revenue shares), plus a billing summary — all scoped to the portal user's
 * shared records via "with sharing".
 *
 * Data flows through the JV_Partner_Sharing Sharing Set keyed on Account__c,
 * so a JV-partner user only ever sees their own account's records.
 */
public with sharing class PortalInvoiceController {

    @AuraEnabled(cacheable=true)
    public static List<Invoice__c> getInvoices(String statusFilter, Integer maxRows) {
        if (!Schema.sObjectType.Invoice__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to view invoices.');
        }
        Integer limitVal = maxRows != null && maxRows > 0 ? maxRows : 50;
        if (String.isNotBlank(statusFilter)) {
            return [
                SELECT Id, Name, Invoice_Date__c, Amount__c, Status__c,
                       JV__c, JV__r.Name, Account__c, Account__r.Name
                FROM Invoice__c
                WHERE Status__c = :statusFilter
                ORDER BY Invoice_Date__c DESC NULLS LAST
                LIMIT :limitVal
            ];
        }
        return [
            SELECT Id, Name, Invoice_Date__c, Amount__c, Status__c,
                   JV__c, JV__r.Name, Account__c, Account__r.Name
            FROM Invoice__c
            ORDER BY Invoice_Date__c DESC NULLS LAST
            LIMIT :limitVal
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Production_Allocation__c> getRoyaltyStatements(Integer maxRows) {
        if (!Schema.sObjectType.Production_Allocation__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to view royalty statements.');
        }
        Integer limitVal = maxRows != null && maxRows > 0 ? maxRows : 12;
        return [
            SELECT Id, Name, Period_Start__c, Period_End__c,
                   Well__c, Well__r.Name,
                   Oil_Volume_bbls__c, Gas_Volume_MCF__c, Water_Volume_bbls__c,
                   Allocated_Revenue__c, Working_Interest_Share__c,
                   Net_Revenue_Interest_Share__c, Severance_Tax__c,
                   Account__c, Account__r.Name
            FROM Production_Allocation__c
            WHERE Allocated_Revenue__c != NULL
            ORDER BY Period_End__c DESC NULLS LAST
            LIMIT :limitVal
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBillingSummary() {
        Map<String, Object> result = new Map<String, Object>();

        if (!Schema.sObjectType.Invoice__c.isAccessible() ||
            !Schema.sObjectType.Production_Allocation__c.isAccessible()) {
            throw new AuraHandledException('Insufficient permissions to view billing.');
        }

        AggregateResult outstanding = [
            SELECT SUM(Amount__c) total
            FROM Invoice__c
            WHERE Status__c NOT IN ('Paid', 'Cancelled')
        ];
        AggregateResult paid = [
            SELECT SUM(Amount__c) total
            FROM Invoice__c
            WHERE Status__c = 'Paid'
        ];
        AggregateResult overdue = [
            SELECT SUM(Amount__c) total
            FROM Invoice__c
            WHERE Status__c = 'Overdue'
        ];
        AggregateResult royalty = [
            SELECT SUM(Allocated_Revenue__c) total
            FROM Production_Allocation__c
            WHERE Period_End__c >= :Date.today().addMonths(-12)
        ];

        result.put('totalInvoices', [SELECT COUNT() FROM Invoice__c]);
        result.put('outstandingAmount', outstanding.get('total') != null ? outstanding.get('total') : 0);
        result.put('paidAmount', paid.get('total') != null ? paid.get('total') : 0);
        result.put('overdueAmount', overdue.get('total') != null ? overdue.get('total') : 0);
        result.put('royalty12Months', royalty.get('total') != null ? royalty.get('total') : 0);

        return result;
    }
}