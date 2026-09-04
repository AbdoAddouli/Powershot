// ============================================================
// SETUP OILPRICE API (REPLACED 2026-09-03)
// ------------------------------------------------------------
// The OilPriceAPI token is NO LONGER stored in API_Key_Settings__c
// and must NOT be committed to source control.
//
// CommodityPricingService now sends:
//     Authorization: Token {!$Credential.Password}
// The token therefore lives ONLY in the org, provisioned on the
// 'CommodityPricing' EXTERNAL CREDENTIAL's principal Password field
// (Username is a placeholder), verified live HTTP 200 on 2026-09-03:
//   Setup > Named Credentials > CommodityPricing > edit principal
//   Username = (placeholder)
//   Password = <OilPriceAPI token>   (encrypted)
//
// This .apex file is retained as documentation only. Do not set the
// token through Apex or inline scripts. If you must record it for
// troubleshooting, use a scratch/per-environment secret store, never git.
//
// Legacy pattern (removed) stored the key in API_Key_Settings__c:
//   API_Key_Settings__c s = API_Key_Settings__c.getOrgDefaults();
//   s.OilPrice_API_Key__c = '<SECRET REMOVED>';
//   upsert s;
System.debug('=== OilPriceAPI token lives in the CommodityPricing external credential Password ({!$Credential.Password}) ===');
System.debug('=== Do not store OilPrice credentials in source control. ===');
