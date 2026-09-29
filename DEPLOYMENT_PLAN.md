# PowerShot — Deployment Plan

> **Source Org:** `ouil gas` (`addouliabdo9.76deae143000@agentforce.com`)
> **Target Org:** _(fill in alias or username)_
> **API Version:** 66.0 (some LWCs target 67.0)
> **Date:** September 2026

---

## Table of Contents

1. [Pre-Deployment Checklist](#1-pre-deployment-checklist)
2. [Deployment Phases](#2-deployment-phases)
   - Phase 0: Connectivity & Validation
   - Phase 1: Standard Object Extensions
   - Phase 2: Anchor Custom Objects (no cross-obj deps)
   - Phase 3: Level 2 Objects
   - Phase 4: Level 3 Objects
   - Phase 5: Level 4 Objects (leaf nodes)
   - Phase 6: Remaining Objects & Custom Settings
   - Phase 7: Apex Classes & Triggers
   - Phase 8: Flows
   - Phase 9: UI — Layouts, Tabs, FlexiPages, LWCs, App
   - Phase 10: Security — Permission Sets, Profiles, Groups
   - Phase 11: Sharing Rules & Sharing Sets
   - Phase 12: Integrations — Auth Providers, Credentials, Remote Sites
   - Phase 13: Agentforce — Bot, GenAI Plugins, Functions, Planner
   - Phase 14: Experience Cloud — Networks, Sites
3. [Post-Deployment Manual Steps](#3-post-deployment-manual-steps)
4. [Verification Checklist](#4-verification-checklist)
5. [Rollback Plan](#5-rollback-plan)

---

## 1. Pre-Deployment Checklist

### 1.1 Target Org Requirements

| Requirement | Detail |
|---|---|
| **Edition** | Enterprise, Unlimited, or Developer (need custom objects, flows, Apex, LWC) |
| **API Version** | Must support v67.0 (for 5 portal LWC components) |
| ** Licenses needed** | Salesforce (for 18 permission sets), Customer Community Plus (for `O_G_Field_Portal_Access`), Cloud Integration User (for `sfdcInternalInt__sfdc_scrt2`) |
| **Features enabled** | Knowledge, Communities/Experience Cloud, Einstein AI, Flow (Autolaunched + Record-Triggered + Scheduled), Platform Events |
| **User accounts** | A running user with System Administrator profile for deployment; portal community user(s) for testing |
| **Groups** | Create `Executive_Leadership` and `HSE_Compliance_Team` public groups in target org (or the sharing rules/groups metadata will handle it) |

### 1.2 Backup

```bash
# Backup target org metadata before deploying
sf project retrieve start -o "TARGET_ALIAS" -d backup_before_deploy/
```

### 1.3 Clone the Repo

```bash
git clone <repo-url> Energy_Salesforce_project_deploy
cd Energy_Salesforce_project_deploy
```

---

## 2. Deployment Phases

> **Golden Rule:** Deploy each phase and verify before moving to the next. If a phase fails, fix it before continuing.
>
> **Command pattern:** `sf project deploy start -d "force-app\main\default\PATH" -o "TARGET_ALIAS" --wait 30`

---

### Phase 0: Connectivity & Validation

Verify you can connect to the target org.

```bash
sf org display -o "TARGET_ALIAS"
sf project deploy preview -o "TARGET_ALIAS"
```

If `sf org display` fails, authenticate first:
```bash
sf org login web -o "TARGET_ALIAS" -a "TARGET_ALIAS" -d
```

---

### Phase 1: Standard Object Extensions

Deploy custom fields and record types on the 6 standard objects. These must exist before any custom object can reference them via Lookup/Master-Detail.

```bash
sf project deploy start -d "force-app\main\default\objects\Account" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Contact" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Asset" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Opportunity" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Case" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\WorkOrder" -o "TARGET_ALIAS" --wait 30
```

**Verify:** Check Setup → Object Manager → Account → Fields. Confirm custom fields (Operator_Type__c, Account_Type__c, etc.) exist.

---

### Phase 2: Anchor Custom Objects (Level 1 — no custom-object dependencies)

These objects only reference standard objects (Account, User, Contact). They are the foundation.

```bash
sf project deploy start -d "force-app\main\default\objects\Land_Parcel__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Joint_Venture__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Pipeline__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Refinery__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Terminal__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Retail_Outlet__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Store__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Service_Contract__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Supply_Agreement__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\WhatsApp_Message__c" -o "TARGET_ALIAS" --wait 30
```

**Verify:** Setup → Object Manager shows all 10 objects with their custom fields.

---

### Phase 3: Level 2 Objects

Objects that depend on Level 1 objects.

```bash
sf project deploy start -d "force-app\main\default\objects\Lease__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Pipeline_Station__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Well__c" -o "TARGET_ALIAS" --wait 30
```

**Dependency chain:** `Land_Parcel__c` → `Lease__c` → `Well__c`; `Pipeline__c` → `Pipeline_Station__c`

**Verify:** Well__c Lookup fields (Lease__c, Account__c) resolve correctly. Pipeline_Station__c.Pipeline__c lookup works.

---

### Phase 4: Level 3 Objects

Objects that depend on Level 1 + Level 2.

```bash
sf project deploy start -d "force-app\main\default\objects\Well_Operation__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Regulatory_Permit__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Fuel_Inventory__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Inspection__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\HSE_Incident__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\HSE_Observation__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Transportation_Nomination__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Measurement__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Refinery__c" -o "TARGET_ALIAS" --wait 30
```

**Critical:** `Well_Operation__c` has a **Master-Detail** on `Well__c` — Well__c MUST exist first.

**Verify:** Well_Operation__c creates successfully. Measurement__c lookups to Pipeline, Pipeline_Station, Terminal, Well all resolve.

---

### Phase 5: Level 4 Objects (Leaf Nodes)

Objects that depend on Level 3.

```bash
sf project deploy start -d "force-app\main\default\objects\Compliance_Report__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Inventory_Transaction__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Permit_to_Work__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Production_Allocation__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Invoice__c" -o "TARGET_ALIAS" --wait 30
```

---

### Phase 6: Remaining Objects & Custom Settings

Custom settings and objects with no custom-object deps.

```bash
sf project deploy start -d "force-app\main\default\objects\API_Key_Settings__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\GTM_Config__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\SCADA_Config__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\WhatsApp_Config__c" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\objects\Shopify_Settings__c" -o "TARGET_ALIAS" --wait 30
```

Also deploy the platform event:
```bash
sf project deploy start -d "force-app\main\default\objects\Slack_Alert__e" -o "TARGET_ALIAS" --wait 30
```

---

### Phase 7: Apex Classes & Triggers

Deploy all 60 classes and 9 triggers. Classes have inter-dependencies (services call other services), so deploy them all together.

```bash
sf project deploy start -d "force-app\main\default\classes" -o "TARGET_ALIAS" --wait 60
sf project deploy start -d "force-app\main\default\triggers" -o "TARGET_ALIAS" --wait 30
```

**Verify compilation:** The deploy command will fail if there are compilation errors. Common issues:
- Missing object fields (check Phase 1-6 completed)
- Missing external credential references (deploy Phase 12 first if needed)

**If compilation fails on external credential references:** Deploy Phase 12 (credentials) before this phase.

**Alternative — split into safe chunks if full deploy fails:**

```bash
# First: service classes with no external deps
sf project deploy start -d "force-app\main\default\classes\WellStatusService.cls-meta.xml" -o "TARGET_ALIAS"
sf project deploy start -d "force-app\main\default\classes\HSEIncidentService.cls-meta.xml" -o "TARGET_ALIAS"
sf project deploy start -d "force-app\main\default\classes\ComplianceDueDateService.cls-meta.xml" -o "TARGET_ALIAS"
sf project deploy start -d "force-app\main\default\classes\InspectionService.cls-meta.xml" -o "TARGET_ALIAS"
sf project deploy start -d "force-app\main\default\classes\InventoryBalanceService.cls-meta.xml" -o "TARGET_ALIAS"
sf project deploy start -d "force-app\main\default\classes\ProductionAllocationService.cls-meta.xml" -o "TARGET_ALIAS"
sf project deploy start -d "force-app\main\default\classes\RoyaltyCalculationService.cls-meta.xml" -o "TARGET_ALIAS"
sf project deploy start -d "force-app\main\default\classes\PermitToWorkValidationService.cls-meta.xml" -o "TARGET_ALIAS"
sf project deploy start -d "force-app\main\default\classes\PipelineIntegrityService.cls-meta.xml" -o "TARGET_ALIAS"

# Then: wrapper classes
sf project deploy start -d "force-app\main\default\classes\ProductionHistoryWrapper.cls-meta.xml" -o "TARGET_ALIAS"
sf project deploy start -d "force-app\main\default\classes\RoyaltyCalculationWrapper.cls-meta.xml" -o "TARGET_ALIAS"
sf project deploy start -d "force-app\main\default\classes\PipelineIntegrityStatusWrapper.cls-meta.xml" -o "TARGET_ALIAS"

# Then: all remaining classes + triggers
sf project deploy start -d "force-app\main\default\classes" -o "TARGET_ALIAS" --wait 60
sf project deploy start -d "force-app\main\default\triggers" -o "TARGET_ALIAS" --wait 30
```

---

### Phase 8: Flows

Deploy all 11 flows. Flows reference objects and Apex classes that must already exist.

```bash
sf project deploy start -d "force-app\main\default\flows" -o "TARGET_ALIAS" --wait 30
```

**Notes:**
- `HSE_Incident_Escalation` will deploy as **Draft** (inactive) — this is expected.
- `HSE_Critical_Slack_Alert` calls `SlackAlertService` Apex — class must exist.
- Scheduled flows (7) will start running on their schedule immediately since start dates are in the past.

**Post-deploy:** Immediately activate `HSE_Incident_Escalation` in Flow Builder if needed.

---

### Phase 9: UI — Layouts, Tabs, FlexiPages, LWCs, App

#### 9a: Tabs (must exist before layouts reference them)

```bash
sf project deploy start -d "force-app\main\default\tabs" -o "TARGET_ALIAS" --wait 30
```

#### 9b: Layouts

```bash
sf project deploy start -d "force-app\main\default\layouts" -o "TARGET_ALIAS" --wait 30
```

#### 9c: LWC Components

```bash
sf project deploy start -d "force-app\main\default\lwc" -o "TARGET_ALIAS" --wait 60
```

**Note:** 5 LWC components target API v67.0 (`marketDataHome`, `portalHSEIncidentForm`, `portalCompliance`, `portalDashboard`, `portalWellStatus`, `portalInvoices`). The target org must support this version.

#### 9d: FlexiPages (depend on LWCs being deployed)

```bash
sf project deploy start -d "force-app\main\default\flexipages" -o "TARGET_ALIAS" --wait 30
```

#### 9e: Custom Application

```bash
sf project deploy start -d "force-app\main\default\apps" -o "TARGET_ALIAS" --wait 30
```

#### 9f: AI Evaluation Definitions

```bash
sf project deploy start -d "force-app\main\default\aiEvaluationDefinitions" -o "TARGET_ALIAS" --wait 30
```

**Verify:** App Launcher → search "PowerShot" → open it → confirm tabs appear and record pages load with LWC components.

---

### Phase 10: Security — Permission Sets, Profiles, Groups

#### 10a: Public Groups

```bash
sf project deploy start -d "force-app\main\default\groups" -o "TARGET_ALIAS" --wait 30
```

#### 10b: Profiles

```bash
sf project deploy start -d "force-app\main\default\profiles" -o "TARGET_ALIAS" --wait 30
```

**Note:** The `whatssapp webhook Profile` is a Guest User profile tied to the WhatsApp webhook site.

#### 10c: Permission Sets

```bash
sf project deploy start -d "force-app\main\default\permissionsets" -o "TARGET_ALIAS" --wait 60
```

**Verify:** Setup → Permission Sets → confirm all 20 exist. Open `O_G_All_Access` → verify object permissions include all 30 objects.

---

### Phase 11: Sharing Rules & Sharing Sets

```bash
sf project deploy start -d "force-app\main\default\sharingRules" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\sharingSets" -o "TARGET_ALIAS" --wait 30
```

**Note:** Sharing rules are currently empty stubs (`<SharingRules/>`). They deploy without error but define no actual sharing. The `JV_Partner_Sharing` sharing set is the critical one for the portal — it grants JV partners Read access via Account__c field matching.

---

### Phase 12: Integrations — Auth Providers, Credentials, Remote Sites

Deploy in order: Auth Providers → External Credentials → Named Credentials → Remote Sites → CSP Trusted Sites.

```bash
sf project deploy start -d "force-app\main\default\authproviders" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\externalCredentials" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\namedCredentials" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\remoteSiteSettings" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\cspTrustedSites" -o "TARGET_ALIAS" --wait 30
```

**Important:** Auth providers will deploy with placeholder secrets. OAuth integrations (GTM, WhatsApp) will not work until secrets are configured manually (see Phase 3 post-deployment).

---

### Phase 13: Agentforce — Bot, GenAI Plugins, Functions, Planner

```bash
sf project deploy start -d "force-app\main\default\bots" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\genAiFunctions" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\genAiPlugins" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\genAiPlannerBundles" -o "TARGET_ALIAS" --wait 30
```

**Note:** The bot references a service user `o_g_operations_assistant@...` that must exist in the target org. See Post-Deployment Step 13.

---

### Phase 14: Experience Cloud — Networks, Sites

```bash
sf project deploy start -d "force-app\main\default\networks" -o "TARGET_ALIAS" --wait 30
sf project deploy start -d "force-app\main\default\sites" -o "TARGET_ALIAS" --wait 30
```

**Note:** Sites reference `siteAdmin` and `siteGuestRecordDefaultOwner` = `addouliabdo9.76deae143000@agentforce.com`. This user must exist in the target org, or the deploy will fail.

---

## 3. Post-Deployment Manual Steps

These steps CANNOT be automated via metadata deploy. They require manual action in the target org.

### Step 1: Configure OAuth Secrets

| Auth Provider | What to Do | Where |
|---|---|---|
| **WhatsApp_OAuth** | Paste the Facebook App consumer secret (replace `Placeholder_Value`) | Setup → Auth Providers → WhatsApp_OAuth → Consumer Secret |
| **GTM_OAuth** | Paste the Google OAuth client secret (replace `Placeholder_Value`) | Setup → Auth Providers → GTM_OAuth → Consumer Secret |

### Step 2: Configure Named Credential Secrets

Some Named Credentials use named principals that require secret values:

| Named Credential | Action |
|---|---|
| **CommodityPricing** | Set the OilPriceAPI key in the External Credential → Named Principal → Value |
| **EIA_API** | Set the EIA API key in the External Credential → Named Principal → Value |
| **Slack_HSE_Webhook** | Verify the webhook URL matches your Slack workspace (currently hardcoded to a specific channel) |
| **WhatsApp_API** | Set the WhatsApp Cloud API access token in the External Credential → Named Principal → Value |
| **PetrelAPI** | Update the Named Credential URL from `petrel-api.example.com` to your actual Petrel API endpoint; set API key |
| **EPA_CDX_API** | Set the EPA CDX API credentials in the External Credential |

### Step 3: Configure SCADA Config

1. Setup → Custom Settings → SCADA Config → Manage
2. Create a hierarchy record and set `Shared_Secret__c` to match your SCADA bridge shared secret
3. Set `Endpoint_URL__c` to your Salesforce SCADA ingestion endpoint

### Step 4: Configure WhatsApp Config

1. Setup → Custom Settings → WhatsApp Config → Manage
2. Set the WhatsApp Business Account ID, Phone Number ID, and verify token

### Step 5: Configure GTM/GA4 Config

1. Setup → Custom Settings → GTM Config → Manage
2. Set GTM Container ID, GA4 Property ID, Measurement ID

### Step 6: Configure API Key Settings

1. Setup → Custom Settings → API Key Settings → Manage
2. Add records for any API keys needed (OilPriceAPI, EIA, etc.) as named credentials are the preferred method

### Step 7: Assign Permission Sets to Users

For each user role, assign the appropriate permission set:

| Role | Permission Set |
|---|---|
| System Administrator | `O_G_All_Access` |
| C-Suite / Executives | `O_G_Executive` |
| Compliance Analyst | `O_G_Compliance_Analyst` |
| Drilling Engineer | `O_G_Drilling_Engineer` |
| Production Engineer | `O_G_Production_Engineer` |
| Field Technician | `O_G_Field_Technician` |
| HSE Advisor | `O_G_HSE_Advisor` |
| Pipeline Engineer | `O_G_Pipeline_Engineer` |
| Landman | `O_G_Landman` |
| Refinery Manager | `O_G_Refinery_Manager` |
| Retail Manager | `O_G_Retail_Manager` |
| Supply Chain | `O_G_Supply_Chain` |
| Terminal Operator | `O_G_Terminal_Operator` |
| Portal Users (JV Partners) | `O_G_Portal_Access` |
| Field Portal Users | `O_G_Field_Portal_Access` |
| GTM/GA Admin | `GTM_Integration_Admin` |
| Tab Visibility (all users) | `Energy_Tab_Visibility` |
| Experience Cloud Manager | `Experience_Profile_Manager` |

```bash
# Example: assign permission set via CLI
sf permset assign -n "O_G_All_Access" -u "TARGET_ALIAS" --target-org "TARGET_ALIAS"
sf permset assign -n "Energy_Tab_Visibility" -u "TARGET_ALIAS" --target-org "TARGET_ALIAS"
```

### Step 8: Activate HSE_Incident_Escalation Flow

This flow deploys as Draft (inactive). Activate it manually:

1. Setup → Flow → find `HSE_Incident_Escalation`
2. Click into it → click **Activate**

### Step 9: Activate Experience Cloud Sites

1. Setup → All Sites → find `PowerShot`
2. Click **Workspaces** → **Builder** → verify the site loads
3. Publish the site if it's in Draft status
4. Repeat for the `whatssapp_webhook` site if needed

### Step 10: Configure Agentforce Bot

1. Setup → Agentforce (or Einstein Bots) → find `O_G_Operations_Assistant`
2. Verify the bot is **Active**
3. Verify the bot user `o_g_operations_assistant@...` exists and has the right permissions
4. Test the bot in the embedded service chat widget

### Step 11: Register GenAI Functions with Agentforce

The 8 GenAiFunction metadata files deploy the function definitions, but the agent-to-function binding may need to be verified:

1. Setup → Agentforce → O_G_Operations_Assistant → verify topics and actions are wired
2. If not, use Agentforce Builder to link the 4 action plugins (Production, Ops, HSE, Compliance) to their respective functions

### Step 12: Create the Agentforce Agent User

1. Setup → Users → create or verify the bot service user exists
2. The bot metadata references: `o_g_operations_assistant@00dgk00000pvj811115807102.ext`
3. This is a special service/messaging user — create it via Setup → Einstein Bots → O_G_Operations_Assistant → Chat User Settings

### Step 13: Configure Shopify Settings (if used)

1. Setup → Custom Settings → Shopify Settings → Manage
2. Set the Shopify store URL and admin API access token

### Step 14: Set Up Email Alerts for Slack Integration

The `HSE_Critical_Slack_Alert` flow calls `SlackAlertService` which posts to a Slack webhook. Verify:
1. The Slack webhook URL in Named Credential `Slack_HSE_Webhook` points to your workspace
2. The `Slack_Alert__e` platform event is being published (test with a Critical HSE incident)

### Step 15: Create Portal Community User(s)

For testing the JV Partner Portal:
1. Create a Customer Community Plus user
2. Link them to an Account record that is referenced by JV, Well, Production Allocation, etc.
3. Assign `O_G_Portal_Access` permission set
4. Test login at the PowerShot community URL

### Step 16: Configure Page Layout Assignments

The layouts deploy but are not assigned to profiles. Manual assignment:
1. Setup → Object Manager → [each object] → Page Layouts
2. Verify the deployed layout is set as the default for the System Administrator profile
3. Repeat for each profile that needs specific layouts

### Step 17: Set Tab Visibility for Profiles

Tabs deploy but may not be visible to all profiles. The `Energy_Tab_Visibility` permission set handles this, but verify:
1. Setup → Profiles → [profile] → Tab Settings
2. Confirm the 24 custom tabs are visible/DefaultOn as needed

---

## 4. Verification Checklist

Run through this after deployment completes:

### 4.1 Objects & Fields
- [ ] All 31 custom objects exist in Setup → Object Manager
- [ ] All 6 standard objects have their custom fields
- [ ] Lookup/Master-Detail fields resolve correctly (create test records)
- [ ] Validation rules fire correctly (test: create Well without API Number → should fail for Producing status)

### 4.2 Apex & Triggers
- [ ] `sf apex run test -o "TARGET_ALIAS" --result-format human --code-coverage` — verify all tests pass
- [ ] Test coverage ≥ 75% (current baseline: ~39% — may need additional tests)
- [ ] Create a Well record → verify WellTrigger fires (Status_Change_Date__c auto-populates)
- [ ] Create an HSE Incident → verify severity classification triggers
- [ ] Create a Pipeline Station → verify Measurement pressure anomaly detection

### 4.3 Flows
- [ ] Create a Regulatory Permit → verify Regulatory_Permit_Compliance flow creates Compliance Report
- [ ] Create a Permit to Work → verify Permit_to_Work_Approval flow creates review Task
- [ ] Create a WorkOrder → verify Field_Service_Dispatch flow fires
- [ ] Verify scheduled flows are listed in Setup → Flow → check Schedule section

### 4.4 UI
- [ ] PowerShot app appears in App Launcher
- [ ] All 33 tabs are visible and load correctly
- [ ] Record pages (Well, HSE Incident, Pipeline, etc.) show LWC components
- [ ] FlexiPages render without errors

### 4.5 Security
- [ ] All 20 permission sets exist
- [ ] `O_G_All_Access` grants full CRUD on all 30 objects
- [ ] `O_G_Portal_Access` grants read-only on portal objects
- [ ] Groups (Executive_Leadership, HSE_Compliance_Team) exist

### 4.6 Integrations
- [ ] Named credentials are accessible (Setup → Named Credentials → click Test Connection)
- [ ] Remote sites are active (Setup → Remote Site Settings)
- [ ] Test a callout to OilPriceAPI (run anonymous apex: `CommodityPricingService.getLatestPrices()`)

### 4.7 Agentforce
- [ ] Bot appears in Setup → Einstein Bots / Agentforce
- [ ] Bot responds to test messages
- [ ] GenAiFunctions are registered (Setup → Agentforce → Actions)

### 4.8 Portal
- [ ] PowerShot community site is accessible
- [ ] Portal LWC components render on community pages
- [ ] Test user can log in and see permitted records

---

## 5. Rollback Plan

If deployment fails catastrophically:

### Option A: Destructive Changes (remove what was deployed)

```bash
# Remove all custom objects (WARNING: destroys data)
sf project deploy start -d "destructive_changes.xml" -o "TARGET_ALIAS" --wait 60
```

Create `destructive_changes.xml` listing all deployed metadata types.

### Option B: Manual Cleanup

1. Setup → Object Manager → delete custom objects one by one (if no data to preserve)
2. Setup → Permission Sets → delete all O_G_* and other permission sets
3. Setup → Flows → deactivate and delete all flows
4. Setup → Apex Classes → delete all custom classes
5. Setup → Custom Apps → delete PowerShot

### Option C: Org Snapshot (if available)

If you have an org snapshot or sandbox clone from before deployment, refresh it.

---

## Appendix A: Quick Deploy Command (All at Once)

If you want to deploy everything in one shot (risky, but faster):

```bash
sf project deploy start -d "force-app\main\default" -o "TARGET_ALIAS" --wait 120 --test-level RunLocalTests
```

**Warning:** This may fail due to dependency ordering. Use the phased approach above if it does.

---

## Appendix B: File Counts Summary

| Type | Count |
|---|---|
| Custom Objects | 31 (+ 4 custom settings + 1 platform event) |
| Standard Object Extensions | 6 |
| Apex Classes | 60 (including 14 test classes) |
| Apex Triggers | 9 |
| LWC Components | 15 |
| Flows | 11 |
| Permission Sets | 20 |
| Profiles | 2 |
| Layouts | 25 |
| Tabs | 25 |
| FlexiPages | 8 |
| Auth Providers | 6 |
| External Credentials | 7 |
| Named Credentials | 9 |
| Remote Site Settings | 5 |
| CSP Trusted Sites | 3 |
| Sharing Rules | 10 (empty stubs) |
| Sharing Sets | 1 |
| Groups | 2 |
| Custom Application | 1 |
| Bot | 1 |
| GenAI Functions | 8 |
| GenAI Plugins | 12 |
| GenAI Planner Bundle | 1 |
| Networks | 2 |
| Sites | 2 |

---

## Appendix C: Known Issues to Watch For

1. **Test Coverage:** Currently ~39%, production requires 75%. Run `sf apex run test` after deployment and add tests if coverage is insufficient.
2. **Invoice__c in Permission Sets:** Nearly every O_G_* permission set grants full ModifyAllRecords + ViewAllRecords on Invoice__c. Verify this is intentional.
3. **Draft Flow:** `HSE_Incident_Escalation` deploys as Draft — must be manually activated.
4. **Placeholder Secrets:** GTM_OAuth and WhatsApp_OAuth consumer secrets are placeholders. Integrations will fail until real secrets are pasted in.
5. **PetrelAPI URL:** Points to `petrel-api.example.com` — needs real endpoint.
6. **Site Owner:** Sites reference `addouliabdo9.76deae143000@agentforce.com` as site admin. This user must exist in the target org.
7. **Bot User:** The Agentforce bot references a specific service user that may not exist in the target org.
8. **Scheduled Flow Start Dates:** All scheduled flows have start dates in June/July 2026 (past). They will run on next scheduled time after deployment.
9. **`sfdcInternalInt__sfdc_scrt2`** permission set requires the `Cloud Integration User` license — skip if not available.
10. **ApexDevNet Remote Site** uses plain HTTP (`http://www.apexdevnet.com`) — may be blocked by org security policies.
