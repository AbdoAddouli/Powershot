# Oil & Gas Salesforce Architecture

## Overview

Integrated Salesforce architecture covering **Upstream (E&P)**, **Midstream**, and **Downstream** segments of the Oil & Gas industry.

| Property | Value |
|---|---|
| **Domain** | Oil & Gas (Integrated — All Segments) |
| **Org Type** | New greenfield org |
| **Salesforce API** | v67.0 (Spring 2025) |
| **MVP Timeline** | 1–3 months |
| **Full Scope** | Land & Lease, Wells, Pipelines, Terminals, Refining, Retail, HSE, Regulatory, Supply Chain, JV/Partners |

---

## Phase 1: MVP (1–3 months)

---

### 1. Data Model — Custom Objects

#### Upstream (E&P)

| Object | Type | Key Fields |
|---|---|---|
| **Land_Parcel__c** | Lookup (Account) | Parcel_Number, County, State, Acreage, Mineral_Rights_Owner, Surface_Rights_Owner, Legal_Description, Coordinates |
| **Lease__c** | Lookup (Account, Land_Parcel) | Lease_Number, Lease_Type (Paid-Up/Free/Net Profits), Royalty_Percent, Term_Years, Primary_Term_End, Delay_Rental_Amount, Status (Active/Expired/Terminated) |
| **Well__c** | Lookup (Account, Lease) | API_Number, Well_Name, Well_Type (Oil/Gas/Injection/Water Disposal), Status (Drilling/Producing/Plugged/Abandoned), Total_Depth, True_Vertical_Depth, Spud_Date, Completion_Date, Formation, Production_Status |
| **Well_Operation__c** | Lookup (Well) | Operation_Type (Drilling/Completion/Workover/Plug & Abandon), Start_Date, End_Date, Rig_Contractor, AFE_Number, AFE_Amount, Actual_Cost, Status (Planned→Completed), Daily_Report |
| **Production_Allocation__c** | Lookup (Well, Lease) | Period_Start, Period_End, Oil_Volume_bbls, Gas_Volume_MCF, Water_Volume_bbls, Days_On_Production, Allocated_Revenue, Severance_Tax, Working_Interest_Share, Net_Revenue_Interest_Share |

#### Midstream

| Object | Type | Key Fields |
|---|---|---|
| **Pipeline__c** | Lookup (Account) | Pipeline_Name, Segment_Length_Miles, Diameter_inches, Commodity (Crude/Gas/NGL/Refined), Capacity_bpd, Operating_Pressure, Status (Active/Idle/Decommissioned), SHVS_Class_Location, MAOP |
| **Pipeline_Station__c** | Lookup (Pipeline) | Station_Name, Station_Type (Pump/Compressor/Valve/Meter), Capacity, Horsepower, Status, Station_Location |
| **Terminal__c** | Lookup (Account) | Terminal_Code, Storage_Capacity_bbls, Commodity_Type, Tank_Count, Rail/Truck/Marine_Access, Status |
| **Transportation_Nomination__c** | Lookup (Account, Pipeline) | Nomination_Period, Requested_Volume, Confirmed_Volume, Shipper, Contract_Reference, Status (Requested→Scheduled→Delivered) |
| **Measurement__c** | Lookup (Pipeline_Station, Terminal) | Reading_DateTime, Gross_Volume, Net_Volume, Temperature, Pressure, Gravity, BS&W_Percent, Meter_Factor, Source (Custody Transfer/Check) |

#### Downstream

| Object | Type | Key Fields |
|---|---|---|
| **Refinery__c** | Lookup (Account) | Refinery_Name, PADD_District, Capacity_bpd, Nelson_Complexity_Index, Units_List (Crude/Vacuum/FCC/Hydrocracker/Reformer), Status |
| **Retail_Outlet__c** | Lookup (Account, Contact) | Outlet_Code, Brand, Location, Store_Type (Company/Dealer/Jobber), Fuel_Tank_Count, Fuel_Volume_Monthly, C_Store, Car_Wash, Status |
| **Supply_Agreement__c** | Lookup (Account) | Agreement_Type (Term/Spot/Exchange), Commodity, Volume, Price_Basis, Index, Term_Start, Term_End, Status, Credit_Terms, Delivery_Point |
| **Fuel_Inventory__c** | Lookup (Terminal, Retail_Outlet) | Product, Tank_Number, Tank_Capacity, Current_Volume, Available_Volume, Last_Receipt_Date, Last_Delivery_Date, Gauge_Type, Status |

#### Cross-Cutting

| Object | Type | Key Fields |
|---|---|---|
| **HSE_Incident__c** | Lookup (Account, Well, Pipeline, Retail_Outlet) | Incident_Type (Spill/Injury/Vehicle/Fire/Explosion/Safety Near Miss/Environmental), Incident_Date, Severity, Description, Root_Cause, Corrective_Action, Regulatory_Reportable, LTI, Recordable, Status (Open→Closed) |
| **HSE_Observation__c** | Lookup (Account, Location) | Observation_Type (Safe/Unsafe), Category, Description, Location, Observer, Corrective_Action_Taken, Status |
| **Permit_to_Work__c** | Lookup (Well, Pipeline_Station, Terminal, Refinery) | Permit_Type (Hot Work/Confined Space/Excavation/Work at Height/Electrical), Description, Location, Issuer, Holder, Start_DateTime, End_DateTime, Isolation_Required, Gas_Test_Result, Status (Requested→Issued→Completed→Cancelled) |
| **Regulatory_Permit__c** | Lookup (Account, Well, Pipeline, Refinery) | Permit_Type (SPCC/Title V/NSPS/NPDES/Underground Injection), Permit_Number, Agency (EPA/State/Local), Issue_Date, Expiration_Date, Status, Compliance_Status, Renewal_Reminder |
| **Compliance_Report__c** | Lookup (Regulatory_Permit, Account) | Report_Type, Reporting_Period, Due_Date, Submitted_Date, Submitted_By, Status, Notes |
| **Joint_Venture__c** | Lookup (Account) | JV_Name, Partners, Operator, Working_Interest_Percent, Revenue_Interest_Percent, Accounting_Method, Status, JV_Agreement_Document |
| **Inspection__c** | Lookup (Asset, Pipeline, Terminal, Well) | Inspection_Type (Visual/NDT/Cathodic/Hydrotest/Internal), Scheduled_Date, Completed_Date, Inspector, Result (Pass/Fail/Conditional), Findings, Next_Due_Date |
| **Service_Contract__c** | Lookup (Account) | Contract_Type (Drilling/Workover/Well Service/Inspection/Cleaning), Contractor, Scope_of_Work, Value, Start_Date, End_Date, Insurance_Requirements, Status, PO_Reference |

**Total (MVP): 18 custom objects**

---

### 2. Enhanced Standard Objects

| Object | Record Types | Key Custom Fields |
|---|---|---|
| **Account** | Operator, Partner/JV, Supplier/Vendor, Regulatory Agency, Retail Customer, Commercial Customer | `EIN__c`, `DUNS__c`, `NAICS_Code__c`, `Supplier_Tier__c`, `Insurance_Expiration__c`, `HSE_Rating__c` |
| **Contact** | Engineer, Landman, HSE Officer, Field Tech, Account Manager, Regulatory Contact | `Job_Title_Oil_Gas__c`, `Field_Location__c`, `Safety_Certifications__c`, `TWIC_Expiration__c`, `Emergency_Contact__c` |
| **Asset** | Pump, Compressor, Valve, Tank, Meter, Separator, Heater Treater, Generator | `API_Equipment_Type__c`, `Criticality_Rating__c`, `Installation_Date__c`, `Last_Inspection_Date__c`, `Inspection_Frequency_Days__c`, `Operating_Hours__c` |
| **Opportunity** | Service Sale, Equipment Sale, Supply Contract, JV Proposal | `Contract_Value__c`, `Start_Date__c`, `Commodity_Type__c`, `Volume_MMBTU__c` |
| **Case** | HSE Incident, Equipment Failure, Regulatory, Customer Issue, Field Request | `Severity__c`, `Location__c`, `Regulatory_Reportable__c`, `Well__c`, `Pipeline__c`, `Root_Cause_Category__c` |
| **Work Order** | Preventive Maintenance, Corrective, Inspection, Field Service | `Pump__c`, `Pipeline_Station__c`, `Well__c`, `Permit_to_Work__c`, `Isolation_Required__c`, `Lockout_Tagout__c` |

---

### 3. Object Relationship Architecture

```
Account (Operator)
├── Lease__c (1+)
│   └── Well__c (1+) ─── Well_Operation__c (1+)
│       └── Production_Allocation__c
├── Land_Parcel__c (1+)
├── Joint_Venture__c (1+)
├── Pipeline__c (1+)
│   ├── Pipeline_Station__c (1+)
│   │   └── Measurement__c (1+)
│   └── Transportation_Nomination__c (1+)
├── Terminal__c (1+)
│   └── Fuel_Inventory__c (1+)
├── Refinery__c (1+)
├── Retail_Outlet__c (1+)
│   └── Fuel_Inventory__c
├── Supply_Agreement__c (1+)
├── Service_Contract__c (1+)
├── HSE_Incident__c
├── Regulatory_Permit__c
│   └── Compliance_Report__c
├── Asset (1+)
│   └── Inspection__c (1+)
├── Permit_to_Work__c
└── Case / Work Order
```

---

### 4. MVP Apex Classes

| Class | Responsibility |
|---|---|
| `ProductionAllocationService` | Calculate monthly production allocation by WI/NRI |
| `HSEIncidentService` | Classify severity, determine regulatory reportability, notify compliance |
| `ComplianceDueDateService` | Calculate upcoming permit renewals and report due dates |
| `PipelineIntegrityService` | Track inspection intervals, flag overdue inspections |
| `WellStatusService` | Manage well lifecycle transitions (Drilling→Producing→Plugged) |
| `InventoryBalanceService` | Track fuel/product inventory movements and reconciliations |
| `RoyaltyCalculationService` | Calculate royalty payments from production data |
| `PermitToWorkValidationService` | Validate isolation, gas test, and authorization checks |

**Triggers:** `WellTrigger`, `HSEIncidentTrigger`, `AssetTrigger`, `RegulatoryPermitTrigger`, `ProductionAllocationTrigger`, `InspectionTrigger`

---

### 5. Flows (MVP)

| Flow | Trigger |
|---|---|
| **Well Lifecycle** | Well status change — create Well_Operation record, notify team |
| **HSE Incident Escalation** | Incident created/updated — notify HSE Manager, Legal, Regulatory if reportable |
| **Compliance Calendar** | Daily — check upcoming permit expirations, report due dates, send reminders |
| **Inspection Due** | Weekly — create Inspection records for overdue/scheduled inspections |
| **Permit to Work Approval** | PTW created — route to approver based on type and location |
| **Field Service Dispatch** | Work Order created — assign crew, check PTW requirements |
| **Production Reconciliation** | Monthly — aggregate production data, flag discrepancies |
| **Retail Inventory Alert** | Daily — alert when fuel inventory below minimum threshold |

---

### 6. LWC Components (MVP)

| Component | Purpose |
|---|---|
| **wellProductionChart** | Well production trends (oil/gas/water over time) |
| **hseIncidentMap** | GIS map of HSE incidents by location |
| **pipelineIntegrityDashboard** | Pipeline inspection status, integrity overview |
| **complianceCalendar** | Upcoming regulatory deadlines, permit renewals |
| **inventoryTankGauge** | Visual tank-level indicators for terminals/retail |
| **leaseMapView** | Interactive map of lease boundaries and well locations |
| **permitToWorkBoard** | Kanban board for PTW lifecycle (Requested→Issued→Completed) |
| **fieldServiceChecklist** | Mobile-ready inspection/PTW checklist component |
| **productionAllocationReport** | Revenue / volume allocation by working interest |

---

### 7. Security Model

#### Role Hierarchy

```
CEO
├── VP Upstream
│   ├── Land Manager → Landman
│   ├── Drilling Manager → Drilling Engineer
│   └── Production Manager → Production Engineer
├── VP Midstream
│   ├── Pipeline Director → Pipeline Engineer
│   └── Terminals Manager → Terminal Operator
├── VP Downstream
│   ├── Refinery Manager
│   ├── Supply & Trading Manager
│   └── Retail Operations Manager → Store Supervisor
├── VP HSE & Regulatory
│   ├── HSE Director → HSE Advisor
│   └── Regulatory Compliance Manager → Compliance Analyst
├── VP Supply Chain
│   ├── Procurement Manager
│   └── Warehouse / Inventory Manager
└── VP JV & Partnerships
```

#### Permission Sets

| Permission Set | Access |
|---|---|
| **O&G_Landman** | CRUD on Lease, Land_Parcel, Joint_Venture; read on Well |
| **O&G_Drilling_Engineer** | CRUD on Well, Well_Operation; read on Lease |
| **O&G_Production_Engineer** | CRUD on Well (production fields), Production_Allocation |
| **O&G_Pipeline_Engineer** | CRUD on Pipeline, Pipeline_Station, Measurement, Inspection |
| **O&G_Terminal_Operator** | CRUD on Terminal, Fuel_Inventory, Measurement |
| **O&G_Refinery_Manager** | CRUD on Refinery, Supply_Agreement; read on Pipeline/Terminal |
| **O&G_Retail_Manager** | CRUD on Retail_Outlet, Fuel_Inventory |
| **O&G_HSE_Advisor** | CRUD on HSE_Incident, HSE_Observation, Permit_to_Work |
| **O&G_Compliance_Analyst** | CRUD on Regulatory_Permit, Compliance_Report; read on HSE_Incident |
| **O&G_Field_Technician** | CRUD on Inspection, PTW (limited), read on Well, Pipeline, Asset |
| **O&G_Supply_Chain** | CRUD on Service_Contract, Product, Inventory |
| **O&G_Executive** | Read all, reports and dashboards |

---

### 8. Integrations (Post-MVP Roadmap)

| Integration | Purpose | Phase |
|---|---|---|
| **SCADA / PI System** (OSIsoft) | Real-time production, pipeline, terminal data | Phase 2 |
| **GIS** (ArcGIS) | Well/lease/pipeline spatial data, map layers | Phase 2 |
| **ERP** (SAP/Oracle) | Procurement, inventory, financial accounting | Phase 2 |
| **UK Land / WellHub / Enverus** | Well data, production data imports | Phase 2 |
| **E-signature** (DocuSign) | Lease, JV, contract signing | Phase 2 |
| **HSE Software** (Intelex/Sphera) | Incident management integration | Phase 3 |
| **CMMS** (IBM Maximo/Asset 360) | Asset maintenance and work order sync | Phase 3 |
| **Measurement / Allocation** (Quorum, P2) | Production accounting integration | Phase 3 |
| **Fuel Logistics** (Tela/AFS) | Dispatch and delivery tracking | Phase 3 |
| **Experience Cloud** | Vendor portal, retail dealer portal | Phase 3 |
| **IoT / IIoT** | Tank monitoring, pipeline sensors | Phase 3 |

---

### 9. Phasing Roadmap

```
Phase 1 (MVP — 1-3 months):
  Data Model:  18 custom objects + enhanced standard objects
  Apex:        8 classes, 6 triggers
  Flows:       8 automations
  LWC:         9 components
  Security:    12 permission sets

Phase 2 (3-6 months):
  SCADA/PI integration (production and pipeline data)
  GIS integration (ArcGIS map layers)
  ERP integration (procurement, inventory)
  E-signature for contracts
  Advanced Well lifecycle management
  Pipeline integrity management

Phase 3 (6-12 months):
  CMMS integration (Maximo/Asset 360)
  Production accounting systems (Quorum/P2)
  IoT/IIoT tank and sensor monitoring
  HSE software integration
  Retail dealer / vendor portal (Experience Cloud)
  Fuel logistics integration
  Advanced analytics and dashboards
```

---

### 10. Key Business Processes (MVP Scope)

| Process | Flow |
|---|---|
| **Lease Acquisition** | Prospect → Land_Parcel → Lease__c → Acquisition Cost → Well Planning |
| **Well Lifecycle** | Spud → Drilling → Completion → Production → Workover → P&A |
| **Production Accounting** | Monthly volumes → Allocation → Revenue Distribution → Royalty Payment |
| **HSE Incident** | Report → Classify → Investigate → Corrective Action → Close → Regulate Report |
| **Permit to Work** | Request → Risk Assessment → Isolation/Test → Approve → Execute → Close |
| **Pipeline Integrity** | Schedule Inspection → Execute → Evaluate → Remediate → Re-inspect |
| **Fuel Distribution** | Refinery → Pipeline/Terminal → Retail Outlet → End Customer |
| **Compliance Cycle** | Permit → Conditions → Monitoring → Report → Renew |
