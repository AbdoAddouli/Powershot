# Oil & Gas Salesforce Solution — Project Description

> **Project:** Energy_Salesforce_project  
> **API Version:** 66.0 (Spring '25)  
> **Target Org:** `addouliabdo9.76deae143000@agentforce.com`  
> **Last Updated:** June 2026

---

## 1. Project Overview

This Salesforce solution is built for an integrated Oil & Gas company covering the **full value chain** — from mineral rights and drilling wells to transporting crude, refining it, and selling fuel at retail outlets. The solution manages 24 custom objects, 9 Apex classes, 6 triggers, 11 flows, 7 LWCs, and 13 permission sets across four business segments:

| Segment | Business Activity | Core Objects |
|---|---|---|
| **Upstream** | Exploration, land leasing, drilling, well operations, production | Well, Lease, Land Parcel, Well Operation, Production Allocation, Joint Venture |
| **Midstream** | Pipeline transport, measurement, nomination scheduling | Pipeline, Pipeline Station, Measurement, Transportation Nomination |
| **Downstream** | Refining, terminal storage, retail fuel sales | Refinery, Terminal, Retail Outlet, Fuel Inventory, Supply Agreement |
| **Corporate** | HSE, regulatory compliance, commercial contracts, invoicing | HSE Incident, Regulatory Permit, Compliance Report, Service Contract, Invoice |

---

## 2. Business Domains & Process Steps

### 2.1 Upstream — Well Lifecycle & Production

The upstream domain manages the entire life of a well, from securing mineral rights to final abandonment.

#### Step 1: Land & Leasing

A **Landman** identifies mineral rights and creates a `Land_Parcel__c` record tracking county, state, acreage, and ownership. A lease is negotiated with the mineral rights owner and recorded as a `Lease__c`, specifying royalty percentage, term length, and working interest. The **Land_Lease_Expiration** flow runs daily, flags leases expiring within 90 days, and creates reminder tasks.

#### Step 2: Well Permitting

A `Regulatory_Permit__c` (Drilling permit) is obtained from the agency. A `Well__c` record is created with Status = `Permitted`. The **WellTrigger** automatically sets `Status_Change_Date__c` to today and defaults fields.

#### Step 3: Drilling

The well status advances to `Drilling`. The **WellTrigger** + **WellStatusService** validate that this is a legal transition (Permitted → Drilling is valid). A `Well_Operation__c` record is created logging the status change. The well tracks spud date, total depth, and formation.

#### Step 4: Production

When drilling completes, the well status moves to `Producing`. Each month, production volumes are entered as `Production_Allocation__c` records (oil in barrels, gas in MCF, water in barrels). The **ProductionAllocationTrigger** validates that the **Working Interest** across all allocations for a well does not exceed 100%. The **ProductionAllocationService.calculateMonthlyAllocation()** creates the initial allocation record.

#### Step 5: Revenue Allocation & Royalties

The **RoyaltyCalculationService** calculates monthly royalty payments based on production volumes, working interest percentages, and revenue interest percentages. Tasks are created for Joint Venture partners with calculated payment amounts.

#### Step 6: Joint Venture Billing

The **Joint_Venture_Billing** flow runs daily. On the 1st of each month, it queries active `Joint_Venture__c` records and creates `Invoice__c` records for each partner.

#### Step 7: Reconciliation

The **Production_Reconciliation** flow runs daily. It checks for `Production_Allocation__c` records where both oil AND gas volumes are zero, and creates a `Compliance_Report__c` with type "Production Discrepancy".

#### Step 8: Shut-In & Suspension

Wells can transition to `Shut-In` or `Suspended` status. The **WellStatusService.getWellsDueForAbandonment()** flags wells that have been Shut-In for over 24 months.

#### Step 9: Abandonment

The final stage. Well status moves to `Plugged` then `Abandoned` (terminal state). Regulatory permits are updated for abandonment.

#### Valid Well Status Transitions

```
Permitted → Drilling, Cancelled
Drilling → Producing, Suspended, Plugged, Abandoned
Producing → Shut-In, Suspended, Plugged, Abandoned
Shut-In → Producing, Suspended, Plugged, Abandoned
Suspended → Producing, Shut-In, Plugged, Abandoned
Plugged → Abandoned
Abandoned → (terminal — no transitions out)
```

---

### 2.2 Midstream — Pipeline & Transportation

The midstream domain manages crude/gas/NGL transport from wells to refineries and terminals.

#### Step 1: Pipeline Registration

A `Pipeline__c` record tracks each pipeline segment with commodity type, diameter, MAOP (Maximum Allowable Operating Pressure), operating pressure, and compliance status. `Pipeline_Station__c` records (pump stations, compressor stations, valve sites, meter stations) are linked along each pipeline.

#### Step 2: Measurement

Field devices report flow, pressure, temperature, and volume readings as `Measurement__c` records linked to pipelines or stations. This data feeds pipeline integrity analysis and production reconciliation.

#### Step 3: Transportation Nominations

Shippers request transport capacity via `Transportation_Nomination__c`. Status progresses through: **Draft → Submitted → Confirmed → Scheduled → Completed**.

#### Step 4: Pipeline Integrity

The **PipelineIntegrityService** manages inspection compliance:
- `getOverdueInspections()` — finds inspections past their scheduled or next-due date
- `isInspectionCompliant(pipelineId)` — checks if a pipeline's last inspection falls within its required interval
- `flagNonCompliantPipelines()` — bulk updates all pipelines to `Compliant` or `Non-Compliant` based on inspection status
- `calculateNextInspectionDueDate()` — determines when the next inspection is due

---

### 2.3 Downstream — Refining, Terminal & Retail

The downstream domain manages the transformation of crude into finished products and their distribution to end customers.

#### Step 1: Refining

`Refinery__c` records track refinery capacity (barrels per day), Nelson Complexity Index, and PADD district. Refineries receive crude via pipeline and produce gasoline, diesel, jet fuel, and other refined products.

#### Step 2: Terminal Storage

`Terminal__c` records manage storage facilities with tank count, storage capacity, and rail/truck/marine access. `Fuel_Inventory__c` records track individual tank levels (product type, current volume, tank capacity, minimum threshold).

#### Step 3: Inventory Movements

The **InventoryBalanceService** handles all inventory transactions:
- `recordInventoryMovement()` — updates tank volume and creates an `Inventory_Transaction__c` audit record for receipts, deliveries, transfers, and consumption
- `reconcileInventory()` — compares physical counts against system volume, flags discrepancies over 5%
- `getLowInventoryAlerts()` — identifies tanks below minimum threshold

#### Step 4: Retail Operations

`Retail_Outlet__c` records manage company-owned or dealer-operated gas stations and convenience stores. Each outlet can have multiple `Fuel_Inventory__c` tanks. The **Retail_Inventory_Alert** flow runs daily, finds tanks below minimum threshold, and creates restock tasks.

#### Step 5: Supply Agreements

`Supply_Agreement__c` records define the terms for product supply between parties (crude, gas, NGL, or refined products), including pricing index, volume terms, delivery point, and credit terms.

---

### 2.4 HSE — Health, Safety & Environment

The HSE domain manages incident reporting, safety observations, and safe work authorization.

#### Step 1: Incident Reporting

When an HSE incident occurs, an `HSE_Incident__c` record is created. Key data includes incident type (Spill, Injury, Fire, Explosion, Environmental, Near Miss), location, fatality indicator, spill volume, and injury type.

#### Step 2: Severity Classification

The **HSEIncidentTrigger** fires and delegates to **HSEIncidentService.classifySeverities()**:

| Condition | Severity |
|---|---|
| Fatality occurred | Critical |
| Life-Threatening injury or Permanent Disability | Critical |
| Major environmental impact or Spill > 1,000 bbl | High |
| Lost Time injury or Moderate environmental impact | High |
| Medical Treatment injury or Spill > 100 bbl | Medium |
| All other cases | Low |

#### Step 3: Regulatory Notification

If the incident is `Regulatory_Reportable__c`, **HSEIncidentService.notifyComplianceTeams()** sends email alerts to the HSE Compliance Team group and creates compliance notification tasks.

#### Step 4: Executive Escalation

If severity is `Critical`, **HSEIncidentService.escalateIfCritical()** sends escalation emails to the Executive Leadership group and creates critical escalation tasks.

#### Step 5: Incident Resolution

Incidents progress through: **New → Investigating → Resolved → Closed**. Root cause analysis and corrective actions are documented.

#### Step 6: Safety Observations

`HSE_Observation__c` records track proactive safety observations (Safe/Unsafe observations). Status flow: **Open → Acknowledged → Closed**.

#### Step 7: Permit to Work

The **Permit_to_Work__c** process governs high-risk work:
1. Request submitted (Status = Requested)
2. **Permit_to_Work_Approval** flow creates a review task
3. **PermitToWorkValidationService** validates:
   - **Isolation Requirements** — Lockout/Tagout for electrical/mechanical work
   - **Gas Test Results** — O₂, LEL, H₂S, CO within safe ranges
   - **Authorization Chain** — Low risk = 1 approver, Medium = 2, High = 2, Critical = 3
4. PTW issued (Status = Issued)
5. **Field_Service_Dispatch** flow verifies PTW validity before dispatching crews
6. Work completed → PTW closed

---

### 2.5 Regulatory & Compliance

The compliance domain tracks government permits, regulatory reporting, and renewal cycles.

#### Step 1: Permit Registration

When a regulatory agency issues a permit, a `Regulatory_Permit__c` is created with permit type, agency, issue date, expiration date, and status.

#### Step 2: Compliance Status Updates

The **RegulatoryPermitTrigger** fires on insert/update and delegates to **ComplianceDueDateService.updateComplianceStatuses()**:

**Expiration-based:**
| Days Until Expiration | Compliance Status |
|---|---|
| Past due (expired) | Expired |
| 1–30 days | Critical - Expiring Soon |
| 31–90 days | Approaching Expiration |
| > 90 days | No change |

**Status-based:**
| Permit Status | Compliance Status |
|---|---|
| Active / Approved | Compliant |
| Expired | Expired |
| Suspended / Revoked | Non-Compliant |

#### Step 3: Compliance Reporting

The **Regulatory_Permit_Compliance** flow creates a `Compliance_Report__c` when a permit nears expiration. Reports track due dates, submission status, and regulatory body. The **ComplianceDueDateService.sendRenewalReminders()** sends email notifications to the responsible party for upcoming renewals and overdue reports.

#### Step 4: Renewal Cycle

The **Compliance_Calendar** flow runs daily, marking `Renewal_Reminder_Sent__c` on permits. The full cycle is: **Permit Issued → Conditions Monitored → Reports Filed → Renewal Submitted**.

---

### 2.6 Commercial — Contracts & Supply Chain

The commercial domain manages vendor contracts, supply agreements, and sales opportunities.

**Service Contracts** (`Service_Contract__c`): Track drilling, completion, production, transportation, and maintenance agreements with vendors and customers. Lifecycle: **Draft → Active → Expired/Terminated**.

**Supply Agreements** (`Supply_Agreement__c`): Define commodity supply terms with pricing index, volume minimums/maximums, delivery points, and credit terms. Linked to supplier and buyer accounts.

**Opportunities** (standard): Extended with Oil & Gas fields for commodity type, contract value, volume in MMBTU, and delivery start date.

---

### 2.7 Operations — Inspections & Work Orders

The operations domain manages field inspections, asset maintenance, and work order dispatch.

#### Step 1: Inspection Scheduling

`Inspection__c` records track all field inspections (Visual, NDT, Cathodic, Hydrotest, Internal) linked to assets, pipelines, wells, or terminals.

#### Step 2: Asset Maintenance Calculation

The **AssetTrigger** (before insert/update on Asset) calculates:
- `Next_Inspection_Date__c` from `Last_Inspection_Date__c` + `Inspection_Frequency_Days__c`
- `Maintenance_Schedule__c` (Monthly / Quarterly / Semi-Annual / Annual / Custom)
- Flags assets beyond their expected lifespan

#### Step 3: Inspection Completion

The **InspectionTrigger** fires when inspections are completed:
- Updates the parent `Asset.Last_Inspection_Date__c` and `Pipeline__c.Last_Inspection_Date__c` with the most recent inspection date
- If the inspection is recurring, creates the next scheduled `Inspection__c` automatically

#### Step 4: Work Order Dispatch

`WorkOrder` (standard) is extended with Oil & Gas fields (Permit_to_Work__c, Isolation_Required, Lockout_Tagout). The **Field_Service_Dispatch** flow checks if a valid PTW exists before dispatching crews, routing to either a dispatch task or a "PTW required" exception task.

---

## 3. Automation Architecture

### 3.1 Apex Triggers (6)

All triggers follow a **thin-trigger** pattern — they delegate business logic to service classes and only perform collection/batch setup in the trigger itself.

| Trigger | Object | Timing | Delegates To |
|---|---|---|---|
| **WellTrigger** | Well__c | Before/After Insert/Update | WellStatusService |
| **HSEIncidentTrigger** | HSE_Incident__c | After Insert/Update | HSEIncidentService |
| **InspectionTrigger** | Inspection__c | After Insert/Update | InspectionService |
| **RegulatoryPermitTrigger** | Regulatory_Permit__c | After Insert/Update | ComplianceDueDateService |
| **ProductionAllocationTrigger** | Production_Allocation__c | Before Insert/Update | ProductionAllocationService |
| **AssetTrigger** | Asset | Before Insert/Update | (inline — field calculations only) |

### 3.2 Apex Service Classes (9)

| Service | Key Methods | Business Function |
|---|---|---|
| **WellStatusService** | `createWellOperations()`, `transitionWellStatus()`, `isValidTransition()`, `getWellsDueForAbandonment()` | Well lifecycle state machine |
| **HSEIncidentService** | `classifySeverities()`, `isRegulatoryReportable()`, `notifyComplianceTeams()`, `escalateIfCritical()` | Incident triage & notification |
| **ComplianceDueDateService** | `updateComplianceStatuses()`, `sendRenewalReminders()`, `getUpcomingRenewals()`, `getOverdueReports()` | Permit & compliance management |
| **InspectionService** | `updateParentInspectionDates()`, `createRecurringInspections()`, `getChecklistItems()`, `submitChecklist()` | Inspection lifecycle |
| **InventoryBalanceService** | `recordInventoryMovement()`, `reconcileInventory()`, `getLowInventoryAlerts()`, `getTankInventory()` | Tank inventory management |
| **ProductionAllocationService** | `validateWorkingInterest()`, `calculateMonthlyAllocation()`, `getProductionHistory()`, `getAllocatedRevenue()` | Production allocation & validation |
| **RoyaltyCalculationService** | `calculateRoyaltyPayment()`, `calculateMonthlyRoyalties()`, `generateRoyaltyStatements()` | Royalty math & partner payment |
| **PermitToWorkValidationService** | `validateIsolationRequirements()`, `validateGasTestResults()`, `validateAuthorizationChain()` | Permit safety validation |
| **PipelineIntegrityService** | `flagNonCompliantPipelines()`, `isInspectionCompliant()`, `calculateNextInspectionDueDate()`, `getOverdueInspections()` | Pipeline compliance |

### 3.3 Flows (10 Active)

**Scheduled Flows** (run on timer):
| Flow | Schedule | Business Action |
|---|---|---|
| **Compliance_Calendar** | Daily 06:00 | Marks permits for renewal reminder |
| **Inspection_Due** | Weekly 07:00 | Creates new inspections from recurring templates |
| **Joint_Venture_Billing** | Daily 02:00 | Creates invoices for active JVs on 1st of month |
| **Land_Lease_Expiration** | Daily 02:00 | Creates tasks for leases expiring in 90 days |
| **Production_Reconciliation** | Daily 02:00 | Flags zero-production allocations |
| **Retail_Inventory_Alert** | Daily 05:00 | Creates restock tasks for low inventory |

**Record-Triggered Flows** (fire on data changes):
| Flow | Trigger Event | Business Action |
|---|---|---|
| **Field_Service_Dispatch** | WorkOrder created | Verifies PTW, routes dispatch |
| **HSE_Incident_Escalation** | HSE_Incident__c created/updated | Routes by severity, creates tasks |
| **Permit_to_Work_Approval** | Permit_to_Work__c created | Creates review task |
| **Regulatory_Permit_Compliance** | Regulatory_Permit__c created/updated | Creates compliance reports |

### 3.4 LWC Components (7)

| Component | Function | Business User |
|---|---|---|
| **complianceCalendar** | Calendar view of report due dates | Compliance Analyst |
| **fieldServiceChecklist** | Dynamic safety checklist linked to PTW | Field Technician |
| **hseIncidentMap** | Map with clustering of incident locations | HSE Advisor, Executive |
| **inventoryTankGauge** | Visual tank fill-level gauge | Terminal Operator, Retail Manager |
| **permitToWorkBoard** | Kanban board by permit status | HSE Advisor, Field Technician |
| **productionAllocationReport** | Tabular breakdown of allocations | Production Engineer |
| **wellProductionChart** | Production chart over time | Production Engineer, Executive |

---

## 4. Data Model Overview

### 4.1 Custom Objects (24)

| Object | Records Expected | Parent Lookups |
|---|---|---|
| Land_Parcel__c | Hundreds | Account |
| Lease__c | Hundreds | Account, Land_Parcel |
| Well__c | Thousands | Account, Lease |
| Well_Operation__c | Millions | Well__c (Master-Detail) |
| Production_Allocation__c | Millions | Well, Lease, Joint_Venture |
| Joint_Venture__c | Hundreds | Account |
| Pipeline__c | Hundreds | Account |
| Pipeline_Station__c | Thousands | Pipeline |
| Measurement__c | Millions | Pipeline, Pipeline_Station, Terminal |
| Transportation_Nomination__c | Thousands | Account, Pipeline |
| Refinery__c | Tens | Account |
| Terminal__c | Hundreds | Account |
| Retail_Outlet__c | Hundreds | Account, Contact |
| Fuel_Inventory__c | Thousands | Terminal, Retail_Outlet |
| Inventory_Transaction__c | Millions | Fuel_Inventory |
| Supply_Agreement__c | Hundreds | Account |
| Service_Contract__c | Hundreds | Account |
| HSE_Incident__c | Thousands | Account, Well, Pipeline, Retail_Outlet, Contact |
| HSE_Observation__c | Thousands | Account |
| Permit_to_Work__c | Thousands | Well, Pipeline, Terminal, Refinery |
| Regulatory_Permit__c | Thousands | Account, Well, Pipeline, Refinery |
| Compliance_Report__c | Thousands | Regulatory_Permit, Account |
| Inspection__c | Thousands | Asset, Pipeline, Terminal, Well |
| Invoice__c | Thousands | Joint_Venture |

### 4.2 Standard Objects Extended (6)

Account, Contact, Asset, Opportunity, Case, WorkOrder — each extended with Oil & Gas-specific fields.

### 4.3 Key Relationships

```
Account → Lease → Well → Well_Operation
Account → Pipeline → Pipeline_Station → Measurement
Account → Terminal / Refinery / Retail_Outlet
Well → Production_Allocation → Lease → Joint_Venture
Regulatory_Permit → Compliance_Report
Fuel_Inventory → Inventory_Transaction
```

---

## 5. Security Model

### 5.1 Permission Sets (13)

| Permission Set | Business Role | Access Level |
|---|---|---|
| O_G_All_Access | System Admin | Full CRUD on all objects |
| O_G_Executive | C-Suite | Read-only on key objects |
| O_G_Compliance_Analyst | Regulatory | CRUD on permits/reports |
| O_G_Drilling_Engineer | Drilling | CRUD on Well, Well_Operation |
| O_G_Production_Engineer | Production | CRUD on Well, Production_Allocation |
| O_G_Field_Technician | Field Tech | CRUD on Inspection, PTW |
| O_G_HSE_Advisor | HSE | CRUD on HSE incidents, observations, PTWs |
| O_G_Pipeline_Engineer | Pipeline | CRUD on Pipeline, Station, Measurement, Inspection |
| O_G_Landman | Land Management | CRUD on Lease, Land_Parcel, Joint_Venture |
| O_G_Refinery_Manager | Refinery | CRUD on Refinery, Supply_Agreement |
| O_G_Retail_Manager | Retail | CRUD on Retail_Outlet, Fuel_Inventory |
| O_G_Supply_Chain | Procurement | CRUD on Service_Contract |
| O_G_Terminal_Operator | Terminal | CRUD on Terminal, Fuel_Inventory, Measurement |

---

## 6. End-to-End Business Flows

### Well to Revenue (Complete Chain)

```
Land Acquisition → Lease → Well Permitting → Drilling → Production
  → Allocation → Revenue Distribution → Royalty Payment → JV Billing
  → Shut-In → Plug & Abandon
```

### HSE Incident to Resolution

```
Incident Occurs → Report → Classify Severity → Regulatory Notification
  → Executive Escalation (if Critical) → Investigation
  → Root Cause → Corrective Action → Close → Lessons Learned
```

### Permit to Work to Field Dispatch

```
PTW Request → Risk Assessment → Isolation/Gas Test Validation
  → Authorization Chain → PTW Issued → WorkOrder Created
  → PTW Verification → Field Dispatch → Work Completion → PTW Close
```

### Regulatory Compliance Cycle

```
Permit Issued → Compliance Monitoring → Status Updates
  → Expiration Alerts → Report Filing → Renewal → Re-Issue
```

### Inventory Management

```
Product Receipt → Volume Update → Transaction Audit
  → Product Dispensed → Decrement → Low Stock Alert
  → Physical Reconciliation → Discrepancy Flagging
```

---

## 7. Project Status & Known Gaps

### Resolved Issues
- Well_Lifecycle flow deleted (Apex trigger handles Well_Operation creation correctly)
- All 5 picklist mismatches between code and schema corrected
- 24 duplicate layout files removed from project root
- All 6 triggers bulkified and refactored to thin-trigger/service pattern
- Unrestricted queries fixed with LIMIT and WHERE clauses
- `@isTest` → `@IsTest` across all test classes

### Known Gaps
- No page layouts defined for any object
- No profiles created
- No custom app for navigation
- `Invoice__c` missing from all permission sets
- 39% Apex test coverage (75% required for production deployment)
- `InspectionService.submitChecklist()` references non-existent `Comment__c` field

### Enhancement Roadmap
1. **Quick Wins:** Slack HSE alerts, commodity pricing service, production dashboard
2. **API Integrations:** SCADA pipeline monitoring, drilling data sync, regulatory filing
3. **Einstein AI:** Production forecasting, pipeline failure prediction, inventory prediction
4. **Experience Cloud:** Partner portal for JV partners, suppliers, regulators
5. **Advanced Analytics:** Executive KPIs, automated PDF statements
6. **Data Cloud:** Unified data model across all data sources

---

*For detailed technical documentation, see [BUSINESS_PROCESS_MAPPING.md](./BUSINESS_PROCESS_MAPPING.md), [ARCHITECTURE.md](./ARCHITECTURE.md), and [ENHANCEMENT_GUIDE.md](./ENHANCEMENT_GUIDE.md).*
