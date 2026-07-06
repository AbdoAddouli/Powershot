# PowerShot — Oil & Gas Salesforce Platform

**Version:** 1.0 | **API Version:** 66.0 | **Last Updated:** 2026-07-01

PowerShot is a comprehensive Oil & Gas operations management platform built on Salesforce. It covers the full value chain — Upstream (exploration & production), Midstream (pipelines & storage), Downstream (refining & retail), and Cross-Domain (HSE, regulatory compliance, commercial trading).

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Custom Objects & Data Model](#2-custom-objects--data-model)
3. [Apex Classes](#3-apex-classes)
4. [Apex Triggers](#4-apex-triggers)
5. [Automated Flows](#5-automated-flows)
6. [Lightning Web Components](#6-lightning-web-components)
7. [External Integrations](#7-external-integrations)
8. [Permission Sets & Security](#8-permission-sets--security)
9. [Scheduled Jobs & Batch Processing](#9-scheduled-jobs--batch-processing)
10. [Testing & Coverage](#10-testing--coverage)
11. [Deployment Guide](#11-deployment-guide)
12. [Enhancement Roadmap](#12-enhancement-roadmap)

---

## 1. Architecture Overview

### Business Domains

```
┌─────────────────────────────────────────────────────────────┐
│                    POWERSHOT PLATFORM                        │
├────────────┬──────────┬─────────────┬───────────────────────┤
│  UPSTREAM  │ MIDSTREAM│ DOWNSTREAM  │    CROSS-DOMAIN       │
│            │          │             │                       │
│ • Wells    │• Pipelines│• Refineries │ • HSE Incidents       │
│ • Leases   │• Stations │• Terminals  │ • Observations        │
│ • Production│• Inspect.│• Retail     │ • Regulatory Permits  │
│ • Alloc.   │• SCADA   │• Fuel Inv.  │ • Compliance Reports  │
│ • Well Ops │• Integrity│• Supply Agr.│ • Permit to Work      │
│            │          │• Transport  │ • Inspections          │
└────────────┴──────────┴─────────────┴───────────────────────┘
```

### Key Design Patterns

| Pattern | Implementation |
|---------|---------------|
| **Trigger → Service** | All triggers delegate to service-layer Apex classes |
| **Queueable for Async** | Callout-heavy & long-running ops use `Queueable` + `Database.AllowsCallouts` |
| **Named Credentials** | All external API callouts go through named credentials (no hardcoded URLs/keys) |
| **Protected Custom Settings** | API keys stored in Protected Hierarchy Custom Settings |
| **Event-Driven Alerts** | Platform Events + Queueable for Slack HSE alerts |
| **Scheduled Flows + Apex** | Daily/weekly batch operations via both Flow scheduler and Apex schedulers |
| **@AuraEnabled LWC Backing** | Service classes expose `@AuraEnabled(cacheable=true)` methods for LWCs |

### Salesforce Org

| Property | Value |
|----------|-------|
| **Org Alias** | `ouil gas` |
| **Username** | addouliabdo9.76deae143000@agentforce.com |
| **Edition** | Developer |
| **Source API Version** | 66.0 |
| **Package Directory** | `force-app/` |

---

## 2. Custom Objects & Data Model

### 2.1 Upstream Objects

#### Well__c

| Field | Type | Description |
|-------|------|-------------|
| Status__c | Picklist | Permitted → Drilling → Producing → Shut-In → Suspended → Plugged → Abandoned / Cancelled |
| Well_Type__c | Picklist | Oil, Gas, Injection, Water Disposal |
| Production_Status__c | Picklist | Flowing, Artificial Lift, Shut-In, Abandoned |
| API_Number__c | Text(20) | Unique well identifier (API number) |
| Spud_Date__c | Date | Date drilling commenced |
| Completion_Date__c | Date | Date well completed |
| Total_Depth__c | Number(10,2) | Total measured depth (ft) |
| True_Vertical_Depth__c | Number(10,2) | True vertical depth (ft) |
| Formation__c | Text(100) | Producing formation name |
| Is_Declining__c | Checkbox | Flag for declining production |
| Total_Oil_Volume_12M__c | Number(18,2) | Rolling 12-month oil volume |
| Status_Change_Date__c | Date | Date of last status change |
| Lease__c | Lookup(Lease__c) | Parent lease |
| Account__c | Master-Detail(Account) | Operating company |

**Status Lifecycle:**
```
Permitted → Drilling → Producing → Shut-In → Suspended → Plugged → Abandoned
                    ↘ Cancelled (at any pre-Producing step)
```
Enforced by `WellStatusService.isValidTransition()`.

#### Lease__c

| Field | Type | Description |
|-------|------|-------------|
| Status__c | Picklist | Active, Expired, Terminated |
| Lease_Type__c | Picklist | Oil & Gas, Mineral, Surface |
| Royalty_Percent__c | Percent | Royalty rate |
| Working_Interest_Percent__c | Percent | Working interest share |
| Revenue_Interest_Percent__c | Percent | Net revenue interest share |
| Primary_Term_End__c | Date | End of primary term |
| Lease_End_Date__c | Date | Lease expiration |
| Land_Parcel__c | Lookup(Land_Parcel__c) | Associated land parcel |
| Account__c | Master-Detail(Account) | Lessee |

#### Land_Parcel__c

Tracks mineral rights, surface ownership, and parcel boundaries.

#### Well_Operation__c

| Field | Type | Description |
|-------|------|-------------|
| Operation_Type__c | Picklist | Drilling, Completion, Workover, Stimulation, Abandonment |
| Status__c | Picklist | Planned, In Progress, Completed, Cancelled |
| AFE_Number__c | Text | Authorization for Expenditure number |
| AFE_Amount__c | Currency | Budgeted amount |
| Actual_Cost__c | Currency | Actual cost incurred |
| Well__c | Lookup(Well__c) | Parent well |

#### Production_Allocation__c

| Field | Type | Description |
|-------|------|-------------|
| Gross_Volume__c | Number(18,2) | Gross production volume |
| Oil_Volume_bbls__c | Number(18,2) | Oil volume (barrels) |
| Gas_Volume_MCF__c | Number(18,2) | Gas volume (thousand cubic feet) |
| Water_Volume_bbls__c | Number(18,2) | Water volume (barrels) |
| Working_Interest_Share__c | Percent | WI allocation |
| Net_Revenue_Interest_Share__c | Percent | NRI allocation |
| Allocated_Revenue__c | Currency | Calculated revenue |
| Period_Start__c / Period_End__c | Date | Allocation period |
| Well__c | Lookup(Well__c) | Producing well |
| Lease__c | Lookup(Lease__c) | Associated lease |

**Validation Rules:**
- Insert: WI <= 100% AND NRI <= 100%
- Update: WI + NRI <= 200%

### 2.2 Midstream Objects

#### Pipeline__c

| Field | Type | Description |
|-------|------|-------------|
| Status__c | Picklist | Active, Idle, Decommissioned |
| Commodity__c | Picklist | Crude, Gas, NGL, Refined, Water |
| Capacity_bpd__c | Number(12,0) | Capacity (barrels per day) |
| Diameter_inches__c | Number(5,1) | Pipeline diameter |
| Segment_Length_Miles__c | Number(8,2) | Segment length |
| MAOP__c | Number(10,2) | Maximum Allowable Operating Pressure |
| Compliance_Status__c | Picklist | Compliant, Non-Compliant |
| Last_Inspection_Date__c | Date | Most recent inspection |
| Required_Inspection_Interval_Months__c | Number(3,0) | Inspection frequency |
| Account__c | Master-Detail(Account) | Operator |

#### Pipeline_Station__c

Pump stations, compressor stations, and metering stations along pipeline routes.

#### Measurement__c

| Field | Type | Description |
|-------|------|-------------|
| Gross_Volume__c | Number(18,2) | Gross measured volume |
| Net_Volume__c | Number(18,2) | Net measured volume |
| BSandW_Percent__c | Percent | Basic Sediment & Water |
| Pressure__c | Number(10,2) | Line pressure (psi) |
| Temperature__c | Number(5,1) | Temperature |
| Reading_DateTime__c | DateTime | Measurement timestamp |
| Source__c | Picklist | SCADA, Manual, Meter |
| Pipeline__c / Pipeline_Station__c / Terminal__c | Lookup | Location context |

**Anomaly Detection:** Pressure < 100 psi or > 1500 psi auto-creates `HSE_Observation__c`.

### 2.3 Downstream Objects

#### Refinery__c

| Field | Type | Description |
|-------|------|-------------|
| Status__c | Picklist | Active, Idle, Decommissioned |
| Capacity_bpd__c | Number(12,0) | Processing capacity |
| Nelson_Complexity_Index__c | Number(4,1) | Complexity rating |
| PADD_District__c | Picklist | PADD region |
| Units_List__c | Multi-Select | Crude, Vacuum, FCC, Hydrocracker, Reformer |

#### Terminal__c

| Field | Type | Description |
|-------|------|-------------|
| Commodity_Type__c | Picklist | Crude, Gas, NGL, Refined |
| Storage_Capacity_bbls__c | Number(14,0) | Total storage capacity |
| Tank_Count__c | Number(4,0) | Number of tanks |
| Rail_Truck_Marine_Access__c | Multi-Select | Access modes |

#### Retail_Outlet__c

| Field | Type | Description |
|-------|------|-------------|
| Store_Type__c | Picklist | Gas Station, C-Store, Truck Stop |
| Fuel_Tank_Count__c | Number(3,0) | Underground tank count |
| Fuel_Volume_Monthly__c | Number(12,0) | Monthly fuel volume |
| C_Store__c | Checkbox | Has convenience store |
| Car_Wash__c | Checkbox | Has car wash |

#### Fuel_Inventory__c

| Field | Type | Description |
|-------|------|-------------|
| Product__c / Product_Type__c | Picklist | Fuel type (Crude, Gasoline, Diesel, Jet Fuel, NGL) |
| Current_Volume__c | Number(18,2) | Current tank volume |
| Maximum_Capacity__c | Number(18,2) | Tank capacity |
| Minimum_Threshold__c | Number(18,2) | Reorder threshold |
| Available_Volume__c | Number(18,2) | Usable volume |
| EIA_National_Stock__c | Number(18,2) | EIA benchmark stock |
| Discrepancy_Flagged__c | Checkbox | >5% reconciliation variance |
| Tank_Number__c | Text | Tank identifier |
| Gauge_Type__c | Picklist | Manual, Automatic, Radar |
| Retail_Outlet__c / Terminal__c | Lookup | Location |

### 2.4 Commercial Objects

#### Supply_Agreement__c

| Field | Type | Description |
|-------|------|-------------|
| Agreement_Type__c | Picklist | Term, Spot, Exchange |
| Commodity_v2__c | Picklist | Crude, Gas, NGL, Refined, Diesel, Jet Fuel, Heating Oil |
| Status__c | Picklist | Draft, Active, Expired, Terminated |
| Price_Basis__c | Picklist | WTI, Brent, HH, TTF, JKM |
| Current_Price__c | Number(18,2) | Latest market price (updated via API) |
| Volume__c | Number(18,2) | Agreement volume |
| Term_Start__c / Term_End__c | Date | Agreement term |
| Account__c | Master-Detail(Account) | Counterparty |

**Price Sync:** Updated daily via `CommodityPriceSyncScheduler` → OilPriceAPI (WTI, Brent, Gas, etc.)

#### Transportation_Nomination__c

| Field | Type | Description |
|-------|------|-------------|
| Status__c | Picklist | Requested, Scheduled, Delivered |
| Nomination_Period__c | Date | Shipping period |
| Requested_Volume__c / Confirmed_Volume__c | Number(18,2) | Volumes |
| Pipeline__c | Lookup(Pipeline__c) | Transport pipeline |

#### Service_Contract__c

Vendor/contractor service agreements for well services, maintenance, and operations.

### 2.5 HSE Objects

#### HSE_Incident__c

| Field | Type | Description |
|-------|------|-------------|
| Severity__c | Picklist | Low, Medium, High, Critical |
| Incident_Type__c | Picklist | Spill, Fire, Explosion, Injury, Near Miss, LTI, Fatality |
| Status__c | Picklist | Reported, Investigating, Action Taken, Closed |
| Fatality_Occurred__c | Checkbox | Fatality flag |
| LTI__c | Checkbox | Lost Time Incident |
| Regulatory_Reportable__c | Checkbox | Must report to regulator |
| Spill_Volume__c | Number(10,2) | Volume spilled (bbls) |
| Environmental_Impact__c | Picklist | Minor, Moderate, Major |
| Location__c | Text | Incident location |
| Well__c / Pipeline__c / Retail_Outlet__c | Lookup | Asset context |

**Severity Classification Logic (in HSEIncidentService):**
- **Critical:** Fatality OR Life-Threatening/PermanentDisability injury
- **High:** Major environmental impact OR Spill >1000 bbl OR Lost Time injury OR Moderate impact
- **Medium:** Medical Treatment injury OR Spill >100 bbl
- **Low:** Default

#### HSE_Observation__c

| Field | Type | Description |
|-------|------|-------------|
| Observation_Type__c | Picklist | Safe, Unsafe |
| Category__c | Picklist | Pressure Anomaly, Unsafe Act, Unsafe Condition, Near Miss |
| Status__c | Picklist | Open, Investigating, Closed |

#### Permit_to_Work__c

| Field | Type | Description |
|-------|------|-------------|
| Permit_Type__c | Picklist | Confined Space Entry, Hot Work, Electrical, Mechanical, Excavation, Working at Height |
| Risk_Level__c | Picklist | Low, Medium, High, Critical |
| Status__c | Picklist | Requested, Issued, Completed, Cancelled |
| Gas_Test_Required__c / Completed__c / Result__c | Various | Gas testing data |
| H2S_Level__c / CO_Level__c / LEL_Pct__c / Oxygen_Level_Pct__c | Number | Gas readings |
| Isolation_Required__c / Verified__c | Checkbox | Energy isolation |
| Lockout_Tagout_Completed__c / Zero_Energy_State_Verified__c | Checkbox | Safety verifications |
| Authorizer__c / Authorizer_2__c / Authorizer_3__c | Lookup(User) | Approval chain |
| Well__c / Terminal__c / Refinery__c / Pipeline_Station__c | Lookup | Work location |

**Authorization Requirements:**
- Low risk: 1 approval
- Medium/High risk: 2 approvals (min 2 for Confined Space/Hot Work/Electrical/Excavation)
- Critical risk: 3 approvals

**Gas Test Safe Limits:** O₂ 19.5–23.5%, LEL ≤10%, H₂S ≤10 ppm, CO ≤25 ppm

### 2.6 Regulatory Compliance Objects

#### Regulatory_Permit__c

| Field | Type | Description |
|-------|------|-------------|
| Permit_Type__c | Picklist | SPCC, Title V, NSPS, NPDES, Underground Injection |
| Agency__c | Picklist | EPA, State, Local |
| Status__c | Picklist | Pending, Active, Approved, Expired, Suspended, Revoked |
| Compliance_Status__c | Picklist | Compliant, Non-Compliant, Expired, Critical - Expiring Soon, Approaching Expiration, Pending Review |
| Issue_Date__c / Expiration_Date__c | Date | Permit validity period |
| Renewal_Reminder_Sent__c | Checkbox | Reminder sent flag |
| Account__c / Well__c / Pipeline__c / Refinery__c | Lookup | Permit context |

#### Compliance_Report__c

| Field | Type | Description |
|-------|------|-------------|
| Report_Type__c | Picklist | Regulatory Compliance, Production Discrepancy, Environmental |
| Status__c | Picklist | Pending, Submitted, Waived |
| Due_Date__c / Submitted_Date__c | Date | Due/submitted dates |
| Regulatory_Body__c | Text | Agency name |
| Assigned_To__c | Lookup(User) | Responsible person |
| Regulatory_Permit__c | Lookup(Regulatory_Permit__c) | Related permit |

### 2.7 Digital / Store Ecosystem Objects

#### Store__c

| Field | Type | Description |
|-------|------|-------------|
| Store_Type__c | Picklist | TikTok, Snap, LinkedIn, Meta, Shopify, Other |
| Website_URL__c | URL | Store website |
| GTM_Container_ID__c | Text | GTM public ID (GTM-XXXXXX) |
| GTM_Numeric_ID__c | Text | GTM API container ID |
| GA4_Property_ID__c | Text | GA4 property numeric ID |
| Measurement_ID__c | Text | GA4 measurement ID (G-XXXXXXXX) |
| Provisioning_Status__c | Picklist | Pending, InProgress, Complete, Failed |
| Active__c | Checkbox | Store active flag |

#### GTM_Config__c (Hierarchy Custom Setting)

Stores Google Tag Manager and GA4 account IDs, TikTok/Snapchat/LinkedIn pixel IDs.

#### Shopify_Settings__c (Hierarchy Custom Setting)

| Field | Description |
|-------|-------------|
| Store_URL__c | Shopify store URL |

#### API_Key_Settings__c (Hierarchy Protected Custom Setting)

| Field | Description |
|-------|-------------|
| OilPrice_API_Key__c | OilPriceAPI key (protected, not in metadata) |

### 2.8 Standard Object Extensions

| Object | Added Fields |
|--------|-------------|
| **Account** | Well_Count__c, Lease_Count__c, Pipeline_Count__c, Regulatory_Compliance_Status__c, Emergency_Contact_Name__c, Emergency_Contact_Phone__c |
| **Asset** | Inspiration_Frequency_Days__c, Expected_Lifespan_Days__c, Maintenance_Schedule__c, Next_Inspection_Date__c |
| **Case** | Well__c, Pipeline__c, Incident_Type__c, Severity__c, HSE_Related__c, Regulatory_Reportable__c |
| **Opportunity** | Well__c, Lease__c, Agreement_Type__c, Volume__c |
| **WorkOrder** | Well__c, Pipeline__c, Permit_to_Work__c, PTW_Required__c, PTW_Approved__c, Safety_Briefing_Completed__c |

### 2.9 Platform Events

| Object | Type | Fields |
|--------|------|--------|
| **Slack_Alert__e** | HighVolume Platform Event | Incident_Id__c |

---

## 3. Apex Classes

### 3.1 Service Classes

| Class | Lines | Domain | Key Methods |
|-------|-------|--------|-------------|
| `WellStatusService` | 65 | Upstream | `isValidTransition(from, to)`, `createWellOperations(wells)` |
| `ProductionAllocationService` | 137 | Upstream | `calculateMonthlyAllocation`, `validateWorkingInterest`, `getProductionHistory` |
| `ComplianceDueDateService` | 177 | Regulatory | `getUpcomingRenewals`, `getOverdueReports`, `updateComplianceStatuses`, `sendRenewalReminders` |
| `HSEIncidentService` | 248 | HSE | `classifySeverities`, `isRegulatoryReportable`, `notifyComplianceTeams`, `escalateIfCritical`, `getHSEIncidents` |
| `InspectionService` | 171 | Midstream | `getChecklistItems`, `submitChecklist`, `updateParentInspectionDates`, `createRecurringInspections` |
| `PermitToWorkValidationService` | 245 | HSE | `validateIsolationRequirements`, `validateGasTestResults`, `validateAuthorizationChain`, `getMissingRequirements` |
| `PipelineIntegrityService` | 95 | Midstream | `getOverdueInspections`, `isInspectionCompliant`, `flagNonCompliantPipelines`, `calculateNextInspectionDueDate` |
| `InventoryBalanceService` | 152 | Downstream | `getTankInventory`, `recordInventoryMovement`, `getLowInventoryAlerts`, `reconcileInventory` |
| `RoyaltyCalculationService` | — | Upstream | Royalty payment calculations |
| `SCADAMeasurementProcessor` | — | Midstream | SCADA data processing |
| `SlackAlertService` | — | Integration | `sendSlackAlert(incidentId, message, webhookUrl)` — Invocable Apex for flow |

### 3.2 Integration / API Classes

| Class | Lines | Integration | Key Methods |
|-------|-------|-------------|-------------|
| `CommodityPricingService` | 121 | OilPriceAPI | `syncPrices`, `processPriceSync`, `fetchPrice(apiCode)` |
| `EIAPricingService` | 236 | EIA API | `processPriceSync`, `processStockSync`, `fetchRetailPrice`, `fetchNationalStock` |
| `PetrelWellSync` | 111 | Petrel/EDM | `runSync`, `fetchWellsFromPetrel`, `upsertWells` |
| `RegulatoryFilingService` | 78 | EPA CDX | `fileComplianceReport` — Invocable Apex for flow |
| `SCADAIngestionAPI` | — | SCADA | REST API for external SCADA data ingestion |
| `GTMService` | 632 | Google Tag Manager | `createContainer`, `deleteContainer`, `createTag`, `createTrigger`, `publishVersion` |
| `GA4AdminService` | 157 | Google Analytics Admin | `validateCredential`, `createPropertyAndStream` |
| `GAEventsController` | 275 | Google Analytics Data | `getEventData`, `getEventDataByDateRange`, `getClickEventData` |
| `GTMPixelBuilder` | 85 | — | `buildTikTokPixelHtml`, `buildSnapchatPixelHtml`, `buildLinkedInInsightHtml` |

### 3.3 Queueable & Batch Classes

| Class | Type | Purpose |
|-------|------|---------|
| `CommodityPriceSyncQueueable` | Queueable | Async commodity price sync |
| `EIAQueueable` | Queueable | Async EIA price/stock sync |
| `PetrelWellSyncQueueable` | Queueable | Async Petrel well sync |
| `SlackAlertQueueable` | Queueable | Async Slack webhook dispatch |
| `RenewalReminderQueueable` | Queueable | Async permit renewal reminders |
| `ProvisioningQueueable` | Queueable | Store provisioning orchestrator |
| `PipelineIntegrityBatch` | Batch | Batch pipeline compliance check |
| `WellProductionRollupBatch` | Batch | Batch production volume rollup |

### 3.4 Scheduler Classes

| Class | Schedule | Purpose |
|-------|----------|---------|
| `CommodityPriceSyncScheduler` | Daily 8:00 AM | Sync commodity prices to Supply_Agreement__c |
| `EIAPriceSyncScheduler` | Weekly Wed 2:30 PM | Sync EIA fuel prices & stock benchmarks |

### 3.5 Test Classes

| Class | Tests | Purpose |
|-------|-------|---------|
| `TestWellLifecycle` | — | Well status transition validation |
| `TestFieldServices` | — | Field service triggers & inspections |
| `TestHSEServices` | — | HSE incident classification & escalation |
| `TestEIAPricingService` | — | EIA API pricing/stock sync |
| `TestCommercialServices` | — | Commercial & commodity sync |
| `TestAPIEndToEnd` | — | End-to-end API callout tests |
| `RegulatoryFilingServiceTest` | 3/3 ✅ | Regulatory filing with mocking |
| `PetrelWellSyncTest` | 3/3 ✅ | Petrel sync with mocking |

### 3.6 Provisioning Classes

| Class | Lines | Purpose |
|-------|-------|---------|
| `ProvisioningService` | 363 | Store provisioning orchestrator — creates GTM container, GA4 property + data stream |
| `ProvisioningQueueable` | — | Async execution of provisioning steps |
| `GTMService` | 632 | GTM container/tag/trigger/publish operations |
| `GA4AdminService` | 157 | GA4 property + data stream creation |
| `GTMPixelBuilder` | 85 | TikTok, Snapchat, LinkedIn pixel HTML generation |
| `GAEventsController` | 275 | GA4 event analytics queries |
| `StoreController` | — | Store management Apex controller |

---

## 4. Apex Triggers

| Trigger | Object | Events | Key Logic |
|---------|--------|--------|-----------|
| `WellTrigger` | Well__c | B/I/U, A/I/U | Defaults status to 'Permitted', validates lifecycle transitions, records Well_Operation__c audit |
| `ProductionAllocationTrigger` | Production_Allocation__c | B/I/U | Defaults null values to 0, validates WI ≤ 100% (insert), WI+NRI ≤ 200% (update) |
| `HSEIncidentTrigger` | HSE_Incident__c | A/I/U | Classifies severity, notifies compliance for reportable, escalates critical |
| `RegulatoryPermitTrigger` | Regulatory_Permit__c | A/I/U | Delegates compliance status calculation to `ComplianceDueDateService` |
| `InspectionTrigger` | Inspection__c | A/I/U | Updates parent Asset/Pipeline inspection dates, creates recurring inspections |
| `MeasurementTrigger` | Measurement__c | A/I | Detects pressure anomalies (<100 or >1500 psi), creates HSE_Observation__c |
| `SlackAlertEventTrigger` | Slack_Alert__e | A/I | Enqueues `SlackAlertQueueable` for async Slack dispatch |
| `AssetTrigger` | Asset | B/I/U | Calculates Next_Inspection_Date__c, flags assets beyond lifespan |

---

## 5. Automated Flows

All flows are API version 66.0.

| Flow | Trigger | Type | Key Logic |
|------|---------|------|-----------|
| **Permit to Work Approval** | Record-Triggered (Create) | AutoLaunched | Creates review Task when PTW is created |
| **Field Service Dispatch** | Record-Triggered (Create on WorkOrder) | AutoLaunched | Verifies PTW is 'Issued' before dispatching crew |
| **HSE Critical Slack Alert** | Record-Triggered (Update, Severity→Critical) | AutoLaunched | Calls `SlackAlertService` Apex action for Slack webhook |
| **HSE Incident Escalation** | Record-Triggered (I/U on reportable/critical) | AutoLaunched | Routes by severity: Fatality→Fatality Task, Reportable→Regulatory Task, else→General Task |
| **Compliance Calendar** | Scheduled (Daily) | AutoLaunched | Marks `Renewal_Reminder_Sent__c` = true on qualifying permits |
| **Regulatory Permit Compliance** | Record-Triggered (I/U) | AutoLaunched | Creates Compliance_Report__c when permit expires within 90 days |
| **Retail Inventory Alert** | Scheduled (Daily) | AutoLaunched | Creates restock Task when Current_Volume__c < Minimum_Threshold__c |
| **Production Reconciliation** | Scheduled (Daily) | AutoLaunched | Flags zero-production allocations as Compliance_Report__c |
| **Land Lease Expiration** | Scheduled (Daily) | AutoLaunched | Queries leases expiring within 90 days, creates Tasks |
| **Joint Venture Billing** | Scheduled (1st of month) | AutoLaunched | Creates Invoice__c records for active JVs |
| **Inspection Due** | Scheduled (Weekly) | AutoLaunched | Creates new Inspection__c records for overdue recurring inspections |

---

## 6. Lightning Web Components

| Component | Apex Controller | Key Features |
|-----------|-----------------|--------------|
| **complianceCalendar** | `ComplianceDueDateService.getUpcomingDeadlines` | Datatable with filters (All/Upcoming/Overdue), summary cards, color-coded expiration status |
| **fieldServiceChecklist** | `InspectionService.getChecklistItems`, `InspectionService.submitChecklist` | Interactive checklist with checkboxes, comments, progress bar, photo upload support |
| **hseIncidentMap** | `HSEIncidentService.getHSEIncidents` | Datatable of incidents with type, severity, status, date, location columns |
| **inventoryTankGauge** | `InventoryBalanceService.getTankInventory` | Visual tank gauge with fill percentage, color bands (green/yellow/red at 60%/85%), volume display |
| **permitToWorkBoard** | `PermitToWorkValidationService.getPermitsToWork`, `.updatePermitStatus` | Kanban board (Requested/Issued/Completed columns), status advancement, detail panel |
| **productionAllocationReport** | `ProductionAllocationService.getProductionHistory` | Summary cards (Oil/Gas/Revenue), period selector (3/6/12/24 months), datatable |
| **wellProductionChart** | — | Well production visualization |
| **storeManager** | Various GA/GTM | Store ecosystem management UI |
| **storeProvisioning** | `ProvisioningService.provisionStore`, `.getProvisioningStatus` | Store provisioning wizard with status polling |

All LWCs expose `lightning__RecordPage`, `lightning__AppPage`, and `lightning__HomePage` targets.

---

## 7. External Integrations

### 7.1 Named Credential Infrastructure

| Named Credential | URL | External Credential | Auth Protocol | Purpose |
|-----------------|-----|---------------------|---------------|---------|
| `CommodityPricing` | https://api.oilpriceapi.com/v1 | CommodityPricing | Custom | OilPriceAPI commodity prices |
| `EIA_API` | https://api.eia.gov | EIA_API | Basic | EIA fuel prices & stocks |
| `PetrelAPI` | https://petrel-api.example.com/v1 | PetrelAPI | Basic | Petrel/EDM well data |
| `EPA_CDX_API` | https://cdx.epa.gov/api | EPA_CDX_API | Basic | EPA compliance filing |
| `GTM_TagManager` | https://tagmanager.googleapis.com | GTM_API | OAuth 2.0 | Google Tag Manager |
| `GTM_API` | https://analyticsdata.googleapis.com | GTM_API | OAuth 2.0 | Google Analytics Data API |
| `GA4_Admin` | https://analyticsadmin.googleapis.com | GTM_API | OAuth 2.0 | Google Analytics Admin API |
| `Slack_HSE_Webhook` | https://hooks.slack.com | Slack_HSE_Webhook | Basic (Anonymous) | Slack webhook |

### 7.2 Integration Matrix

| Integration | Direction | Mechanism | Frequency | Auth |
|-------------|-----------|-----------|-----------|------|
| **OilPriceAPI** | Inbound | Schedulable → Queueable → Named Credential | Daily | API key via custom setting |
| **EIA API** | Inbound | Schedulable → Queueable → Named Credential | Weekly (Wed) | API key via merge field |
| **Petrel/EDM** | Inbound | Schedulable → Queueable → Named Credential | Daily or On-demand | Password |
| **EPA CDX** | Outbound | Invocable Apex → Named Credential | Trigger-driven | Password |
| **Slack** | Outbound | Platform Event → Queueable → Named Credential → Webhook | Event-driven | Anonymous |
| **Google Tag Manager** | Outbound | Queueable → Named Credential (OAuth) | Event-driven | OAuth 2.0 |
| **Google Analytics Admin** | Outbound | Queueable → Named Credential (OAuth) | Event-driven | OAuth 2.0 |
| **Google Analytics Data** | Inbound | AuraEnabled Apex → Named Credential (OAuth) | On-demand (LWC) | OAuth 2.0 |
| **SCADA** | Inbound | REST API (SCADAIngestionAPI) → Apex | Real-time | Custom auth |

### 7.3 CSP Trusted Sites

| Site | Purpose |
|------|---------|
| https://api.oilpriceapi.com | Commodity pricing |
| https://api.eia.gov | EIA data |
| https://hooks.slack.com | Slack webhooks |

### 7.4 Remote Site Settings

| Site | Purpose |
|------|---------|
| https://api.oilpriceapi.com | OilPriceAPI (legacy) |
| https://api.eia.gov | EIA API (legacy) |
| https://hooks.slack.com | Slack (legacy) |
| https://admin.shopify.com | Shopify admin |
| https://apex.devnet.com | Apex DevNet |

### 7.5 Auth Providers

| Provider | Type | Purpose |
|----------|------|---------|
| `GTM_OAuth` | OAuth 2.0 | Google Tag Manager/GA4 API auth |
| `DEVOPS_CENTER_BITBUCKET` | — | DevOps Center Bitbucket |
| `DEVOPS_CENTER_GITHUB` | — | DevOps Center GitHub |
| `DEVOPS_CENTER_PROD` | — | DevOps Center Production |
| `DEVOPS_CENTER_TEST` | — | DevOps Center Test |

### 7.6 Environment Variables (.env)

| Variable | Used By |
|----------|---------|
| `OIL_PRICE_API_KEY` | CommodityPricingService (via API_Key_Settings__c) |
| `OIL_PRICE_API_BASE_URL` | CommodityPricing named credential |
| `EIA_API_KEY` | EIAPricingService (via merge field) |
| `EIA_API_BASE_URL` | EIA_API named credential |
| `COMMODITY_PRICING_NC_USERNAME/PASSWORD/ENDPOINT` | CommodityPricing external credential |
| `EIA_API_NC_USERNAME/PASSWORD/ENDPOINT` | EIA_API external credential |
| `SLACK_CLIENT_ID/SECRET/SIGNING_SECRET/TOKEN/WEBHOOK_URL` | Slack integration |

---

## 8. Permission Sets & Security

### 8.1 Permission Sets

| Permission Set | Role | Object Access |
|----------------|------|---------------|
| `O_G_All_Access` | System Administrator | Full CRUD across all O&G objects |
| `O_G_Field_Technician` | Field Tech | Well, Inspection, Measurement CRUD |
| `O_G_Production_Engineer` | Prod Engineer | Well, Production Allocation, Lease |
| `O_G_Pipeline_Engineer` | Pipeline Eng | Pipeline, Inspection, Measurement |
| `O_G_HSE_Advisor` | HSE Advisor | HSE Incident, Observation, Permit to Work |
| `O_G_Landman` | Landman | Lease, Land Parcel, Well (read) |
| `O_G_Retail_Manager` | Retail Mgr | Retail Outlet, Fuel Inventory |
| `O_G_Refinery_Manager` | Refinery Mgr | Refinery, Terminal |
| `O_G_Terminal_Operator` | Terminal Op | Terminal, Fuel Inventory, Measurement |
| `O_G_Supply_Chain` | Supply Chain | Supply Agreement, Transportation Nomination |
| `O_G_Executive` | Executive | Read-only + dashboards |
| `O_G_Compliance_Analyst` | Compliance | Regulatory Permit, Compliance Report |
| `O_G_Drilling_Engineer` | Drilling Eng | Well_Operation, Well (write) |
| `GTM_Integration_Admin` | GTM Admin | Store, GTM Config, API access |
| `GTM_GA_principles_permission` | GA User | GA4 data access |
| `Energy_Tab_Visibility` | All Users | Tab visibility for all O&G tabs |
| `Experience_Profile_Manager` | — | Experience Cloud profile |
| `sfdcInternalInt__sfdc_scrt2` | Internal | Salesforce internal secret |

### 8.2 External Credential Principals

| External Credential | Principal | Access |
|---------------------|-----------|--------|
| CommodityPricing | CommodityPricing_Principal | Permission set: O_G_All_Access |
| EIA_API | EIA_API_Principal | Permission set: O_G_All_Access |
| PetrelAPI | PetrelAPI_Principal | Permission set: O_G_All_Access |
| EPA_CDX_API | EPA_CDX_API_Principal | Permission set: O_G_All_Access |
| GTM_API | GTM_OAuth_Principal | Permission set: GTM_Integration_Admin |
| Slack_HSE_Webhook | — | Anonymous |

### 8.3 Profile

| Profile | Purpose |
|---------|---------|
| Admin | System administrator profile with full platform access |

---

## 9. Scheduled Jobs & Batch Processing

### 9.1 Active Schedules

| Job | Schedule | Type | What It Does |
|-----|----------|------|-------------|
| Commodity Price Sync | Daily 8:00 AM | Apex Schedulable | Syncs WTI/Brent/Gas prices to Supply_Agreement__c |
| EIA Weekly Sync | Weekly Wed 2:30 PM ET | Apex Schedulable | Syncs fuel prices + national stock benchmarks |
| Compliance Calendar | Daily | Flow | Marks permit renewal reminders |
| Retail Inventory Alert | Daily 5:00 AM | Flow | Creates restock Tasks for low inventory |
| Production Reconciliation | Daily 2:00 AM | Flow | Flags zero-production allocations |
| Land Lease Expiration | Daily 2:00 AM | Flow | Creates Tasks for expiring leases |
| Joint Venture Billing | 1st of month 2:00 AM | Flow | Creates Invoice records for active JVs |
| Inspection Due | Weekly 7:00 AM | Flow | Creates new inspections for overdue recurring ones |

### 9.2 Batch Jobs

| Job | Type | Scope | What It Does |
|-----|------|-------|-------------|
| PipelineIntegrityBatch | Batchable | All Pipelines | Evaluates inspection compliance, sets Compliance_Status__c |
| WellProductionRollupBatch | Batchable | All Wells | Rolls up production volumes to Well__c |

### 9.3 Queueable Chains

```
CommodityPriceSyncScheduler → CommodityPriceSyncQueueable → CommodityPricingService.processPriceSync
EIAPriceSyncScheduler → EIAQueueable (PRICE) → EIAPricingService.processPriceSync
EIAPriceSyncScheduler → EIAQueueable (STOCK) → EIAPricingService.processStockSync
PetrelWellSync Scheduler → PetrelWellSyncQueueable → PetrelWellSync.runSync
ProvisioningService.provisionStore → ProvisioningQueueable → GTMService + GA4AdminService + GTMPixelBuilder
SlackAlertEventTrigger → SlackAlertQueueable → SlackAlertService.sendSlackAlert
```

---

## 10. Testing & Coverage

### 10.1 Test Classes

| Test Class | Status | Coverage Target |
|------------|--------|-----------------|
| `TestWellLifecycle` | ✅ | WellTrigger, WellStatusService |
| `TestFieldServices` | ✅ | InspectionTrigger, InspectionService, AssetTrigger |
| `TestHSEServices` | ✅ | HSEIncidentTrigger, HSEIncidentService |
| `TestEIAPricingService` | ✅ | EIAPricingService, EIAQueueable |
| `TestCommercialServices` | ✅ | CommodityPricingService |
| `TestAPIEndToEnd` | ✅ | All named credential callouts |
| `RegulatoryFilingServiceTest` | ✅ 3/3 | RegulatoryFilingService (96% coverage) |
| `PetrelWellSyncTest` | ✅ 3/3 | PetrelWellSync |

### 10.2 Current Coverage (as of 2026-07-01)

| Metric | Value |
|--------|-------|
| **Org-Wide Coverage** | 44% |
| **Test Run Coverage** | 86% (last run) |
| **RegulatoryFilingService** | 96% |
| **ComplianceDueDateService** | 80% |
| **RegulatoryPermitTrigger** | 83% |

---

## 11. Deployment Guide

### 11.1 Prerequisites

- Salesforce CLI (sf) v2.135+
- Access to the `ouil gas` org
- Node.js + npm for LWC testing

### 11.2 Commands

```bash
# Deploy to main org
sf project deploy start -d "force-app\main\default\PATH" -o "ouil gas"

# Deploy with test execution
sf project deploy start -d "force-app\main\default\classes" -l RunSpecifiedTests -t "TestWellLifecycle" -o "ouil gas"

# Run all tests
sf apex run test -o "ouil gas" -w 10

# Run specific test class
sf apex run test -o "ouil gas" -n "RegulatoryFilingServiceTest" -w 10
```

### 11.3 Key Deployment Considerations

- Always deploy test classes with their service classes
- External credentials and named credentials must be deployed first for callout classes
- Custom settings (`API_Key_Settings__c`, `GTM_Config__c`) must be populated post-deploy
- `O_G_All_Access` permission set must be assigned to users for external credential access
- `StoreController` and `ProvisioningService` classes have known issues with `Store__c` schema — deploy separately if needed

### 11.4 Post-Deploy Steps

1. Assign permission sets via Permission Set Group or individual assignment
2. Populate `API_Key_Settings__c` with OilPriceAPI key
3. Configure `GTM_Config__c` with GTM account ID and GA4 account ID
4. Schedule Apex jobs:
   ```apex
   System.schedule('Commodity Price Sync', '0 0 8 * * ?', new CommodityPriceSyncScheduler());
   System.schedule('EIA Weekly Sync', '0 30 14 * * 3', new EIAPriceSyncScheduler());
   ```
5. Activate flows (ensure `HSE_Incident_Escalation` is set to Active)
6. Verify named credential connectivity via `TestAPIEndToEnd`

---

## 12. Enhancement Roadmap

See `ENHANCEMENT_GUIDE.md` for full details (6 phases, 1031 lines).

### Phase 1: Quick Wins (Completed)
- ✅ Permit-to-Work validation service
- ✅ Inventory balance tracking with alerts
- ✅ SCADA anomaly detection (MeasurementTrigger)
- ✅ Well status lifecycle enforcement
- ✅ Production allocation validation

### Phase 2.1: External APIs — Commodity & EIA (Completed)
- ✅ OilPriceAPI integration with named credential
- ✅ EIA API fuel prices + national stock benchmarks
- ✅ Daily/weekly scheduled sync
- ✅ Protected custom setting for API keys
- ✅ 3/3 end-to-end API tests passing

### Phase 2.2: Petrel Well Sync (Completed)
- ✅ Petrel API external + named credential
- ✅ PetrelWellSync service + queueable
- ✅ Upsert by API_Number__c
- ✅ 3/3 tests passing

### Phase 2.3: Regulatory Filing (Completed)
- ✅ EPA CDX API external + named credential
- ✅ RegulatoryFilingService (invocable Apex)
- ✅ 3/3 tests passing (96% coverage)
- 🔲 `AutoFileComplianceReport` flow (record-triggered on Compliance_Report__c)

### Phase 3: Einstein AI (Pending)
- 🔲 `EinsteinPredictionService` — predict well decline
- 🔲 `PredictiveMaintenanceService` — predict pipeline failures
- 🔲 Einstein Analytics dashboards with production, HSE, compliance lenses

### Phase 4: Experience Cloud (Pending)
- 🔲 Field Technician portal with branded LWC
- 🔲 Well & inspection mobile app
- 🔲 Partner portal for JV billing

### Phase 5: Advanced Analytics (Pending)
- 🔲 Custom report types combining Well + Production + Compliance
- 🔲 Pipeline integrity heat map dashboard
- 🔲 HSE incident trend analysis

### Phase 6: Data Cloud (Pending)
- 🔲 SCADA real-time streaming
- 🔲 Well production historical data lake
- 🔲 Unified customer 360 for retail/commercial

---

## Appendices

### A. Key Files Reference

| File | Path |
|------|------|
| PowerShot App | `force-app/main/default/apps/PowerShot.app-meta.xml` |
| sfdx-project.json | `sfdx-project.json` |
| Manifest (full) | `manifest/package.xml` |
| Manifest (store ecosystem) | `manifest/package-store-ecosystem.xml` |
| Enhancement Guide | `ENHANCEMENT_GUIDE.md` |
| Business Process Mapping | `BUSINESS_PROCESS_MAPPING.md` |
| Oil & Gas Architecture | `OIL_AND_GAS_ARCHITECTURE.md` |
| API Integrations | `API_INTEGRATIONS.md` |
| Project Description | `PROJECT_DESCRIPTION.md` |
| Deployment Summary | `DEPLOY_SUMMARY.md` |
| Manual Fixes | `MANUAL_FIXES.md` |
| Agent Notes | `AGENTS.md` |

### B. Object Count Summary

| Category | Count |
|----------|-------|
| Custom Objects | 24 |
| Standard Objects Extended | 6 |
| Custom Fields | ~260 |
| Record Types | 24 |
| Apex Classes | 40 |
| Apex Triggers | 8 |
| Flows | 11 |
| Permission Sets | 18 |
| LWC Components | 9 |
| Custom Tabs | 23 |
| Layouts | 24 |
| FlexiPages | 6 |
| Named Credentials | 8 |
| External Credentials | 6 |
| CSP Trusted Sites | 3 |
| Remote Site Settings | 5 |
| Auth Providers | 5 |

### C. Business Rules Summary

| Rule | Enforced By | Object |
|------|-------------|--------|
| Well lifecycle transitions | WellTrigger + WellStatusService | Well__c |
| Production WI ≤ 100% (insert) | ProductionAllocationTrigger | Production_Allocation__c |
| Production WI + NRI ≤ 200% (update) | ProductionAllocationTrigger | Production_Allocation__c |
| HSE severity classification | HSEIncidentTrigger + HSEIncidentService | HSE_Incident__c |
| Regulatory reportable notification | HSEIncidentTrigger + HSEIncidentService | HSE_Incident__c |
| Critical incident escalation | HSEIncidentTrigger + HSEIncidentService | HSE_Incident__c |
| Compliance status on permits | RegulatoryPermitTrigger + ComplianceDueDateService | Regulatory_Permit__c |
| Pressure anomaly → observation | MeasurementTrigger | Measurement__c |
| PTW isolation/gas/authorization validation | PermitToWorkValidationService | Permit_to_Work__c |
| Pipeline inspection compliance | PipelineIntegrityBatch | Pipeline__c |
| Low inventory alerts | InventoryBalanceService | Fuel_Inventory__c |
| Asset lifespan flagging | AssetTrigger | Asset |
| Renewal reminders (60-day window) | ComplianceDueDateService | Regulatory_Permit__c |
| Overdue compliance reports | ComplianceDueDateService | Compliance_Report__c |
