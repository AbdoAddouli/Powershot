/**
 * InvoiceAccountTrigger
 * =====================
 * Before-insert/update: derives Invoice__c.Account__c from the parent
 * Joint_Venture__c lookup so the JV_Partner_Sharing Sharing Set can grant
 * read access to portal partners.
 *
 * Used by: InvoiceAccountService
 */
trigger InvoiceAccountTrigger on Invoice__c (before insert, before update) {
    if (Trigger.isBefore) {
        InvoiceAccountService.populateAccount(Trigger.new);
    }
}