/**
 * InvoiceAccountService
 * ======================
 * Keeps Invoice__c.Account__c in sync with the parent Joint_Venture__c lookup
 * (JV__r.Account__c). Invoked from InvoiceAccountTrigger before insert/update.
 *
 * Account__c is the key on the JV_Partner_Sharing Sharing Set, so backfilling
 * this derived field is required for JV-partner portal users to see invoices.
 *
 * Business Process: Billing & Royalties (MIDSTREAM / DOWNSTREAM)
 *   JV Agreement → Invoice Issued → Account Derivation → Portal Sharing
 */
public with sharing class InvoiceAccountService {

    /**
     * Populates Account__c on each invoice from its Joint_Venture__c parent.
     * No-op for invoices without a JV reference.
     * @param invoices  Trigger.new records (before insert / before update)
     */
    public static void populateAccount(List<Invoice__c> invoices) {
        Set<Id> jvIds = new Set<Id>();
        for (Invoice__c invoice : invoices) {
            if (invoice.JV__c != null) {
                jvIds.add(invoice.JV__c);
            }
        }

        if (jvIds.isEmpty()) {
            return;
        }

        Map<Id, Joint_Venture__c> jvById = new Map<Id, Joint_Venture__c>([
            SELECT Id, Account__c
            FROM Joint_Venture__c
            WHERE Id IN :jvIds
        ]);

        for (Invoice__c invoice : invoices) {
            Joint_Venture__c jv = invoice.JV__c != null ? jvById.get(invoice.JV__c) : null;
            if (jv != null) {
                invoice.Account__c = jv.Account__c;
            }
        }
    }
}