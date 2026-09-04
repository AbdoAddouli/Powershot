# PowerShot Headless 360 Architecture

**Version:** 1.0 | **Date:** 2026-08-26 | **Status:** Conceptual Architecture — Phase 0-1 implemented & verified (78/78 tests); agent `O_G_Operations_Assistant` built, activated & source-captured; Phase 2+ deferred → see **PHASE_2_MCP_BINDING.md**

---

## The Concept

PowerShot currently has **one consumer**: humans clicking through Lightning pages. Headless 360 adds **infinite consumers** — AI agents, Slack bots, Teams, WhatsApp, mobile apps, custom React frontends — all reusing the same Apex services, triggers, flows, and data model you already built.

Two directions:
- **MCP (Inbound)**: External agents call INTO PowerShot
- **HXL (Outbound)**: PowerShot pushes experiences OUT to any surface

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         POWERSHOT HEADLESS 360                           │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    SURFACES (Consumers)                         │    │
│  │                                                                 │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐          │    │
│  │  │  Slack   │  │ Teams   │  │WhatsApp │  │ Mobile  │          │    │
│  │  │(Field    │  │(Office  │  │(Contract│  │  App    │          │    │
│  │  │ Crew)    │  │ Staff)  │  │ Workers)│  │(Any)    │          │    │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘          │    │
│  │       │             │            │             │                │    │
│  │  ┌────┴─────────────┴────────────┴─────────────┴────┐          │    │
│  │  │         HEADLESS EXPERIENCE LAYER (HXL)          │          │    │
│  │  │    "Define once → Render natively everywhere"    │          │    │
│  │  └─────────────────────┬────────────────────────────┘          │    │
│  └─────────────────────────┼───────────────────────────────────────┘    │
│                              │                                           │
│  ┌──────────────────────────┼───────────────────────────────────────┐  │
│  │                    AGENTFORCE LAYER                               │  │
│  │  ┌───────────────────────┴──────────────────────────────┐        │  │
│  │  │              Agentforce Runtime                       │        │  │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌────────────┐ │        │  │
│  │  │  │ Agentforce   │  │  Agentforce  │  │  Agentforce│ │        │  │
│  │  │  │ HSE Agent    │  │  Ops Agent   │  │  Comply    │ │        │  │
│  │  │  │ (Incidents)  │  │  (Wells)     │  │  Agent     │ │        │  │
│  │  │  └──────────────┘  └──────────────┘  └────────────┘ │        │  │
│  │  └──────────────────────────────────────────────────────┘        │  │
│  └──────────────────────────┬───────────────────────────────────────┘  │
│                              │                                           │
│  ┌──────────────────────────┼───────────────────────────────────────┐  │
│  │               MCP SERVERS (Inbound Path)                         │  │
│  │                                                                   │  │
│  │  ┌──────────────────────────────────────────────────────────┐    │  │
│  │  │         Headless 360 MCP Server (Beta)                   │    │  │
│  │  │   Discover → Describe → Dispatch → Dispatch (Read-Only)  │    │  │
│  │  │   ~100+ skills, growing to thousands                     │    │  │
│  │  └───────────────────────┬──────────────────────────────────┘    │  │
│  │                          │                                        │  │
│  │  ┌───────────────────────┴──────────────────────────────────┐    │  │
│  │  │              SObject MCP Servers                          │    │  │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │    │  │
│  │  │  │ sobject-     │  │ sobject-     │  │ sobject-     │   │    │  │
│  │  │  │ reads        │  │ mutations    │  │ deletes      │   │    │  │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘   │    │  │
│  │  └──────────────────────────────────────────────────────────┘    │  │
│  │                                                                   │  │
│  │  ┌──────────────────────────────────────────────────────────┐    │  │
│  │  │          Custom MCP Server (PowerShot-Specific)           │    │  │
│  │  │  Named Queries + Invocable Actions for least-privilege   │    │  │
│  │  │  access to sensitive O&G objects                          │    │  │
│  │  └──────────────────────────────────────────────────────────┘    │  │
│  └──────────────────────────┬───────────────────────────────────────┘  │
│                              │                                           │
│  ┌──────────────────────────┼───────────────────────────────────────┐  │
│  │               SALESFORCE PLATFORM (PowerShot)                    │  │
│  │                                                                   │  │
│  │  ┌──────────────────────────────────────────────────────────┐    │  │
│  │  │              BUSINESS LOGIC LAYER                         │    │  │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │    │  │
│  │  │  │   Apex      │  │   Triggers  │  │    Flows        │  │    │  │
│  │  │  │  Services   │  │    (8)      │  │    (11)         │  │    │  │
│  │  │  │  (40 cls)   │  │             │  │                 │  │    │  │
│  │  │  └─────────────┘  └─────────────┘  └─────────────────┘  │    │  │
│  │  └──────────────────────────────────────────────────────────┘    │  │
│  │                                                                   │  │
│  │  ┌──────────────────────────────────────────────────────────┐    │  │
│  │  │              DATA LAYER (28 Objects, 310+ Fields)         │    │  │
│  │  │  Upstream │ Midstream │ Downstream │ HSE │ Commercial    │    │  │
│  │  └──────────────────────────────────────────────────────────┘    │  │
│  │                                                                   │  │
│  │  ┌──────────────────────────────────────────────────────────┐    │  │
│  │  │              GOVERNANCE LAYER                             │    │  │
│  │  │  Permission Sets (18) │ Validation Rules (10)            │    │  │
│  │  │  Sharing Rules │ Field-Level Security │ Named Credentials │    │  │
│  │  └──────────────────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │              EXTERNAL INTEGRATIONS (via Named Credentials)       │  │
│  │  OilPriceAPI │ EIA │ Petrel │ EPA CDX │ Slack │ GTM/GA4 │ SCADA │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │              CODING AGENTS (Dev-Time MCP)                        │  │
│  │  Claude Code │ Cursor │ Codex │ Windsurf                        │  │
│  │  → 60+ MCP tools │ 30+ coding skills │ DevOps Center MCP        │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## The 5 Tiers Mapped to PowerShot

### Tier 1: System of Context (Data 360)

| PowerShot Data | How It Serves Agents |
|---|---|
| **Well__c** (28 objects, 310+ fields) | Agent reads field definitions, picklist values, relationships to understand "what is a well" without prompts |
| **Production_Allocation__c** | Agent queries production volumes, WI/NRI shares for reasoning tasks |
| **HSE_Incident__c** | Agent understands severity classification, incident types from metadata descriptions |
| **Regulatory_Permit__c** | Agent reads compliance status, expiration dates to make renewal decisions |
| **Named Credentials** (8) | Agent callouts use same auth infrastructure (no hardcoded keys) |
| **API_Key_Settings__c** (Protected) | API keys travel with the trust layer, never exposed to agents |

**Key Insight**: Your metadata layer (field names, descriptions, picklist values, relationships) becomes **machine-readable business context**. An agent querying `Well__c.Status__c` picklist values understands the lifecycle: `Permitted → Drilling → Producing → Shut-In → Suspended → Plugged → Abandoned`.

---

### Tier 2: System of Work (Customer 360 — Apex + Flows)

| PowerShot Logic | Headless Exposure |
|---|---|
| `WellStatusService.isValidTransition()` | Callable via MCP tool — agent validates well status changes |
| `HSEIncidentService.classifySeverities()` | Agent classifies incidents without re-implementing logic |
| `PermitToWorkValidationService.getMissingRequirements()` | Agent checks PTW compliance before approving work |
| `ComplianceDueDateService.getUpcomingRenewals()` | Agent proactively monitors permit renewals |
| `ProductionAllocationService.calculateMonthlyAllocation()` | Agent calculates allocations on demand |
| `PipelineIntegrityService.flagNonCompliantPipelines()` | Agent identifies pipeline issues autonomously |
| 8 Apex Triggers | Fire identically regardless of entry point (browser, MCP, HXL) |
| 11 Flows | Execute the same business rules for agents and humans |

**Key Insight**: Every Apex service, trigger, and flow you already built is **automatically available** via MCP. No rewrite needed. The agent calls your existing `@AuraEnabled` methods or `InvocableMethod` annotations.

---

### Tier 3: System of Agency (Agentforce)

| Agent | Domain | PowerShot Capabilities |
|---|---|---|
| **HSE Agent** | Safety | Classify incidents, escalate critical events, notify compliance teams, trigger Slack alerts |
| **Ops Agent** | Wells | Check well status, validate lifecycle transitions, query production data, flag declining wells |
| **Compliance Agent** | Regulatory | Monitor permit expirations, generate compliance reports, track regulatory filings |
| **Retail Agent** | Downstream | Monitor fuel inventory levels, trigger restock alerts, reconcile discrepancies |
| **Field Service Agent** | Cross-Domain | Dispatch crews, verify PTW issuance, validate gas test results |

**Key Insight**: Agents inherit PowerShot's 18 permission sets, 10 validation rules, sharing rules, and field-level security. An HSE Agent cannot see financial data. A Retail Agent cannot modify well records.

---

### Tier 4: System of Engagement (HXL — Headless Experience Layer)

| Surface | User | PowerShot Experience |
|---|---|---|
| **Slack** | Field Technicians | Permit-to-Work cards, inspection checklists, HSE incident alerts — rendered natively in Slack threads |
| **Slack** | Pipeline Engineers | Pipeline compliance status cards, anomaly alerts from MeasurementTrigger |
| **Microsoft Teams** | Office Staff | Production allocation reports, compliance calendar, JV billing summaries |
| **WhatsApp** | Contractors | PTW approval requests, gas test result submission, safety briefings |
| **Mobile App** | Field Crews | Well production charts, tank gauge visualizations, inspection forms |
| **ChatGPT/Claude** | Analysts | Conversational queries: "Show me all Critical HSE incidents this quarter" |
| **Custom React** | Executives | Executive dashboard with production, HSE, compliance lenses |

**Key Insight**: Your 9 LWCs (complianceCalendar, inventoryTankGauge, permitToWorkBoard, etc.) define the **business intent** once. HXL renders that intent as Slack blocks, Teams cards, mobile views — without rebuilding per surface.

---

### Tier 5: System of Insight (Tableau + Analytics)

| Insight | Source | Surface |
|---|---|---|
| Production decline trends | Well__c.Total_Oil_Volume_12M__c + Is_Declining__c | Tableau dashboard → Slack summary |
| HSE incident hotspots | HSE_Incident__c + Location__c | Map visualization → Teams card |
| Pipeline integrity heat map | Pipeline__c.Compliance_Status__c + Last_Inspection_Date__c | Tableau → Executive Slack channel |
| Regulatory expiration forecast | Regulatory_Permit__c.Expiration_Date__c | Conversational analytics in ChatGPT |

---

## MCP Server Architecture (Inbound Path)

### Server 1: Headless 360 MCP Server (Platform)

```
External Agent (Claude, ChatGPT, Cursor)
        │
        ▼
┌─────────────────────────────────────────┐
│  platform/headless-360 MCP Server       │
│                                         │
│  1. DISCOVER                            │
│     "How do I check well status?"       │
│     → Returns: WellStatusService        │
│       .getWellProduction                │
│                                         │
│  2. DESCRIBE                            │
│     → Returns: API contract, params,    │
│       dependencies, ordered steps       │
│                                         │
│  3. DISPATCH                            │
│     → Routes to Apex service            │
│     → Enforces user access guard        │
│     → Returns: Well production data     │
│                                         │
│  4. DISPATCH (Read-Only)                │
│     → Same as DISPATCH but never        │
│       modifies data                     │
└─────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────┐
│  PowerShot Apex Services                │
│  (WellStatusService, HSEIncidentService,│
│   ComplianceDueDateService, etc.)       │
└─────────────────────────────────────────┘
```

**At launch (Beta, July 2026)**: ~100 skills focused on Setup operations.
**Growing to**: Cloud-specific skills for business users — covering your O&G objects.

---

### Server 2: SObject MCP Servers (Standard)

```
External Agent
        │
        ▼
┌─────────────────────────────────────────┐
│  sobject-reads MCP Server               │
│  Query Well__c, HSE_Incident__c, etc.  │
│  (Respects FLS, sharing rules)         │
├─────────────────────────────────────────┤
│  sobject-mutations MCP Server           │
│  Create/Update records                  │
│  (Triggers fire, validation rules hold) │
├─────────────────────────────────────────┤
│  sobject-deletes MCP Server             │
│  Delete records                         │
│  (Restricted access)                    │
└─────────────────────────────────────────┘
```

**Risk**: Gives agent access to everything the connected user can see.
**Mitigation**: Use Permission Sets to restrict what `O_G_All_Access`, `O_G_Field_Technician`, etc. expose.

---

### Server 3: Custom MCP Server (PowerShot-Specific) — RECOMMENDED

```
External Agent
        │
        ▼
┌─────────────────────────────────────────────┐
│  PowerShot Custom MCP Server                │
│  (Named Queries + Invocable Actions)        │
│                                             │
│  NAMED QUERIES (Read-Only):                 │
│  ┌─────────────────────────────────────┐    │
│  │ getWellByApiNumber                  │    │
│  │ → Returns: Status, Type, Formation, │    │
│  │   Lease, Account (NOT financials)   │    │
│  ├─────────────────────────────────────┤    │
│  │ getOpenHSEIncidents                 │    │
│  │ → Returns: Type, Severity, Location,│    │
│  │   Status (NOT corrective actions)   │    │
│  ├─────────────────────────────────────┤    │
│  │ getExpiringPermits                  │    │
│  │ → Returns: Permit Type, Expiry,     │    │
│  │   Compliance Status                  │    │
│  ├─────────────────────────────────────┤    │
│  │ getInventoryLevels                  │    │
│  │ → Returns: Product, Volume,         │    │
│  │   Threshold, Discrepancy Flag       │    │
│  └─────────────────────────────────────┘    │
│                                             │
│  INVOCABLE ACTIONS (Write):                 │
│  ┌─────────────────────────────────────┐    │
│  │ createHSEIncident                   │    │
│  │ → Validates required fields         │    │
│  │ → Triggers HSEIncidentTrigger       │    │
│  │ → Classifies severity automatically │    │
│  ├─────────────────────────────────────┤    │
│  │ updatePTWStatus                     │    │
│  │ → Validates gas test, isolation     │    │
│  │ → Enforces authorization chain      │    │
│  ├─────────────────────────────────────┤    │
│  │ recordInventoryMovement             │    │
│  │ → Updates Fuel_Inventory__c         │    │
│  │ → Flags discrepancies               │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

**Why Custom**: Principle of least privilege. Agent gets access to ONLY what it needs, not everything the user can see.

---

## Headless Experience Layer (Outbound Path)

### How HXL Works

```
Agent determines action
        │
        ▼
┌─────────────────────────────────────────┐
│  Agentforce Runtime                     │
│  (Reasons about the task)               │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│  Headless Experience Layer (HXL)        │
│                                         │
│  Business Intent:                       │
│  "Show PTW approval card with           │
│   Permit Type, Risk Level, Gas Test,    │
│   Authorization Status"                 │
│                                         │
│  Renders as:                            │
│  ├─→ Slack Block Kit (Slack users)      │
│  ├─→ Teams Adaptive Card (Teams users)  │
│  ├─→ Mobile Card (mobile app)           │
│  ├─→ ChatGPT Response (ChatGPT users)   │
│  └─→ React Component (custom web)       │
└─────────────────────────────────────────┘
```

### PowerShot HXL Experiences

| Experience | Business Intent | Surfaces |
|---|---|---|
| **PTW Approval Card** | Permit details + Approve/Reject buttons | Slack, Teams, WhatsApp |
| **HSE Incident Alert** | Severity badge + Location + Incident Type | Slack, Mobile, Teams |
| **Well Status Card** | API Number + Status + Formation + Lease | Slack, Teams, Mobile |
| **Inventory Gauge** | Fill % + Color band (green/yellow/red) | Slack, Mobile, Custom Web |
| **Compliance Deadline** | Permit type + Days until expiry + Action | Slack, Teams, ChatGPT |
| **Production Summary** | Oil/Gas/Revenue totals + Period selector | Slack, Teams, Tableau |

---

## Step-by-Step Implementation Plan

### Phase 0: Foundation Check (Week 1)

```
□ Verify metadata descriptions are complete on all 28 objects
□ Ensure all @AuraEnabled methods have proper documentation
□ Confirm InvocableMethod annotations exist on key services
□ Validate Named Credentials are functional
□ Ensure permission sets correctly scope object access
```

### Phase 1: MCP Server Activation (Week 2-3)

```
Step 1: Enable Headless 360 MCP Server (Beta)
  → Salesforce Setup → MCP Servers → Enable platform/headless-360

Step 2: Enable SObject MCP Servers
  → Enable sobject-reads, sobject-mutations
  → Configure per permission set

Step 3: Build Custom MCP Server
  → Create Named Queries for each PowerShot domain
    - Upstream: Wells, Leases, Production
    - Midstream: Pipelines, Inspections, Measurements
    - Downstream: Inventory, Retail, Fuel
    - HSE: Incidents, Observations, PTW
    - Regulatory: Permits, Compliance Reports

Step 4: Create Invocable Actions
  → Wrap existing Apex services as invocable methods
  → Add input validation and error handling
  → Test with Agentforce Testing Center
```

### Phase 2: Agentforce Agents (Week 4-6)

```
Step 5: Define Agentforce Agents
  → HSE Agent: Tools = getOpenHSEIncidents, createHSEIncident
  → Ops Agent: Tools = getWellByApiNumber, getWellProduction
  → Compliance Agent: Tools = getExpiringPermits, fileComplianceReport

Step 6: Configure Agent Guardrails
  → Agent Script: Define which behaviors follow business logic
  → Custom Scoring Evals: Define what "good" looks like
  → Set token limits and retry policies

Step 7: Test with Agentforce Testing Center
  → Run 100+ scenarios per agent
  → Validate: Does HSE Agent correctly classify Critical incidents?
  → Validate: Does Compliance Agent respect 90-day renewal window?
  → Validate: Does Ops Agent enforce well lifecycle transitions?
```

### Phase 3: Headless Experience Layer (Week 7-9)

```
Step 8: Define HXL Experiences
  → Convert existing LWC business intents to HXL definitions
  → Start with: permitToWorkBoard, hseIncidentMap, inventoryTankGauge

Step 9: Configure Surface Targets
  → Slack: HXL for Slack (GA) — deploy to #field-ops channel
  → Teams: HXL for Teams — deploy to Operations team
  → Mobile: HXL for Mobile — deploy to field crew app

Step 10: Test Cross-Surface Consistency
  → Verify: PTW card renders identically in Slack and Teams
  → Verify: Same permissions enforce on all surfaces
  → Verify: Action buttons (Approve/Reject) work on all surfaces
```

### Phase 4: Governance & Observability (Week 10-12)

```
Step 11: Enable Session Tracing
  → Monitor agent decisions across all PowerShot objects
  → Track: Which MCP tools agents call, in what order

Step 12: Configure A/B Testing
  → Test two agent versions for HSE escalation
  → Measure: Which version correctly escalates more Critical incidents

Step 13: Set Up Observability
  → Dashboard: Agent tool call frequency, error rates, latency
  → Alerts: When agent exceeds governor limits or fails validation
  → Audit trail: Every agent action logged with user identity
```

---

## Security Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    TRUST BOUNDARY                        │
│                                                          │
│  Every MCP call, HXL render, and Agent action:          │
│                                                          │
│  1. IDENTITY                                             │
│     → Agent acts as specific Salesforce user             │
│     → Not anonymous — authenticated via OAuth 2.0       │
│                                                          │
│  2. ACCESS                                               │
│     → 18 Permission Sets enforce what agent sees         │
│     → Field-Level Security on 310+ fields                │
│     → Sharing Rules limit record visibility              │
│                                                          │
│  3. INVOCATION SCOPE                                     │
│     → Custom MCP Server exposes ONLY named queries       │
│     → Agent cannot access objects/fields not exposed     │
│     → Invocable Actions validate all inputs              │
│                                                          │
│  4. GOVERNANCE                                           │
│     → 10 Validation Rules fire on every write            │
│     → 8 Triggers enforce business logic                  │
│     → 11 Flows execute regardless of entry point         │
│     → Governor limits apply identically                  │
│                                                          │
│  5. AUDIT                                                │
│     → Every agent action logged                          │
│     → Session Tracing shows reasoning path               │
│     → Shield Event Monitoring detects anomalies          │
└─────────────────────────────────────────────────────────┘
```

---

## What Changes vs. What Stays

| Component | Current State | With Headless 360 |
|---|---|---|
| **Well__c data model** | 12 fields, status lifecycle | Same — agents read metadata to understand it |
| **WellStatusService** | Called by WellTrigger | Same — also callable via MCP tool |
| **HSEIncidentTrigger** | Fires on I/U | Same — fires when agent creates incident via MCP |
| **Permission Sets** | 18 sets, human-assigned | Same — agents inherit user's permission set |
| **Validation Rules** | 10 rules | Same — fire on agent writes too |
| **Named Credentials** | 8 credentials | Same — agent callouts use same auth |
| **LWC Components** | 9 components on Lightning pages | Same — also rendered via HXL to Slack/Teams |
| **Scheduled Jobs** | 8 Apex/Flow schedules | Same — also completable by agents |
| **New: MCP Servers** | — | Inbound path for external agents |
| **New: HXL** | — | Outbound path to any surface |
| **New: Agentforce Agents** | — | Domain-specific AI agents |
| **New: Observability** | — | Session tracing, A/B testing, scoring |

---

## Bottom Line

PowerShot's architecture is **already 80% ready** for Headless 360 because:

1. **Business logic is in Apex/Triggers/Flows** — not buried in UI code
2. **Metadata is well-defined** — 28 objects with clear field names, picklists, relationships
3. **Governance exists** — validation rules, sharing rules, permission sets
4. **Named Credentials exist** — auth infrastructure is in place
5. **Services use @AuraEnabled and InvocableMethod** — already agent-callable

The remaining 20% is: enabling MCP servers, defining named queries for least-privilege access, configuring HXL surface targets, and testing with Agentforce Testing Center.

---

## References

| Reference | URL |
|---|---|
| Headless 360 Product Page | https://www.salesforce.com/headless/ |
| Headless 360 Architecture Blog | https://www.salesforce.com/blog/systems-headless-360-architecture/ |
| Headless 360 MCP Server Docs | https://developer.salesforce.com/docs/platform/hosted-mcp-servers/references/reference/headless-360-mcp.html |
| HXL Product Page | https://www.salesforce.com/headless/agentic-experience-layer/ |
| Headless 360 Integration Architecture | https://www.salesforce.com/blog/headless-360-integration-architecture/ |
| PowerShot Documentation | ./POWERSHOT_DOCUMENTATION.md |
| Enhancement Guide | ./ENHANCEMENT_GUIDE.md |
