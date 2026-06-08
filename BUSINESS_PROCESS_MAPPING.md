# Oil & Gas Salesforce Solution — Business Process Mapping

> **Project:** Energy_Salesforce_project  
> **API Version:** 66.0 (Spring '25)  
> **Date:** June 2026  
> **Author:** Salesforce Business Analyst

---

## Table of Contents

1. [Solution Overview](#1-solution-overview)
2. [Data Model & Relationship Map](#2-data-model--relationship-map)
3. [Business Domain: Upstream — Well Lifecycle & Production](#3-upstream)
4. [Business Domain: Midstream — Pipeline & Transportation](#4-midstream)
5. [Business Domain: Downstream — Refining, Terminal & Retail](#5-downstream)
6. [Business Domain: HSE — Health, Safety & Environment](#6-hse)
7. [Business Domain: Regulatory & Compliance](#7-regulatory--compliance)
8. [Business Domain: Commercial — Contracts, Supply & Invoicing](#8-commercial)
9. [Business Domain: Operations — Permit to Work, Inspections & Work Orders](#9-operations)
10. [Role-Based Access & Permission Mapping](#10-role-based-access)
11. [Automation Inventory](#11-automation-inventory)
12. [LWC Dashboard Mapping](#12-lwc-dashboard-mapping)
13. [End-to-End Process Flows](#13-end-to-end-process-flows)
14. [Gap Analysis & Recommendations](#14-gap-analysis)

---

## 1. Solution Overview

### Business Context

This Salesforce solution is built for an integrated Oil & Gas company covering the full value chain:

- **Upstream:** Exploration, land acquisition, drilling, well operations, and production
- **Midstream:** Pipeline transportation, measurement, and nomination scheduling
- **Downstream:** Refining, terminal storage, retail outlets, and fuel inventory management
- **Corporate:** HSE management, regulatory compliance, commercial contracts, joint ventures, and invoicing

### Solution Stats

| Category | Count |
|---|---|
| Custom Objects | 24 |
| Standard Objects Extended | 6 (Account, Contact, Opportunity, Asset, Case, WorkOrder) |
| Custom Fields | ~260 |
| Record Types | 24 (on Account, Asset, Contact, WorkOrder) |
| Flows | 11 |
| Apex Classes | 9 |
| Apex Triggers | 6 |
| Permission Sets | 13 |
| LWC Components | 7 |
| Custom Tabs | 23 |

---

## 2. Data Model & Relationship Map

### Core Entity Relationship Diagram

```
Account ────┐
  │          ├── Well__c (Operator)
  │          ├── Lease__c (Lessor/Lessee)
  │          ├── Joint_Venture__c (Partner/Operator)
  │          ├── Pipeline__c (Operator)
  │          ├── Refinery__c (Operator)
  │          ├── Terminal__c (Operator)
  │          ├── Retail_Outlet__c (Operator)
  │          ├── Service_Contract__c (Vendor/Customer)
  │          ├── Supply_Agreement__c (Supplier/Buyer)
  │          ├── Transportation_Nomination__c (Shipper)
  │          ├── Regulatory_Permit__c (Account)
  │          ├── HSE_Incident__c (Account)
  │          ├── Inspection__c (Account)
  │          └── Invoice__c (Supplier/Customer)
  │
Contact ────┐
  │          ├── HSE_Incident__c (Reported_By)
  │          ├── Compliance_Report__c (Assigned_To/Submitted_By)
  │          ├── Permit_to_Work__c (Holder/Issuer)
  │          └── Retail_Outlet__c (Contact)
  │
Lease__c ───┐
  │          ├── Well__c
  │          ├── Land_Parcel__c
  │          └── Production_Allocation__c
  │
Well__c ────┐
  │          ├── Well_Operation__c [MD]
  │          ├── Production_Allocation__c
  │          ├── HSE_Incident__c
  │          ├── Inspection__c
  │          ├── Measurement__c
  │          ├── Regulatory_Permit__c
  │          ├── Permit_to_Work__c
  │          └── Case
  │
Pipeline__c ┐
  │          ├── Pipeline_Station__c
  │          ├── Measurement__c
  │          ├── Transportation_Nomination__c
  │          ├── Inspection__c
  │          ├── Permit_to_Work__c
  │          ├── HSE_Incident__c
  │          └── Case
  │
Asset ──────┐
  │          ├── Inspection__c
  │          ├── Measurement__c
  │          └── WorkOrder
  │
Permit_to_Work__c ── WorkOrder
Regulatory_Permit__c ── Compliance_Report__c
Joint_Venture__c ── Production_Allocation__c
Fuel_Inventory__c ── Inventory_Transaction__c
```

### Master-Detail Relationship

| Child | Parent | Detail |
|---|---|---|
| Well_Operation__c | Well__c | Only MD in the model |

### Key Lookup Chains

| Chain | Business Meaning |
|---|---|
| Account → Lease → Well → Well_Operation | Operator → Lease → Well → Operations history |
| Account → Pipeline → Pipeline_Station | Operator → Pipeline → Station assets |
| Account → Refinery / Terminal / Retail_Outlet | Operator → Facility hierarchy |
| Well → Production_Allocation → Lease → Joint_Venture | Production → Revenue allocation → Partner distribution |
| Regulatory_Permit → Compliance_Report | Permit → periodic compliance documentation |
| Fuel_Inventory → Inventory_Transaction | Tank → movement/reconciliation audit trail |

---

## 3. Business Domain: Upstream — Well Lifecycle & Production <a id="3-upstream"></a>

### 3.1 Domain Objects

| Object | Role | Key Fields |
|---|---|---|
| Land_Parcel__c | Mineral/ Surface rights tracking | County, State, Acreage, Mineral_Rights_Owner |
| Lease__c | Lease contract management | Account__c (Lessor), Land_Parcel__c, Royalty_Percent, Status, Lease_End_Date |
| Well__c | Well master record | API_Number, Lease__c, Account__c (Operator), Status, Well_Type, Total_Depth |
| Well_Operation__c | Well event/activity log (MD to Well) | Well__c, Operation_Type, Status, Start_Date, End_Date |
| Production_Allocation__c | Monthly production & revenue split | Well__c, Lease__c, Oil_Volume_bbls, Gas_Volume_MCF, Working_Interest, Revenue_Interest |
| Joint_Venture__c | Partnership agreements | Account__c, Operator__c, Working_Interest_Pct, Revenue_Interest_Pct |

### 3.2 Well Lifecycle Process

```
┌─────────────────────────────────────────────────────────────────┐
│                    WELL LIFECYCLE                                │
└─────────────────────────────────────────────────────────────────┘

  Permitted ──→ Drilling ──→ Producing ──→ Shut-In ──→ Suspended
      │            │            │  │           │            │
      │            │            │  └───────────┘            │
      │            │            │                           │
      └── Cancelled ┘            └────── Plugged ────→ Abandoned

Valid Transitions (WellStatusService.VALID_TRANSITIONS):
  Permitted   → Drilling, Cancelled
  Drilling    → Producing, Suspended, Plugged, Abandoned
  Producing   → Shut-In, Suspended, Plugged, Abandoned
  Shut-In     → Producing, Suspended, Plugged, Abandoned
  Suspended   → Producing, Shut-In, Plugged, Abandoned
  Plugged     → Abandoned
  Abandoned   → (terminal state)
```

### 3.3 Automation Triggers

**WellTrigger** (before insert/update, after insert/update):
- **Before Insert:** Sets default Status = 'Permitted', sets Status_Change_Date = today
- **Before Update:** Validates status transitions via `WellStatusService.isValidTransition()`, updates Status_Change_Date
- **After Insert:** Creates Well_Operation__c if status != 'Permitted'
- **After Update:** Creates Well_Operation__c on status change

~~**Well_Lifecycle Flow** (Record-Triggered, Update on Well__c):~~ *(Deleted — Apex WellTrigger handles this with correct dynamic values; flow had hardcoded wrong values and would cause duplicates)*

### 3.4 Production Allocation Process

```
Monthly cycle:
  1. Production data entered → Production_Allocation__c record created
  2. Trigger validates Working_Interest ≤ 100% per well
  3. Production_Reconciliation flow runs daily:
     - Checks for zero oil AND zero gas volumes
     - Creates Compliance_Report__c with type "Production Discrepancy"
  4. Royalty calculation (Apex):
     - RoyaltyCalculationService.calculateRoyaltyPayment()
     - Generates Task per partner with calculated payment
```

### 3.5 Land & Leasing Process

```
Landman identifies parcel → Land_Parcel__c created
  ↓
Lease negotiated → Lease__c record with Royalty%, Term, Status
  ↓
Wells permitted on leased land → Well__c linked via Lease__c lookup
  ↓
Land_Lease_Expiration flow runs daily:
  - Finds Lease__c expiring within 90 days
  - Creates "Lease Expiring Soon" Task for each
  ↓
Production allocated → Production_Allocation__c linked to Lease__c
  ↓
Royalty calculated → RoyaltyCalculationService
  → Tasks created for JV partners with payment amounts
```

### 3.6 Joint Venture Billing Process

```
Joint_Venture_Billing flow (Scheduled, Daily on 1st of month):
  1. Checks if current date is 1st day of month
  2. Queries Joint_Venture__c records with Status = 'Active'
  3. For each active JV, creates Invoice__c record:
     - JV__c = Joint_Venture, Status = 'Pending', Amount = 0
```

---

## 4. Business Domain: Midstream — Pipeline & Transportation <a id="4-midstream"></a>

### 4.1 Domain Objects

| Object | Role | Key Fields |
|---|---|---|
| Pipeline__c | Pipeline master | Commodity, Diameter, MAOP, Operating_Pressure, Compliance_Status |
| Pipeline_Station__c | Station along pipeline | Pipeline__c, Station_Type, Capacity, Horsepower |
| Measurement__c | Flow/Pressure/Temp readings | Pipeline__c, Pipeline_Station__c, Reading_DateTime, Net_Volume |
| Transportation_Nomination__c | Scheduled transport volume | Pipeline__c, Shipper, Requested_Volume, Confirmed_Volume, Status |

### 4.2 Pipeline Integrity Process

```
PipelineIntegrityService:
  ┌─ getOverdueInspections() → finds inspections past due
  └─ flagNonCompliantPipelines() → updates Pipeline__c.Compliance_Status
       ┌─ If inspection up to date → "Compliant"
       └─ If inspection overdue   → "Non-Compliant"

Pipeline Inspection Schedule (AssetTrigger pattern):
  Last_Inspection_Date + Required_Inspection_Interval_Months = Next due
```

### 4.3 Measurement Process

```
Field devices report readings → Measurement__c records
  ↓
Pipeline_Station__c or Pipeline__c linked as parent
  ↓
Types: Pressure, Temperature, Flow, Level, Volume
  ↓
Data used for: Pipeline integrity, Production reconciliation, Nominations
```

### 4.4 Transportation Nomination Process

```
Shipper requests capacity → Transportation_Nomination__c
  Status flow: Draft → Submitted → Confirmed → Scheduled → Completed
  ↓
Linked to Pipeline__c and Account (Shipper)
  ↓
Confirmed volumes tracked for scheduling
```

---

## 5. Business Domain: Downstream — Refining, Terminal & Retail <a id="5-downstream"></a>

### 5.1 Domain Objects

| Object | Role | Key Fields |
|---|---|---|
| Refinery__c | Refinery facility | Account__c (Operator), Capacity_bpd, Nelson_Complexity_Index |
| Terminal__c | Storage/export terminal | Account__c (Operator), Storage_Capacity_bbls, Tank_Count |
| Retail_Outlet__c | Gas station / store | Account__c (Operator), Brand, Store_Type, Fuel_Volume_Monthly |
| Fuel_Inventory__c | Tank-level inventory | Terminal__c / Retail_Outlet__c, Product__c, Current_Volume, Min_Threshold, Tank_Capacity |
| Inventory_Transaction__c | Movement audit trail | Fuel_Inventory__c, Movement_Type, Volume_Change, Volume_Before, Volume_After |

### 5.2 Inventory Management Process

```
Inventory movement flow:

  Receipt / Delivery / Transfer-In / Transfer-Out / Consumption
       ↓
  InventoryBalanceService.recordInventoryMovement()
       ↓
  1. Updates Fuel_Inventory__c.Current_Volume
  2. Creates Inventory_Transaction__c audit record
       ↓
  InventoryBalanceService.reconcileInventory()
  - Physical count vs system volume
  - Creates reconciliation transaction
  - Flags discrepancy if >5% of system volume
       ↓
  Retail_Inventory_Alert flow (Scheduled Daily):
  - Queries Fuel_Inventory__c where Current_Volume < Minimum_Threshold
  - Creates "Restock tank below minimum threshold" Task
```

### 5.3 Supply Agreement Process

```
Supply_Agreement__c manages:
  - Product being supplied (Crude/Gas/NGL/Refined)
  - Pricing Index and Price_Basis
  - Volume and Credit_Terms
  - Linked to Supplier (Account) and Buyer (Account)
  - Duration via Term_Start / Term_End
```

### 5.4 Retail Operations

```
Retail_Outlet__c:
  - Operator (Account), Brand, Store_Type
  - Fuel_Tank_Count, Fuel_Volume_Monthly
  - Links to Contact (manager)

Fuel_Inventory__c at retail:
  - Tracks individual tanks by Tank_Number
  - Product_Type, Current vs Min_Threshold, Max_Capacity
  - Low stock alerts via flow
```

---

## 6. Business Domain: HSE — Health, Safety & Environment <a id="6-hse"></a>

### 6.1 Domain Objects

| Object | Role | Key Fields |
|---|---|---|
| HSE_Incident__c | Incident record | Incident_Type, Severity, Fatality_Occurred, Spill_Volume, Regulatory_Reportable |
| HSE_Observation__c | Safety observation | Observation_Type, Location, Risk_Rating, Corrective_Action |
| Permit_to_Work__c | Work authorization | Permit_Type, Risk_Level, Gas_Test, Isolation, Authorization chain |

### 6.2 Incident Management & Escalation Process

```
Incident Reported → HSE_Incident__c created
  ↓
HSEIncidentTrigger (after insert/update):
  ↓
HSEIncidentService.classifySeverity():
  ┌─ Fatality detected                    → Severity = Critical
  ├─ Life-Threatening/Permanent Disability → Severity = Critical
  ├─ Major env impact / Spill >1000bbl    → Severity = High
  ├─ Lost Time / Moderate env impact       → Severity = High
  ├─ Medical Treatment / Spill >100bbl    → Severity = Medium
  └─ Otherwise                            → Severity = Low
  ↓
HSEIncidentTrigger continues:
  ├─ If Regulatory_Reportable → notifyComplianceTeam() (email to HSE_Compliance_Team group)
  └─ If Severity = Critical   → escalateIfCritical() (email to Executive_Leadership group + Task)
  ↓
HSE_Incident_Escalation Flow (Record-Triggered):
  Filters for OR(Regulatory_Reportable = true, Severity = "Critical")
  ┌─ If Critical + Fatality    → "CRITICAL INCIDENT with fatality" Task
  ├─ If Regulatory Reportable  → "File regulatory report for incident" Task
  └─ Low/Medium Severity       → "Incident recorded" Task
```

### 6.3 HSE Observation Process

```
Observer reports → HSE_Observation__c
  Status flow: Open → Acknowledged → Closed
  Types: Safety, Environmental, Security, Behavioral
  Risk_Rating assigned by HSE Advisor
  Corrective_Action tracked to closure
```

### 6.4 Permit to Work Process

```
Permit Requested → Permit_to_Work__c created (Status = Requested)
  ↓
Permit_to_Work_Approval Flow (Record-Triggered):
  Creates "Review Permit to Work" Task on creation
  ↓
PermitToWorkValidationService:
  1. validateIsolationRequirements()
     - If Isolation_Required = true, checks Isolation_Verified
     - For Electrical/Mechanical: checks Lockout_Tagout + Zero_Energy_State
  2. validateGasTestResults()
     - O₂: 19.5-23.5%, LEL: <10%, H₂S: <10ppm, CO: <25ppm
  3. validateAuthorizationChain()
     - Risk Level determines # required approvers: Low=1, Med=2, High=2, Critical=3
     - Confined Space Entry / Hot Work / Electrical / Excavation → min 2 approvers
  ↓
Field_Service_Dispatch Flow (Record-Triggered on WorkOrder):
  - If WorkOrder references a Permit_to_Work__c, verifies it's "Issued"
  - If PTW not valid → creates "Valid PTW required before dispatch" Task
  - If PTW valid or not needed → creates "Dispatch crew for Work Order" Task
```

---

## 7. Business Domain: Regulatory & Compliance <a id="7-regulatory--compliance"></a>

### 7.1 Domain Objects

| Object | Role | Key Fields |
|---|---|---|
| Regulatory_Permit__c | Agency permit tracking | Permit_Type, Agency, Issue_Date, Expiration_Date, Compliance_Status, Renewal_Reminder |
| Compliance_Report__c | Regulatory reporting | Report_Type, Due_Date, Status, Regulatory_Body, Regulatory_Permit__c |

### 7.2 Permit Lifecycle Process

```
Permit issued by agency → Regulatory_Permit__c created
  Status: Active / Approved / Expired / Suspended / Revoked / Pending
  ↓
RegulatoryPermitTrigger (after insert/update):
  - On expiration approaching:
    ┌─ Expired (past due)                         → Compliance_Status = "Expired"
    ├─ Within 30 days                             → "Critical - Expiring Soon"
    └─ Within 31-90 days                          → "Approaching Expiration"
  - On Status change:
    ┌─ Active / Approved                          → Compliance_Status = "Compliant"
    ├─ Expired                                    → Compliance_Status = "Expired"
    └─ Suspended / Revoked                        → "Non-Compliant"
  ↓
Regulatory_Permit_Compliance Flow (Record-Triggered):
  - Checks if Expiration_Date within 90 days
  - Creates Compliance_Report__c (Report_Type = "Regulatory Compliance", Status = "Pending")
  - Links report to the permit
  ↓
Compliance_Calendar Flow (Scheduled Daily):
  - Queries Regulatory_Permit__c where Renewal_Reminder_Sent = false
  - Sets Renewal_Reminder_Sent__c = true
  ↓
ComplianceDueDateService:
  - getUpcomingRenewals(60 days) → sends email reminders to Responsible_Party
  - getOverdueReports() → finds past-due Compliance_Report__c records
  - sendRenewalReminders() → sends emails for both permit renewals AND overdue reports
```

### 7.3 Compliance Reporting Process

```
Compliance_Report__c types:
  - Regulatory Compliance (auto-created by flow)
  - Production Discrepancy (auto-created by Production_Reconciliation flow)
  - Environmental / Safety / Production / Financial (manual)

Compliance_Report__c lifecycle:
  Status: Pending → Submitted (or remains Pending if overdue)
  Days_Overdue__c tracks delinquency
```

---

## 8. Business Domain: Commercial — Contracts, Supply & Invoicing <a id="8-commercial"></a>

### 8.1 Domain Objects

| Object | Role | Key Fields |
|---|---|---|
| Service_Contract__c | Vendor/service agreements | Contract_Type, Account__c (Vendor/Customer), Start_Date, End_Date, Value |
| Supply_Agreement__c | Product supply terms | Agreement_Type, Commodity, Price_Basis, Volume, Term |
| Invoice__c | Billing records | JV__c, Amount, Invoice_Date, Status |
| Opportunity | Sales pipeline (standard) | Commodity_Type, Contract_Value, Start_Date, Volume_MMBTU |
| Account | Standard with O&G fields | DUNS__c, EIN__c, HSE_Rating, Supplier_Tier |
| Contact | Standard with O&G fields | Job_Title_Oil_Gas, Safety_Certifications, TWIC_Expiration |

### 8.2 Service Contract Process

```
Service_Contract__c lifecycle:
  Types: Drilling, Completion, Production, Transportation, Maintenance
  Status: Draft → Active → Expired / Terminated
  Linked to: Vendor (Account), Customer (Account)
  Insurance Requirements, PO_Reference tracked
```

### 8.3 Supply Agreement Process

```
Supply_Agreement__c lifecycle:
  Types: various by commodity
  Pricing: Index-based with Price_Basis
  Volume terms: Min/Max per day
  Delivery_Point and Credit_Terms specified
```

### 8.4 Sales Opportunities

```
Opportunity extended for O&G:
  Commodity_Type: Crude, Gas, NGL, Refined
  Volume_MMBTU__c and Contract_Value__c tracked
  Start_Date__c for delivery commencement
```

---

## 9. Business Domain: Operations — Inspections & Work Orders <a id="9-operations"></a>

### 9.1 Domain Objects

| Object | Role | Key Fields |
|---|---|---|
| Inspection__c | Inspection records | Inspection_Type, Asset__c, Pipeline__c, Well__c, Status, Result, Is_Recurring |
| Asset | Standard with O&G fields | Installation_Date, Last_Inspection_Date, Expected_Lifespan, Inspection_Frequency_Days, Criticality_Rating |
| WorkOrder | Standard with O&G fields | Permit_to_Work__c, Isolation_Required, Lockout_Tagout, Pipeline_Station__c |

### 9.2 Inspection Lifecycle Process

```
Inspection scheduled → Inspection__c created (Status = Scheduled)
  ↓
AssetTrigger (on Asset before insert/update):
  - Calculates Next_Inspection_Date from Last_Inspection_Date + Frequency
  - Sets Maintenance_Schedule: Monthly/Quarterly/Semi-Annual/Annual/Custom
  - Flags assets Beyond Expected Life
  ↓
InspectionTrigger (after insert/update):
  On completion:
  - Updates Asset.Last_Inspection_Date (most recent date across inspections)
  - Updates Pipeline__c.Last_Inspection_Date
  - If Is_Recurring: creates next scheduled Inspection__c
  ↓  
Inspection_Due Flow (Scheduled Weekly):
  - Queries Inspection__c where Next_Due_Date <= today
  - Creates new Inspection__c (Status = Scheduled) from overdue templates
  ↓
InspectionService.submitChecklist():
  - Aura-enabled for LWC use
  - Updates inspection status + findings
```

### 9.3 Work Order & Field Service Process

```
WorkOrder created:
  Types: Corrective, Field_Service, Inspection_WO, Preventive_Maintenance
  ↓
Field_Service_Dispatch Flow (Record-Triggered):
  1. If Permit_to_Work__c referenced → verifies it's "Issued"
  2. Decision routing:
     ┌─ PTW is null (not needed) → Create Dispatch Task
     ├─ PTW is valid (Issued)    → Create Dispatch Task
     └─ PTW is invalid           → "Valid PTW required before dispatch" Task
```

---

## 10. Role-Based Access & Permission Mapping <a id="10-role-based-access"></a>

### 10.1 Permission Set to Business Role Mapping

| Permission Set | Business Role | Object Access | Access Level |
|---|---|---|---|
| **O_G_All_Access** | System Admin / Super User | All 26 custom + 6 standard objects | Full CRUD, Modify All, View All |
| **O_G_Executive** | C-Suite / VP Level | Well, Pipeline, Lease, Terminal, Refinery, HSE_Incident, Fuel_Inventory, Supply_Agreement, Accounts, Contacts, Assets, Opportunities, Cases, WorkOrders, Pipeline_Stations | Read Only |
| **O_G_Compliance_Analyst** | Regulatory Compliance | Regulatory_Permit__c, Compliance_Report__c (CRUD), HSE_Incident__c (Read) | CRUD on compliance, Read on incidents |
| **O_G_Drilling_Engineer** | Drilling Engineer | Well__c, Well_Operation__c (CRUD), Lease__c (Read) | Full on drilling objects |
| **O_G_Production_Engineer** | Production Engineer | Well__c, Production_Allocation__c (CRUD) | Full on production objects |
| **O_G_Field_Technician** | Field Technician | Inspection__c, Permit_to_Work__c (CRUD); Well__c, Pipeline__c, Account, Asset (Read) | Create/Edit inspections & PTWs |
| **O_G_HSE_Advisor** | HSE Advisor | HSE_Incident__c, HSE_Observation__c, Permit_to_Work__c (CRUD) | Full on HSE objects |
| **O_G_Pipeline_Engineer** | Pipeline Engineer | Pipeline__c, Pipeline_Station__c, Measurement__c, Inspection__c (CRUD) | Full on pipeline objects |
| **O_G_Landman** | Landman / Land Manager | Lease__c, Land_Parcel__c, Joint_Venture__c (CRUD); Well__c (Read) | Full on land objects |
| **O_G_Refinery_Manager** | Refinery Manager | Refinery__c, Supply_Agreement__c (CRUD); Pipeline__c, Terminal__c (Read) | Full on refinery, read on pipelines/terminals |
| **O_G_Retail_Manager** | Retail Manager | Retail_Outlet__c, Fuel_Inventory__c (CRUD) | Full on retail objects |
| **O_G_Supply_Chain** | Supply Chain / Procurement | Service_Contract__c (CRUD); Product2, Fuel_Inventory__c (Read) | Full on contracts, read on inventory |
| **O_G_Terminal_Operator** | Terminal Operator | Terminal__c, Fuel_Inventory__c, Measurement__c (CRUD) | Full on terminal objects |

### 10.2 Functional Role Coverage Matrix

```
Object                    All Access  Exec  CompAnalyst  DrillEng  ProdEng  FieldTech  HSE  PipelineEng  Landman  RefMgr  RetailMgr  SupplyChain  TermOp
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
Well__c                   CRUD        R     -            CRUD      CRUD     R          -    -            R        -       -          -            -
Well_Operation__c         CRUD        -     -            CRUD      -        -          -    -            -        -       -          -            -
Lease__c                  CRUD        R     -            R         -        -          -    -            CRUD     -       -          -            -
Land_Parcel__c            CRUD        -     -            -         -        -          -    -            CRUD     -       -          -            -
Joint_Venture__c          CRUD        -     -            -         -        -          -    -            CRUD     -       -          -            -
Production_Allocation__c  CRUD        -     -            -         CRUD     -          -    -            -        -       -          -            -
Pipeline__c               CRUD        R     -            -         -        R          -    CRUD         -        R       -          -            -
Pipeline_Station__c       CRUD        R     -            -         -        -          -    CRUD         -        -       -          -            -
Measurement__c            CRUD        -     -            -         -        -          -    CRUD         -        -       -          -            -
Transport_Nomination__c   CRUD        -     -            -         -        -          -    -            -        -       -          -            -
Refinery__c               CRUD        R     -            -         -        -          -    -            -        CRUD    -          -            -
Terminal__c               CRUD        R     -            -         -        -          -    -            -        R       -          -            CRUD
Retail_Outlet__c          CRUD        -     -            -         -        -          -    -            -        -       CRUD       -            -
Fuel_Inventory__c         CRUD        R     -            -         -        -          -    -            -        -       CRUD       R            CRUD
Inventory_Transaction__c  CRUD        -     -            -         -        -          -    -            -        -       -          -            -
Regulatory_Permit__c      CRUD        -     CRUD         -         -        -          -    -            -        -       -          -            -
Compliance_Report__c      CRUD        -     CRUD         -         -        -          -    -            -        -       -          -            -
HSE_Incident__c           CRUD        R     R            -         -        -          CRUD  -            -        -       -          -            -
HSE_Observation__c        CRUD        -     -            -         -        -          CRUD  -            -        -       -          -            -
Permit_to_Work__c         CRUD        -     -            -         -        CRUD       CRUD  -            -        -       -          -            -
Inspection__c             CRUD        -     -            -         -        CRUD       -     CRUD         -        -       -          -            -
Service_Contract__c       CRUD        -     -            -         -        -          -    -            -        -       -          CRUD         -
Supply_Agreement__c       CRUD        R     -            -         -        -          -    -            -        CRUD    -          -            -
Invoice__c                -           -     -            -         -        -          -    -            -        -       -          -            -
Account (standard)        CRUD        R     -            -         -        R          -    -            -        -       -          -            -
Contact (standard)        CRUD        R     -            -         -        -          -    -            -        -       -          -            -
Asset (standard)          CRUD        R     -            -         -        R          -    -            -        -       -          -            -
Opportunity (standard)    CRUD        R     -            -         -        -          -    -            -        -       -          -            -
Case (standard)           CRUD        R     -            -         -        -          -    -            -        -       -          -            -
WorkOrder (standard)      CRUD        R     -            -         -        -          -    -            -        -       -          -            -
```

> **Note:** Invoice__c is the only object with zero permission set coverage. It has no tab and appears in no permission set.

---

## 11. Automation Inventory <a id="11-automation-inventory"></a>

### 11.1 Flows

| Flow | Trigger | Object | Schedule / Event | Business Action |
|---|---|---|---|---|
| **Compliance_Calendar** | Scheduled (Daily) | Regulatory_Permit__c | 06:00 daily | Sets Renewal_Reminder_Sent__c = true |
| **Field_Service_Dispatch** | Record-Triggered (Create) | WorkOrder | On creation | Verifies PTW, creates dispatch/PTW tasks |
| **HSE_Incident_Escalation** | Record-Triggered (CreateAndUpdate) | HSE_Incident__c | On relevant changes | Routes by severity, creates escalation tasks |
| **Inspection_Due** | Scheduled (Weekly) | Inspection__c | Weekly 07:00 | Creates new Inspection__c from overdue recurring |
| **Joint_Venture_Billing** | Scheduled (Daily) | Joint_Venture__c | Daily 02:00 | Creates Invoice__c on 1st of month for active JVs |
| **Land_Lease_Expiration** | Scheduled (Daily) | Lease__c | Daily 02:00 | Creates Tasks for leases expiring in 90 days |
| **Permit_to_Work_Approval** | Record-Triggered (Create) | Permit_to_Work__c | On creation | Creates review Task |
| **Production_Reconciliation** | Scheduled (Daily) | Production_Allocation__c | Daily 02:00 | Flags zero production → Compliance_Report__c |
| **Regulatory_Permit_Compliance** | Record-Triggered (CreateAndUpdate) | Regulatory_Permit__c | On creation/update | Creates Compliance_Report__c for near-expiry permits |
| **Retail_Inventory_Alert** | Scheduled (Daily) | Fuel_Inventory__c | Daily 05:00 | Creates restock Tasks when below threshold |
| ~~Well_Lifecycle~~ *(Deleted)* | Record-Triggered (Update) | Well__c | On status change | ~~Creates Well_Operation__c record~~ *(Apex WellTrigger handles this)* |

### 11.2 Apex Triggers

| Trigger | Object | Timing | Logic |
|---|---|---|---|
| **AssetTrigger** | Asset | Before Insert/Update | Calculates Next_Inspection_Date, Maintenance_Schedule; flags Beyond Expected Life |
| **HSEIncidentTrigger** | HSE_Incident__c | After Insert/Update | Classifies severity, notifies compliance, escalates critical |
| **InspectionTrigger** | Inspection__c | After Insert/Update | Updates Asset/Pipeline Last_Inspection_Date; creates recurring inspections |
| **ProductionAllocationTrigger** | Production_Allocation__c | Before Insert/Update | Validates Working_Interest ≤ 100%; checks combined WI/NRI ≤ 200% |
| **RegulatoryPermitTrigger** | Regulatory_Permit__c | After Insert/Update | Sets Compliance_Status based on expiration vs status |
| **WellTrigger** | Well__c | Before/After Insert/Update | Sets defaults, validates status transitions, logs operations |

### 11.3 Apex Service Classes

| Class | Key Methods | Business Function |
|---|---|---|
| **WellStatusService** | `isValidTransition()`, `transitionWellStatus()`, `createWellOperations()`, `getWellsDueForAbandonment()` | Well lifecycle state machine (bulkified) |
| **HSEIncidentService** | `classifySeverity(s)`, `isRegulatoryReportable()`, `notifyComplianceTeam(s)`, `escalateIfCritical(s)` | Incident triage & notification (bulkified) |
| **ComplianceDueDateService** | `getUpcomingRenewals()`, `getOverdueReports()`, `sendRenewalReminders()`, `updateComplianceStatuses()` | Permit renewal, reports & compliance status updates |
| **InspectionService** | `getChecklistItems()`, `submitChecklist()`, `updateParentInspectionDates()`, `createRecurringInspections()` | Inspection checklist management & lifecycle |
| **InventoryBalanceService** | `recordInventoryMovement()`, `reconcileInventory()`, `getLowInventoryAlerts()` | Tank inventory & transaction management |
| **ProductionAllocationService** | `calculateMonthlyAllocation()`, `getProductionHistory()`, `validateWorkingInterest()` | Production allocation creation & validation |
| **RoyaltyCalculationService** | `calculateRoyaltyPayment()`, `calculateMonthlyRoyalties()`, `generateRoyaltyStatements()` | Royalty math & partner payment task creation |
| **PermitToWorkValidationService** | `validateIsolationRequirements()`, `validateGasTestResults()`, `validateAuthorizationChain()` | Permit safety & authorization validation |
| **PipelineIntegrityService** | `isInspectionCompliant()`, `flagNonCompliantPipelines()`, `calculateNextInspectionDueDate()` | Pipeline inspection compliance |

### 11.4 Automation Interaction Diagram

```
Scheduled Flows (Daily/Weekly):
  Compliance_Calendar → Regulatory_Permit__c (reminder flags)
  Inspection_Due      → Inspection__c (creates new from recurring)
  Joint_Venture_Billing → Invoice__c (monthly billing)
  Land_Lease_Expiration → Task (lease reminders)
  Production_Reconciliation → Compliance_Report__c (zero production flag)
  Retail_Inventory_Alert → Task (restock alerts)

Record-Triggered Flows:
  Field_Service_Dispatch     ← WorkOrder creation
  HSE_Incident_Escalation    ← HSE_Incident__c create/update
  Permit_to_Work_Approval    ← Permit_to_Work__c creation
  Regulatory_Permit_Compliance ← Regulatory_Permit__c create/update
  ~~Well_Lifecycle~~ *(Deleted — superseded by Apex WellTrigger)*

Apex Triggers:
  WellTrigger                ← validates before flow runs
  HSEIncidentTrigger         ← classifies severity before escalation flow
  InspectionTrigger          ← updates parents + creates recurring
  ProductionAllocationTrigger ← validates WI/NRI before insert
  RegulatoryPermitTrigger    ← sets compliance status
  AssetTrigger               ← calculates inspection schedule
```

---

## 12. LWC Dashboard Mapping <a id="12-lwc-dashboard-mapping"></a>

| Component | Target Record | Function | Business User |
|---|---|---|---|
| **complianceCalendar** | Compliance_Report__c | Calendar view of report due dates | Compliance Analyst |
| **fieldServiceChecklist** | WorkOrder | Dynamic safety checklist linked to PTW | Field Technician |
| **hseIncidentMap** | HSE_Incident__c | Map with clustering of incident locations | HSE Advisor, Executive |
| **inventoryTankGauge** | Fuel_Inventory__c | Visual tank fill-level gauge | Terminal Operator, Retail Manager |
| **permitToWorkBoard** | Permit_to_Work__c | Kanban board by permit status | HSE Advisor, Field Technician |
| **productionAllocationReport** | Production_Allocation__c | Tabular breakdown of allocations | Production Engineer |
| **wellProductionChart** | Well__c | Production chart over time | Production Engineer, Executive |

---

## 13. End-to-End Process Flows <a id="13-end-to-end-process-flows"></a>

### 13.1 End-to-End: Well Lifecycle → Production → Revenue

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    WELL TO REVENUE PROCESS CHAIN                                    │
└────────────────────────────────────────────────────────────────────────────────────┘

  1. LAND & LEASING
     Landman identifies mineral rights → Land_Parcel__c created
     Negotiates lease → Lease__c (Royalty%, Term, Working Interest %)
     ↓
  2. WELL PERMITTING
     Regulatory_Permit__c obtained (Drilling permit)
     Well__c created with Status = "Permitted"
     WellTrigger sets Status_Change_Date = today
     ↓
  3. DRILLING
     Well__c.Status = "Drilling"
      WellTrigger + WellStatusService validates transition → creates Well_Operation__c (Operation_Type = "Status Change", Status = newStatus)
     ↓
  4. COMPLETION & PRODUCTION
     Well__c.Status = "Producing"
     Monthly production volumes → Production_Allocation__c
     ProductionAllocationTrigger validates Working Interest ≤ 100%
     ProductionAllocationService.calculateMonthlyAllocation()
     ↓
  5. RECONCILIATION
     Production_Reconciliation Flow checks for zero volumes
     If zero → Compliance_Report__c (Production Discrepancy)
     ↓
  6. REVENUE ALLOCATION
     RoyaltyCalculationService.calculateMonthlyRoyalties()
       → Tasks created for JV partners with payment amounts
       → Revenue shared per Working Interest / Revenue Interest %
     ↓
  7. JOINT VENTURE BILLING
     Joint_Venture_Billing Flow (1st of month)
       → Creates Invoice__c for active JVs
     ↓
  8. WELL MAINTENANCE / SHUT-IN
     Well__c.Status = "Shut-In" or "Suspended"
     WellStatusService.getWellsDueForAbandonment() flags dormant wells
     ↓
  9. ABANDONMENT
     Well__c.Status = "Plugged" → "Abandoned" (terminal)
     Regulatory_Permit__c updated for abandonment permits
```

### 13.2 End-to-End: HSE Incident → Escalation → Resolution

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    INCIDENT MANAGEMENT PROCESS                                      │
└────────────────────────────────────────────────────────────────────────────────────┘

  Incident Occurs
    ↓
  HSE_Incident__c created (reported by Contact)
    ↓
  HSEIncidentTrigger.HSEIncidentService.classifySeverity()
    → Severity set: Low / Medium / High / Critical
    ↓
  HSEIncidentService.isRegulatoryReportable()
    → Regulatory_Reportable__c = true/false
    ↓
  HSE_Incident_Escalation Flow:
    ┌─────────────────────────────────────────────────┐
    │ Severity = Critical + Fatality                  │
    │ → "CRITICAL INCIDENT with fatality" Task        │
    │ → HSEIncidentService.escalateIfCritical()       │
    │   → Email to Executive_Leadership Group         │
    │   → "Critical Incident Escalation" Task         │
    ├─────────────────────────────────────────────────┤
    │ Regulatory_Reportable = true                     │
    │ → "File regulatory report for incident" Task    │
    │ → HSEIncidentService.notifyComplianceTeam()     │
    │   → Email to HSE_Compliance_Team Group          │
    ├─────────────────────────────────────────────────┤
    │ Low/Medium Severity                              │
    │ → "Incident recorded" Task                      │
    └─────────────────────────────────────────────────┘
    ↓
  Investigation → Root_Cause analysis → Corrective_Action
    ↓
  Status progression: New → Investigating → Resolved → Closed
    ↓
  Lessons Learned documented

  HSE_Observation__c (preventative):
    Open → Acknowledged → Closed
    Corrective_Action_Taken tracked
```

### 13.3 End-to-End: Permit to Work → Authorization → Field Dispatch

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    PERMIT TO WORK & FIELD SERVICE PROCESS                          │
└────────────────────────────────────────────────────────────────────────────────────┘

  Work Requester submits PTW request
    ↓
  Permit_to_Work__c created (Status = Requested)
    ↓
  Permit_to_Work_Approval Flow:
    → "Review Permit to Work" Task created
    ↓
  Authorization chain (PermitToWorkValidationService):
    ┌─ Risk = Low    → 1 authorizer
    ├─ Risk = Medium → 2 authorizers
    ├─ Risk = High   → 2 authorizers
    └─ Risk = Critical → 3 authorizers
    ↓
  PTW issued (Status = Issued)
    ↓
  WorkOrder created for the field work
    ↓
  Field_Service_Dispatch Flow:
    ┌─ No PTW needed → "Dispatch crew for Work Order" Task
    ├─ PTW valid (Issued) → "Dispatch crew for Work Order" Task
    └─ PTW not valid → "Valid PTW required before dispatch" Task
    ↓
  Field crew dispatched with PTW
    ↓
  On-site safety validation (validateGasTestResults, validateIsolationRequirements)
    ↓
  Work completed → PTW Status = "Completed"
```

### 13.4 End-to-End: Regulatory Compliance → Renewal

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    REGULATORY COMPLIANCE PROCESS                                   │
└────────────────────────────────────────────────────────────────────────────────────┘

  Permit issued → Regulatory_Permit__c (Active, with Expiration_Date)
    ↓
  Regulatory_Permit_Compliance Flow (on create/update):
    If Expiration_Date ≤ 90 days away
    → Creates Compliance_Report__c (Regulatory Compliance, Pending)
    ↓
  RegulatoryPermitTrigger (after update):
    On status change:
    ┌─ Active/Approved → Compliance_Status = "Compliant"
    ├─ Expired         → Compliance_Status = "Expired"
    └─ Suspended/Revoked → "Non-Compliant"
    ↓
  As expiration approaches:
    ┌─ ≥ 90 days → no action
    ├─ 31-90 days → Compliance_Status = "Approaching Expiration"
    ├─ 1-30 days  → Compliance_Status = "Critical - Expiring Soon"
    └─ Past due   → Compliance_Status = "Expired"
    ↓
  Compliance_Calendar Flow (Daily):
    → Marks Renewal_Reminder_Sent__c = true
    ↓
  ComplianceDueDateService.sendRenewalReminders():
    → Email to Responsible_Party (reminder)
    → Email if Compliance_Report overdue
    ↓
  Renewal submitted → New Compliance_Report__c
    → Regulatory_Permit__c expiration date extended
```

### 13.5 End-to-End: Inventory Management

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                    INVENTORY MANAGEMENT PROCESS                                    │
└────────────────────────────────────────────────────────────────────────────────────┘

  Product received at Terminal/Retail Outlet
    ↓
  InventoryBalanceService.recordInventoryMovement()
    → Updates Fuel_Inventory__c.Current_Volume
    → Creates Inventory_Transaction__c (Receipt)
    ↓
  Product dispensed (Delivery/Transfer-Out/Consumption)
    ↓
  InventoryBalanceService.recordInventoryMovement()
    → Decrements Current_Volume
    → Creates Inventory_Transaction__c
    ↓
  Daily Retail_Inventory_Alert Flow:
    → Finds tanks where Current_Volume < Minimum_Threshold
    → Creates "Restock tank below minimum threshold" Task
    ↓
  Periodic reconciliation:
    InventoryBalanceService.reconcileInventory()
    → Physical count vs system volume
    → Creates Reconciliation transaction
    → Flags discrepancy if > 5%
```

---

## 14. Gap Analysis & Recommendations <a id="14-gap-analysis"></a>

### Critical Gaps

| Issue | Impact | Recommendation |
|---|---|---|
| **No Page Layouts** | Objects not deployable to org | Create minimum 1 layout per object before production deployment |
| **No Profiles** | Users cannot be created | Create minimal profiles or rely on permission sets |
| **No Custom App** | No navigation grouping | Create a custom app grouping all O&G objects by domain |
| **Invoice__c missing from all permission sets** | No user can access invoices | Add Invoice__c to O_G_All_Access and relevant permission sets |
| **Invoice__c has no tab** | No UI navigation to invoices | Create a custom tab for Invoice__c |

### Moderate Gaps

| Issue | Recommendation |
|---|---|
| **No validation rules** on any object | Add rules for required fields, date logic (e.g. End > Start) |
| **No compact layouts** | Add compact layouts for mobile/Lightning experience |
| **No role hierarchy** | Define organization role hierarchy for sharing |
| **O_G_Executive only has 12/24 objects** | Review and expand executive read access |
| **Public groups missing** (HSE_Compliance_Team, Executive_Leadership) | Create groups referenced by Apex email notifications |

### Architecture Observations

1. ~~**Duplicate automation:** Well status changes trigger both the `Well_Lifecycle` Flow AND the `WellTrigger` + `WellStatusService` Apex — both create `Well_Operation__c` records~~ *(RESOLVED: Well_Lifecycle flow deleted — Apex WellTrigger handles this with correct dynamic values)*

2. **Flow vs Apex overlap:** Several processes are split between flows and Apex triggers (e.g., HSE incident escalation runs in both flow and trigger). Consider consolidating to one automation channel to avoid conflicts.

3. **Picklist mismatches (now resolved):** All 5 picklist mismatches between code and field definitions have been corrected.

4. **InspectionService.Comment__c reference:** `submitChecklist()` references `Comment__c` field in JSON deserialization but this field does not exist on Inspection__c. The code falls back to `Findings__c` but the JSON structure expects `Comment__c`.

---

*Document generated from project source analysis — June 2026*
