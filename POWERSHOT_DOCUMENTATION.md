# PowerShot — Oil & Gas Salesforce Platform

**Version:** 1.5 | **API Version:** 67.0 | **Last Updated:** 2026-09-03

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
13. [Agentforce & Headless Operations](#13-agentforce--headless-operations)

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
| **Source API Version** | 66.0 (sfdx-project) — newer portal/SCADA/WhatsApp LWCs and API classes target 67.0 |
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
| PI_Tag__c | Text | PI Historian tag — the key used to resolve inbound SCADA readings to wells |
| Spud_Date__c | Date | Date drilling commenced |
| Completion_Date__c | Date | Date well completed |
| Total_Depth__c | Number(10,2) | Total measured depth (ft) |
| True_Vertical_Depth__c | Number(10,2) | True vertical depth (ft) |
| Formation__c | Text(100) | Producing formation name |
| Is_Declining__c | Checkbox | Flag for declining production |
| Total_Oil_Volume_12M__c | Number(18,2) | Rolling 12-month oil volume |
| Status_Change_Date__c | Date | Date of last status change |
| Last_Production_Date__c | Date | Most recent telemetry reading date (updated by rollup batch) |
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
| PI_Tag__c | Text | PI Historian tag — key used to resolve inbound SCADA readings to pipelines |
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
| Measurement_Type__c | Picklist | Oil Flow, Gas Flow, Water Flow, Pressure, Temperature, Other (drives routing + rollup) |
| Source__c | Picklist | SCADA, Manual, Meter (legacy source) |
| Source_System__c | Picklist | PI Historian, SCADA, Manual — identifies the ingestion origin |
| PI_Tag__c | Text | PI Historian tag for the reading |
| Well__c | Lookup(Well__c) | Linked producing well (tag-resolved) |
| Pipeline__c / Pipeline_Station__c / Terminal__c | Lookup | Location context |
| External_Key__c | Text (externalId, unique) | Idempotency key: `<Source_System>|<tag\|pipelineId>|<timestamp>` |
| Gravity__c, Meter_Factor__c, Net_Volume__c | Number | Additional meter / product data |

**Note:** The O&G "Well" telemetry path routes through the SCADA ingestion API. Pressure/temperature
readings are stored for telemetry; only Well-linked `Oil Flow` / `Gas Flow` / `Water Flow` readings
feed the monthly `Production_Allocation__c` rollup.

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

#### Inventory_Transaction__c

Tracks individual inventory movements (receipts, deliveries, adjustments, reconciliations) for Fuel_Inventory__c records.

| Field | Type | Description |
|-------|------|-------------|
| Transaction_Type__c | Picklist | Receipt, Delivery, Adjustment, Reconciliation |
| Volume__c | Number(18,2) | Transaction volume |
| Transaction_DateTime__c | DateTime | When the transaction occurred |
| Fuel_Inventory__c | Lookup(Fuel_Inventory__c) | Related inventory record |
| Terminal__c / Retail_Outlet__c | Lookup | Location context |
| Reference_Number__c | Text | External reference (ticket, BOL) |

### 2.4 Commercial Objects

#### Supply_Agreement__c

| Field | Type | Description |
|-------|------|-------------|
| Agreement_Type__c | Picklist | Term, Spot, Exchange |
| Commodity__c | Picklist | Crude, Gas, NGL, Refined, Diesel, Jet Fuel, Heating Oil |
| Status__c | Picklist | Draft, Active, Expired, Terminated |
| Price_Basis__c | Picklist | WTI, Brent, HH, TTF, JKM |
| Current_Price__c | Number(18,2) | Latest market price (synced via API) |
| Price_Benchmark__c | Picklist | WTI, Brent, HH, TTF, JKM, Dubai, NYMEX — benchmark index |
| Previous_Price__c | Currency | Price before last sync (used for variance calc) |
| Price_Change__c | Formula (Number) | `(Current_Price__c - Previous_Price__c) / Previous_Price__c * 100` |
| Last_Sync_DateTime__c | DateTime | Timestamp of last successful API sync |
| Price_Source__c | Picklist | OilPriceAPI, EIA, Manual, Platts, OPIS — data origin |
| Price_Frequency__c | Picklist | Real-Time, Daily, Weekly, Monthly, On-Demand |
| Contract_Price__c | Currency | Negotiated contract price (manual) |
| Price_Variance_Limit__c | Number(5) | Max allowed % variance before alert (default: 5) |
| Volume__c | Number(18,2) | Agreement volume |
| Term_Start__c / Term_End__c | Date | Agreement term |
| Account__c | Master-Detail(Account) | Counterparty |

**Price Sync:** Current_Price__c is auto-populated on scheduled runs. `CommodityPricingService` runs daily at 8:00 AM (OilPriceAPI). `EIAPricingService` runs weekly Thursday 2:30 PM (EIA API). Price_Change__c is auto-calculated as the percentage difference between Previous_Price__c and Current_Price__c.

#### Transportation_Nomination__c

| Field | Type | Description |
|-------|------|-------------|
| Status__c | Picklist | Requested, Scheduled, Delivered |
| Nomination_Period__c | Date | Shipping period |
| Requested_Volume__c / Confirmed_Volume__c | Number(18,2) | Volumes |
| Pipeline__c | Lookup(Pipeline__c) | Transport pipeline |

#### Service_Contract__c

Vendor/contractor service agreements for well services, maintenance, and operations.

| Field | Type | Description |
|-------|------|-------------|
| Contract_Type__c | Picklist | Well Services, Maintenance, Consulting |
| Status__c | Picklist | Draft, Active, Expired, Terminated |
| Start_Date__c / End_Date__c | Date | Contract term |
| Total_Value__c | Currency | Contract value |
| Account__c | Master-Detail(Account) | Vendor/contractor |

#### Joint_Venture__c

Tracks joint venture partnerships for shared oil & gas operations.

| Field | Type | Description |
|-------|------|-------------|
| JV_Name__c | Text | Joint venture name |
| Status__c | Picklist | Active, Inactive, Dissolved |
| Operator__c | Master-Detail(Account) | Operating company |
| Working_Interest__c | Percent | WI share |
| Revenue_Share__c | Percent | Revenue share |
| Well__c / Pipeline__c | Lookup | Related asset |

#### Invoice__c

Billing records generated for joint venture operations and production allocations.

| Field | Type | Description |
|-------|------|-------------|
| Invoice_Number__c | Text | Unique invoice ID |
| Amount__c | Currency | Invoice amount |
| Status__c | Picklist | Draft, Sent, Paid, Overdue |
| Due_Date__c | Date | Payment due date |
| Joint_Venture__c | Lookup(Joint_Venture__c) | Related JV |
| Account__c | Master-Detail(Account) | Billing party |

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
| OilPrice_API_Key__c | **DEPRECATED** for `CommodityPricingService` — the OilPriceAPI token now lives in the `CommodityPricing` external credential's **Password** (resolved as `{!$Credential.Password}`; verified live HTTP 200, 2026-09-03). Field kept for backward-compat only; do not populate in new deployments.

### 2.8 Standard Object Extensions

| Object | Added Fields |
|--------|-------------|
| **Account** | Well_Count__c, Lease_Count__c, Pipeline_Count__c, Regulatory_Compliance_Status__c, Emergency_Contact_Name__c, Emergency_Contact_Phone__c |
| **Asset** | Inspiration_Frequency_Days__c, Expected_Lifespan_Days__c, Maintenance_Schedule__c, Next_Inspection_Date__c |
| **Case** | Well__c, Pipeline__c, Incident_Type__c, Severity__c, HSE_Related__c, Regulatory_Reportable__c |
| **Opportunity** | Well__c, Lease__c, Agreement_Type__c, Volume__c |
| **WorkOrder** | Well__c, Pipeline__c, Permit_to_Work__c, PTW_Required__c, PTW_Approved__c, Safety_Briefing_Completed__c |

**WorkOrder Record Types:**

| Record Type | Purpose |
|-------------|---------|
| Corrective | Reactive maintenance/repair work |
| Field_Service | Routine field service operations |
| Inspection_WO | Inspection-related work orders |
| Preventive_Maintenance | Scheduled preventive maintenance |

### 2.9 Platform Events

| Object | Type | Fields |
|--------|------|--------|
| **Slack_Alert__e** | HighVolume Platform Event | Incident_Id__c |

### 2.10 Validation Rules (Deployed)

| Object | Rule | Condition | Error Message |
|--------|------|-----------|---------------|
| **Well__c** | `Require_API_Number_For_Prod_Well` | Producing/Drilling wells must have API number | API Number is required for Producing and Drilling wells |
| **Well__c** | `Require_Depth_Fields` | Total_Depth__c and True_Vertical_Depth__c required when Status ≠ Permitted | Total Depth and True Vertical Depth are required when well has been spudded |
| **Permit_to_Work__c** | `Require_Scope_of_Work` | Scope_of_Work__c must be ≥10 characters when provided | Scope of Work must be at least 10 characters long |
| **Permit_to_Work__c** | `Valid_Date_Range` | Valid_From__c must be before Valid_To__c | Permit expiry must be after start date |
| **Permit_to_Work__c** | `Require_Gas_Test_Results` | Gas_Test_Result__c required when gas test is required and completed | Gas Test Result (Pass/Fail) is required when gas test has been completed |
| **Pipeline__c** | `Operating_Pressure_Limits` | MAOP__c must be between 0 and 15,000 psi | Operating pressure must be within acceptable limits (0–15,000 psi) |
| **Pipeline__c** | `Require_Diameter_And_Capacity` | Diameter_inches__c and Capacity_bpd__c required for Active pipelines | Diameter and capacity are required for active pipelines |
| **HSE_Incident__c** | `Require_Incident_Date` | Incident date must be populated | Incident date is required |
| **HSE_Incident__c** | `Require_Corrective_Action_When_Closed` | Corrective action required when Status = Closed | Corrective action description is required before closing an incident |
| **HSE_Incident__c** | `Spill_Volume_Required_When_Spill` | Spill_Volume__c required when Incident_Type__c = Spill | Spill volume is required for spill incidents |

### 2.11 Integration Config Objects

#### SCADA_Config__c (Hierarchy Custom Setting)

Fail-closed configuration for the SCADA/PI ingestion endpoint.

| Field | Type | Description |
|-------|------|-------------|
| Enabled__c | Checkbox | Master switch — ingest returns 401 when false |
| Shared_Secret__c | Text | HMAC-SHA256 shared secret (matches operator bridge; kept out of source control) |
| Backfill_Mode__c | Checkbox | Enables bulk/backfill ingestion path |

#### WhatsApp_Config__c (Hierarchy Custom Setting)

| Field | Description |
|-------|-------------|
| Phone_Number_ID__c | WhatsApp Business phone number ID |
| App_Secret__c | Meta app secret (used for webhook request verification) |
| Verify_Token__c | Webhook verification token |

#### WhatsApp_Message__c

| Field | Type | Description |
|-------|------|-------------|
| Direction__c | Picklist | Inbound / Outbound |
| Message_Type__c | Picklist | Text / Image / etc. |
| Status__c | Picklist | Received / Processed / etc. |
| WhatsApp_Message_ID__c | Text | Meta message ID |
| Sender_Phone__c | Phone | Sender's phone number |
| Sender_Name__c | Text | Sender name (matched to Contact) |
| Message_Body__c | LongTextArea | Message text |
| Timestamp__c | DateTime | Message time |
| Raw_Payload__c | LongTextArea | Full Meta webhook payload |
| Contact__c | Lookup(Contact) | Matched contact (by phone) |
| Account__c | Lookup(Account) | Derived account |

### 2.12 Compact Layouts

| Compact Layout | Object | Primary Fields |
|----------------|--------|----------------|
| `Well_Compact_Layout` | Well__c | API_Number__c, Status__c, Well_Type__c, Formation__c, Account__c |
| `Pipeline_Compact_Layout` | Pipeline__c | Commodity__c, Status__c, Diameter_inches__c, MAOP__c, Account__c |
| `HSE_Incident_Compact_Layout` | HSE_Incident__c | Incident_Type__c, Severity__c, Status__c, Location__c |
| `PTW_Compact_Layout` | Permit_to_Work__c | Permit_Type__c, Risk_Level__c, Status__c, Holder__c |

### 2.13 Public Groups

| Group | Developer Name | Purpose |
|-------|---------------|---------|
| `HSE_Compliance_Team` | HSE_Compliance_Team | HSE compliance review and notification recipients |
| `Executive_Leadership` | Executive_Leadership | Executive-level dashboards and reporting visibility |

---

## 3. Apex Classes

### 3.1 Service Classes

| Class | Lines | Domain | Key Methods |
|-------|-------|--------|-------------|
| `WellStatusService` | 123 | Upstream | `isValidTransition(from, to)`, `createWellOperations(wells)`, `getWellProduction` |
| `ProductionAllocationService` | 137 | Upstream | `calculateMonthlyAllocation`, `validateWorkingInterest`, `getProductionHistory` |
| `ComplianceDueDateService` | 177 | Regulatory | `getUpcomingRenewals`, `getOverdueReports`, `updateComplianceStatuses`, `sendRenewalReminders` |
| `HSEIncidentService` | 248 | HSE | `classifySeverities`, `isRegulatoryReportable`, `notifyComplianceTeams`, `escalateIfCritical`, `getHSEIncidents` |
| `InspectionService` | 171 | Midstream | `getChecklistItems`, `submitChecklist`, `updateParentInspectionDates`, `createRecurringInspections` |
| `PermitToWorkValidationService` | 245 | HSE | `validateIsolationRequirements`, `validateGasTestResults`, `validateAuthorizationChain`, `getMissingRequirements` |
| `PipelineIntegrityService` | 95 | Midstream | `getOverdueInspections`, `isInspectionCompliant`, `flagNonCompliantPipelines`, `calculateNextInspectionDueDate` |
| `InventoryBalanceService` | 152 | Downstream | `getTankInventory`, `recordInventoryMovement`, `getLowInventoryAlerts`, `reconcileInventory` |
| `RoyaltyCalculationService` | 156 | Upstream | Royalty payment calculations |
| `SCADAMeasurementProcessor` | 11 | Midstream | SCADA data processing (stub) |
| `SlackAlertService` | 15 | Integration | `sendSlackAlert(incidentId, message, webhookUrl)` — Invocable Apex for flow |

### 3.2 Integration / API Classes

| Class | Lines | Integration | Key Methods |
|-------|-------|-------------|-------------|
| `CommodityPricingService` | 121 | OilPriceAPI | `syncPrices`, `processPriceSync`, `fetchPrice(apiCode)` — commodity map covers Crude→WTI, Gas→NG, NGL→NGL_USD, Refined→RB, Diesel→EPDXL0, Jet Fuel→EPJK, Heating Oil→EPMM |
| `EIAPricingService` | 236 | EIA API | `processPriceSync`, `processStockSync`, `fetchRetailPrice`, `fetchNationalStock` — price map covers Refined→EER_EPMRU_PF4_Y44NY_DPG, Gas→EER_EPMRU_PF4_Y35NY_DPG, Diesel→EPDXL0, Jet Fuel→EPJK, Heating Oil→EPMM |
| `PetrelWellSync` | 111 | Petrel/EDM | `runSync`, `fetchWellsFromPetrel`, `upsertWells` |
| `RegulatoryFilingService` | 78 | EPA CDX | `fileComplianceReport` — Invocable Apex for flow |
| `SCADAIngestionAPI` | — | SCADA | REST endpoint `/services/apexrest/api/scada/measurements` — fail-closed HMAC-SHA256 auth, tag resolution, ≤5000-reading chunking, idempotent upsert |
| `WhatsAppWebhookHandler` | — | WhatsApp Cloud API | Inbound webhook handler — signature/verify-token validation, sender → Contact match, `WhatsApp_Message__c` persistence |
| `WhatsAppMessageService` | — | WhatsApp Cloud API | Message send/receive service backing the webhook |
| `MarketDataController` | — | Commodity/EIA | `@AuraEnabled` market-data queries for `marketDataHome` LWC |
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
| `WellProductionRollupBatch` | Batch | Batch production volume rollup (legacy well rollup) |
| `WellProductionTelemetryRollupBatch` | Batch + Schedulable | Rolls PI telemetry `Measurement__c` into monthly `Production_Allocation__c`; updates `Well__c.Last_Production_Date__c`. **Live in org** — scheduled nightly at 1:00 AM (cron `0 0 1 * * ?`) |

> **Note:** `WellProductionRollupBatch` (the original well-rollup batch) has been superseded for the SCADA/PI telemetry path by `WellProductionTelemetryRollupBatch`. Both batch classes use `without sharing`.

### 3.7 Experience Cloud Portal Controllers

All portal controllers are `with sharing` and CRUD/FLS-guarded to respect the JV-partner record-sharing model.

| Class | Key Methods | Purpose |
|-------|-------------|---------|
| `PortalDashboardController` | Dashboard summary, recent incidents, deadlines, production summary | Partner portal home |
| `PortalWellStatusController` | Wells list, per-well production, status counts, telemetry | Wells & Production page |
| `PortalIncidentController` | Incident list, create incident, incident detail | HSE page + incident submission |
| `PortalInvoiceController` | Invoices list (status filter), royalty statements, billing summary | Billing & Royalties page (**NEW 2026-08-27**) |
| `PortalComplianceController` | Permits list, compliance reports list, compliance summary, upcoming-deadline horizon | Compliance page (**NEW 2026-08-27**) |

### 3.8 Account Derivation Services

| Class | Purpose |
|-------|---------|
| `InvoiceAccountService` (called by `InvoiceAccountTrigger`) | Derives `Invoice__c.Account__c` from `JV__r.Account__c` before insert/update — feeds the `JV_Partner_Sharing` Sharing Set (**NEW 2026-08-27**) |
| `ProductionAllocationAccountService` (called by `ProductionAllocationTrigger`) | Derives `Production_Allocation__c.Account__c` from `Well__r.Account__c` before insert/update — feeds the `JV_Partner_Sharing` Sharing Set (**NEW 2026-08-27**) |

### 3.4 Scheduler Classes

| Class | Schedule | Purpose |
|-------|----------|---------|
| `CommodityPriceSyncScheduler` | Daily 8:00 AM | Sync commodity prices to Supply_Agreement__c |
| `EIAPriceSyncScheduler` | Weekly Thu 2:30 PM | Sync EIA fuel prices & stock benchmarks |

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
| `TestSCADAIngestionAPI` | 12/12 ✅ | SCADA ingest: valid/bad/missing signature, disabled, unmatched tag, idempotency, legacy path, chunking |
| `TestWellProductionTelemetryRollupBatch` | 3/3 ✅ | Telemetry rollup: monthly allocation, upsert/idempotent, ignores non-PI/unlinked |
| `TestPortalPageControllers` | 16/16 ✅ | Experience Cloud portal page controllers (+ `getWellTelemetry`) |
| `TestPortalControllers` | 15 ✅ | Portal controllers |
| `TestWhatsAppIntegration` | 8 ✅ | WhatsApp webhook integration |
| `TestPhase2Wrappers` | — | Phase 2 response wrappers (ProductionHistoryWrapper, RoyaltyCalculationWrapper, PipelineIntegrityStatusWrapper) |

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
| `InvoiceAccountTrigger` | Invoice__c | B/I/U | Derives `Account__c` from `JV__r.Account__c` for JV-partner portal sharing (**NEW 2026-08-27**) |

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

> **Known issue (from audit 2026-08-06):** Three scheduled flows (`Inspection_Due`, `Production_Reconciliation`, `Retail_Inventory_Alert`) reference `$Record`, which is **not valid in scheduled-trigger flows** (there is no triggering record at schedule time). They will fail at runtime / validate-fail. Fix: replace `$Record` with a SOQL-based scheduled path or convert to record-triggered design.

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
| **wellProductionChart** | `WellStatusService.getWellProduction` | Well production visualization with oil/gas/water bar chart |
| **storeManager** | `StoreController`, `ProvisioningService`, `GAEventsController` | Store ecosystem management UI |
| **storeProvisioning** | `ProvisioningService.provisionStore`, `.getProvisioningStatus` | Store provisioning wizard with status polling |
| **marketDataHome** | `MarketDataController.getSupplyAgreementPricing`, `MarketDataController.getMarketData` | Supply agreement pricing grouped by commodity with variance badges, CSS bar chart, price tiles, EIA inventory table |
| **portalDashboard** | `PortalDashboardController` | Partner portal home — KPI tiles + incident/deadline/production tables |
| **portalWellStatus** | `PortalWellStatusController` | Well list + status counts + 12-month production + telemetry table |
| **portalHSEIncidentForm** | `PortalIncidentController` | Incident list + new incident submission form |
| **portalInvoices** | `PortalInvoiceController` | Billing & Royalties page — summary tiles, invoice table (status filter), royalty-statement table (**NEW 2026-08-27**) |
| **portalCompliance** | `PortalComplianceController` | Compliance page — summary tiles, upcoming-deadline horizon strip, permits & reports tables (**NEW 2026-08-27**) |

All internal LWCs expose `lightning__RecordPage`, `lightning__AppPage`, and `lightning__HomePage` targets.
The five `portal*` LWCs target the Experience Cloud community (JV-partner portal), plus `marketDataHome`.
Portal LWCs are **not** intended for Lightning record pages.

### 6.5 FlexiPages

| FlexiPage | Object/Context | Embedded LWCs |
|-----------|----------------|---------------|
| **Well_Record_Page** | Well__c | `fieldServiceChecklist`, `hseIncidentMap`, `permitToWorkBoard`, `wellProductionChart`, `productionAllocationReport` |
| **Account_Record_Page** | Account | `complianceCalendar`, `fieldServiceChecklist`, `hseIncidentMap` |
| **HSE_Incident_Record_Page** | HSE_Incident__c | Standard layout (no custom LWCs) |
| **Lease_Record_Page** | Lease__c | Standard layout |
| **Pipeline_Record_Page** | Pipeline__c | Standard layout |
| **Production_Allocation_Record_Page** | Production_Allocation__c | Standard layout |
| **Regulatory_Permit_Record_Page** | Regulatory_Permit__c | Standard layout |
| **Terminal_Record_Page** | Terminal__c | Standard layout |

The **Well_Record_Page** is the richest page, embedding 5 of the 9 LWC components. It serves as the primary operations dashboard for upstream well management.

### 6.6 Page Layouts

25 page layouts are deployed, one per custom object plus standard object extensions:

| Layout | Object | Notable Sections |
|--------|--------|-----------------|
| `Permit_to_Work Layout` | Permit_to_Work__c | Gas test fields, isolation checkboxes, authorization chain, location lookups (171 lines — most complex) |
| `HSE Incident Layout` | HSE_Incident__c | Severity, incident type, spill volume, environmental impact, regulatory flags |
| `Store Layout` | Store__c | GTM/GA4 provisioning fields, store type, website URL |
| `Fuel Inventory Layout` | Fuel_Inventory__c | Volume gauges, thresholds, EIA stock comparison |
| `Inspection Layout` | Inspection__c | Checklist items, frequency, asset/pipeline lookups |
| `Well Layout` | Well__c | Status lifecycle, depth fields, production data, lease lookup |
| `Pipeline Layout` | Pipeline__c | MAOP, diameter, compliance status, inspection dates |
| `Regulatory Permit Layout` | Regulatory_Permit__c | Permit type, agency, compliance status, expiration |
| `Production Allocation Layout` | Production_Allocation__c | Oil/gas/water volumes, WI/NRI shares, period dates |
| Remaining 16 layouts | Various | Standard field arrangements per object |

### 6.7 Data Seeder Scripts

| Script | Lines | Purpose |
|--------|-------|---------|
| `seed_all_powershot.apex` | 529 | **Master seeder** — creates ~280 records across 24 object types with realistic O&G data |
| `seed_wells.apex` | 37 | Well-only seed for quick testing |
| `check_well_data.apex` | 6 | SOQL query to verify well record counts |
| `run_rollup_batch.apex` | 1 | Executes WellProductionRollupBatch |
| `create_test_records.apex` | 36 | Creates general test records |
| `create_v2.apex` | 22 | v2 record creation variant |
| `create_and_sync.apex` | 34 | Create and sync test for integrations |
| `eia_test.apex` | 86 | EIA API integration test script |
| `field_check.apex` | 14 | Field existence checker across objects |
| `direct_test.apex` | 16 | Direct API callout test |
| `hello.apex` | 10 | Hello world connectivity test |

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
| `WhatsApp_API` | https://graph.facebook.com/v21.0 | WhatsApp_API | Basic | WhatsApp Cloud API (outbound / future) |

> **Note:** The audit flags `Slack_HSE_Webhook` as **duplicated/unused** — Slack alerts are actually driven by `GTM_Config__c.Slack_Webhook_URL__c` (`SlackAlertQueueable`).

### 7.2 Integration Matrix

| Integration | Direction | Mechanism | Frequency | Auth |
|-------------|-----------|-----------|-----------|------|
| **OilPriceAPI** | Inbound | Schedulable → Queueable → Named Credential | Daily | API key via custom setting |
| **EIA API** | Inbound | Schedulable → Queueable → Named Credential | Weekly (Thu) | API key via merge field |
| **Petrel/EDM** | Inbound | Schedulable → Queueable → Named Credential | Daily or On-demand | Password |
| **EPA CDX** | Outbound | Invocable Apex → Named Credential | Trigger-driven | Password |
| **Slack** | Outbound | Platform Event → Queueable → Named Credential → Webhook | Event-driven | Anonymous |
| **Google Tag Manager** | Outbound | Queueable → Named Credential (OAuth) | Event-driven | OAuth 2.0 |
| **Google Analytics Admin** | Outbound | Queueable → Named Credential (OAuth) | Event-driven | OAuth 2.0 |
| **Google Analytics Data** | Inbound | AuraEnabled Apex → Named Credential (OAuth) | On-demand (LWC) | OAuth 2.0 |
| **SCADA / PI** | Inbound | REST API (SCADAIngestionAPI) → Queueable → Apex | Real-time / Nightly rollup | Custom (HMAC-SHA256 + Bearer) |
| **WhatsApp Cloud API** | Inbound | REST webhook (`/services/apexrest/whatsapp/webhook`) → Apex | Real-time | X-Hub-Signature-256 HMAC verification |

### 7.7 WhatsApp Integration (COMPLETED)

The WhatsApp webhook integration is **fully implemented** (contrary to `WHATSAPP_INTEGRATION_PLAN.md` status header, which is stale and says "Not started"). Components:

| Asset | Detail |
|-------|--------|
| `WhatsAppWebhookHandler` | `@RestResource` at `/whatsapp/webhook`. GET = webhook verification (verify-token match → challenge); POST = message ingestion. Validates `X-Hub-Signature-256` HMAC-SHA256 with app secret; always returns 200 for fast ack. |
| `WhatsAppMessageService` | `normalizePhone()` (E.164, default country code '1'), `matchContact()`, `parseAndStore()` with idempotency (`WhatsApp_Message_ID__c` unique) and `MAX_MESSAGES_PER_REQUEST = 50`. |
| `WhatsApp_Message__c` | Custom object persisting inbound messages (fields listed in §2.12). |
| `whatssapp webhook` site/network | Public CustomSite (`active=true`) exposing only the webhook class to guests; guest profile has no object access. |
| `TestWhatsAppIntegration` | 8 tests passing. |

### 7.8 SCADA / PI Integration (GO-LIVE 2026-08-30)

The SCADA/PI telemetry ingestion is **live and verified** in the org (`ouil gas`) as of 2026-08-30. See `SCADA_PI_INTEGRATION.md` for the operator go-live manual and `bridge/` for the runnable bridge artifacts:

| Asset | Detail |
|-------|--------|
| `SCADAIngestionAPI` | REST `POST /api/scada/measurements` — fail-closed (401 unless `SCADA_Config__c.Enabled__c` AND valid HMAC-SHA256 signature), Bearer token required (no MyDomain), ≤5000-reading chunking, idempotent `External_Key__c` upsert. |
| `SCADA_Config__c` | Hierarchy custom setting — `Enabled__c`, `Shared_Secret__c` (out-of-band, not in source control), `Backfill_Mode__c`. |
| `Measurement__c` | Tag-resolved (`PI_Tag__c`), routed by `measurementType` (Oil/Gas/Water Flow → monthly rollup; Pressure/Temperature → telemetry only). |
| `WellProductionTelemetryRollupBatch` | Nightly (1:00 AM) — sums Well-linked Oil/Gas/Water Flow readings into monthly `Production_Allocation__c`, updates `Well__c.Last_Production_Date__c`. Idempotent. |
| `bridge/` | `sender.ps1` (signed test-payload sender), `bridge_poc.py` (Python reference bridge), `scada_bridge.env.example` (config template). |

### 7.9 Store / GTM / GA4 (part of Store ecosystem)

`StoreController`, `ProvisioningService`, `GTMService`, `GA4AdminService`, `GTMPixelBuilder`, `GAEventsController` make up the Store provisioning ecosystem. See §3.6.

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
| `OIL_PRICE_API_KEY` | **DEPRECATED** — `CommodityPricingService` now uses the `CommodityPricing` external credential's Password (`{!$Credential.Password}`) |
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
| `O_G_Portal_Access` | JV Partner (Partner Community) | Read on 8 JV-partner objects + 5 portal controllers + tabs; 66 explicit field-level read grants |
| `O_G_Field_Portal_Access` | Field Technician (Customer Community Plus) | CRUD Inspection/PTW/WorkOrder; future field-tech partner audience |
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
| EIA Weekly Sync | Weekly Thu 2:30 PM ET | Apex Schedulable | Syncs fuel prices + national stock benchmarks |
| Compliance Calendar | Daily | Flow | Marks permit renewal reminders |
| Retail Inventory Alert | Daily 5:00 AM | Flow | Creates restock Tasks for low inventory |
| Production Reconciliation | Daily 2:00 AM | Flow | Flags zero-production allocations |
| Land Lease Expiration | Daily 2:00 AM | Flow | Creates Tasks for expiring leases |
| Joint Venture Billing | 1st of month 2:00 AM | Flow | Creates Invoice records for active JVs |
| Inspection Due | Weekly 7:00 AM | Flow | Creates new inspections for overdue recurring ones |
| Well Production Telemetry Rollup | Nightly 1:00 AM | Apex Schedulable | `WellProductionTelemetryRollupBatch` — rolls PI telemetry `Measurement__c` into monthly `Production_Allocation__c` (cron `0 0 1 * * ?`, CronTrigger `08egK00000dkkSuQAI`) |

### 9.2 Batch Jobs

| Job | Type | Scope | What It Does |
|-----|------|-------|-------------|
| PipelineIntegrityBatch | Batchable | All Pipelines | Evaluates inspection compliance, sets Compliance_Status__c |
| WellProductionRollupBatch | Batchable | All Wells | Rolls up production volumes to Well__c (legacy) |
| WellProductionTelemetryRollupBatch | Batchable + Schedulable | Well-linked Measurements | Rolls daily PI telemetry readings into monthly `Production_Allocation__c`; updates `Well__c.Last_Production_Date__c` — **live in org** |

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
| `TestFieldServices` | ⚠️ (fails on pre-existing validation rule) | InspectionTrigger, InspectionService, AssetTrigger |
| `TestHSEServices` | ✅ | HSEIncidentTrigger, HSEIncidentService |
| `TestEIAPricingService` | ✅ | EIAPricingService, EIAQueueable |
| `TestCommercialServices` | ✅ | CommodityPricingService |
| `TestAPIEndToEnd` | ✅ | All named credential callouts |
| `RegulatoryFilingServiceTest` | ✅ 3/3 | RegulatoryFilingService (96% coverage) |
| `PetrelWellSyncTest` | ✅ 3/3 | PetrelWellSync |
| `TestSCADAIngestionAPI` | ✅ 12/12 | SCADA ingest: valid/bad/missing signature, disabled, unmatched tag, idempotency, legacy path, chunking |
| `TestWellProductionTelemetryRollupBatch` | ✅ 3/3 | Telemetry rollup: monthly allocation, upsert/idempotent, ignores non-PI/unlinked |
| `TestPortalPageControllers` | ✅ 16/16 | Experience Cloud portal page controllers (+ `getWellTelemetry`) |
| `TestPortalControllers` | ✅ 14 | Portal controllers |
| `TestWhatsAppIntegration` | ✅ 8 | WhatsApp webhook integration |
| `TestPhase2Wrappers` | ✅ | Phase 2 response wrappers |

> **Note on baseline test failures:** `TestFieldServices` (and `TestPortalControllers` in some runs) fail in the org on a **pre-existing** validation rule (`Pipeline Diameter and Capacity are required fields`) — its `@TestSetup` inserts a `Pipeline__c` that violates that rule. This is unrelated to the portal/SCADA work and predates it.

### 10.2 Current Coverage (as of 2026-07-11)

| Metric | Value |
|--------|-------|
| **Tests Passed** | 97/97 (100%) |
| **Org-Wide Coverage** | 40% |
| **InspectionService** | 100% |
| **ProductionAllocationService** | 100% |
| **HSEIncidentService** | 100% |
| **SlackAlertService** | 100% |
| **WellStatusService** | 93% |
| **RegulatoryFilingService** | 96% |
| **ComplianceDueDateService** | 80% |
| **PipelineIntegrityService** | 80% |
| **PermitToWorkValidationService** | 38% |
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
- Custom settings (`GTM_Config__c`) must be populated post-deploy
- `O_G_All_Access` permission set must be assigned to users for external credential access
- **OilPriceAPI token** already lives in the `CommodityPricing` external credential's **Password** (used by `CommodityPricingService` via `{!$Credential.Password}`; Username is a placeholder) — keep it out of source code / custom settings
- `StoreController` and `ProvisioningService` classes have known issues with `Store__c` schema — deploy separately if needed

### 11.4 Post-Deploy Steps

1. Assign permission sets via Permission Set Group or individual assignment
2. Confirmed the **OilPriceAPI token** is provisioned in the `CommodityPricing` external credential's **Password** field (used by `CommodityPricingService` via `{!$Credential.Password}`; verified live HTTP 200, 2026-09-03)
3. Configure `GTM_Config__c` with GTM account ID and GA4 account ID
4. Schedule Apex jobs:
   ```apex
   System.schedule('Commodity Price Sync', '0 0 8 * * ?', new CommodityPriceSyncScheduler());
   System.schedule('EIA Weekly Sync', '0 30 14 ? * 4', new EIAPriceSyncScheduler());
   ```
5. Activate flows (ensure `HSE_Incident_Escalation` is set to Active)
6. Verify named credential connectivity via `TestAPIEndToEnd`

---

## 12. Enhancement Roadmap

See `ENHANCEMENT_GUIDE.md` for full details (6 phases, 1031 lines).

### Phase 1: Quick Wins (Completed)

**Core Services:**
- ✅ Permit-to-Work validation service
- ✅ Inventory balance tracking with alerts
- ✅ SCADA anomaly detection (MeasurementTrigger)
- ✅ Well status lifecycle enforcement
- ✅ Production allocation validation

**Phase 1 Gap Fixes (Deployed 2026-07-11):**
- ✅ Deleted corrupted `Supply_Agreement__c.Commodity__c` field; renamed `Commodity_v2__c` label to "Commodity"
- ✅ Created public groups `HSE_Compliance_Team` and `Executive_Leadership`
- ✅ 4 compact layouts (Well, Pipeline, HSE Incident, Permit to Work) with primary field assignments
- ✅ 10 validation rules across 4 objects (Well__c ×2, Permit_to_Work__c ×3, Pipeline__c ×2, HSE_Incident__c ×3)
- ✅ 97/97 tests passing (100%) — test classes updated to accommodate new validation rules

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

### Phase 2.4: Supply Agreement Pricing (Completed 2026-08-26)
- ✅ Commodity picklist expanded: Diesel, Jet Fuel, Heating Oil
- ✅ 8 new pricing fields on Supply_Agreement__c: Price_Benchmark, Previous_Price, Price_Change (formula), Last_Sync_DateTime, Price_Source, Price_Frequency, Contract_Price, Price_Variance_Limit
- ✅ CommodityPricingService commodity map expanded (NGL fix, Diesel/Jet Fuel/Heating Oil via OilPriceAPI product codes)
- ✅ EIAPricingService price + stock maps expanded (Diesel→EPDXL0, Jet Fuel→EPJK, Heating Oil→EPMM)
- ✅ MarketDataController.getSupplyAgreementPricing() — returns commodity-grouped Supply Agreements with spot price variance
- ✅ marketDataHome LWC — Supply Agreement Pricing section with grouped tables, JS-side variance sorting, variance badges
- ✅ All scheduled syncs verified: Commodity Price Sync (daily 8AM), EIA Weekly Sync (Thu 2:30PM)

### Phase 3: Einstein AI (Pending)
- 🔲 `EinsteinPredictionService` — predict well decline
- 🔲 `PredictiveMaintenanceService` — predict pipeline failures
- 🔲 Einstein Analytics dashboards with production, HSE, compliance lenses

### Phase 4: Experience Cloud (Partially Complete — Phase 1/3 done 2026-08-27)
- ✅ **Phase 1 — Security & Sharing (DONE 2026-08-27):** OWD → Private on 8 JV-partner objects; `Account__c` lookups added to `Invoice__c` + `Production_Allocation__c`; `JV_Partner_Sharing` Sharing Set keyed on Account; backfill executed (0 records missing `Account__c`); record-triggered automation via `InvoiceAccountTrigger` + `ProductionAllocationTrigger`; 66 field-level read grants on `O_G_Portal_Access`.
- ✅ **Phase 3 — Data Layer (DONE 2026-08-27):** `PortalInvoiceController`, `PortalComplianceController`, `TestPortalPageControllers`.
- ✅ **Phase 4 — Portal pages & LWCs (DONE 2026-08-27):** `portalInvoices`, `portalCompliance` built alongside existing `portalDashboard`, `portalWellStatus`, `portalHSEIncidentForm`; `marketDataHome` shipped 2026-08-15.
- 🔲 **Field Technician portal** with branded LWC (via `O_G_Field_Portal_Access`)
- 🔲 **Well & inspection mobile app**
- 🔲 **Partner portal for JV billing** (data layer done; Experience Builder page build-out remains)
- 🔲 **Phase 2 — LWR site skeleton** (`experienceBundle`; `Enable ExperienceBundle Metadata API` must be turned on first)
- 🔲 **Phase 5 — Automation:** royalty/invoice notifications, optional PDF + WhatsApp outbound
- 🔲 **Phase 1F** — test JV-partner user verification (blocked: no community users exist in org yet)

### Phase 5: Advanced Analytics (Pending)
- 🔲 Custom report types combining Well + Production + Compliance
- 🔲 Pipeline integrity heat map dashboard
- 🔲 HSE incident trend analysis

### Phase 6: Data Cloud (Pending)
- 🔲 SCADA real-time streaming
- 🔲 Well production historical data lake
- 🔲 Unified customer 360 for retail/commercial

### Known Issues / Known Gaps (from `PROJECT_AUDIT_REPORT.md`, 2026-08-06)

These are outstanding issues identified by the audit and not yet resolved in source:

| # | Priority | Issue |
|---|----------|-------|
| 1 | **High** | **3 scheduled flows are broken** — `Inspection_Due`, `Production_Reconciliation`, `Retail_Inventory_Alert` reference `$Record`, invalid in scheduled-trigger flows. |
| 2 | **High** | **`Is_Declining__c` field type conflict** — source declares Picklist, org has Checkbox; seeder scripts seed `'Yes'/'No'` strings. |
| 3 | **High** | **Hardcoded EIA API key** committed in `scripts/apex/eia_test.apex` — must move to a secret store. |
| 4 | Medium | Slack webhook config duplicated (`Slack_HSE_Webhook` NC vs `GTM_Config__c.Slack_Webhook_URL__c`). |
| 5 | Medium | `PetrelWellSync` inserts wells without API-number dedupe (dup risk). |
| 6 | Medium | Portal dashboard "upcoming deadlines" count includes expired permits while list filters them. |
| 7 | — | **Doc drift** — several docs (README, DATA_MODEL, WHATSAPP plan, PROJECT_DESCRIPTION) have stale counts/status vs source. |
| 8 | Low | Both batch classes use `without sharing`. |
| 9 | Low | Repo hygiene: `$null` artifact, retrieve/temp folders, CSV failure logs, `.env` with only variable names. |
| 10 | Low | Stray root-level retrieval artifacts (`org_custom_objects.json`, `field_permissions_*`, etc.) should move under `temp/`. |

---

## 13. Agentforce & Headless Operations

### 13.1 O&G Operations Assistant Agent

The org ships a built, activated, and source-captured Agentforce copilot: **`O_G_Operations_Assistant`** ("O&G Operations Assistant"). It is a hands-on field-ops copilot for HSE, compliance, production, permits-to-work, and terminal inventory. It answers from live CRM data, follows least-privilege, and only writes when the user explicitly confirms.

| Property | Value |
|----------|-------|
| **Bot** | `O_G_Operations_Assistant` (metadata file `force-app/main/default/bots/O_G_Operations_Assistant/O_G_Operations_Assistant.bot-meta.xml`) |
| **Version** | `v1` (`v1.botVersion-meta.xml`) |
| **Type** | `EinsteinServiceAgent` / `ExternalCopilot` |
| **Agent type / source** | Einstein Service Agent, `botSource= None` |
| **Bot user** | `o_g_operations_assistant@00dgk00000pvj811115807102.ext` |
| **Primary language** | `en_US`, casual tone, rich content enabled, PowerShell-style wait/error/transfer dialogs |
| **Surface** | End-user messaging (Embedded Messaging, WhatsApp, Facebook, Line, Email, Apple Business Chat, Text, Custom) — channel context variables `ContactId`, `EndUserId`, `EndUserLanguage`, `RoutableId` |
| **Status** | **Built, activated & source-captured** (per `HEADLESS_360_ARCHITECTURE.md` v1.0, 2026-08-26) — verified against 78/78 tests |
| **Test definition** | `aiEvaluationDefinitions/O_G_Operations_Assistant_Test_M1.aiEvaluationDefinition-meta.xml` (10 test cases) |

### 13.2 Topics (Agentforce topics)

The agent is domain-routed via the `agent_router` topic through a set of sub-topic planners (all metadata in `force-app/main/default/genAiPlugins/`):

| Topic (plugin) | Domain | Description |
|----------------|--------|-------------|
| `agent_router` | Router | Welcome + route to the appropriate O&G domain subagent by intent |
| `hse_advisor` | HSE | HSE incidents, severity classification, regulatory reportability, escalation |
| `compliance_analyst` | Compliance | Permit renewals, expirations, compliance deadlines, overdue filings, non-compliance |
| `production` | Production | Well production history, well status, abandonment-due wells, allocations, WI/royalty queries |
| `ops` | Operations | Permits-to-work, inspections, pipeline integrity, terminal tank inventory, inventory movements, low-stock alerts |
| `escalation` | Escalation | Transfer conversation to a live human agent |
| `off_topic` | Guardrail | Redirect off-topic requests back to O&G operations topics |
| `ambiguous_question` | Guardrail | Ask a clarifying question rather than guessing |

Domain actions are bound through additional topics: `O_G_HSE_Actions`, `O_G_Compliance_Actions`, `O_G_Production_Actions`, `O_G_Ops_Actions`.

### 13.3 Core Agent Instructions & Guardrails

The shared instruction block (inlined into every topic description) enforces these platform-wide rules:

- **NO FABRICATION** — every figure must come from a query/tool result; otherwise state "I don't have that data".
- **Grounding objects** — live reads from `HSE_Incident__c`, `HSE_Observation__c`, `Regulatory_Permit__c`, `Compliance_Report__c`, `Well__c`, `Well_Operation__c`, `Production_Allocation__c`, `Permit_to_Work__c`, `Inspection__c`, `Asset`, `Pipeline__c`, `Fuel_Inventory__c`, `Measurement__c`, `Terminal__c`, `Refinery__c`, `Retail_Outlet__c`, `Lease__c`, `Joint_Venture__c`, `Invoice__c`, `Product2`, `Account`, `Contact`, `WorkOrder`.
- **HSE severity matrix** — Critical (fatality/life-threatening), High (major impact / >1000 bbl / LTI), Medium (MTI / >100 bbl), Low (default).
- **Regulatory reportability** — reportable when ANY of: fatality, Critical/High severity, spill ≥50 bbl, LTI, life-threatening.
- **Compliance thresholds** — permit expiring within 45 days → renewal warning; expired/suspended → NON-COMPLIANT immediately.
- **Pipeline integrity** — missed inspection interval → NON-COMPLIANT + immediate inspection scheduling.
- **Inventory rules** — movements change balance by exactly the recorded volume; reject zero/negative volumes.
- **Safety guardrails (never override)** — PTW isolation/gas-test/authorization chain always validated; critical incidents always escalate to `Executive_Leadership` + notify `HSE_Compliance_Team`; never initiate external EPA/CDX filings without explicit confirmation; least-privilege on `O_G_*` permission sets; **write-confirmation gate** before any create/update.
- **Output format** — lead with verdict (OK / NOT-OK / ACTION NEEDED), 3–6 bullets, 1–2 next steps, plain technician-friendly language.

### 13.4 Agent-Callable Apex Actions (`@InvocableMethod`)

Headless wrappers power the agent's domain actions. Each exposes an `@InvocableMethod` + `@InvocableVariable` request/response shape for Agentforce/Flow/MCP consumption:

| Class | Agent action | Type | Notes |
|-------|--------------|------|-------|
| `HSEIncidentService` | Classify Incident Severity (`classifySeverities`) | Read/Write | Severity + regulatory reportability |
| `ComplianceDueDateService` | Get Compliance Overview (`getUpcomingRenewals`/`getOverdueReports`) | Read | Days-ahead window (default 45) |
| `PipelineIntegrityStatusWrapper` | Get Pipeline Integrity Status | Read | Compliance + next-inspection-due |
| `PermitToWorkValidationService` | Update Permit Status (`updatePermitStatus`) | Write | Validates isolation/gas/authorization before update |
| `InventoryBalanceService` | Record Inventory Movement (`recordInventoryMovement`) | Write | Volume-change semantics |
| `ProductionHistoryWrapper` | Get Production History | Read | Default 12-month look-back |
| `RoyaltyCalculationWrapper` | Calculate Royalty | Read | Lease royalty/revenue shares |
| `WellStatusService` | Transition Well Status (`transitionWellStatus`) | Write | Validated under `WellStatusService.isValidTransition` |

> **Note:** `docs/headless_audit.md` (Phase 0, 2026-09-01) predates several of these wrappers — it reported only 2 `@InvocableMethod` surfaces (`SlackAlertService`, `RegulatoryFilingService`). The wrapper classes above (7 agent-facing + `RegulatoryFilingService`) were added afterwards. See §13.6 for the still-open `classAccess` gap.

### 13.5 Agent Test Automation (AI Evaluation)

`O_G_Operations_Assistant_Test_M1.aiEvaluationDefinition-meta.xml` defines 10 automated AI-evaluation test cases (utterance → expected topic + response rating). It is the source of the "78/78 tests" figure quoted in `HEADLESS_360_ARCHITECTURE.md`:

| # | Utterance | Expected domain/topic | Response expectation |
|---|-----------|----------------------|----------------------|
| 1 | 75 bbl spill, no injuries — reportable? | `hse_advisor` | Reportable, escalate + notify |
| 2 | Fatality — classification? | `hse_advisor` | CRITICAL, reportable, immediate escalation |
| 3 | Permits expiring in 45 days? | `compliance_analyst` | Renewal warning for each |
| 4 | Permit already expired? | `compliance_analyst` | NON-COMPLIANT immediately |
| 5 | Production history (12 months)? | `production` | Summarize from live data |
| 6 | Pipeline compliant / next inspection? | `ops` | Integrity + inspection due |
| 7 | Set well A-1001 to Shut-In | `production` | State transition, wait for confirmation (no write) |
| 8 | "Write me a poem" | `off_topic` | Redirect to O&G topics |
| 9 | "Tell me about wells" | `ambiguous_question` | Ask a clarifying question |
| 10 | Production for well X-9999 (Jan 2001) | `production` | Say no data rather than invent |

### 13.6 Known Gaps & Next Steps (Agent / Headless)

| # | Priority | Gap | Remediation |
|---|----------|-----|-------------|
| 1 | **High** | **Zero `classAccess` on all 14 `O_G_*` permission sets** (per `docs/headless_audit.md`) — role-based users/agents cannot yet execute the Apex service methods. | Grant `classAccess` to each service class on the matching `O_G_*` permission set (e.g. `O_G_HSE_Advisor` → `HSEIncidentService`, `O_G_Production_Engineer` → `WellStatusService`/`ProductionHistoryWrapper`, `O_G_Terminal_Operator` → `InventoryBalanceService`). |
| 2 | Medium | No `@AuraEnabled(cacheable=true)` on several candidate read methods yet (see audit §5 tool matrix). | Add cacheable `@AuraEnabled` where a read should be agent/LWC-callable. |
| 3 | Medium | No event-driven agent trigger path (no production `EventBus.publish`). | Add platform-event → agent/flow trigger for critical HSE/alerts. |
| 4 | Low | MCP binding (Phase 2) not implemented. | See `PHASE_2_MCP_BINDING.md` — map named-query/tool → permission-set matrix. |

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
| Oil & Gas Architecture | `OIL_AND_GAS_ARCHITECTURE.md` (deleted from repo) |
| API Integrations | `API_INTEGRATIONS.md` |
| Project Description | `PROJECT_DESCRIPTION.md` |
| Deployment Summary | `DEPLOY_SUMMARY.md` (deleted from repo) |
| Manual Fixes | `MANUAL_FIXES.md` (deleted from repo) |
| Agent Notes | `AGENTS.md` |
| Experience Cloud Portal | `EXPERIENCE_CLOUD_PORTAL_ARCHITECTURE.md` |
| SCADA/PI Go-Live | `SCADA_PI_INTEGRATION.md` (+ `bridge/sender.ps1`, `bridge/bridge_poc.py`, `bridge/scada_bridge.env.example`) |
| WhatsApp Plan | `WHATSAPP_INTEGRATION_PLAN.md` (implementation complete; header note stale) |
| Audit Report | `PROJECT_AUDIT_REPORT.md` |
| Headless/Agent/MCP Audit | `docs/headless_audit.md` |
| Headless 360 Architecture | `HEADLESS_360_ARCHITECTURE.md` |
| Agent MCP Binding (Phase 2) | `PHASE_2_MCP_BINDING.md` |
| O&G Operations Assistant (agent) | `force-app/main/default/bots/O_G_Operations_Assistant/` |
| Agent AI-eval tests | `force-app/main/default/aiEvaluationDefinitions/O_G_Operations_Assistant_Test_M1.aiEvaluationDefinition-meta.xml` |
| Agent topics/actions | `force-app/main/default/genAiPlugins/` |
| Data Seeder (master) | `force-app/main/default/scripts/seed_all_powershot.apex` |
| Well Record Page | `force-app/main/default/flexipages/Well_Record_Page.flexipage-meta.xml` |

### B. Object Count Summary

| Category | Count |
|----------|-------|
| Custom Objects | 30 |
| Standard Objects Extended | 6 |
| Custom Fields | ~340 |
| Record Types | 28 |
| Apex Classes | 56 |
| Apex Triggers | 9 |
| Flows | 11 |
| Permission Sets | 20 |
| LWC Components | 15 |
| Agentforce Topics (`genAiPlugins`) | 12 |
| Agent (Einstein Service Agent) | 1 (`O_G_Operations_Assistant`, v1) |
| Agent AI-eval test cases | 10 (`O_G_Operations_Assistant_Test_M1`) |
| Custom Tabs | 25+ |
| Page Layouts | 25 |
| Compact Layouts | 4+ |
| FlexiPages | 8+ |
| Named Credentials | 8 |
| External Credentials | 6 |
| CSP Trusted Sites | 3 |
| Remote Site Settings | 5 |
| Auth Providers | 5 |
| Public Groups | 2 |
| Validation Rules | 10 |

> **Note:** These counts reflect the on-disk force-app source (including new WhatsApp/portal/SCADA assets). They are **best-effort estimates**; the audit (`PROJECT_AUDIT_REPORT.md`) notes that older docs (24–28 objects, 40 classes) are stale. Reconcile against a fresh `sf project retrieve` before production reporting.

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
| API Number required for Producing/Drilling wells | WellTrigger (validation rule) | Well__c |
| Depth fields required post-spudding | WellTrigger (validation rule) | Well__c |
| Scope of Work ≥10 characters | Validation rule | Permit_to_Work__c |
| Valid date range enforced | Validation rule | Permit_to_Work__c |
| Gas test result required when completed | Validation rule | Permit_to_Work__c |
| Pipeline operating pressure limits (0–15,000 psi) | Validation rule | Pipeline__c |
| Diameter & capacity required for Active pipelines | Validation rule | Pipeline__c |
| Incident date required | Validation rule | HSE_Incident__c |
| Corrective action required to close incidents | Validation rule | HSE_Incident__c |
| Spill volume required for spill incidents | Validation rule | HSE_Incident__c |
| SCADA ingest fail-closed (401 unless enabled + valid HMAC) | SCADAIngestionAPI + SCADA_Config__c | Measurement__c |
| SCADA telemetry rollup (Well-linked Oil/Gas/Water Flow → monthly allocation) | WellProductionTelemetryRollupBatch | Production_Allocation__c |
| Invoice/Allocation Account derivation for portal sharing | InvoiceAccountTrigger + ProductionAllocationTrigger | Invoice__c / Production_Allocation__c |
| WhatsApp webhook signature verification + idempotency | WhatsAppWebhookHandler + WhatsAppMessageService | WhatsApp_Message__c |
