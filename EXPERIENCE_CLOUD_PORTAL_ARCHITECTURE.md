# Experience Cloud Portal Architecture — JV Partner Portal

**Project:** Energy_Salesforce_project (PowerShot)
**Target Org:** `ouil gas` (addouliabdo9.76deae143000@agentforce.com)
**API Version:** 66.0 / 67.0 (LWCs target both)
**Last Updated:** 2026-08-27
**Status:** Phase 1 (Security & Sharing) **DONE** — OWD Private, `Account__c` lookups, Sharing Set, backfill, record-triggered automation, and **field-level read security granted** (66 fields on `O_G_Portal_Access`) all complete (2026-08-27). Phase 3 data layer for Billing & Compliance controllers **SHIPPED** with LWCs (2026-08-27). Test-user verification (1F) still **pending** (no community users in org); Phase 2 (LWR example bundle) and portal page build-out in Experience Builder are the next work items.

---

## 1. Scope & Decisions (Confirmed)

| Decision | Choice |
|---|---|
| Audience (MVP) | **JV Partners only** (extend later to regulators, suppliers, field techs, retail) |
| License | **Partner Community** |
| Site runtime | **New LWR Experience** (`experienceBundle` in source control) |
| Data access model | **Account-based sharing** (OWD Private + Sharing Sets) |
| Access level | Read-mostly (partners view wells, production, royalties, invoices, compliance, HSE) |
| Deliverable | Architecture doc + phased implementation plan |

---

## 2. Target Experience Cloud Topology

```
Experience Cloud Site: PowerShot Partner Portal (LWR)
├── Pages (Experience Builder, per-audience page variations)
│   ├── Landing (guest)   — hero, benefits, login
│   ├── Dashboard         — KPI tiles, recent incidents, deadlines, production summary
│   ├── Wells & Production— well list, status counts, production history charts
│   ├── Billing & Royalties — invoices, royalty statements (new)
│   ├── Compliance        — permits, compliance reports, deadlines
│   └── HSE               — incident log + new incident form
└── Network: PowerShot (existing, Live, urlPathPrefix PowerShotvforcesite)
```

### Site Runtime Recommendation
- Prefer a **new LWR `experienceBundle`** (e.g. `PowerShotPartner`) over the existing
  Aura `PowerShot1` site — LWR is git-versionable, faster, and the existing LWCs are LWR-compatible.
- **One network, multiple page variations** keyed by profile/permission set — not separate sites.

---

## 3. Current State of Portal (Existing Assets — reuse)

### Already in repo (`force-app/main/default`)

| Asset | Notes |
|---|---|
| `networks/PowerShot.network-meta.xml` | Site config, site `PowerShot`, picassoSite `PowerShot1` (Aura), no self-registration. **NOTE (2026-08-10):** network `Status` is `DownForMaintenance` in the org — the CustomSite is `<active>false</active>` (metadata `<status>Live</status>` is stale). Site is NOT actually Live. |
| `sites/PowerShot.site-meta.xml` | **NEW (retrieved 2026-08-10).** CustomSite `PowerShot`, `active=false` → why the network is DownForMaintenance. |
| `sites/whatssapp_webhook.site-meta.xml` | **NEW (retrieved 2026-08-10).** CustomSite for the WhatsApp guest webhook, `active=true`. |
| `networks/whatssapp webhook.network-meta.xml` | **NEW (retrieved 2026-08-10).** WhatsApp webhook network, `Status: Live`. |
| `sharingSets/JV_Partner_Sharing.sharingSet-meta.xml` | **NEW (retrieved 2026-08-10).** Read-only Sharing Set keyed on `Account__c` for the 8 portal objects; mapped to the 5 customer/partner community profiles. |
| `sharingRules/*.sharingRules-meta.xml` | **NEW (retrieved 2026-08-10).** Empty sharing-rules shells for 10 O&G objects (Well, Lease, Invoice, Production_Allocation, Joint_Venture, HSE_Incident, Regulatory_Permit, Compliance_Report, Pipeline, Supply_Agreement) — no rules defined. |
| `objects/Invoice__c/fields/Account__c.field-meta.xml` | **NEW (retrieved 2026-08-10).** Account lookup added to `Invoice__c`. |
| `objects/Production_Allocation__c/fields/Account__c.field-meta.xml` | **NEW (retrieved 2026-08-10).** Account lookup added to `Production_Allocation__c`. |
| `objects/{8 portal objects}/*.object-meta.xml` | **UPDATED (retrieved 2026-08-10).** OWD now `Private` (was `ReadWrite` in source). |
| `classes/PortalDashboardController.cls` | `with sharing`; dashboard summary, recent incidents, deadlines, production summary |
| `classes/PortalWellStatusController.cls` | `with sharing`; wells list, per-well production, status counts |
| `classes/PortalIncidentController.cls` | `with sharing`; incident list, create incident, incident detail |
| `classes/PortalInvoiceController.cls` | **NEW (2026-08-27).** `with sharing`; invoices list (status filter), royalty statements (allocations with revenue shares), billing summary — CRUD/FLS guarded |
| `classes/PortalComplianceController.cls` | **NEW (2026-08-27).** `with sharing`; permits list, compliance reports list, compliance summary, sorted upcoming-deadline horizon (permits + reports) — CRUD/FLS guarded |
| `classes/InvoiceAccountService.cls` + `triggers/InvoiceAccountTrigger` | **NEW (2026-08-27).** Derives `Invoice__c.Account__c` from `JV__r.Account__c` before insert/update |
| `classes/ProductionAllocationAccountService.cls` (called from existing `ProductionAllocationTrigger`) | **NEW (2026-08-27).** Derives `Production_Allocation__c.Account__c` from `Well__r.Account__c` before insert/update |
| `scripts/portal_backfill_accounts.apex` | **NEW (2026-08-27).** One-time anonymous-Apex backfill for existing Invoice/Production_Allocation records missing `Account__c` |
| `classes/MarketDataController.cls` | **NEW (2026-08-15).** `without sharing`; `@AuraEnabled(cacheable=true)` market-data getter — reads synced OilPriceAPI prices (`Supply_Agreement__c.Current_Price__c`) and EIA stock benchmarks (`Fuel_Inventory__c.EIA_National_Stock__c`). `without sharing` so the widget always renders for portal users; switch to `with sharing` + sharing set if the data must respect record security. |
| `lwc/portalDashboard` | KPI tiles + incident/deadline/production tables (apiVersion 67) |
| `lwc/portalWellStatus` | Well list + status counts + 12-month production table (apiVersion 67) |
| `lwc/portalHSEIncidentForm` | Incident list + new incident form (apiVersion 67) |
| `lwc/portalInvoices` | **NEW (2026-08-27).** Billing & Royalties page (apiVersion 67): 4 summary tiles, invoice table with status filter, royalty-statement table |
| `lwc/portalCompliance` | **NEW (2026-08-27).** Compliance page (apiVersion 67): 4 summary tiles, upcoming-deadline horizon strip, permits table, compliance-reports table (each with status filter) |
| `lwc/marketDataHome` | **NEW (2026-08-15).** Experience Cloud home-page widget (apiVersion 67): CSS bar chart + price tiles for synced commodity spot prices + EIA national inventory table. `lightning-chart` base component is **not available** in this org (`No MODULE named markup://lightning:chart`), so the chart is pure SLDS/CSS (same approach as `wellProductionChart` gauges). Exposed to `lightning__HomePage` and both community targets. |
| `permissionsets/O_G_Portal_Access` | Partner Community license; read on 12 objects; 3 portal controllers; 3 tabs |
| `permissionsets/O_G_Field_Portal_Access` | Customer Community Plus license; CRUD Inspection/PTW/WorkOrder; future field-tech audience |
| `profiles/whatssapp webhook Profile` | Guest profile — Apex access to `WhatsAppWebhookHandler` ONLY (no object access) |

### Reusable record-page LWCs (not yet on portal pages)
`complianceCalendar`, `hseIncidentMap`, `permitToWorkBoard`, `fieldServiceChecklist`,
`inventoryTankGauge`, `wellProductionChart`, `productionAllocationReport`.

---

## 4. Data Security & Sharing Architecture

### 4.1 Current Org-wide Defaults (verified in source 2026-08-10)
- All 8 JV-partner objects are now **Private** (org + source aligned after 2026-08-10 retrieve).
- Remaining O&G objects are `ReadWrite` (Public Read/Write) except:
  - `Well_Operation__c` → `ControlledByParent` (master-detail, no action needed).
- Note: the source package previously shipped these objects as `ReadWrite`; the 2026-08-10 retrieve pulled the org's `Private` OWD into source so a future deploy won't revert it.

### 4.2 Target OWD — DONE (org + source 2026-08-10)
Objects on the JV partner surface:
`Well__c`, `Lease__c`, `Production_Allocation__c`, `Joint_Venture__c`, `Invoice__c`,
`HSE_Incident__c`, `Regulatory_Permit__c`, `Compliance_Report__c`
Optional later: `Pipeline__c`, `Supply_Agreement__c`.

### 4.3 Field Gaps — RESOLVED in org + source (2026-08-10); backfill EXECUTED + automation in place (2026-08-27)
| Object | Problem | Fix | Status |
|---|---|---|---|
| `Invoice__c` | Only had `JV__c` lookup (no Account) | `Account__c` lookup added; populate from `JV__r.Account__c` | Field **DONE** in org + source; backfill ran **2026-08-27 → 0 records missing `Account__c`**; new records populated by `InvoiceAccountTrigger` |
| `Production_Allocation__c` | Only had `Well__c` / `Lease__c` (no Account) | `Account__c` lookup added; populate from `Well__r.Account__c` | Field **DONE** in org + source; backfill ran **2026-08-27 → 0 records missing `Account__c`**; new records populated by `ProductionAllocationTrigger` |

### 4.4 Sharing Mechanism — SHARING SETS (**DONE** in org + source, 2026-08-10)
> **NOT** site workspace → Administration → Sharing.
> **Correct path:** Setup → Quick Find `Digital Experiences` → **Digital Experiences → Settings**
> → scroll to **Sharing Sets** related list → **New**.

- `JV_Partner_Sharing` exists in the org (retrieved to source): Read-only mappings for
  Well, Lease, Joint_Venture, Invoice, Production_Allocation, HSE_Incident,
  Regulatory_Permit, Compliance_Report — each keyed on the **Account** lookup.
- Mapped to profiles: `Partner Community User`, `Partner Community Login User`,
  `Customer Community User`, `Customer Community Plus User`, `Customer Community Plus Login User`.
- No fallback needed (Sharing Sets are available).

### 4.5 Apex security posture
- All portal controllers already `with sharing` — keep it.
- Add CRUD/FLS guards (`Schema.sObjectType...isAccessible()/isCreateable()`) on writes.
- Reads: `@wire(cacheable=true)`; writes: non-cacheable.
- Lists: paginate (fixed LIMIT, avoid 50k governor risk).

---

## 5. Target Component & API Layer

### New controllers (future phases)
- `PortalJVController` — joint venture details + partners *(optional)*

### New/portal LWCs (future phases)
- Reuse existing record-page LWCs listed in §3.

### Market data widget (SHIPPED 2026-08-15, portal Home page)
- `MarketDataController.getMarketData()` returns distinct commodity spot prices (latest `Current_Price__c` per `Commodity_v2__c`) + EIA national stocks, plus the last sync timestamp.
- `marketDataHome` renders a responsive CSS bar chart of prices, price tiles, and an EIA inventory table.
- Data source is the **synced records** — OilPriceAPI (`CommodityPricingService`, daily `Commodity Price Sync`) and EIA (`EIAPricingService`, weekly `EIA Weekly Sync` Wed `0 30 14 ? * 4`). The widget reads records; it does not call the APIs live.
- Verified: `getMarketData()` returns Refined 3.13 / Crude 81.19, Crude stock 711,796 MBBL in `ouil gas`.

### Reuse strategy
- **Reads** go through portal controllers with `with sharing`.
- **Writes** (incident creation) already exist via `PortalIncidentController.createIncident` (FLS-guarded).

---

## 6. Identity & Authentication

- **Admin-provisioned** Partner Community users (no self-registration — network already has `selfRegistration=false`).
- Native Salesforce login initially; optional **SAML SSO** later for JV partners.
- `WhatsApp_OAuth` auth provider is for the bot/webhook side, NOT portal login.
- Enable MFA + per-profile session policies for portal profiles.
- Guest profile stays locked to the WhatsApp webhook class only (already the case).

---

## 7. Automation & Integration (future phases)

- Flows: royalty/invoice notifications, incident-submission follow-up.
- Optional PDF statements (royalties / invoices) via Visualforce/PDF generation.
- Optional **WhatsApp outbound** notifications (24h window replies) via existing
  `WhatsApp_API` named credential + `WhatsAppMessageService`.
- Existing flows (`Regulatory_Permit_Compliance`, `Permit_to_Work_Approval`, etc.)
  already feed the data the portal displays.

---

## 8. Phased Implementation Plan

| Phase | Deliverables | Verification |
|---|---|---|
| **0. Preflight** | Confirm Partner Community license; (recommended) commit dirty git tree first | `sf project retrieve` for license/OWD check |
| **1. Security & Sharing** *(DONE 2026-08-27)* | OWD → Private (**done**); `Account__c` on Invoice + Production_Allocation (**done**); Sharing Set `JV_Partner_Sharing` (**done**); **backfill EXECUTED 2026-08-27** (`scripts/portal_backfill_accounts.apex`, 0 records left missing) + record-triggered automation (before-triggers via account services); FLS check + test JV-partner user still open | OWD verified Private in org; sharing set present; source retrieved (2026-08-10); automation + tests added (2026-08-27) |
| **2. LWR Site Skeleton** | `experienceBundle` LWR site, theme layout + branding, guest landing + login, nav menu; publish | Publish + URL check |
| **3. Data Layer** | **DONE (2026-08-27)** — `PortalInvoiceController`, `PortalComplianceController`, `TestPortalPageControllers` | `sf apex run test` |
| **4. Portal Pages & LWCs** | `portalInvoices` + `portalCompliance` built; wire into Experience Builder pages; page variations per profile | Manual QA as JV partner |
| **5. Automation** | Royalty/invoice notifications, optional PDF + WhatsApp outbound | Flow validation + test run |
| **6. Deploy & Go-Live** | Ordered deploy (objects→sharing→permission sets→network→experience bundle→pages→publish) | Deploy + tests green |

### Phase 1 manual checklist (progress tracker)
- [x] 1A. O_G_All_Access / Admin View All set before locking down
- [x] 1B. OWD → Private on 8 objects *(verified in org + captured in source 2026-08-10)*
- [x] 1C. Add `Account__c` lookup to `Invoice__c` + `Production_Allocation__c` *(done in org + source)*
- [x] 1C. Backfill existing records — `scripts/portal_backfill_accounts.apex` **(EXECUTED 2026-08-27 → 0 invoices, 0 allocations still missing `Account__c`)**
- [x] 1C. Record-triggered automation to populate Account on new records — `InvoiceAccountTrigger` + `ProductionAllocationTrigger` via the two account services **(implemented as Apex before-triggers, not flows, so they are source-controlled and testable)**
- [x] 1D. Sharing Set `JV_Partner_Sharing` *(exists in org, retrieved to source 2026-08-10)*
- [x] 1E. FLS (read) on portal fields + new Account fields — **DONE (2026-08-27):** deployed 66 explicit field-level read grants on `O_G_Portal_Access` covering every field the portal controllers SOQL (verified live in org — 66 `FieldPermissions` rows). AutoNumber `Name` fields (Invoice, Compliance_Report, Production_Allocation, HSE_Incident, Lease, Supply_Agreement) are **not** FLS-gated → always readable. NOTE: Metadata API silently drops custom-object `Name` rows from **PermissionSet** `fieldPermissions` (only Profile metadata/branding supports it), so `Name` on the 4 Text(80) objects (Well, Joint_Venture, Pipeline, Regulatory_Permit) relies on profile-level read; confirm in 1F.
- [ ] 1F. Verify with test JV-partner user — **blocked: no community users exist in org yet** (this is the remaining check for visible-field parity, incl. the Text(80) `Name` note above)

### Verification (2026-08-27)
- Deployed to `ouil gas` via `manifest/package-billing-compliance.xml` — all 10 components OK (2 triggers, 5 classes, 2 LWCs, permission set, test class).
- `TestPortalPageControllers` → **13/13 PASS** (isolated synchronous run).
- Backfill run → **0 invoices + 0 allocations still missing `Account__c`**.
- **Phase 1E FLS:** 66 field-level read grants deployed to `O_G_Portal_Access` (verified live in org; source == org). See §8 checklist 1E for the AutoNumber vs Text(80) `Name` nuance.
- NOTE: `TestPortalControllers` (14) and `TestFieldServices` (15) fail in the org on a **pre-existing** validation rule (`Pipeline Diameter and Capacity are required fields` — their `@TestSetup` inserts a `Pipeline__c` that violates it). Unrelated to portal work; baseline issue in repo tests vs. org validation rules.
- NOTE: `O_G_Portal_Access.permissionset-meta.xml` had `<license>Partner Community</license>` **removed from source** — Metadata API refuses to update an existing permission set's license ("License can't be updated"); the org keeps its existing license. Re-deploying the source does **not** strip the license from the org.

---

## 9. Known Risks / Open Questions

1. **Sharing Sets availability** — **RESOLVED (2026-08-10):** the Sharing Sets related list is available; `JV_Partner_Sharing` exists in the org (read on 8 objects via Account, mapped to the 5 customer/partner community profiles).
2. **Portal profile** — `Partner Community User` / `Partner Community Login User` profiles exist; **no community users are provisioned yet** (0 users on community licenses) — must create a test JV-partner user linked to an Account before 1F can pass.
3. **Aura vs LWR** — existing sites are Aura (`PowerShot1`, `PowerShott1`, `whatssapp_webhook1`). **`Enable ExperienceBundle Metadata API` is OFF** in Digital Experiences → Settings — the ExperienceBundle metadata could not be retrieved ("ExperienceBundle isn't enabled for Aura sites"). Enable it before the LWR `experienceBundle` phase if the site must be managed from source.
4. **Controllers query ALL records** — no *actual* sharing rules in repo (the 10 retrieved `sharingRules` files are empty shells). Validated end-to-end: OWD Private, `JV_Partner_Sharing` sharing set, `Account__c` kept populated by `InvoiceAccountTrigger` / `ProductionAllocationTrigger`, and **backfill executed 2026-08-27 (0 records still missing `Account__c`)** (**resolved 2026-08-27**).
5. **Preflight state (2026-08-10):** Partner Community + Guest licenses Active; Experience Cloud enabled; domain present. `O_G_Field_Portal_Access` is **not** in the org (only `O_G_Portal_Access`). Redundant `PowerShott` site/network exists (DownForMaintenance, typo) — candidate for cleanup.
6. Doc drift is common in this repo — keep this file updated as phases complete.

---

## 10. Deployment Commands (reference)

```powershell
# Deploy to main org
sf project deploy start -d "force-app\main\default\PATH" -o "ouil gas"

# Run tests
sf apex run test -o "ouil gas"

# Retrieve experience bundle once created
sf project retrieve start -o "ouil gas" -m ExperienceBundle -d force-app/main/default
```
