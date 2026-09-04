# Phase 2 — MCP Actions Binding & Next Phases (Continuation Plan)

**Status (2026-09-02):** Source layer DEPLOYED — 8 invocable Apex actions are now registered as `GenAiFunction` metadata (+ 4 domain `GenAiPlugin` groupings) in `ouil gas`, fully verified. **Final wiring of the live agent's subagents is NOT done** — it requires Agentforce Builder UI (`apex://<class>/<method>`) or `@salesforce/plugin-agentforce` (`sf agent publish`), neither available from this CLI (`@salesforce/cli/2.135.7`). See §2.5 handoff interface below.

---

## 1. Where we are (as of 2026-09-01)

Phase 0 (audit) and Phase 1 (invocable wrappers + permission grants) are **done and verified**:

- **78/78 tests green** (`TestWellLifecycle` 16, `TestHSEServices` 29, `TestCommercialServices` 17, `TestFieldServices` 16).
- 5 invocable wrapper classes deployed: `HSEIncidentService`, `ComplianceDueDateService`, `PermitToWorkValidationService`, `WellStatusService`, `InventoryBalanceService`.
- 6 permission sets deployed Succeeded: `O_G_HSE_Advisor`, `O_G_Compliance_Analyst`, `O_G_Production_Engineer`, `O_G_Terminal_Operator`, `O_G_Field_Technician`, `O_G_All_Access`.
- **Agent build (UI, from scratch):** "O&G Operations Assistant" — `developerName O_G_Operations_Assistant`, `agentType EinsteinServiceAgent`, compiled + saved + **activated**, version `v1`.

### Verified agent structure (org-retrieved, decoded)

| Component | Value |
|---|---|
| Initial node | `agent_router` (welcome + intent routing) |
| Subagents (8) | `hse_advisor`, `compliance_analyst`, `production`, `ops`, `escalation`, `off_topic`, `ambiguous_question` |
| Router tools (7) | `go_to_hse_advisor`, `go_to_compliance_analyst`, `go_to_production`, `go_to_ops`, `go_to_escalation`, `go_to_off_topic`, `go_to_ambiguous_question` |
| Escalation tool | `escalate_to_human` (handoff to live agent) |
| Actions bound | **0** (`actionDefinitions` empty everywhere) |
| Context vars | `EndUserId`, `RoutableId`, `ContactId`, `EndUserLanguage`, `VerifiedCustomerId` |
| Runtime user | `o_g_operations_assistant@00dgk00000pvj811115807102.ext` |

Business rules embedded in every subagent instruction set: HSE severity matrix (CRITICAL/HIGH/MEDIUM/LOW), regulatory reportability (≥50 bbl, fatality, LT/Life-threatening, Crit/High), 45-day permit renewal window, NON-COMPLIANT on expired/suspended, pipeline integrity, inventory zero/negative rejection, PTW 3-gate guardrail (isolation + gas test + authorization chain), external-filing confirmation gate, least-privilege, write-confirmation gate, record citation, output format (OK / NOT-OK / ACTION NEEDED).

### Agent source now in repo

Retrieved metadata was copied into `force-app/main/default` (source-controlled, redeployable):

- `force-app/main/default/bots/O_G_Operations_Assistant/` — `.bot-meta.xml` + `v1.botVersion-meta.xml`
- `force-app/main/default/genAiPlannerBundles/O_G_Operations_Assistant_v1/` — `*.genAiPlannerBundle`, `agentGraph/O_G_Operations_Assistant_v1_graph.json` (Base64 of JSON), `agentScript/O_G_Operations_Assistant_v1_definition.agent` (Base64 of YAML agent definition)
- `force-app/main/default/genAiPlugins/` — 8 plugins, all suffixed `_16jgK0000027eu1` (`agent_router`, `hse_advisor`, `compliance_analyst`, `production`, `ops`, `escalation`, `off_topic`, `ambiguous_question`)

> CLI note: `@salesforce/cli/2.135.7` reports `INVALID_TYPE: Unknown type:Agent` for `--metadata-type Agent`, but `sf project retrieve start --metadata "Agent"` works (composite: Bot/BotVersion/GenAiPlannerBundle/GenAiPlugin). REST metadata API returns 404 on this org. Update to CLI `2.148.3` and re-test `list metadata` + `project deploy` of the copied folders before relying on source deploys.

---

## 2. Phase 2 — Bind MCP/Apex actions to the agent (DO NEXT)

### 2.1 Tool inventory (21 named actions from the builder brief)

Grouped by domain → backing service:

| # | Action name | Domain | Backing service (Phase 1) |
|---|---|---|---|
| 1 | `getOpenHSEIncidents` | HSE | `HSEIncidentService` |
| 2 | `classifyIncidentSeverity` | HSE | `HSEIncidentService` |
| 3 | `getUpcomingRenewals` | Compliance | `ComplianceDueDateService` |
| 4 | `getOverdueComplianceReports` | Compliance | `ComplianceDueDateService` |
| 5 | `getUpcomingDeadlines` | Compliance | `ComplianceDueDateService` |
| 6 | `getWellProduction` | Production | `WellStatusService` |
| 7 | `getWellsDueForAbandonment` | Production | `WellStatusService` |
| 8 | `transitionWellStatus` | Production | `WellStatusService` (write) |
| 9 | `getPermitsToWork` | FieldOps | `PermitToWorkValidationService` |
| 10 | `updatePermitStatus` | FieldOps | `PermitToWorkValidationService` (write) |
| 11 | `getPTWMissingRequirements` | FieldOps | `PermitToWorkValidationService` |
| 12 | `validatePTWIsolation` | FieldOps | `PermitToWorkValidationService` |
| 13 | `validatePTWGasTest` | FieldOps | `PermitToWorkValidationService` |
| 14 | `validatePTWAuthChain` | FieldOps | `PermitToWorkValidationService` |
| 15 | `getTankInventory` | Inventory | `InventoryBalanceService` |
| 16 | `getCurrentInventory` | Inventory | `InventoryBalanceService` |
| 17 | `getLowInventoryAlerts` | Inventory | `InventoryBalanceService` |
| 18 | `recordInventoryMovement` | Inventory | `InventoryBalanceService` (write) |
| 19 | `getProductionHistory` | Production | **NEW wrapper needed** (Production_Allocation__c/Measurement__c history) |
| 20 | `getPipelineIntegrityStatus` | FieldOps | **NEW wrapper needed** (Inspection__c interval check) |
| 21 | `calculateRoyalty` | Commercial | **NEW wrapper needed** (Invoice__c/Lease__c/Product2) |

### 2.2 Subagent → tool assignment (planned)

- **hse_advisor**: 1, 2
- **compliance_analyst**: 3, 4, 5
- **production**: 6, 7, 8, 19
- **ops**: 9, 10, 11, 12, 13, 14, 20
- **escalation / off_topic / ambiguous_question**: no tools
- **router**: none (transitions only)

### 2.3 Binding steps (Agent Builder UI or source)

1. **Data/Grounding step** — confirm the 23 grounding objects are still connected to the agent (HSE_Incident__c, HSE_Observation__c, Regulatory_Permit__c, Compliance_Report__c, Well__c, Well_Operation__c, Production_Allocation__c, Permit_to_Work__c, Inspection__c, Asset, Pipeline__c, Fuel_Inventory__c, Measurement__c, Terminal__c, Refinery__c, Retail_Outlet__c, Lease__c, Joint_Venture__c, Invoice__c, Product2, Account, Contact, WorkOrder). Check that the agent's runtime user has `AgentforceServiceAgentSecureBase` + the `O_G_*` permission sets.
2. **Create the missing wrappers first** (`getProductionHistory`, `getPipelineIntegrityStatus`, `calculateRoyalty`) — one `@InvocableMethod` per class, `HttpCalloutMock`-style tests, deploy + run tests before binding.
3. In Agent Builder: open each subagent → Actions → add the invocable actions for its domain; verify schema fields resolve (inputs/outputs) and the write-confirmation gate in instructions still guards the write actions (8, 10, 18).
4. Deploy HALF the writes last: keep read-only tools enabled first, test, then enable write actions behind the confirmation gate.
5. After binding, re-retrieve `--metadata "Agent"` and diff the graph's `actionDefinitions` (should no longer be empty) and the `.agent` definition against the current repo copy. Keep repo copy in sync (note plugin ID suffix `_16jgK0000027eu1` — re-retrieval may change it).

### 2.4 Verification checklist (from architecture doc Steps 6-7)

- Run scenarios in Agentforce Testing Center (validate all pre-existing 78 tests still pass; add tests for the 3 new wrappers).
- HSE: does `hse_advisor` correctly classify Critical and flag ≥50 bbl reportable?
- Compliance: respects 45-day renewal window and NON-COMPLIANT on expired/suspended (note: architecture doc wrote "90-day" — **we standardized on 45 days**; do not reintroduce 90).
- Ops: enforces well lifecycle transitions; PTW 3-gate never skippable.
- Inventory: zero/negative volume rejected.
- Write actions never fire without the confirmation string `"I will set [field] to [value] on [record name/ID] — confirm?"`.

### 2.5 Executed 2026-09-02 — GenAiFunction source layer (user-chosen safe path)

**Why the plan changed — resolved the 21-action list down to 8 bindable actions:** Only methods wrapped in `@InvocableVariable` input/outputs are bindable as Agent Builder Apex actions (the agentscript `apex://` reference requires this; *Bare @InvocableMethod Pattern with `List<Id>` params is NOT compatible*).

- **8 bindable (all Active, now deployed):** `HSEIncidentService.classifyIncidentSeverities`, `ComplianceDueDateService.getComplianceOverview`, `ProductionHistoryWrapper.getProductionHistory`, `WellStatusService.transitionWellStatuses` (write), `RoyaltyCalculationWrapper.calculateRoyalties`, `PermitToWorkValidationService.updatePermitStatuses` (write), `InventoryBalanceService.recordInventoryMovements` (write), `PipelineIntegrityStatusWrapper.getPipelineIntegrityStatuses`.
- **NOT bindable:** `RegulatoryFilingService.submitReports(List<Id>)`, `SlackAlertService.sendAlert(List<Id>)` — bare `List<Id>` args, no `@InvocableVariable` wrapper.
- **NOT invocable at all:** ~13 plain/`@AuraEnabled` read-only queries (`getOpenHSEIncidents`, `getUpcomingRenewals`, `getOverdueComplianceReports`, `getUpcomingDeadlines`, `getWellsDueForAbandonment`, `getPermitsToWork`, `getPTWMissingRequirements`, `validatePTW*`, `getTankInventory`, `getCurrentInventory`, `getLowInventoryAlerts`). These stay grounded via the connected objects / SOQL, not as agent actions.

**What was deployed (verified `GenAiFunctionDefinition` in org, deploy id `0AfgK00000SJb5NSAT`):**

| GenAiFunction | Apex invocationTarget | Domain plugin | Write? |
|---|---|---|---|
| `O_G_ClassifyIncidentSeverity` | `HSEIncidentService` | `O_G_HSE_Actions` | no |
| `O_G_GetComplianceOverview` | `ComplianceDueDateService` | `O_G_Compliance_Actions` | no |
| `O_G_GetProductionHistory` | `ProductionHistoryWrapper` | `O_G_Production_Actions` | no |
| `O_G_TransitionWellStatus` | `WellStatusService` | `O_G_Production_Actions` | **yes** |
| `O_G_CalculateRoyalty` | `RoyaltyCalculationWrapper` | `O_G_Production_Actions` | no |
| `O_G_UpdatePermitStatus` | `PermitToWorkValidationService` | `O_G_Ops_Actions` | **yes** |
| `O_G_RecordInventoryMovement` | `InventoryBalanceService` | `O_G_Ops_Actions` | **yes** |
| `O_G_GetPipelineIntegrityStatus` | `PipelineIntegrityStatusWrapper` | `O_G_Ops_Actions` | no |

- Source: `force-app/main/default/genAiFunctions/O_G_*` (each bundle = `*.genAiFunction-meta.xml` + `input/schema.json` + `output/schema.json`) and `force-app/main/default/genAiPlugins/O_G_*_Actions.genAiPlugin-meta.xml`.
- The 3 write actions are correctly flagged `IsConfirmationRequired = true`; the 5 reads are `false` (verified via SOQL).
- **Authoritative metadata lesson (org API 67):** GenAiFunction XML only allows `description, invocationTarget, invocationTargetType, isConfirmationRequired, masterLabel`; schemas live in the `schema.json` files. collections/list outputs (`type:"array"`/`items`) are **rejected** by the deploy parser → collection outputs must be omitted from `schema.json` (the Apex method still returns them; they just aren't exposed as structured schema). GenAiPlugin uses `genAiPluginInstructions` (nested object) + `pluginType Topic`, `canEscalate`, `localDeveloperName`; the `masterLabel` must XML-escape `&` as `&amp;`.

**Hard blockers for fully wiring the LIVE agent from this environment:**
1. **Agent Script (`apex://`) source-edit path: BLOCKED.** SFDC rejects source-deploying an edited published `AiAuthoringBundle`: *"content cannot be changed once the bundle version is published."* `@salesforce/cli/2.135.7` has **no `sf agent publish`/activate/convert** (only `create|preview|test|generate`).
2. **GenAiPlannerBundle graph edit: BLOCKED (high-risk).** `actionDefinitions`/`tools` in `agentGraph/*_graph.json` are compiled output with no validated binding example for `Atlas__ConcurrentMultiAgentOrchestration` subagents; editing requires deactivate→deploy→reactivate on the live agent. Rejected by user.
3. Therefore the deployed `GenAiFunction`/`GenAiPlugin` layer does **not** wire into the live agent by itself — it merely makes the actions available in Agent Builder and via REST (`POST /services/data/v67.0/actions/custom/apex/<Class>`).

**Final handoff interface (what a human/Builder-UI operator must do to finish):**
1. Open the activated `O_G_Operations_Assistant` in **Agent Builder** → the deployed functions now appear as Actions (optionally within the `O_G_*_Actions` topics). Enable them on the right subagents, mirroring §2.2:
   - **hse_advisor** ← `O_G_ClassifyIncidentSeverity`
   - **compliance_analyst** ← `O_G_GetComplianceOverview`
   - **production** ← `O_G_GetProductionHistory`, `O_G_CalculateRoyalty` (reads) ; `O_G_TransitionWellStatus` (write, confirmation-gated)
   - **ops** ← `O_G_GetPipelineIntegrityStatus` (read); `O_G_UpdatePermitStatus`, `O_G_RecordInventoryMovement` (writes, confirmation-gated)
   - **escalation / off_topic / ambiguous_question / agent_router** ← no actions.
2. Re-save (creates v2) and **reactivate**. Then re-retrieve `--metadata "Agent"` and diff `actionDefinitions` (should no longer be empty) against the repo copy.
3. Alternative automated path: install `@salesforce/plugin-agentforce` (get `sf agent publish`) and publish a new authored `AiAuthoringBundle` version that references these functions via `apex://<Class>` in `.agent`.

> Deploy note: use plain `sf project deploy start` for these folders (no tests needed). For Apex use `--test-level RunSpecifiedTests` — pre-existing unrelated failures (`TestPortalControllers`, `PowerShotLoginControllerTest`) break `RunLocalTests`.

---

## 3. Phase 3 — Agent guardrails & testing

(from architecture doc Step 6, Step 7)

- Agent Script: encode fallback behaviors (currently the router + utility subagents handle out-of-scope/vague/escalation; verify phrase coverage).
- Custom Scoring Evals: define what "good" looks like per domain (severity classify hit rate, thresholds, hallucination checks).
- Token limits / retry policies per subagent.
- 100+ scenario runs per agent; log failures against the business-rule table above.

---

## 4. Phase 4 — Governance & observability

(from architecture doc Step 11-13)

- Session tracing: agent tool calls across objects, order, latency.
- A/B test two agent versions for HSE escalation behavior.
- Dashboard + alerts: tool-call frequency, error rates, audit trail with user identity.

---

## 5. Quick-start resumption commands

- Run tests: `sf apex run test -o "ouil gas"`
- Deploy source folder: `sf project deploy start -d "force-app\main\default\PATH" -o "ouil gas"`
- Retrieve agent: `sf project retrieve start --target-org "ouil gas" --metadata "Agent" --output-dir "_tmp_retrieve"`
- Decode `.agent`: PowerShell `[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((Get-Content -Raw FILE).Trim()))`
- Decode graph: same, then `ConvertFrom-Json`.

## 6. Key identifiers (keep for resumes)

- Project root: `C:\Users\addou\OneDrive\Bureau\SalesForce_projects\Energy project\Energy_Salesforce_project`
- Org `ouil gas`: `addouliabdo9.76deae143000@agentforce.com` / `00DgK00000PVJ81UAH` / API 67.0 / sourceApiVersion 66.0
- Agent: `O_G_Operations_Assistant` v1; botUser `o_g_operations_assistant@00dgk00000pvj811115807102.ext`
- Plugin suffix: `_16jgK0000027eu1`
- Manifests: `manifest/package-phase1-invocables.xml`, `manifest/package-phase1-permsets.xml`, `manifest/package-phase1-tests.xml`