# Deploy Summary

## Status: ✅ All force-app metadata deploys with zero failures

All custom objects, fields, Apex classes, triggers, LWCs, permission sets, and record types deploy successfully to `addouliabdo9.76deae143000@agentforce.com`.

---

## Session 1: What was fixed (12 deploys)

### Schema
- **12 LongTextArea fields** were changed from `<type>TextArea</type>` → `<type>LongTextArea</type>` with `<length>32768</length>` added
- **Refinery__c.Units_List__c** — added `<visibleLines>4</visibleLines>`
- **Created Inventory_Transaction__c** — new child object of `Fuel_Inventory__c` with 7 fields

### Apex classes rewritten
| Class | Issue | Fix |
|---|---|---|
| `InventoryBalanceService` | Reserved word `transaction`, invalid subquery with `LIMIT`, reserved param `limit` | Renamed to `txn`, removed subquery, filter in Apex instead |
| `HSEIncidentService` | `setTargetObjectIds(List<String>)`, missing `getHSEIncidents` | Changed to `setTargetObjectId(Id)`, added `@AuraEnabled getHSEIncidents` |
| `PermitToWorkValidationService` | Fields not deployed yet | Resolved once LongTextArea fields deployed |
| `ProductionAllocationService` | Wired method missing | Added `@AuraEnabled(cacheable=true)` to `getProductionHistory` |
| `ComplianceDueDateService` | `getUpcomingDeadlines` missing | Added `@AuraEnabled getUpcomingDeadlines(Id)` |
| `ProductionAllocationService` | References to `Well_Production__c`, `Working_Interest__c` | Rewritten to use `Production_Allocation__c`, `Lease__c` |
| `RoyaltyCalculationService` | References to `Mineral_Lease__c`, `Mineral_Right_Owner__c`, `Royalty_Statement__c` | Rewritten to use `Lease__c`, `Joint_Venture__c` |
| `WellStatusService` | Missing `getWellProduction` | Added method returning `Production_Allocation__c` |
| **New: `InspectionService`** | Did not exist | Created with `getChecklistItems` and `submitChecklist` |

### LWC fixes
| LWC | Fix |
|---|---|
| `productionAllocationReport` | Updated to use real `Production_Allocation__c` field names |
| `complianceCalendar` | Removed `c:errorPanel`, fixed Apex method reference |
| `hseIncidentMap` | Simplified to datatable (no geolocation fields available) |
| `inventoryTankGauge` | Removed `c:errorPanel`, fixed Apex method reference |
| `fieldServiceChecklist` | Removed `c:errorPanel`, fixed Apex method reference, updated fields |
| All LWCs | Removed all `c:errorPanel` references (component doesn't exist) |

---

## Session 2: Commodity Pricing Integration & O&G Services

### Deployed
- **Apex Classes (15 total):**
  - `WellStatusService` — Well lifecycle state machine (Permitted→Drilling→Producing→Shut-In→Suspended→Plugged→Abandoned)
  - `ProductionAllocationService` — Production split across working interests
  - `PipelineIntegrityService` — Risk scoring & assessment recommendations
  - `InventoryBalanceService` — Daily volume changes, min/max alerts
  - `InspectionService` — Recurring inspection scheduling
  - `PermitToWorkValidationService` — Permit validation & approvals
  - `ComplianceDueDateService` — Compliance deadline tracking
  - `HSEIncidentService` — Incident severity scoring & escalation
  - `CommodityPricingService` — OilPriceAPI integration (`@future(callout=true)`)
  - `CommodityPriceSyncScheduler` — Schedulable wrapper for daily 06:00 sync
  - `TestCommercialServices`, `TestFieldServices`, `TestHSEServices`, `TestWellLifecycle` — Test classes
- **CSP Trusted Site:** `CommodityPricing` for `https://api.oilpriceapi.com`
- **Named Credential:** `CommodityPricing` (Anonymous, NoAuthentication — auth in code)
- **Permission Set:** `Energy_Platform_Admin`
- **Scheduled Job:** Daily sync at 06:00 (Job Id: `08egK00000WlJrHQAV`, state: `WAITING`)

### Key Decisions
- **Auth in-code:** NamedCredential `authValues` not supported in API v66.0 → set `Authorization: Token` header via `req.setHeader()` in Apex
- **OilPriceAPI per-commodity:** API returns one price per `?by_code=CODE` (no bulk) → loop per commodity
- **Code-to-API mapping:** `Crude→WTI_USD`, `Gas→NATURAL_GAS_USD`, `NGL→BRENT_CRUDE_USD`, `Refined→GASOLINE_USD`, `Diesel→DIESEL_USD`, `Jet Fuel→JET_FUEL_USD`, `Heating Oil→HEATING_OIL_USD`

---

---

## Session 3: Named Credential Refactoring, Slack Alert Flow & EIA Integration

### What Changed

- **Named Credential auth changed** from `Anonymous/NoAuthentication` with in-code auth header, to **`Basic protocol` + `NamedPrincipal`** with credentials stored via `ConnectApi.NamedCredentials.createCredential()`
- **External Credentials** created for `CommodityPricing`, `EIA_API`, and `Slack_HSE_Webhook`
- **Slack HSE Alert** (`HSE_Critical_Slack_Alert` flow) now sends to `#hse-emergency` via `@future(callout=true)` — working end-to-end
- **EIA API** (`EIAPricingService`) fetches weekly retail fuel prices + national crude stock levels
- **CommodityPricing** (`CommodityPricingService`) now uses `{!$Credential.Password}` merge field in headers (resolved by Named Credential framework)
- **API keys stored in `.env`** at project root, populated at runtime via Apex `ConnectApi.NamedCredentials.createCredential()` (never in metadata XML)
- **Secrets for Slack webhook** use dummy credentials — Slack ignores Basic auth, webhook URL provides all auth

### Deployed

| Component | Type | Details |
|---|---|---|
| `SlackAlertService` | Apex class | `@future(callout=true)` sends JSON to Slack webhook |
| `CommodityPricingService` | Apex class | Refactored: `{!$Credential.Password}` header, 7 commodity codes |
| `CommodityPriceSyncScheduler` | Apex class | Schedulable wrapper for daily 06:00 sync |
| `EIAPricingService` | Apex class | Fetch retail prices + national stocks via `X-Api-Key` header |
| `EIAPriceSyncScheduler` | Apex class | Schedulable wrapper |
| `TestEIAPricingService` | Apex test | 17 tests: response parsing + sync logic |
| `TestAPIEndToEnd` | Apex class | Manual test via anonymous Apex (`@future(callout=true)`) |
| `Slack_HSE_Webhook` | Named Credential | `SecuredEndpoint`, dummy Basic credentials |
| `CommodityPricing` | Named Credential | `SecuredEndpoint`, `{!$Credential.Password}` resolved by NC |
| `EIA_API` | Named Credential | `SecuredEndpoint`, `allowMergeFieldsInHeader=true` |
| `CommodityPricing` | External Credential | Basic protocol, `NamedPrincipal` |
| `EIA_API` | External Credential | Basic protocol, `NamedPrincipal` |
| `Slack_HSE_Webhook` | External Credential | Basic protocol, `NamedPrincipal` |
| CSP trusted sites | 3 | `CommodityPricing`, `EIA_API`, `Slack` |
| `O_G_All_Access` | Permission Set | Updated with `SetupEntityAccess` grants |
| `HSE_Critical_Slack_Alert` | Flow | AutoLaunched, triggers on Critical severity update |

### Verified

- All **86 tests pass**
- **Commodity API** (OilPriceAPI): WTI Crude = **$72.84/barrel** (via Named Credential callout)
- **EIA Price API**: U.S. Gasoline = **$4.048/gallon** (via `X-Api-Key` header)
- **EIA Stock API**: U.S. Crude Stocks = **758,473 MBBL** (via `X-Api-Key` header)
- **Slack alert**: Confirmed delivered to `#hse-emergency` (no error Task)
- **Named Credentials** authenticate via merge field resolution in headers (Commodity) and custom headers (EIA)

### Key Decisions

- **NamedPrincipal needs SetupEntityAccess**: `SetupEntityAccess` record linking ExternalCredentialPrincipal → PermissionSet is required before any user can call out via that Named Credential. Without it: `cannot access the credential`
- **Merge fields in headers only**: `{!$Credential.Password}` in `setHeader()` resolves correctly. In `setEndpoint()` URL it causes `Illegal character in opaque part` because `callout:` URIs don't allow `{!$}` chars
- **EIA accepts `X-Api-Key` header**: EIA Open Data API v2 accepts the API key as a custom header, not just as a query param
- **`@future(callout=true)` required** for Slack because flow runs in `CurrentTransaction` mode alongside DML (uncommitted work blocks synchronous callouts)

---

## Remaining for Next Session

### Blockers (must resolve first)

1. **`Supply_Agreement__c.Commodity__c` field inaccessible** — exists in Tooling API metadata but REST describe, SOQL, and anonymous Apex all fail with "Field does not exist". This org-level schema corruption prevents:
   - Creating `Supply_Agreement__c` records with a commodity value
   - Triggering `CommodityPricingService.syncPrices()` to test end-to-end Apex flow
   - Options: deploy to a fresh scratch org, or investigate if field was deleted/recreated

2. **CRM Analytics not licensed** — Phase 1.3 (Well Production Dashboard) requires CRM Analytics license. Developer Edition doesn't include it.

### Ready to continue when blockers resolved

1. **Fix Commodity__c field** → create test `Supply_Agreement__c` records → verify commodity pricing sync
2. **Deploy 9 flows** (`Compliance_Calendar`, `Field_Service_Dispatch`, `HSE_Incident_Escalation`, `Inspection_Due`, `Joint_Venture_Billing`, `Land_Lease_Expiration`, `Pipeline_Maintenance_Schedule`, `Production_Decline`, `Well_Shut_Down`)
3. **Phase 2 — Automations**: Process builder flows, approval processes, scheduled jobs
4. **Phase 3 — Compliance**: Regulatory permit triggers, compliance deadlines, reporting
5. **Enable CRM Analytics + configure Well Production Dashboard** (Phase 1.3)

### How to continue

```powershell
# Deploy force-app (all metadata)
sf project deploy start --source-dir force-app --target-org vscodeOrg --wait 30

# Run all tests
sf apex run test --test-level RunLocalTests --target-org vscodeOrg --wait 15

# Set commodity pricing API key
sf apex run --file scripts/apex/create_and_sync.apex --target-org vscodeOrg

# Test Commodity API manually from Developer Console
#   TestAPIEndToEnd.testCommodityAPI();
#   TestAPIEndToEnd.testEIAAPI();
#   TestAPIEndToEnd.testAllAPIs();
```
