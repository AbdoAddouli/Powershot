# Solar/ Renewables Salesforce Architecture

## Overview

This document defines the architecture for a greenfield Salesforce org serving the **Solar / Renewables** sector. The solution covers the full customer lifecycle: lead generation → sales → installation → asset management → service → compliance.

| Property | Value |
|---|---|
| **Domain** | Solar / Renewables |
| **Org Type** | New greenfield org |
| **Salesforce API** | v67.0 (Spring 2025) |
| **MVP Timeline** | 1–3 months |
| **Full Scope** | Customer Mgmt, Sales, Projects, Assets, Service, Compliance, Partners, Billing |

---

## Phase 1: MVP (1–3 months)

---

### 1. Data Model

#### 1.1 Enhanced Standard Objects  

| Object | Record Types | Key Custom Fields |
|---|---|---|
| **Account** | Customer, Partner/Installer, Supplier, Utility Company | `Customer_Since__c`, `Credit_Score__c`, `Business_Type__c` |
| **Contact** | — | `Role__c` (Primary, Billing, Emergency, Site), `Language_Preference__c` |
| **Lead** | — | `Monthly_Electric_Bill__c`, `Roof_Type__c`, `Shade_Factor__c`, `Solar_Interest__c` (Own/Lease/PPA), `Site_Address__c` |
| **Opportunity** | Purchase, Lease, PPA | `System_Size_KW__c`, `Estimated_Production_kWh__c`, `Total_System_Cost__c`, `Incentive_Amount__c`, `Payback_Years__c`, `Financing_Type__c` |
| **Case** | Warranty, Maintenance, Performance, General | `Asset__c` (lookup), `Site__c`, `Service_Priority__c` |
| **Product** | Solar Panel, Inverter, Battery, Racking, Monitoring | `Wattage__c`, `Efficiency__c`, `Warranty_Months__c`, `Manufacturer__c`, `Panel_Type__c` |

#### 1.2 Custom Objects (MVP)

| Object | Type | Key Fields |
|---|---|---|
| **Site__c** | Master-Detail (Account) | Roof_Type, Roof_Orientation, Shading_Factor, Utility_Company, Monthly_Bill, Annual_kWh, Solar_Access_Percent, AHJ |
| **System_Design__c** | Lookup (Opportunity, Site) | DC/AC_Size_KW, Panel_Count, Panel/Inverter/Battery_Model (Product lookup), Est_Annual_Production, Offset_Percent, Status (Draft→Approved) |
| **Installation_Project__c** | Lookup (Opportunity, Site) | Status (Scheduled→Complete), PM, Lead_Installer, Permitting/Inspection/PTO_Status, Completion_Date |
| **Solar_Asset__c** | Master-Detail (Site or Account) | Asset_Type, Product, Serial_Number, Warranty_Exp, Status (Active→Retired), Rated_Wattage |
| **Incentive__c** | Lookup (Opportunity, Site) | Type (Federal/State/Utility/SREC), Amount, Status (Available→Paid), Expiration |
| **Permit__c** | Lookup (Installation_Project) | Type (Building/Electrical/HOA), AHJ, Status (Draft→Issued), Fee, Permit_Number |
| **Contract__c** | Lookup (Account, Opportunity) | Type (Purchase/Lease/PPA/Service), Term, Monthly_Payment, Total_Value, Status (Draft→Active→Terminated) |

**Total: 7 custom objects (MVP)**

---

### 2. Object Relationships

```
Account (Customer)
├── Contact (multiple roles)
├── Site__c (1+)
│   ├── Solar_Asset__c (1+)
│   └── System_Design__c
├── Installation_Project__c (1+)
│   ├── Permit__c (1+)
│   └── Inspections
├── Contract__c (1+)
├── Opportunity (1+)
│   ├── System_Design__c
│   ├── Incentive__c
│   └── Quote (standard)
├── Case (1+)
└── Lead (converted)

Account (Partner/Installer)
├── Contact (installer team)
├── Service_Area__c (custom)
└── Installation_Project__c (as Lead_Installer)
```

---

### 3. Apex Classes (MVP)

| Class | Responsibility |
|---|---|
| `LeadScoringService` | Score leads by intent, bill, roof suitability |
| `SystemProductionCalculator` | Estimate kWh production (formula or API callout) |
| `IncentiveCalculator` | Determine applicable rebates by location |
| `OpportunityStageService` | Validate stage transitions, auto-advance |
| `ProjectMilestoneService` | Auto-update project statuses, send notifications |
| `SolarAssetTriggerHandler` | Maintain asset hierarchy, warranty tracking |
| `SiteTriggerHandler` | Geocode address, validate utility compatibility |

**Triggers:** `OpportunityTrigger`, `AccountTrigger`, `SiteTrigger`, `SolarAssetTrigger`

---

### 4. Flows (MVP)

| Flow | Trigger / Schedule |
|---|---|
| **Lead Assignment** | On Lead create — route by territory/source |
| **Opportunity Qualification** | On Stage change — collect site & design data |
| **Project Creation** | On Opportunity Closed Won — auto-create Installation_Project |
| **Installation Milestones** | On Project status change — notify PM, customer, partner |
| **Welcome Sequence** | On Project Completed — customer onboarding email |
| **Warranty Claim Routing** | On Case create (Warranty) — route to service team |

---

### 5. LWC Components (MVP)

| Component | Purpose |
|---|---|
| **solarCalculator** | Lead capture — solar savings estimator |
| **siteSelector** | Interactive map for site location & solar potential |
| **systemDesignViewer** | Read-only design summary on Opportunity page |
| **projectTimeline** | Milestone tracker on Installation_Project record |
| **productionDashboard** | Real-time/historical production charts |
| **incentiveWizard** | Step-through incentive discovery per location |
| **partnerMap** | Partner coverage map for lead routing |

---

### 6. Security Model

#### Role Hierarchy

```
CEO
├── VP Sales
│   ├── Sales Manager
│   │   └── Sales Rep
│   └── Sales Operations
├── Project Director
│   ├── Project Manager
│   └── Lead Installer (Partner)
├── Service Manager
│   └── Service Technician
└── Compliance Officer
```

#### Permission Sets

| Permission Set | Access |
|---|---|
| **Solar_Sales_Rep** | CRUD on Opportunity, Lead, Site, System_Design; read on Asset, Install_Project |
| **Solar_Sales_Manager** | Same as Sales Rep + read all, manage incentives |
| **Solar_Project_Manager** | CRUD on Installation_Project, Permits, Solar_Asset, Contract |
| **Solar_Installer_Partner** | Read Site/Design, update Install_Project (limited), create Service Case |
| **Solar_Service_Technician** | CRUD on Case, read Solar_Asset, asset history |
| **Solar_Compliance_Officer** | Read all, CRUD on Permits, Incentives, regulatory export |

---

### 7. Integrations (Post-MVP Roadmap)

| Integration | Purpose | Phase |
|---|---|---|
| **NREL PVWatts API** | Solar production estimation by lat/lon | Phase 2 |
| **Google Sunroof / Aurora** | Solar design automation | Phase 2 |
| **DocuSign** | E-sign contracts | Phase 2 |
| **Enphase / SolarEdge API** | Real-time production monitoring | Phase 3 |
| **Payment Gateway** (Stripe) | Customer payments | Phase 3 |
| **Experience Cloud** (Customer Portal) | Self-service portal | Phase 3 |
| **ERP** (Netsuite/SAP) | Billing and accounting | Phase 3 |

---

### 8. Phasing Roadmap

```
Phase 1 (MVP — 1-3 months):
  Data Model:  7 custom objects + enhanced standard objects
  Apex:        7 classes, 4 triggers
  Flows:       6 automations
  LWC:         7 components
  Security:    6 permission sets

Phase 2 (3-6 months):
  Incentives & Permits enrichment
  Partner/Contractor management
  E-signature and solar design API integration
  Advanced Case/SLA management
  Production monitoring dashboard

Phase 3 (6-12 months):
  Customer portal (Experience Cloud)
  Real-time monitoring (Enphase/SolarEdge API)
  Mobile field service app
  BI dashboards and AI/ML lead scoring
  ERP integration
```

---

### 9. Decision Log

| Decision | Options | Status |
|---|---|---|
| Residential vs Commercial vs Both | Residential / Commercial / Both | Pending |
| Financing models at MVP | Purchase / Lease / PPA | Pending |
| Existing backend (ERP, monitoring) | None / In-place | Pending |
| Partner access model | Direct Salesforce login / Portal | Pending |
