# Manual Fixes — Oil & Gas Salesforce Project

Deployed to: `addouliabdo9.76deae143000@agentforce.com`
Date: 2026-05-24

---

## 1. Create Flows via Flow Builder UI

Open **Setup → Flow** and create these 8 flows:

| Flow | Type | Trigger / Schedule | Description |
|------|------|-------------------|-------------|
| Well_Lifecycle | Record-Triggered | Well__c status change | Create Well_Operation record, notify team |
| HSE_Incident_Escalation | Record-Triggered | HSE_Incident__c created/updated | Notify HSE Manager, Legal, Regulatory if reportable |
| Compliance_Calendar | Scheduled | Daily | Check upcoming permit expirations, report due dates, send reminders |
| Inspection_Due | Scheduled | Weekly | Create Inspection records for overdue/scheduled inspections |
| Permit_to_Work_Approval | Record-Triggered | Permit_to_Work__c created | Route to approver based on type and location |
| Field_Service_Dispatch | Record-Triggered | WorkOrder created | Assign crew, check PTW requirements |
| Production_Reconciliation | Scheduled | Monthly | Aggregate production data, flag discrepancies |
| Retail_Inventory_Alert | Scheduled | Daily | Alert when fuel inventory below minimum threshold |

---

## 2. Fix Apex Classes

All 8 Apex classes have field references that don't match the deployed schema. Fix by:

1. Open each `.cls` file in VS Code
2. Right-click → `SFDX: Deploy Source to Org`
3. Read compiler errors and fix field/object references²

### Known Issues Per Class

| Class | Problem |
|-------|---------|
| `ProductionAllocationService` | References `Well_Production__c`, `Working_Interest__c` — not in schema |
| `RoyaltyCalculationService` | References `Mineral_Lease__c`, `Mineral_Right_Owner__c`, `Royalty_Statement__c` — not in schema |
| `PipelineIntegrityService` | References fields on `Pipeline__c` that don't exist (e.g. `Last_Inspection_Date__c`, `Status_Change_Date__c`) |
| `WellStatusService` | References `Status_Change_Date__c` — field not created |
| `PermitToWorkValidationService` | References `Isolation_Verified__c`, `Gas_Test_Required__c` — fields not created |
| `HSEIncidentService` | May reference fields not in schema |
| `ComplianceDueDateService` | May reference fields not in schema |
| `InventoryBalanceService` | May reference fields not in schema |

### Triggers

All 6 triggers (`WellTrigger`, `HSEIncidentTrigger`, `AssetTrigger`, `RegulatoryPermitTrigger`, `ProductionAllocationTrigger`, `InspectionTrigger`) will compile once their referenced service classes compile.

---

## 3. Case & Opportunity Record Types

Record type XML files were removed from deployment because they require **Business Processes** which don't exist in the org.

**Option A — Create Business Processes first:**
1. Setup → Object Manager → Case → Business Processes → New
2. Setup → Object Manager → Opportunity → Business Processes → New
3. Then add `<businessProcess>ProcessName</businessProcess>` back to the record type XMLs and redeploy

**Option B — Create manually:**
- Setup → Object Manager → Case → Record Types → New
- Setup → Object Manager → Opportunity → Record Types → New
- Create 5 Case record types: HSE Incident, Equipment Failure, Regulatory, Customer Issue, Field Request
- Create 4 Opportunity record types: Service Sale, Equipment Sale, Supply Contract, JV Proposal

---

## 4. Test LWC Components

8 LWC components are deployed and exposed on Record/App/Home pages:

| Component | Page Type | Notes |
|-----------|-----------|-------|
| wellProductionChart | Record/App/Home | Needs `WellStatusService` to compile |
| hseIncidentMap | Record/App/Home | Needs `HSEIncidentService` to compile |
| complianceCalendar | Record/App/Home | Needs `ComplianceDueDateService` to compile |
| inventoryTankGauge | Record/App/Home | Standalone — no Apex dependency |
| permitToWorkBoard | Record/App/Home | Needs `PermitToWorkValidationService` to compile |
| fieldServiceChecklist | Record/App/Home | Standalone — uses `lightning/ui*Api` |
| productionAllocationReport | Record/App/Home | Needs `ProductionAllocationService` to compile |

To add to a page:
1. Go to any record (e.g., a Well record)
2. Gear icon → Edit Page
3. Drag component from the left panel onto the page
4. Save → Activate

---

## 5. Deploy Pending Items After Fixes

```bash
# After fixing Apex classes
sf project deploy start --source-dir force-app\main\default\classes --target-org addouliabdo9.76deae143000@agentforce.com

# After fixing record types
sf project deploy start --source-dir force-app\main\default\objects\Case\recordTypes --target-org addouliabdo9.76deae143000@agentforce.com
sf project deploy start --source-dir force-app\main\default\objects\Opportunity\recordTypes --target-org addouliabdo9.76deae143000@agentforce.com

# Deploy everything together
sf project deploy start --source-dir force-app --target-org addouliabdo9.76deae143000@agentforce.com
```
