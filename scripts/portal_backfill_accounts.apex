// Portal Account Backfill (Phase 1C) — run once against "ouil gas"
//   sf apex run --file scripts/portal_backfill_accounts.apex -o "ouil gas"
//
// Derives Invoice__c.Account__c from JV__r.Account__c and
// Production_Allocation__c.Account__c from Well__r.Account__c for every
// record where the Account is missing. Account__c powers the
// JV_Partner_Sharing Sharing Set, so this must complete before JV partners
// can see invoices / royalties in the portal.

List<Invoice__c> invoicesToFix = [
    SELECT Id, JV__c, Account__c
    FROM Invoice__c
    WHERE Account__c = NULL AND JV__c != NULL
    ORDER BY Id
];

Integer invoiceIndex = 0;
while (invoiceIndex < invoicesToFix.size()) {
    List<Invoice__c> batch = new List<Invoice__c>();
    for (Integer j = invoiceIndex; j < invoiceIndex + 199 && j < invoicesToFix.size(); j++) {
        batch.add(invoicesToFix[j]);
    }
    invoiceIndex += batch.size();

    InvoiceAccountService.populateAccount(batch);
    update batch;

    System.debug(LoggingLevel.INFO, '[PortalBackfill] Invoices backfilled: ' + batch.size());
}

Integer paOffset = 0;
Integer paLimit = 199;
Boolean paMore = true;

while (paMore) {
    List<Production_Allocation__c> allocations = [
        SELECT Id, Well__c, Account__c
        FROM Production_Allocation__c
        WHERE Account__c = NULL AND Well__c != NULL
        ORDER BY Id
        LIMIT :paLimit
        OFFSET :paOffset
    ];

    paMore = allocations.size() == paLimit;
    paOffset += allocations.size();

    if (!allocations.isEmpty()) {
        ProductionAllocationAccountService.populateAccount(allocations);
        update allocations;
        System.debug(LoggingLevel.INFO, '[PortalBackfill] Allocations backfilled: ' + allocations.size());
    }
}

// Report anything still missing
Integer missingInvoices = [SELECT COUNT() FROM Invoice__c WHERE Account__c = NULL];
Integer missingAllocations = [SELECT COUNT() FROM Production_Allocation__c WHERE Account__c = NULL];

System.debug(LoggingLevel.INFO, '[PortalBackfill] DONE. Invoices still missing Account: ' + missingInvoices);
System.debug(LoggingLevel.INFO, '[PortalBackfill] DONE. Allocations still missing Account: ' + missingAllocations);