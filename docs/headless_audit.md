# Headless / Agent / MCP Audit — Energy_Salesforce_project

> **Phase 0 deliverable.** Inventory of the existing headless call surfaces
> (Apex `@AuraEnabled`, `@InvocableMethod`, REST endpoints, platform events)
> and the permission-set model that agents/MCP will inherit.
>
> Target org: **`ouil gas`** (`addouliabdo9.76deae143000@agentforce.com`)
> Org: `00DgK00000PVJ81UAH` · Instance: `orgfarm-4d94271bcc` · API **67.0**
> Generated from: 2026-09-01 source scan + org verification.

---

## 1. Summary

- **Total Apex classes with a call surface:** 16 expose `@AuraEnabled`; only **2** expose `@InvocableMethod`.
- **Inbound REST endpoints:** 2 (`SCADAIngestionAPI`, `WhatsAppWebhookHandler`), both HMAC fail-closed.
- **Platform events:** 1 object (`Slack_Alert__e`); **no production `EventBus.publish`** (only in `TestHSEServices.cls`).
- **Critical gap:** **zero `classAccess` across all 14 `O_G_*` permission sets.** Role-based users/agents cannot execute the Apex service methods today. Phase 1 must add `classAccess` (and `@AuraEnabled(cacheable=...)`/`@InvocableMethod` access) alongside any new wrappers.

---

## 2. Existing `@InvocableMethod` (agent-callable today)

| Class | Method | Purpose |
|---|---|---|
| `SlackAlertService` | `sendAlert(List<Id>)` | Queue a Slack HSE alert (invocable) |
| `RegulatoryFilingService` | `submitReports(List<Id>)` | File compliance report to EPA/CDX (callout `EPA_CDX_API/submit`) |

These are the only two methods that Flow/AgentBuilder can invoke today.

---

## 3. Inbound REST endpoints (headless)

| Class | URL | Auth |
|---|---|---|
| `SCADAIngestionAPI` | `/services/apexrest/api/scada/measurements` | HMAC + Bearer token |
| `WhatsAppWebhookHandler` | `/services/apexrest/whatsapp/webhook` | HMAC-verified |

Pattern to mirror for any future headless inbound flows (fail-closed HMAC verification).

---

## 4. Platform events

| Event | Fields | Production publish? |
|---|---|---|
| `Slack_Alert__e` | `Incident_Id__c` | ❌ None (`EventBus.publish` only in tests) |

No event-driven agent trigger path exists yet.

---

## 5. Core O&G services — surface (read / write) and candidate agent tools

Legend: **R** = read (query), **W** = write (DML), **V** = validation (returns Boolean).

### HSEIncidentService
| Method | Type | Exposed | Agent-tool candidate |
|---|---|---|---|
| `getHSEIncidents(Id)` | R | `@AuraEnabled` | getOpenHSEIncidents |
| `classifySeverities(List<Id>)` | W | — | classifyHSEIncidents |
| `notifyComplianceTeams(List<Id>)` | W | — | notifyCompliance |
| `escalateIfCritical(List<Id>)` | W | — | escalateCriticalIncident |
| `isRegulatoryReportable(Id)` | V/R | — | isRegulatoryReportable |

### WellStatusService
| Method | Type | Exposed | Agent-tool candidate |
|---|---|---|---|
| `getWellProduction(Id)` | R | `@AuraEnabled` | getWellProduction |
| `getWellsDueForAbandonment()` | R | — | getWellsDueForAbandonment |
| `transitionWellStatus(myId, Status)` | W | — | transitionWellStatus |
| `isValidTransition(cur,new)` | V | — | isValidWellTransition |

### ProductionAllocationService
| Method | Type | Exposed | Agent-tool candidate |
|---|---|---|---|
| `getProductionHistory(myId, months)` | R | `@AuraEnabled` | getProductionHistory |
| `calculateMonthlyAllocation(myId, from, to)` | W | — | calculateMonthlyAllocation |
| `getAllocatedRevenue(allocId)` | R | — | getAllocatedRevenue |
| `validateWorkingInterest(list)` | V | — | validateWorkingInterest |

### PermitToWorkValidationService
| Method | Type | Exposed | Agent-tool candidate |
|---|---|---|---|
| `getPermitsToWork(parentId)` | R | `@AuraEnabled` | getPermitsToWork |
| `updatePermitStatus(myId, Status)` | W | `@AuraEnabled` | updatePTWStatus |
| `validateIsolationRequirements(myId)` | V | — | validatePTWIsolation |
| `validateGasTestResults(myId)` | V | — | validatePTWGasTest |
| `validateAuthorizationChain(myId)` | V | — | validatePTWAuthChain |
| `getMissingRequirements(myId)` | R | — | getPTWMissingRequirements |

### InventoryBalanceService
| Method | Type | Exposed | Agent-tool candidate |
|---|---|---|---|
| `getTankInventory(termId, max)` | R | `@AuraEnabled` | getTankInventory |
| `getCurrentInventory(invId)` | R | — | getCurrentInventory |
| `getLowInventoryAlerts(pct)` | R | — | getLowInventoryAlerts |
| `recordInventoryMovement(invId, chg, type)` | W | — | recordInventoryMovement |
| `reconcileInventory(invId, count)` | W | — | reconcileInventory |

### InspectionService
| Method | Type | Exposed | Agent-tool candidate |
|---|---|---|---|
| `getChecklistItems(parentId, type)` | R | `@AuraEnabled` | getChecklistItems |
| `submitChecklist(data, parentId)` | W | `@AuraEnabled` | submitChecklist |
| `updateParentInspectionDates(list)` | W | — | (internal) |
| `createRecurringInspections(list)` | W | — | (internal) |

### ComplianceDueDateService
| Method | Type | Exposed | Agent-tool candidate |
|---|---|---|---|
| `getUpcomingRenewals(daysAhead)` | R | — | getExpiringPermits |
| `getUpcomingDeadlines(acctId)` | R | `@AuraEnabled` | getUpcomingDeadlines |
| `getOverdueReports()` | R | — | getOverdueComplianceReports |
| `updateComplianceStatuses(sets)` | W | — | (internal/batch) |
| `sendRenewalReminders()` | W | — | sendRenewalReminders |

### PipelineIntegrityService
| Method | Type | Exposed | Agent-tool candidate |
|---|---|---|---|
| `getOverdueInspections()` | R | — | getOverduePipelineInspections |
| `isInspectionCompliant(pipelineId)` | V/R | — | isPipelineCompliant |
| `flagNonCompliantPipelines()` | W | — | flagNonCompliantPipelines |
| `calculateNextInspectionDueDate(pipeId)` | R | — | (internal) |

### RoyaltyCalculationService
| Method | Type | Exposed | Agent-tool candidate |
|---|---|---|---|
| `calculateRoyaltyPayment(leaseId, allocId)` | R | — | calculateRoyalty |
| `calculateMonthlyRoyalties(leaseId, from, to)` | R | — | (internal) |
| `generateRoyaltyStatements(leaseId, from, to)` | W | — | generateRoyaltyStatements |

---

## 6. Permission-set model (least-privilege targets)

All permission sets are **`O_G_*`**, one per domain role. **None currently contain `classAccess`.**

| Permission set | Objects granted |
|---|---|
| `O_G_HSE_Advisor` | HSE_Incident, HSE_Observation, Invoice, Permit_to_Work |
| `O_G_Compliance_Analyst` | Compliance_Report, HSE_Incident, Invoice, Regulatory_Permit |
| `O_G_Production_Engineer` | Invoice, Production_Allocation, Well |
| `O_G_Pipeline_Engineer` | Inspection, Invoice, Measurement, Pipeline, Pipeline_Station |
| `O_G_Terminal_Operator` | Fuel_Inventory, Invoice, Measurement, Terminal |
| `O_G_Retail_Manager` | Fuel_Inventory, Invoice, Retail_Outlet |
| `O_G_Supply_Chain` | Fuel_Inventory, Invoice, Product2, Service_Contract |
| `O_G_Field_Technician` | Account, Asset, Inspection, Invoice, Permit_to_Work, Pipeline, Well |
| `O_G_Field_Portal_Access` | HSE_Incident, HSE_Observation, Inspection, Permit_to_Work, Pipeline, Well, WorkOrder |
| `O_G_Drilling_Engineer` | Invoice, Lease, Well, Well_Operation |
| `O_G_Landman` | Invoice, Joint_Venture, Land_Parcel, Lease, Well |
| `O_G_Refinery_Manager` | Invoice, Pipeline, Refinery, Supply_Agreement, Terminal |
| `O_G_Executive` | Account, Asset, Case, Contact, Fuel_Inventory, HSE_Incident, Invoice, Lease, Opportunity, Pipeline, Pipeline_Station, Refinery, Supply_Agreement, Terminal, Well, WorkOrder |
| `O_G_All_Access` | all O&G + standard (full) |

### Matching candidate tools to permission sets
| Agent tool (candidate) | Permission set |
|---|---|
| HSE getOpen/classify/escalate, PTW status | `O_G_HSE_Advisor` |
| Compliance renewals/overdue/report filing | `O_G_Compliance_Analyst` |
| Production history / allocation | `O_G_Production_Engineer` |
| Pipeline integrity / inspections | `O_G_Pipeline_Engineer` |
| Inventory / tank / movements | `O_G_Terminal_Operator` (or `O_G_Retail_Manager`) |
| Cross-domain / any tool (admin/testing) | `O_G_All_Access` |

Phase 1 must grant the matching permission set(s) `classAccess` to each new/used service class.

---

## 7. Phase 1/2 implications

1. **Add `@InvocableMethod` / `@InvocableVariable` wrappers** on core services lacking them:
   `WellStatusService.transitionWellStatus`, `HSEIncidentService.classifySeverities`,
   `PermitToWorkValidationService.updatePermitStatus/validate*`, `InventoryBalanceService.recordInventoryMovement`,
   `ProductionAllocationService.calculateMonthlyAllocation`, `ComplianceDueDateService.getUpcomingRenewals`, etc.
   (plus tests).
2. **Grant `classAccess`** on the matching `O_G_*` permission sets; add `@AuraEnabled(cacheable=true)` where a read is to be agent/LWC-callable.
3. **Custom named-query MCP** (Phase 2) reads/writes map 1:1 to these wrapped methods → Tool→Permission-set matrix above drives least-privilege.
4. **Watch for regressions:** adding access only adds capability (no existing grants exist for these classes today), so it is non-breaking.
