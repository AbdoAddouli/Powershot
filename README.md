# PowerShot — Oil & Gas Salesforce Solution

> **Project:** `Energy_Salesforce_project`
> **API Version:** 66.0 (some LWC components target 67.0)
> **Last Updated:** September 2026

PowerShot is an integrated **Oil & Gas Salesforce platform** covering the full value chain — from mineral rights and drilling wells to transporting crude, refining it, and selling fuel at retail outlets. The solution includes 31 custom objects, 60 Apex classes, 9 triggers, 11 flows, 15 LWC components, and 20 permission sets across four business segments.

![Value Chain](https://img.shields.io/badge/Upstream-Drilling%20%26%20Production-orange) ![Value Chain](https://img.shields.io/badge/Midstream-Pipelines%20%26%20Transport-blue) ![Value Chain](https://img.shields.io/badge/Downstream-Refining%20%26%20Retail-green) ![Value Chain](https://img.shields.io/badge/Corporate-HSE%20%26%20Compliance-red)

---
## Discover the Architecture in a better visual Design : https://abdoaddouli.github.io/Powershot/
## Table of Contents

1. [Business Domains](#1-business-domains)
2. [Architecture Overview](#2-architecture-overview)
3. [Getting Started](#3-getting-started)
4. [Deployment](#4-deployment)
5. [External Integrations](#5-external-integrations)
6. [Security Model](#6-security-model)
7. [Testing](#7-testing)
8. [Project Structure](#8-project-structure)
9. [Documentation](#9-documentation)
10. [Known Gaps & Roadmap](#10-known-gaps--roadmap)

---

## 1. Business Domains

| Segment | Business Activity | Core Objects |
|---|---|---|
| **Upstream** | Exploration, land leasing, drilling, well operations, production | Well, Lease, Land Parcel, Well Operation, Production Allocation, Joint Venture |
| **Midstream** | Pipeline transport, measurement, nomination scheduling | Pipeline, Pipeline Station, Measurement, Transportation Nomination |
| **Downstream** | Refining, terminal storage, retail fuel sales | Refinery, Terminal, Retail Outlet, Fuel Inventory, Supply Agreement |
| **Corporate** | HSE, regulatory compliance, commercial contracts, invoicing | HSE Incident, Regulatory Permit, Compliance Report, Service Contract, Invoice |

### End-to-End Business Flows

**Well to Revenue:**
```
Land Acquisition → Lease → Well Permitting → Drilling → Production
  → Allocation → Revenue Distribution → Royalty Payment → JV Billing
  → Shut-In → Plug & Abandon
```

**HSE Incident to Resolution:**
```
Incident Occurs → Report → Classify Severity → Regulatory Notification
  → Executive Escalation (if Critical) → Investigation
  → Root Cause → Corrective Action → Close → Lessons Learned
```

**Permit to Work to Field Dispatch:**
```
PTW Request → Risk Assessment → Isolation/Gas Test Validation
  → Authorization Chain → PTW Issued → WorkOrder Created
  → PTW Verification → Field Dispatch → Work Completion → PTW Close
```

**Regulatory Compliance Cycle:**
```
Permit Issued → Compliance Monitoring → Status Updates
  → Expiration Alerts → Report Filing → Renewal → Re-Issue
```

**Inventory Management:**
```
Product Receipt → Volume Update → Transaction Audit
  → Product Dispensed → Decrement → Low Stock Alert
  → Physical Reconciliation → Discrepancy Flagging
```

---

## 2. Architecture Overview

### Component Inventory

| Component | Count | Details |
|---|---|---|
| **Custom Objects** | 31 | + 4 custom settings + 1 platform event |
| **Standard Object Extensions** | 6 | Account, Contact, Asset, Opportunity, Case, WorkOrder |
| **Apex Classes** | 60 | 9 business services, 13 integrations, async/batch, portal controllers, test classes |
| **Apex Triggers** | 9 | Thin-trigger pattern delegating to service classes |
| **LWC Components** | 15 | Record-page, app-page, and Experience Cloud components |
| **Flows** | 11 | 7 scheduled + 4 record-triggered |
| **Permission Sets** | 20 | Role-based access for 13 business roles + portal + GTM |
| **FlexiPages** | 8 | Well, HSE Incident, Lease, Pipeline, Production Allocation, Regulatory Permit, Terminal, Account |
| **Layouts** | 25 | One per Oil & Gas object |
| **Tabs** | 25 | Custom object tabs |
| **Named Credentials** | 9 | Slack, WhatsApp, EIA, OilPriceAPI, EPA, Petrel, GTM/GA4 |
| **GenAI Functions** | 8 | Agentforce actions (4 read / 4 write) |

### Apex Trigger Pattern

All triggers follow a **thin-trigger** pattern — they delegate business logic to service classes and only perform collection/batch setup themselves:

| Trigger | Object | Delegates To |
|---|---|---|
| WellTrigger | Well__c | WellStatusService |
| HSEIncidentTrigger | HSE_Incident__c | HSEIncidentService |
| InspectionTrigger | Inspection__c | InspectionService |
| RegulatoryPermitTrigger | Regulatory_Permit__c | ComplianceDueDateService |
| ProductionAllocationTrigger | Production_Allocation__c | ProductionAllocationService |
| AssetTrigger | Asset | (inline field calc) |
| InvoiceAccountTrigger | Invoice__c | InvoiceAccountService |
| MeasurementTrigger | Measurement__c | (inline anomaly detection) |
| SlackAlertEventTrigger | Slack_Alert__e | SlackAlertQueueable |

### Flows

**Scheduled flows** (7): Compliance_Calendar, Inspection_Due, Joint_Venture_Billing, Land_Lease_Expiration, Production_Reconciliation, Retail_Inventory_Alert, HSE_Critical_Slack_Alert

**Record-triggered flows** (4): Field_Service_Dispatch, HSE_Incident_Escalation, Permit_to_Work_Approval, Regulatory_Permit_Compliance

### Agentforce Integration

The **O&G Operations Assistant** agent is a multi-agent orchestration built with:
- 8 GenAI Functions (Apex-invokable actions — read + confirmation-gated writes)
- 12 GenAI Plugins (8 topic subagents + 4 action groupings)
- 1 GenAI Planner Bundle (Concurrent Multi-Agent Orchestration with router → subagents)
- 1 Bot version for Einstein Service Agent deployment

---

## 3. Getting Started

### Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)
- Node.js 18+ (for LWC Jest testing)
- A Salesforce org (Developer Edition or sandbox)

### Authenticate

```bash
# Authorize your org and give it an alias
sf org login web -o "TARGET_ALIAS" -d
```

### Install Dependencies

```bash
npm install
```

---

## 4. Deployment

This project uses two Salesforce orgs. **Do not confuse them.**

| Alias | Username | Purpose |
|-------|----------|---------|
| `ouil gas` | `addouliabdo9.76deae143000@agentforce.com` | Main Energy project org — all O&G objects, Apex, triggers, LWCs, permission sets, flows, apps deployed here |
| `agentforce` | `addouli@agentfoece.com` | Different org — **do NOT confuse with `ouil gas`** |

### Deploy to the Main Org

```bash
# Deploy a path
sf project deploy start -d "force-app\main\default\PATH" -o "ouil gas"

# Deploy everything
sf project deploy start -d "force-app\main\default" -o "ouil gas" --wait 60
```

### Run Apex Tests

```bash
sf apex run test -o "ouil gas" --result-format human --code-coverage
```

### Deploy to a New Org

Follow the phased deployment plan in **[DEPLOYMENT_PLAN.md](./DEPLOYMENT_PLAN.md)** — it documents the dependency-ordered deployment sequence (objects → classes → flows → UI → security → integrations → Agentforce → Experience Cloud) plus 17 manual post-deployment steps.

---

## 5. External Integrations

| Integration | Direction | Mechanism |
|---|---|---|
| **SCADA / PI** | Inbound telemetry | Signed REST API (`SCADAIngestionAPI`) with HMAC-SHA256 auth, chunked queueable, nightly rollup batch |
| **Commodity Pricing** | Outbound | OilPriceAPI via Named Credential → `CommodityPricingService` + scheduled sync |
| **EIA Pricing** | Outbound | EIA Open Data API via Named Credential → `EIAPricingService` + scheduled sync |
| **Petrel Well Sync** | Bidirectional | Geological well data sync via Named Credential + queueable |
| **WhatsApp Cloud API** | Bidirectional | REST webhook (`WhatsAppWebhookHandler`, GET verify / POST messages) + outbound `WhatsAppMessageService` |
| **Slack (HSE alerts)** | Outbound | Platform event → queueable → named credential webhook |
| **EPA CDX** | Outbound | Regulatory filing service via Named Credential |
| **Google Tag Manager / GA4** | Outbound | Auth provider OAuth + named credentials + LWC (store analytics) |

### SCADA Bridge

The `bridge/` directory contains an on-prem PI → Salesforce bridge:
- `bridge_poc.py` — reference bridge (poll → shape → sign → POST)
- `sender.ps1` — signed test-payload sender
- `scada_bridge.env.example` — configuration template

Full details in [SCADA_PI_INTEGRATION.md](./SCADA_PI_INTEGRATION.md) and [SCADA_PI_BRIDGE.md](./bridge/SCADA_PI_BRIDGE.md).

---

## 6. Security Model

### Permission Sets (20)

| Permission Set | Business Role | Access Level |
|---|---|---|
| `O_G_All_Access` | System Admin | Full CRUD on all objects |
| `O_G_Executive` | C-Suite | Read-only on key objects |
| `O_G_Compliance_Analyst` | Regulatory | CRUD on permits/reports |
| `O_G_Drilling_Engineer` | Drilling | CRUD on Well, Well_Operation |
| `O_G_Production_Engineer` | Production | CRUD on Well, Production_Allocation |
| `O_G_Field_Technician` | Field Tech | CRUD on Inspection, PTW |
| `O_G_HSE_Advisor` | HSE | CRUD on HSE incidents, observations, PTWs |
| `O_G_Pipeline_Engineer` | Pipeline | CRUD on Pipeline, Station, Measurement, Inspection |
| `O_G_Landman` | Land Management | CRUD on Lease, Land_Parcel, Joint_Venture |
| `O_G_Refinery_Manager` | Refinery | CRUD on Refinery, Supply_Agreement |
| `O_G_Retail_Manager` | Retail | CRUD on Retail_Outlet, Fuel_Inventory |
| `O_G_Supply_Chain` | Procurement | CRUD on Service_Contract |
| `O_G_Terminal_Operator` | Terminal | CRUD on Terminal, Fuel_Inventory, Measurement |
| `O_G_Portal_Access` | JV Partner (internal) | Read-only portal objects |
| `O_G_Field_Portal_Access` | Field Portal User | CRUD on Inspection, PTW; Read on incident data |
| `GTM_Integration_Admin` | Marketing Ops | Full access to Store, GTM/GA config |
| `Energy_Tab_Visibility` | All O&G users | Makes 24 tabs visible |
| `Experience_Profile_Manager` | Experience Cloud admin | Community management permissions |
| `GTM_GA_principles_permission` | GTM integration user | UserExternalCredential access |
| `sfdcInternalInt__sfdc_scrt2` | SCRT2 integration | Case read-only |

### Experience Cloud (JV Partner Portal)

The portal grants partners read access to their own entities via the `JV_Partner_Sharing` sharing set (Account-matched):
- Well status, production allocations, invoices, HSE incidents, regulatory permits, compliance reports, leases, joint ventures

---

## 7. Testing

### Apex Tests

```bash
sf apex run test -o "ouil gas" --result-format human --code-coverage
```

14 test classes cover well lifecycle, HSE services, field services, portal controllers, SCADA ingestion, commercial services, EIA pricing, WhatsApp integration, and batch rollups.

### LWC Jest Tests

```bash
npm run test:unit
npm run test:unit:coverage
```

**Note:** No Jest test files exist yet in `force-app` — the sfdx-lwc-jest harness is configured and ready.

### Static Analysis

```bash
sf code-analyzer run --config-file code-analyzer.yml --workspace .
```

---

## 8. Project Structure

```
Energy_Salesforce_project/
├── force-app/main/default/
│   ├── aiEvaluationDefinitions/   # Agentforce test evals (1)
│   ├── apps/                      # PowerShot custom app (1)
│   ├── authproviders/             # Google, Facebook, GitHub, Bitbucket (6)
│   ├── bots/                      # O&G Operations Assistant (1)
│   ├── classes/                   # Apex (60)
│   ├── cspTrustedSites/           # CSP trusted sites (3)
│   ├── externalCredentials/       # External credentials (7)
│   ├── flexipages/                # Lightning record pages (8)
│   ├── flows/                     # Flows (11)
│   ├── genAiFunctions/            # Agentforce invocable actions (8)
│   ├── genAiPlannerBundles/       # Multi-agent orchestration (1)
│   ├── genAiPlugins/              # Agent topics & actions (12)
│   ├── groups/                    # Exec Leadership, HSE Compliance Team
│   ├── layouts/                   # Page layouts (25)
│   ├── lwc/                       # LWC components (15)
│   ├── namedCredentials/          # Named credentials (9)
│   ├── networks/                  # Experience Cloud networks (2)
│   ├── objects/                   # Custom objects, fields, validation rules
│   ├── permissionsets/            # Permission sets (20)
│   ├── profiles/                  # Admin + WhatsApp webhook profile
│   ├── remoteSiteSettings/        # Remote sites (5)
│   ├── sharingRules/              # Sharing rules (10)
│   ├── sharingSets/               # JV partner sharing set (1)
│   ├── sites/                     # Experience sites (2)
│   ├── tabs/                      # Custom tabs (25)
│   └── triggers/                  # Apex triggers (9)
├── bridge/                        # SCADA/PI on-prem bridge
├── manifest/                      # Package manifests for org migrations
├── scripts/                       # Apex/SOQL utility scripts
├── specs/                         # Agentforce agent test specs
├── docs/                          # Deep-dive technical docs
├── DEPLOYMENT_PLAN.md             # Phased deployment + manual post-deploy steps
├── DATA_MODEL.md                  # Object/field reference
├── POWERSHOT_DOCUMENTATION.md     # Full platform documentation v1.5
└── ...
```

---

## 9. Documentation

| Document | Purpose |
|---|---|
| [PROJECT_DESCRIPTION.md](./PROJECT_DESCRIPTION.md) | Business story, domain workflows, end-to-end flows |
| [DEPLOYMENT_PLAN.md](./DEPLOYMENT_PLAN.md) | Phased deployment plan + 17 manual post-deployment steps |
| [DATA_MODEL.md](./DATA_MODEL.md) | Full object/field reference |
| [POWERSHOT_DOCUMENTATION.md](./POWERSHOT_DOCUMENTATION.md) | Main platform doc — architecture, patterns, deployment guide (v1.5) |
| [BUSINESS_PROCESS_MAPPING.md](./BUSINESS_PROCESS_MAPPING.md) | Business processes → objects → automation mapping |
| [ENHANCEMENT_GUIDE.md](./ENHANCEMENT_GUIDE.md) | 9-phase enhancement roadmap with implementation code |
| [SCADA_PI_INTEGRATION.md](./SCADA_PI_INTEGRATION.md) | Operator go-live manual for SCADA/PI bridge |
| [SCADA_PI_INTEGRATION_PLAN.md](./SCADA_PI_INTEGRATION_PLAN.md) | SCADA/PI integration phases |
| [WHATSAPP_INTEGRATION_PLAN.md](./WHATSAPP_INTEGRATION_PLAN.md) | WhatsApp Cloud API integration |
| [DOCUSIGN_INTEGRATION_PLAN.md](./DOCUSIGN_INTEGRATION_PLAN.md) | DocuSign eSignature plan (planned) |
| [EXPERIENCE_CLOUD_PORTAL_ARCHITECTURE.md](./EXPERIENCE_CLOUD_PORTAL_ARCHITECTURE.md) | JV Partner Portal architecture |
| [PowerShot_ARCHITECTURE.md](./PowerShot_ARCHITECTURE.md) | Original architecture — data model & phased build |
| [HEADLESS_360_ARCHITECTURE.md](./HEADLESS_360_ARCHITECTURE.md) | MCP/HXL headless operations over Agentforce |
| [PHASE_2_MCP_BINDING.md](./PHASE_2_MCP_BINDING.md) | Agentforce subagent → tool binding status |
| [API_INTEGRATIONS.md](./API_INTEGRATIONS.md) | Curated real-world APIs for integrations |

---

## 10. Known Gaps & Roadmap

### Known Gaps
- Apex test coverage ~39% (75% required for production deployment)
- No Jest tests for LWC components
- No page-layout-to-profile assignments implemented (layouts deploy unassigned)
- `InspectionService.submitChecklist()` references a non-existent `Comment__c` field
- Slack, WhatsApp, GTM/GA4 secrets must be configured post-deployment (placeholder values in repo)
- `HSE_Incident_Escalation` flow deploys as Draft
- Agentforce live-agent subagent wiring requires the Agentforce Builder UI

### Roadmap
1. **Quick Wins:** Slack HSE alerts, commodity pricing, production dashboard
2. **API Integrations:** SCADA pipeline monitoring, drilling data sync, regulatory filing
3. **Einstein AI:** Production forecasting, pipeline failure prediction, inventory prediction
4. **Experience Cloud:** Partner portal for JV partners, suppliers, regulators
5. **Advanced Analytics:** Executive KPIs, automated PDF statements
6. **Data Cloud:** Unified data model across all data sources

---

### License

Private — for internal use only.
