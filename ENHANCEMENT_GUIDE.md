# Oil & Gas Salesforce Project — Enhancement Guide

**Target Org:** `addouliabdo9.76deae143000@agentforce.com`
**API Version:** 66.0
**Last Updated:** June 2026 (Phase 1 refreshed to reflect External Credential migration)

---

## Table of Contents

1. [Phase 1: Quick Wins (Week 1-2)](#phase-1-quick-wins-week-1-2)
2. [Phase 2: External API Integrations (Week 3-6)](#phase-2-external-api-integrations-week-3-6)
3. [Phase 3: Einstein AI & Predictions (Week 7-10)](#phase-3-einstein-ai--predictions-week-7-10)
4. [Phase 4: Experience Cloud Portal (Week 8-12)](#phase-4-experience-cloud-portal-week-8-12)
5. [Phase 5: Advanced Analytics (Week 10-14)](#phase-5-advanced-analytics-week-10-14)
6. [Phase 6: Data Cloud & 360 (Week 12-16)](#phase-6-data-cloud--360-week-12-16)
7. [Phase 7: Salesforce Clouds Expansion (Week 8-14)](#phase-7-salesforce-clouds-expansion-week-8-14)
8. [Phase 8: Agentforce & Einstein AI (Week 12-18)](#phase-8-agentforce--einstein-ai-week-12-18)
9. [Phase 9: Sustainability & IoT (Week 14-20)](#phase-9-sustainability--iot-week-14-20)

---

## Phase 1: Quick Wins (Week 1-2)

### 1.1 Commodity Pricing Web Service

Wire real-time pricing into `Supply_Agreement__c` and `Production_Allocation__c`.

**Step 1: Create External Credential + Named Credential (SecuredEndpoint format)**

Create the External Credential metadata:

```xml
<!-- externalCredentials/CommodityPricing.externalCredential-meta.xml -->
<ExternalCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <authenticationProtocol>Basic</authenticationProtocol>
    <label>CommodityPricing</label>
</ExternalCredential>
```

Create the Named Credential:

```xml
<!-- namedCredentials/CommodityPricing.namedCredential-meta.xml -->
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
    <allowMergeFieldsInHeader>true</allowMergeFieldsInHeader>
    <label>CommodityPricing</label>
    <namedCredentialParameters>
        <parameterName>Url</parameterName>
        <parameterType>Url</parameterType>
        <parameterValue>https://api.oilpriceapi.com/v1</parameterValue>
    </namedCredentialParameters>
    <namedCredentialParameters>
        <externalCredential>CommodityPricing</externalCredential>
        <parameterName>ExternalCredential</parameterName>
        <parameterType>Authentication</parameterType>
    </namedCredentialParameters>
    <namedCredentialType>SecuredEndpoint</namedCredentialType>
</NamedCredential>
```

> **Important:** Metadata API v66.0 does not support `Password` or `NoAuthentication` protocols for ExternalCredentials. Use `Basic` protocol instead.

**Step 1b: Populate the External Credential Principal**

After deploying the metadata, set the actual credential values via Apex or the Connect REST API (secrets must never live in XML):

```apex
ConnectApi.CredentialInput input = new ConnectApi.CredentialInput();
input.authenticationProtocol = ConnectApi.CredentialAuthenticationProtocol.Basic;
input.externalCredential = 'CommodityPricing';
input.principalType = ConnectApi.CredentialPrincipalType.NamedPrincipal;
input.principalName = 'NamedPrincipal';

Map<String, ConnectApi.CredentialValueInput> creds = new Map<String, ConnectApi.CredentialValueInput>();

ConnectApi.CredentialValueInput username = new ConnectApi.CredentialValueInput();
username.encrypted = false;
username.value = 'placeholder';
creds.put('username', username);

ConnectApi.CredentialValueInput password = new ConnectApi.CredentialValueInput();
password.encrypted = true;
password.value = 'ca5d4a0ef4a62fc508ba4bee550753657539bd58b6147793ae53dd726042ae65';
creds.put('password', password);

input.credentials = creds;
ConnectApi.NamedCredentials.createCredential(input);
```

If the principal does not exist yet, use the Connect REST API to add it first:

```
PUT /services/data/v66.0/named-credentials/external-credentials/CommodityPricing
{
  "authenticationProtocol": "Basic",
  "masterLabel": "CommodityPricing",
  "developerName": "CommodityPricing",
  "principals": [
    {
      "principalName": "NamedPrincipal",
      "principalType": "NamedPrincipal",
      "sequenceNumber": 1
    }
  ]
}
```

> All secrets should be stored in the project's `.env` file and populated via the Connect API / Apex `sf apex run` script, never in metadata XML.

**Step 1c: Grant Principal Access**

For `NamedPrincipal` type, the user needs `SetupEntityAccess` to the principal. Run this once per permission set:

```apex
SetupEntityAccess access = new SetupEntityAccess();
access.ParentId = [SELECT Id FROM PermissionSet WHERE Name = 'O_G_All_Access' LIMIT 1].Id;
access.SetupEntityId = '0pug...principalId';
insert access;
```

**Step 2: Remote Site Setting** (still required for non-Named-Credential callouts, or verify the org's CSP Trusted Sites include the domain)

```
Setup → Remote Site Settings → New Remote Site
  Remote Site Name: CommodityPricing
  Remote Site URL: https://api.oilpriceapi.com
```

**Step 3: Add `Current_Price__c` field to `Supply_Agreement__c`**

Create field: `Supply_Agreement__c.Current_Price__c` (Number(18,2))

**Step 4: Create an Apex Service Class**

```apex
public with sharing class CommodityPricingService {

    private static final Map<String, String> COMMODITY_CODE_MAP = new Map<String, String>{
        'Crude' => 'WTI_USD',
        'Gas' => 'NATURAL_GAS_USD',
        'NGL' => 'BRENT_CRUDE_USD',
        'Refined' => 'GASOLINE_USD',
        'Diesel' => 'DIESEL_USD',
        'Jet Fuel' => 'JET_FUEL_USD',
        'Heating Oil' => 'HEATING_OIL_USD'
    };

    @future(callout=true)
    public static void syncPrices(Set<Id> agreementIds) {
        List<Supply_Agreement__c> agreements = [
            SELECT Id, Commodity__c, Current_Price__c
            FROM Supply_Agreement__c
            WHERE Id IN :agreementIds
        ];
        if (agreements.isEmpty()) return;

        Set<String> commodities = new Set<String>();
        for (Supply_Agreement__c ag : agreements) {
            if (ag.Commodity__c != null) commodities.add(ag.Commodity__c);
        }

        Map<String, Decimal> priceByCode = new Map<String, Decimal>();
        for (String commodity : commodities) {
            String apiCode = COMMODITY_CODE_MAP.get(commodity);
            if (apiCode == null) continue;
            Decimal price = fetchPrice(apiCode);
            if (price != null) priceByCode.put(commodity, price);
        }

        List<Supply_Agreement__c> updates = new List<Supply_Agreement__c>();
        for (Supply_Agreement__c ag : agreements) {
            if (priceByCode.containsKey(ag.Commodity__c)) {
                ag.Current_Price__c = priceByCode.get(ag.Commodity__c);
                updates.add(ag);
            }
        }
        if (!updates.isEmpty()) update updates;
    }

    private static Decimal fetchPrice(String apiCode) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:CommodityPricing/prices/latest?by_code=' + apiCode);
        req.setMethod('GET');
        req.setTimeout(10000);
        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() != 200) return null;
            Map<String, Object> responseMap = (Map<String, Object>)
                JSON.deserializeUntyped(res.getBody());
            Map<String, Object> data = (Map<String, Object>) responseMap.get('data');
            return data != null ? (Decimal) data.get('price') : null;
        } catch (Exception e) {
            System.debug('Failed to fetch price for ' + apiCode + ': ' + e.getMessage());
            return null;
        }
    }
}
```

**Step 5: Schedule Daily Sync**

```
Setup → Apex Classes → Schedule Apex
  Job Name: DailyPriceSync
  Apex Class: CommodityPricingService
  Frequency: Daily at 06:00
```

**Step 5: Add `Current_Price__c` field to `Supply_Agreement__c`**

Create field: `Supply_Agreement__c.Current_Price__c` (Number(18,2))

### 1.2 Slack Alerts for HSE Critical Incidents

**Step 1: Create a Slack App**

Go to https://api.slack.com/apps → Create New App → From Manifest.

```yaml
name: O&G HSE Alerts
display_information:
  name: O&G HSE Alerts
features:
  bot_user:
    display_name: O&G HSE Bot
    always_online: true
oauth_config:
  scopes:
    bot:
      - chat:write
      - channels:join
settings:
  event_subscriptions:
    request_url: https://your-sf-endpoint
```

**Step 2: Create Inbound Webhook in Slack**

Slack App → Incoming Webhooks → Activate → Add New Webhook → Post to #hse-emergency

**Step 3: Create External Credential + Named Credential (SecuredEndpoint)**

Slack webhooks use a token embedded in the URL. No auth headers are needed, but `SecuredEndpoint` with `Basic` protocol requires a configured principal.

```xml
<!-- externalCredentials/Slack_HSE_Webhook.externalCredential-meta.xml -->
<ExternalCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <authenticationProtocol>Basic</authenticationProtocol>
    <label>Slack_HSE_Webhook</label>
</ExternalCredential>
```

```xml
<!-- namedCredentials/Slack_HSE_Webhook.namedCredential-meta.xml -->
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
    <allowMergeFieldsInHeader>false</allowMergeFieldsInHeader>
    <label>Slack_HSE_Webhook</label>
    <namedCredentialParameters>
        <parameterName>Url</parameterName>
        <parameterType>Url</parameterType>
        <parameterValue>https://hooks.slack.com/services/T.../B.../xxxxx</parameterValue>
    </namedCredentialParameters>
    <namedCredentialParameters>
        <externalCredential>Slack_HSE_Webhook</externalCredential>
        <parameterName>ExternalCredential</parameterName>
        <parameterType>Authentication</parameterType>
    </namedCredentialParameters>
    <namedCredentialType>SecuredEndpoint</namedCredentialType>
</NamedCredential>
```

**Step 3b: Populate the Principal & Grant Access**

Add a named principal with dummy credentials (Slack ignores them), then grant user access via `SetupEntityAccess`:

```
PUT /services/data/v66.0/named-credentials/external-credentials/Slack_HSE_Webhook
{
  "authenticationProtocol": "Basic",
  "masterLabel": "Slack_HSE_Webhook",
  "developerName": "Slack_HSE_Webhook",
  "principals": [{
    "principalName": "NamedPrincipal",
    "principalType": "NamedPrincipal",
    "sequenceNumber": 1
  }]
}
```

```apex
// Set dummy credentials (Slack webhooks ignore auth headers)
ConnectApi.CredentialInput input = new ConnectApi.CredentialInput();
input.authenticationProtocol = ConnectApi.CredentialAuthenticationProtocol.Basic;
input.externalCredential = 'Slack_HSE_Webhook';
input.principalType = ConnectApi.CredentialPrincipalType.NamedPrincipal;
input.principalName = 'NamedPrincipal';

Map<String, ConnectApi.CredentialValueInput> creds = new Map<String, ConnectApi.CredentialValueInput>();
ConnectApi.CredentialValueInput u = new ConnectApi.CredentialValueInput();
u.encrypted = false; u.value = 'slack'; creds.put('username', u);
ConnectApi.CredentialValueInput p = new ConnectApi.CredentialValueInput();
p.encrypted = true; p.value = 'not-used'; creds.put('password', p);
input.credentials = creds;
ConnectApi.NamedCredentials.createCredential(input);

// Grant access via SetupEntityAccess
SetupEntityAccess sea = new SetupEntityAccess();
sea.ParentId = [SELECT Id FROM PermissionSet WHERE Name = 'O_G_All_Access' LIMIT 1].Id;
sea.SetupEntityId = '0pug...principalId'; // from Connect API response
insert sea;
```

**Step 4: Create an Apex Service with @future(callout=true)**

⚠️ The flow runs in the same transaction as the record update. Use `@future(callout=true)` to avoid the "uncommitted work pending" error.

```apex
public with sharing class SlackAlertService {

    @InvocableMethod(label='Send HSE Slack Alert')
    public static void sendAlert(List<Id> recordIds) {
        List<HSE_Incident__c> incidents = [
            SELECT Id, Incident_Type__c, Location__c, Incident_Date__c, CreatedBy.Name
            FROM HSE_Incident__c WHERE Id IN :recordIds
        ];
        for (HSE_Incident__c inc : incidents) {
            sendAlertAsync(inc.Id, inc.Incident_Type__c, inc.Location__c,
                inc.Incident_Date__c, inc.CreatedBy.Name);
        }
    }

    @future(callout=true)
    private static void sendAlertAsync(Id incidentId, String incidentType,
            String location, Date incidentDate, String reportedBy) {
        String recordUrl = Url.getOrgDomainUrl().toExternalForm() + '/' + incidentId;
        String slackText = '*🚨 CRITICAL HSE INCIDENT*\n' +
            '*Type:* ' + incidentType + '\n*Location:* ' + location + '\n' +
            '*Date:* ' + incidentDate + '\n*Reported by:* ' + reportedBy + '\n' +
            '<' + recordUrl + '|View in Salesforce>';

        Map<String, Object> message = new Map<String, Object>();
        message.put('channel', '#hse-emergency');
        message.put('blocks', new List<Object>{
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{
                    'type' => 'mrkdwn', 'text' => slackText
                }
            }
        });

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Slack_HSE_Webhook');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(message));
        req.setTimeout(10000);

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                insert new Task(Subject = 'Slack Alert Failed',
                    Description = 'HTTP ' + res.getStatusCode() + ': ' + res.getBody(),
                    Priority = 'High', Status = 'Not Started', WhatId = incidentId);
            }
        } catch (Exception e) {
            insert new Task(Subject = 'Slack Alert Failed',
                Description = e.getMessage(),
                Priority = 'High', Status = 'Not Started', WhatId = incidentId);
        }
    }
}
```

**Step 5: Create the Flow**

```
Flow: HSE_Critical_Slack_Alert
  Trigger: Record-Triggered (Update) on HSE_Incident__c
  Condition: Severity__c = 'Critical' AND PRIORVALUE(Severity__c) != 'Critical'
  Action: Invocable Apex → SlackAlertService.sendAlert (pass $Record.Id)
  Transaction Model: CurrentTransaction
  Status: Active
```

**Step 6: Activate the Flow**

```
Setup → Flows → HSE_Critical_Slack_Alert → Activate
```

### 1.3 Well Production Dashboard (CRM Analytics)

**Step 1: Enable CRM Analytics**

```
Setup → Analytics → Settings → Enable Analytics
```

**Step 2: Create a Dashboard Lens on Well__c**

1. Analytics Studio → Create → Dashboard
2. Add a "Well Production Trend" chart
   - Source: `Production_Allocation__c`
   - X-axis: `Period_End__c`
   - Y-axis: `Oil_Volume_bbls__c`, `Gas_Volume_MCF__c`, `Water_Volume_bbls__c`
   - Filter: `Well__c` equals current record ID
3. Add a "Well Status" gauge
   - Source: `Well__c`
   - Metric: Count by `Status__c`
4. Save as `Well_Production_Dashboard`

**Step 3: Embed on Page Layout**

- Well__c → Page Layouts → Well Layout
- Add Analytics Component → Select Well_Production_Dashboard
- Save → Activate

---

## Phase 2: External API Integrations (Week 3-6)

### 2.1 SCADA Pipeline Monitoring Integration

Connect real-time pipeline pressure, flow rate, and temperature data.

**Step 1: Define the Integration Schema**

| SCADA Source Field | Salesforce Target |
|---|---|
| Pipeline ID | `Pipeline__c.External_ID__c` |
| Flow Rate (bpd) | `Measurement__c.Gross_Volume__c` |
| Pressure (psi) | `Measurement__c.Pressure__c` |
| Temperature (F) | `Measurement__c.Temperature__c` |
| Timestamp | `Measurement__c.Reading_DateTime__c` |

**Step 2: Create REST API Endpoint in Salesforce**

Create an Apex REST class to accept SCADA data:

```apex
@RestResource(urlMapping='/api/scada/measurements')
global with sharing class SCADAIngestionAPI {
    @HttpPost
    global static String ingest() {
        RestRequest req = RestContext.request;
        List<SCADAReading> readings = (List<SCADAReading>)
            JSON.deserialize(req.requestBody.toString(), List<SCADAReading>.class);

        List<Measurement__c> measurements = new List<Measurement__c>();
        for (SCADAReading r : readings) {
            measurements.add(new Measurement__c(
                Pipeline__c = r.pipelineId,
                Reading_DateTime__c = r.timestamp,
                Gross_Volume__c = r.flowRate,
                Pressure__c = r.pressure,
                Temperature__c = r.temperature
            ));
        }
        insert measurements;

        // Flag anomalies
        for (Measurement__c m : measurements) {
            if (m.Pressure__c > 1500 || m.Pressure__c < 100) {
                createAnomalyAlert(m);
            }
        }

        return JSON.serialize(new Map<String, Object>{'status' => 'ok', 'count' => measurements.size()});
    }

    global class SCADAReading {
        global String pipelineId;
        global DateTime timestamp;
        global Decimal flowRate;
        global Decimal pressure;
        global Decimal temperature;
    }
}
```

**Step 3: Expose the Endpoint**

Deploy the class, then configure the SCADA system to POST to:
```
https://your-instance.salesforce.com/services/apexrest/api/scada/measurements
```

**Step 4: Create Pipeline Integrity Anomaly Detection Trigger**

```apex
trigger MeasurementTrigger on Measurement__c (after insert) {
    for (Measurement__c m : Trigger.new) {
        if (m.Pressure__c > 1500 || m.Pressure__c < 100) {
            // Create HSE Observation for pressure anomaly
            HSE_Observation__c obs = new HSE_Observation__c(
                Observation_Type__c = 'Unsafe',
                Category__c = 'Pressure Anomaly',
                Pipeline__c = m.Pipeline__c,
                Description__c = 'Pressure reading: ' + m.Pressure__c + ' psi',
                Status__c = 'Open'
            );
            insert obs;
        }
    }
}
```

### 2.2 Drilling Data Integration (Petrel / EDM)

**Step 1: Create Named Credential for Petrel API**

Create an External Credential + Named Credential (same SecuredEndpoint pattern as in 1.1) to avoid hardcoding the Petrel API URL and auth token in Apex:

```apex
// Reference in Apex: callout:PetrelAPI/wells?status=active
```

For the authentication method, choose the protocol that matches Petrel's API:
- **Basic** for username/password (store in Principal credentials)
- **Custom** for API key in a header

**Step 2: Sync Wells to Custom Object**

Create a scheduled job that reads from Petrel and upserts `Well__c` records:

```apex
global class PetrelWellSync implements Schedulable {
    global void execute(SchedulableContext ctx) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:PetrelAPI/wells?status=active');
        req.setMethod('GET');
        HttpResponse res = http.send(req);
        List<PetrelWell> wells = (List<PetrelWell>)
            JSON.deserialize(res.getBody(), List<PetrelWell>.class);

        List<Well__c> toUpsert = new List<Well__c>();
        for (PetrelWell pw : wells) {
            toUpsert.add(new Well__c(
                API_Number__c = pw.apiNumber,
                Well_Name__c = pw.wellName,
                Total_Depth__c = pw.totalDepth,
                True_Vertical_Depth__c = pw.tvd,
                Formation__c = pw.formation,
                Well_Type__c = pw.wellType
            ));
        }
        upsert toUpsert API_Number__c;
    }
}
```

### 2.3 Regulatory Filing API (EPA / State Agencies)

**Step 1: Create Compliance Report Auto-Filing**

Build a flow that, when `Compliance_Report__c.Status__c = 'Submitted'`, sends the data to EPA/CDX via their REST API:

```
Flow: AutoFileComplianceReport
  Trigger: Record-Triggered (Update) on Compliance_Report__c
  Condition: Status__c = 'Submitted'
  Action: HTTP Callout
    Method: POST
    URL: https://cdx.epa.gov/api/submit
    Headers:
      X-Auth-Token: {!$Credential.Password}
    Body: { report data from record fields }
  Action: Update Record
    Set Status__c = 'Filed'
    Set Submitted_Date__c = NOW()
```

---

## Phase 3: Einstein AI & Predictions (Week 7-10)

### 3.1 Well Production Forecasting

**Step 1: Enable Einstein Prediction Builder**

```
Setup → Einstein → Prediction Builder → Enable
```

**Step 2: Create a Prediction on Well__c**

- Object: `Well__c`
- Prediction Field: `Production_Status__c` (Declining / Stable / Increasing)
- Input Features:
  - `Production_Allocation__c.Oil_Volume_bbls__c` (last 12 months)
  - `Well_Type__c`
  - `Formation__c`
  - `Total_Depth__c`
  - `Well_Age__c` (calculated from `Completion_Date__c`)

**Step 3: Expose Prediction on Page Layout**

Add the Einstein Prediction component to the Well__c page layout. Field technicians see "86% probability of production decline" on each well.

### 3.2 Pipeline Failure Risk Prediction

**Step 1: Create a Custom Object for Predictions**

```apex
Object: Pipeline_Risk_Score__c
  Fields:
    Pipeline__c (Lookup)
    Risk_Score__c (Number 3,0)
    Risk_Factor__c (Picklist: Corrosion/Mechanical/Operational/Geological)
    Predicted_Date__c (Date)
    Confidence__c (Percent)
```

**Step 2: Build a Predictive Apex Service**

```apex
public with sharing class PipelineRiskPredictor {
    public static void calculateRiskScores() {
        // Logistic regression model using historical inspection data
        List<Pipeline__c> pipelines = [SELECT Id, Age__c, Last_Inspection_Date__c,
                                              Inspection_Count__c, Failure_History__c
                                       FROM Pipeline__c];
        for (Pipeline__c p : pipelines) {
            Decimal score = 0;
            score += (p.Age__c > 20 ? 30 : p.Age__c * 1.5);
            score += (p.Inspection_Count__c < 5 ? 25 : 0);
            score += (p.Failure_History__c > 0 ? 20 : 0);
            score += (System.now().date().daysBetween(p.Last_Inspection_Date__c) > 365 ? 25 : 0);
            updateRiskRecord(p.Id, score);
        }
    }
}
```

### 3.3 Retail Inventory Prediction

Use Einstein Discovery to predict when `Fuel_Inventory__c.Current_Volume__c` will drop below `Minimum_Threshold__c`:

```
Setup → Einstein → Discovery → Create Story
  Object: Fuel_Inventory__c
  Goal: Predict 'Days Until Restock Needed'
  Inputs:
    - Current_Volume__c
    - Average_Daily_Volume__c (rollup from Inventory_Transaction__c)
    - Day_of_Week
    - Season
    - Retail_Outlet__c.Type__c
```

---

## Phase 4: Experience Cloud Portal (Week 8-12)

### 4.1 Plan the Portal

**Choose a license type:**

| License | Best For | Limits |
|---|---|---|
| **Customer Community** | Partners, JV partners, suppliers | 1M page views/mo |
| **Customer Community Plus** | Same + more data access | 3M page views/mo |
| **Partner Community** | Channel partners, distributors | Customizable, API access |
| **Employee Community** | Field technicians, internal teams | Full CRM access |

**Recommended for this project:** **Partner Community** — JV partners, suppliers, and regulatory bodies need data visibility and document upload.

**Portal pages needed:**

| Page | Audience | Content |
|---|---|---|
| **Dashboard** | All | Production overview, compliance calendar, recent incidents |
| **Well Status** | JV Partners | Well list, status, production allocations, revenue |
| **Pipeline Integrity** | Regulators, Engineers | Inspection history, compliance status, risk scores |
| **HSE Incidents** | HSE Team, Regulators | Incident log, observation reporting, document upload |
| **Supply Chain** | Suppliers | Inventory levels, delivery schedules, contracts |
| **Partner Billing** | JV Partners | Invoices, revenue statements, payment history |

### 4.2 Setup Experience Cloud

**Step 1: Enable Experience Cloud**

```
Setup → All Sites → Get Started
  → Select "Partner Central" template
  → Site Name: "O&G Partner Portal"
  → Site Label: "O&G Partner Portal"
  → Create
```

**Step 2: Configure Site Settings**

```
Workspaces → All Sites → O&G Partner Portal → Builder
  Settings:
    - Site URL: https://your-domain.force.com/ogportal
    - Active Site: Checked
    - Require Login: Yes
    - Guest Access: Read-only for public content
```

**Step 3: Assign Permission Set Group**

Create permission set group `O_G_Portal_Access`:

| Permission Set | Grants |
|---|---|
| `O_G_Joint_Venture__c` Read, View | JV data access |
| `O_G_Production_Allocation__c` Read | Production data |
| `O_G_HSE_Incident__c` Read, Create | Incident viewing/reporting |
| `O_G_Invoice__c` Read | Invoice access |
| `O_G_Supply_Agreement__c` Read | Contract visibility |

Assign to Portal Users:
```
Setup → Users → Permission Set Group Assignments
  Select users → Assign O_G_Portal_Access
```

### 4.3 Build Portal Pages

**Step 1: Create the Dashboard Page**

In Experience Builder:
1. Add a **CRM Analytics Dashboard** component → Select `Well_Production_Dashboard`
2. Add a **Calendar** component → Source: `Compliance_Report__c.Due_Date__c`
3. Add a **Data Table** → Source: `HSE_Incident__c` (Recent 10, Severity = Critical)

**Step 2: Create Well Status Page**

1. Add a **List View** component → Object: `Well__c`
   - Fields: `Well_Name__c`, `API_Number__c`, `Status__c`, `Well_Type__c`, `Production_Status__c`
   - Actions: View → opens detail record page
2. Add a **Chart** component → Type: Bar, Source: `Production_Allocation__c`
   - Group by: `Period_End__c`
   - Values: `Oil_Volume_bbls__c`, `Gas_Volume_MCF__c`

**Step 3: Create Pipeline Integrity Page**

1. Add a **Tabs** component with tabs:
   - **Overview**: Data Table of `Pipeline__c` with `Compliance_Status__c`
   - **Inspections**: Data Table of `Inspection__c` filtered by Pipeline lookup
   - **Risk Map**: Map component with Pipeline route coordinates
   - **Documents**: File upload/download for inspection reports

**Step 4: Create HSE Incident Reporting Page**

1. Add a **Form** component → Object: `HSE_Incident__c`
   - Fields: `Incident_Type__c`, `Incident_Date__c`, `Severity__c`, `Location__c`,
            `Description__c`, `Spill_Volume__c`, `Environmental_Impact__c`
   - File Upload: Attach photos, reports
2. Add a **Map** component → Source: `HSE_Incident__c`
   - Pin by: `Location__c`, color by: `Severity__c`

**Step 5: Create Billing Page (JV Partners)**

1. Add a **Related List** → Object: `Invoice__c`
   - Filter: `JV__c` = Current Partner's JV
   - Fields: `Invoice_Number__c`, `Amount__c`, `Status__c`, `Invoice_Date__c`
2. Add a **Download** button → Command: Run Flow `Generate_Invoice_PDF`

### 4.4 Setup SSO Authentication

**Step 1: Configure My Domain**

```
Setup → My Domain → Register
  Domain: your-company-name
  Deploy to users
```

**Step 2: Configure SAML SSO**

```
Setup → Single Sign-On → New SAML SSO
  Name: Company SSO
  SAML Version: 2.0
  Issuer: https://your-idp.com/metadata
  Identity Provider Certificate: [Upload from IDP]
  Login URL: https://your-idp.com/login
  User ID Mapping: Federation ID
```

**Step 3: Enable for Experience Cloud**

```
Workspaces → O&G Partner Portal → Settings → Authentication
  Enable SAML SSO: Checked
  Login Type: SAML Single Sign-On
```

### 4.5 Deploy Page Variations by Profile

For each audience, create page variations in Experience Builder:

| Profile | Welcome Message | Visible Data |
|---|---|---|
| `O_G_JV_Partner` | "Welcome Partner" | Their JV wells, production, invoices |
| `O_G_Regulator` | "Regulatory Dashboard" | Compliance reports, permits, inspections |
| `O_G_Supplier` | "Supply Portal" | Inventory levels, delivery schedules |
| `O_G_Field_Technician` | "Field Operations" | Work orders, PTWs, inspection checklists |

Create filters using `$Network.Profile.Name` in page component visibility rules.

### 4.6 Publish the Portal

```
Workspaces → All Sites → O&G Partner Portal → Settings
  → Status: Live
  → Publish
```

Notify users with the portal URL:
```
https://your-domain.force.com/ogportal
```

### 4.7 Post-Launch Checklist

- [ ] Test user registration flow
- [ ] Verify SSO login works
- [ ] Check mobile responsiveness
- [ ] Test file upload/download
- [ ] Verify data visibility for each profile
- [ ] Set up Google Analytics tracking
- [ ] Configure weekly usage reports
- [ ] Test exception scenarios (expired password, locked account)

---

## Phase 5: Advanced Analytics (Week 10-14)

### 5.1 Executive KPI Dashboard

Create a CRM Analytics dashboard with:

| Widget | Source Object | Metric |
|---|---|---|
| Total Production | `Production_Allocation__c` | Sum Oil + Gas volumes (MTD) |
| Revenue by JV | `Invoice__c` | Sum Amount by JV (QTD) |
| Active Wells | `Well__c` | Count by Status |
| Pipeline Compliance | `Pipeline__c` | % Compliant vs Non-Compliant |
| HSE Incident Trend | `HSE_Incident__c` | Count by Month (last 12) |
| Top Producing Wells | `Well__c` + `Production_Allocation__c` | Oil Volume ranking |
| Inventory Coverage | `Fuel_Inventory__c` | % Below Threshold |
| Regulatory Calendar | `Regulatory_Permit__c` | Expirations next 90 days |

### 5.2 Automated PDF Generation

**Step 1: Install PDF Generation Solution**

```
Setup → AppExchange → Install "Conga Composer" or "S-Docs"
  (or use built-in Apex for simpler templates)
```

**Step 2: Create Visualforce Template for Royalty Statements**

```markup
<apex:page standardController="Lease__c">
    <h1>Royalty Statement</h1>
    <p>Lease: {!Lease__c.Name}</p>
    <p>Period: {!periodStart} - {!periodEnd}</p>
    <table>
        <tr><th>Well</th><th>Oil (bbls)</th><th>Gas (MCF)</th><th>Revenue</th></tr>
        <apex:repeat value="{!allocations}" var="a">
        <tr>
            <td>{!a.Well__r.Name}</td>
            <td>{!a.Oil_Volume_bbls__c}</td>
            <td>{!a.Gas_Volume_MCF__c}</td>
            <td>{!a.Allocated_Revenue__c}</td>
        </tr>
        </apex:repeat>
    </table>
</apex:page>
```

**Step 3: Schedule Monthly Batch**

```
Flow: Generate_Monthly_Statements
  Schedule: Monthly on 1st at 08:00
  Actions:
    1. Query active Lease__c records
    2. For each lease, generate PDF via Visualforce
    3. Email PDF to Lessor_Email__c
    4. Attach PDF to related Task record
```

---

## Phase 6: Data Cloud & 360 (Week 12-16)

### 6.1 Enable Data Cloud

```
Setup → Data Cloud → Enable Data Cloud
  Data Space: Oil_Gas_Data_Space
  Region: US (or your region)
```

### 6.2 Connect External Data Streams

| Data Stream | Source | Frequency | Destination Object |
|---|---|---|---|
| SCADA Pipeline Readings | REST Connector | Real-time | `Measurement__c` |
| Commodity Pricing | Platts/Argus API | Daily | `Price_Feed__c` (new) |
| EPA Compliance Status | EPA CDX API | Daily | `Regulatory_Permit__c` |
| Drilling Reports | Petrel OData | Hourly | `Well__c`, `Well_Operation__c` |
| Weather Data | NOAA/AccuWeather API | Hourly | `Weather_Data__c` (new) |
| ERP JV Accounting | SAP Connector | Daily | `Invoice__c`, `Joint_Venture__c` |

### 6.3 Create Unified Data Model

Map external data to Salesforce objects via Data Cloud's Data Model:

```
Data Cloud Object → Salesforce Object Mapping
  Pipeline_Measurement → Measurement__c
  Commodity_Price → Supply_Agreement__c.Current_Price__c
  Regulatory_Status → Regulatory_Permit__c.Compliance_Status__c
  Weather_Condition → Well__c.Weather_Delay__c (calculated)
```

### 6.4 Cross-Domain Insights

With Data Cloud unified, query across previously siloed data:

```
"What wells had >20% production drop within 7 days
 of a pipeline pressure anomaly AND freezing temperatures?"
```

This query spans: `Production_Allocation__c` + `Measurement__c` + `Weather_Data__c`.

---

## Phase 7: Salesforce Clouds Expansion (Week 8-14)

### 7.1 Sales Cloud — Pipeline & Account Management

Enhance opportunity management with O&G-specific sales stages and workflows.

**Step 1: Create Sales Stages for O&G**

| Stage | Description | Probability |
|---|---|---|
| Prospecting | Identify operator/JV partner | 10% |
| Bid/Proposal | Submit tender or proposal | 25% |
| Negotiation | Price/volume terms discussion | 50% |
| Contract Review | Legal & credit review | 75% |
| Won — Active | Contract executed, delivery active | 100% |
| Lost/Expired | Deal lost or contract expired | 0% |

**Step 2: Create Opportunity Record Types**

- `Supply_Contract` — for term/spot supply agreements
- `Service_Sale` — for drilling, well service, inspection contracts
- `Equipment_Sale` — for valves, pumps, meters
- `JV_Proposal` — for joint venture partnership proposals

**Step 3: Path and Kanban for Pipeline Deals**

```
Setup → Path Settings → Opportunity
  Add fields: Commodity_Type__c, Volume_MMBTU__c, Delivery_Point__c
  Add guidance: "Ensure credit check completed before Contract Review stage"
```

### 7.2 Service Cloud — Field Service & Work Orders

**Step 1: Enable Field Service**

```
Setup → Field Service → Settings
  Enable Field Service
  Set Service Territory: Oil & Gas Operations
  Set Operating Hours: 24/7 Emergency, Business Hours (Mon-Fri 8-5)
```

**Step 2: Create Service Territory Hierarchy**

```
Service Territory: All Operations
├── Region: Permian Basin
│   ├── Territory: West Texas Wells
│   └── Territory: Midland Pipelines
├── Region: Eagle Ford
│   ├── Territory: South Texas Wells
│   └── Territory: Corpus Christi Terminal
└── Region: Bakken
    ├── Territory: North Dakota Wells
    └── Territory: Williston Pipelines
```

**Step 3: Assign Service Resources**

| Resource Type | Skills | Certifications |
|---|---|---|
| Field Technician | Wellhead maintenance, pipeline inspection | H2S, TWIC, Confined Space |
| HSE Inspector | Safety audit, incident investigation | CSP, ASP |
| Compliance Officer | Regulatory filing, permit management | None |
| Pump Operator | Load/unload, tank gauging | DOT, HAZMAT |
| Roustabout | General well/pipeline maintenance | H2S, Fall Protection |

**Step 4: Configure Service Appointment Process**

```
Work Order Created
  → Dispatch service resource via Skills Match
  → Create Service Appointment
  → Assign Service Crew
  → Check PTW requirements (if Hot Work/Confined Space)
  → Field technician mobile check-in
  → Complete work, capture signature
  → Check-out, update Inventory if parts used
```

**Step 5: Mobile LWC for Field Technicians**

Extend existing LWCs for offline-capable mobile use:
- `fieldServiceChecklist` — works offline, syncs on reconnect
- `permitToWorkBoard` — read-only offline, permit creation requires connectivity
- `inventoryTankGauge` — real-time gauge reading with photo capture

### 7.3 Marketing Cloud — Customer & Partner Communications

**Step 1: Enable Marketing Cloud Account Engagement (Pardot)**

Integrate with Salesforce to segment and engage customers, partners, and regulators.

**Use Cases:**

| Campaign | Audience | Channel | Trigger |
|---|---|---|---|
| Regulatory Deadline Reminder | Compliance Officers | Email | 30 days before permit expiration |
| Monthly Production Statement | JV Partners | Email + Portal | 1st of month |
| HSE Safety Bulletin | All Field Staff | Email + SMS | New incident/alert |
| Inventory Restock Alert | Retail Outlet Managers | SMS + In-App | Below threshold |
| Contract Renewal Notice | Supply Customers | Email | 90 days before expiry |
| Rig Availability Alert | Drilling Contractors | Email | Speculative campaign quarterly |

**Step 2: Create Email Templates in Marketing Cloud**

```html
<!-- Regulatory Deadline Reminder -->
<h2>Compliance Reminder</h2>
<p>Dear %%Compliance_Officer_Name%%,</p>
<p>Your <b>%%Permit_Type%%</b> (Permit #%%Permit_Number%%)
   expires on <b>%%Expiration_Date%%</b>.</p>
<p>Please submit renewal documents at least 30 days before expiry.</p>
<a href="%%Portal_Login_URL%%">Login to O&G Partner Portal</a>
```

**Step 3: Automate with Journey Builder**

```
Journey: JV Monthly Statement
  Entry: Scheduled (1st of month)
  Audience: Contacts with JV Partner record type
  Step 1: Send Email "Monthly Production Statement"
  Step 2: Wait 3 days
  Step 3: If not opened → Send SMS alert
  Step 4: Wait 7 days
  Step 5: If not viewed → Create Task for Account Manager
```

---

## Phase 8: Agentforce & Einstein AI (Week 12-18)

### 8.1 Agentforce — AI-Powered Sales & Service Agent

Deploy Agentforce agents for field technicians, compliance officers, and partner self-service.

**Step 1: Enable Agentforce**

```
Setup → Agentforce → Enable Agentforce
  Service Agent: O&G Field Service Agent
  Sales Agent: O&G Supply Sales Agent
  Set Default Model: OpenAI GPT-4o (or Einstein Trust Layer)
```

**Step 2: Create Agentforce Topics & Actions**

| Agent | Topic | Actions |
|---|---|---|
| **Field Service Agent** | Well status lookup | Query Well__c, return status, last production |
| | PTW validation | Check Permit_to_Work__c validity, confirm isolation |
| | HSE reporting | Create HSE_Incident__c from chat |
| | Inventory check | Query Fuel_Inventory__c levels |
| | Inspection history | Return recent Inspection__c results |
| **Supply Sales Agent** | Contract terms | Query Supply_Agreement__c details |
| | Pricing | Call CommodityPricingService for current price |
| | Delivery status | Check Transportation_Nomination__c status |
| **Compliance Agent** | Permit expiry check | Query Regulatory_Permit__c upcoming expirations |
| | Report deadlines | Return Compliance_Report__c due dates |
| | Regulatory filing | Guide user through EPA filing requirements |

**Step 3: Configure Einstein Trust Layer**

Ensure sensitive O&G data (prices, contract terms, incident details) is protected:

```
Setup → Einstein → Trust Layer
  Data Masking: Enable for Pricing_Index__c, Contract_Value__c
  Audit Logging: All conversations logged for compliance
  PII Detection: Auto-redact personal data in agent transcripts
  Retention Policy: 90 days
```

**Step 4: Embed Agent on Record Pages**

Add the Agentforce chat component to key pages:

- **Well__c** → "Ask about this well's production history"
- **HSE_Incident__c** → "Report a new incident or check status"
- **Permit_to_Work__c** → "Validate PTW requirements"
- **Regulatory_Permit__c** → "Check renewal deadline"
- **Partner Portal** → "Ask about JV production and revenue"

**Step 5: Create Einstein Copilot Actions (Apex)**

```apex
public with sharing class AgentforceWellActions {
    @InvocableMethod(label='Get Well Status Summary')
    public static List<WellSummaryResult> getWellSummary(List<Id> wellIds) {
        List<WellSummaryResult> results = new List<WellSummaryResult>();
        if (wellIds.isEmpty()) return results;

        Well__c well = [SELECT Id, Name, API_Number__c, Status__c,
            Well_Type__c, Production_Status__c, Total_Depth__c
            FROM Well__c WHERE Id = :wellIds[0] LIMIT 1];

        AggregateResult agg = [SELECT SUM(Oil_Volume_bbls__c) totalOil,
            SUM(Gas_Volume_MCF__c) totalGas
            FROM Production_Allocation__c
            WHERE Well__c = :wellIds[0]
            AND Period_End__c = LAST_N_MONTHS:3];

        WellSummaryResult r = new WellSummaryResult();
        r.wellName = well.Name;
        r.apiNumber = well.API_Number__c;
        r.status = well.Status__c;
        r.wellType = well.Well_Type__c;
        r.productionStatus = well.Production_Status__c;
        r.totalDepth = well.Total_Depth__c;
        r.oilLast3Months = (Decimal) agg.get('totalOil');
        r.gasLast3Months = (Decimal) agg.get('totalGas');
        results.add(r);
        return results;
    }

    public class WellSummaryResult {
        public String wellName;
        public String apiNumber;
        public String status;
        public String wellType;
        public String productionStatus;
        public Decimal totalDepth;
        public Decimal oilLast3Months;
        public Decimal gasLast3Months;
    }
}
```

**Step 6: Define Agent Prompt Templates**

Create prompt templates for common agent interactions:

```
Template: Well Production Summary
  "Summarize the production status for well {!Well__c.Name}
   (API {!Well__c.API_Number__c}). Include the last 3 months
   of oil and gas volumes, current status, and any recent
   HSE incidents or inspections."

Template: PTW Safety Check
  "Validate permit to work {!Permit_to_Work__c.Name}.
   Check: (1) Is the permit still valid? (2) Are isolation
   requirements met? (3) Has gas testing been completed?
   (4) Are all required signatures obtained?"
```

### 8.2 Einstein Next Best Action

**Step 1: Define Recommendation Strategy**

| Scenario | Action | Channel |
|---|---|---|
| Well production declining >20% | Suggest workover or stimulation | Field Service Agent |
| Permit expiring within 30 days | Recommend renewal filing | Compliance Agent |
| Inventory below threshold | Recommend restock order | Retail Manager |
| Pipeline inspection overdue | Schedule inspection | Pipeline Engineer |
| HSE incident frequency increasing | Recommend safety stand-down | HSE Director |

**Step 2: Create Recommendation Objects**

```
Object: NBA_Recommendation__c
  Fields:
    Target_Object__c (Picklist: Well/Pipeline/Terminal/Retail_Outlet)
    Target_Record_Id__c (Text)
    Recommendation_Type__c (Picklist)
    Priority__c (Picklist: Low/Medium/High/Critical)
    Action_URL__c (URL)
    Expiration_Date__c (Date)
```

**Step 3: Surface Recommendations in LWC**

Extend existing record page LWCs to show Einstein NBA recommendations as contextual prompts.

### 8.3 Einstein Bot for Partner Portal

**Step 1: Create Einstein Bot**

```
Setup → Bots → New Bot
  Name: O&G Partner Support Bot
  Channel: Embedded Service (Experience Cloud)
```

**Step 2: Define Bot Dialogs**

| User Intent | Dialog Flow |
|---|---|
| "Show my production" | Query JV → Query Production_Allocation → Return formatted table |
| "When is my next royalty payment?" | Query Lease → Query Invoice → Return date and amount |
| "Report a safety concern" | Create HSE_Observation → Return case number |
| "Where is my delivery?" | Query Transportation_Nomination → Return status/location |
| "How do I file a permit?" | Link to regulatory help article + Compliance Agent handoff |

---

## Phase 9: Sustainability & IoT (Week 14-20)

### 9.1 Carbon & Emissions Tracking

**Step 1: Create Carbon Tracking Objects**

```xml
<CustomObject>
    <label>Carbon_ Emission__c</label>
    <fields>
        <field>Source__c</field>        <!-- Picklist: Flaring/Venting/Fugitive/Combustion/Purchased Power -->
        <field>Scope__c</field>         <!-- Picklist: Scope 1/2/3 -->
        <field>CO2e_MT__c</field>       <!-- Number: Metric tons CO2 equivalent -->
        <field>CH4_MT__c</field>        <!-- Number: Methane metric tons -->
        <field>N2O_MT__c</field>        <!-- Number: Nitrous oxide metric tons -->
        <field>Reporting_Period__c</field> <!-- Picklist: Monthly/Quarterly/Annual -->
        <field>Verified__c</field>      <!-- Checkbox -->
        <field>Verification_Body__c</field> <!-- Text: e.g., SGS, Bureau Veritas -->
        <field>Asset__c</field>         <!-- Lookup: Well__c, Pipeline__c, Refinery__c, Terminal__c -->
    </fields>
</CustomObject>
```

**Step 2: Calculate Emissions from Production Data**

Create an Apex job that calculates estimated emissions from flared volumes:

```apex
global with sharing class EmissionCalculator implements Schedulable {
    global void execute(SchedulableContext ctx) {
        List<Production_Allocation__c> records = [
            SELECT Id, Well__c, Period_End__c, Gas_Volume_MCF__c,
                (SELECT Id, CO2e_MT__c, Reporting_Period__c
                 FROM Carbon_Emissions__r
                 WHERE Reporting_Period__c = 'Monthly')
            FROM Production_Allocation__c
            WHERE Period_End__c = LAST_MONTH
        ];

        List<Carbon_Emission__c> emissions = new List<Carbon_Emission__c>();
        for (Production_Allocation__c pa : records) {
            if (pa.Carbon_Emissions__r.isEmpty()) {
                Decimal gasVolume = pa.Gas_Volume_MCF__c != null ? pa.Gas_Volume_MCF__c : 0;
                Decimal flarePercent = 0.02; // assume 2% flared
                Decimal co2e = gasVolume * flarePercent * 0.054; // EPA factor
                emissions.add(new Carbon_Emission__c(
                    Source__c = 'Flaring',
                    Scope__c = 'Scope 1',
                    CO2e_MT__c = co2e.setScale(2),
                    Reporting_Period__c = 'Monthly',
                    Asset__c = pa.Well__c
                ));
            }
        }
        if (!emissions.isEmpty()) insert emissions;
    }
}
```

**Step 3: Create Sustainability Dashboard**

CRM Analytics dashboard for ESG reporting:

| Widget | Metric | Source |
|---|---|---|
| Total CO2e (MT) | Sum by Scope | Carbon_Emission__c |
| Emission by Asset | Group bar by Well/Pipeline/Refinery | Carbon_Emission__c |
| Flare Volume Trend | Line chart by month | Production_Allocation__c |
| Methane Leak Detection | Count of fugitive events | HSE_Incident__c (type = Fugitive) |
| Intensity Ratio | CO2e per barrel produced | Carbon_Emission__c / Production_Allocation__c |
| Regulatory Compliance | % emissions with verified status | Carbon_Emission__c.Verified__c |

### 9.2 IoT Sensor Integration

**Step 1: Connect IoT Sensors via Platform Events**

```xml
<PlatformEvent>
    <label>Tank_Sensor_Reading__e</label>
    <fields>
        <field>Asset_Id__c</field>      <!-- Text: Tank/Sensor identifier -->
        <field>Level_Percent__c</field>  <!-- Number: Tank fill level 0-100 -->
        <field>Temperature_F__c</field>  <!-- Number -->
        <field>Pressure_PSI__c</field>   <!-- Number -->
        <field>Flow_Rate_bpd__c</field>  <!-- Number -->
        <field>Battery_Level__c</field>  <!-- Number: Sensor battery 0-100 -->
        <field>Reading_Timestamp__c</field> <!-- DateTime -->
    </fields>
</PlatformEvent>
```

**Step 2: Process IoT Events with Apex Trigger**

```apex
trigger TankSensorReadingTrigger on Tank_Sensor_Reading__e (after insert) {
    List<Fuel_Inventory__c> inventoriesToUpdate = new List<Fuel_Inventory__c>();

    for (Tank_Sensor_Reading__e event : Trigger.new) {
        // Find matching inventory record
        Fuel_Inventory__c inv = new Fuel_Inventory__c(
            External_ID__c = event.Asset_Id__c + '_Current'
        );
        // Map level percent to current volume
        // (Join with tank capacity from Asset or Fuel_Inventory.Capacity__c)
        inventoriesToUpdate.add(inv);
    }

    // Use External_ID for upsert
    Database.upsert(inventoriesToUpdate, Fuel_Inventory__c.External_ID__c, false);

    // Fire alerts for anomalies
    for (Tank_Sensor_Reading__e event : Trigger.new) {
        if (event.Level_Percent__c < 10) {
            // Publish inventory alert platform event
            Inventory_Alert__e alert = new Inventory_Alert__e(
                Tank_Id__c = event.Asset_Id__c,
                Level_Percent__c = event.Level_Percent__c,
                Alert_Type__c = 'Low Inventory',
                Alert_Timestamp__c = System.now()
            );
            EventBus.publish(alert);
        }
    }
}
```

**Step 3: Pipeline Leak Detection with IoT**

Use pressure/flow data from Measurement__c to trigger leak alerts:

| Condition | Alert | Action |
|---|---|---|
| Pressure drop >20% in 5 min | Potential leak | Create HSE_Incident → Slack alert |
| Flow rate mismatch >5% (inlet vs outlet) | Theft or leak | Notify Pipeline Engineer |
| Temperature anomaly >15°F | Equipment failure | Dispatch field service |
| Vibration exceeds threshold | Pump bearing failure | Schedule maintenance |

### 9.3 Sustainability Reporting — Automated ESG Filing

**Step 1: Map ESG Data Sources**

| ESG Category | Data Source | Frequency |
|---|---|---|
| GHG Emissions (Scope 1) | Carbon_Emission__c (Flaring, Venting) | Monthly |
| GHG Emissions (Scope 2) | Purchased power records | Monthly |
| GHG Emissions (Scope 3) | Supply chain estimates | Quarterly |
| Water Usage | Injection volumes, disposal records | Monthly |
| Spill Incidents | HSE_Incident__c (type = Spill) | Real-time |
| Safety Metrics | HSE_Incident__c (LTI, Recordable) | Monthly |
| Community Investment | Campaign records | Quarterly |

**Step 2: Create ESG Report Template**

```visualforce
<apex:page standardController="Account" recordSetVar="accounts">
    <h1>ESG Performance Report</h1>
    <h2>Period: {!FROM} — {!TO}</h2>

    <h3>GHG Emissions</h3>
    <table>
        <tr><th>Scope</th><th>CO2e (MT)</th><th>CH4 (MT)</th><th>N2O (MT)</th></tr>
        <apex:repeat value="{!emissionsByScope}" var="scope">
        <tr>
            <td>{!scope.Scope__c}</td>
            <td>{!scope.totalCO2e}</td>
            <td>{!scope.totalCH4}</td>
            <td>{!scope.totalN2O}</td>
        </tr>
        </apex:repeat>
    </table>

    <h3>Safety Statistics</h3>
    <p>Total Recordable Incident Rate (TRIR): {!trir}</p>
    <p>Lost Time Injury Frequency (LTIF): {!ltif}</p>
    <p>Spill Incidents: {!spillCount}</p>
</apex:page>
```

**Step 3: Schedule Quarterly ESG Report Generation**

```
Flow: Generate_ESG_Report
  Schedule: Quarterly (Jan 15, Apr 15, Jul 15, Oct 15)
  Actions:
    1. Query Carbon_Emission__c (last quarter)
    2. Query HSE_Incident__c (last quarter)
    3. Calculate TRIR, LTIF, total emissions
    4. Generate PDF via Visualforce
    5. Email to ESG-Compliance@company.com
    6. Attach to Account record (Operator)
```

### 9.4 Weather & Geospatial API Integration

**Step 1: Create Weather Data Object**

```
Object: Weather_Reading__c
  Fields:
    Location__c (Geolocation)
    Temperature_F__c (Number)
    Wind_Speed_mph__c (Number)
    Precipitation_in__c (Number)
    Visibility_mi__c (Number)
    Weather_Condition__c (Picklist: Clear/Rain/Snow/Ice/Fog/Storm)
    Reading_DateTime__c (DateTime)
    Asset__c (Lookup: Well__c, Pipeline__c, Terminal__c)
```

**Step 2: Create Named Credential for Weather API**

```
External Credential: WeatherAPI (Basic protocol)
Named Credential:   WeatherAPI → https://api.weather.gov/points/
```

**Step 3: Schedule Weather Data Sync**

```apex
global class WeatherDataSync implements Schedulable {
    global void execute(SchedulableContext ctx) {
        // Sync weather for critical assets
        List<Well__c> wells = [SELECT Id, Name, Latitude__c, Longitude__c
                               FROM Well__c WHERE Status__c = 'Producing'];
        for (Well__c w : wells) {
            Weather_Reading__c reading = fetchWeather(w.Latitude__c, w.Longitude__c);
            if (reading != null) {
                reading.Asset__c = w.Id;
                insert reading;
            }
        }
    }

    private Weather_Reading__c fetchWeather(Decimal lat, Decimal lon) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:WeatherAPI/' + lat + ',' + lon + '/forecast');
        req.setMethod('GET');
        req.setTimeout(5000);
        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> resp = (Map<String, Object>)
                    JSON.deserializeUntyped(res.getBody());
                Map<String, Object> props = (Map<String, Object>) resp.get('properties');
                List<Object> periods = (List<Object>) props.get('periods');
                Map<String, Object> current = (Map<String, Object>) periods[0];
                return new Weather_Reading__c(
                    Temperature_F__c = (Decimal) current.get('temperature'),
                    Wind_Speed_mph__c = parseWindSpeed((String) current.get('windSpeed')),
                    Weather_Condition__c = (String) current.get('shortForecast'),
                    Reading_DateTime__c = System.now()
                );
            }
        } catch (Exception e) {
            System.debug('Weather fetch failed: ' + e.getMessage());
        }
        return null;
    }
}
```

### 9.5 ROI Matrix Update

| Enhancement | Effort | Impact | Timeline |
|---|---|---|---|
| Slack HSE Alerts | Low | High (safety) | Week 1 |
| Commodity Pricing | Low | Medium | Week 1 |
| SCADA Integration | Medium | High (ops) | Week 3 |
| Experience Cloud Portal | High | High (partners) | Week 8 |
| Einstein Predictions | Medium | High | Week 7 |
| Data Cloud | High | Transformative | Week 12 |
| Regulatory API Filing | Medium | Medium (compliance) | Week 5 |
| PDF Statements | Low | Medium | Week 2 |
| **Sales Cloud (Stages/Pipelines)** | Low | Medium | Week 8 |
| **Service Cloud (Field Service)** | High | High (ops efficiency) | Week 10 |
| **Marketing Cloud (Journeys)** | Medium | Medium (engagement) | Week 10 |
| **Agentforce Agent** | Medium | High (productivity) | Week 14 |
| **Einstein Bots** | Medium | Medium (self-service) | Week 14 |
| **Carbon Tracking** | Medium | High (ESG) | Week 15 |
| **IoT Sensor Integration** | High | Transformative | Week 16 |
| **Weather API Integration** | Low | Medium (safety) | Week 14 |
| **ESG Automated Reporting** | Medium | High (compliance) | Week 18 |

---

Before deploying any Apex class, ensure >= 75% code coverage:

```bash
sf apex run test --target-org "Oil gas" --test-level RunLocalTests -w 10
```

### B. Deployment Commands

```bash
# Deploy specific metadata
sf project deploy start --target-org "Oil gas" -d force-app/main/default/classes -w 10

# Deploy destructive changes
sf project deploy start --target-org "Oil gas" --pre-destructive-changes destructiveChangesPre.xml -x package.xml -w 10

# Retrieve full metadata
sf project retrieve start --target-org "Oil gas" -m "CustomObject:A,Layout,Flow,ApexClass,PermissionSet"
```

### C. Secret Management Strategy

**Never store secrets in metadata XML files.** The `.env` file at the project root is the source of truth:

```
# .env
OIL_PRICE_API_KEY=xxx
EIA_API_KEY=xxx
SLACK_WEBHOOK_URL=xxx
```

After deploying External Credentials + Named Credentials, populate the Principal credentials via the Connect REST API or Apex:

```bash
# 1. Add a principal to the External Credential
curl -X PUT https://domain.my.salesforce.com/services/data/v66.0/named-credentials/external-credentials/MyCred \
  -H "Authorization: Bearer $token" \
  -H "Content-Type: application/json" \
  -d '{
    "authenticationProtocol": "Basic",
    "masterLabel": "MyCred",
    "developerName": "MyCred",
    "principals": [{"principalName": "NamedPrincipal", "principalType": "NamedPrincipal", "sequenceNumber": 1}]
  }'

# 2. Set credential values
sf apex run --target-org myOrg --file scripts/set_credentials.apex
```

The Apex script reads from the Connect API:

```apex
ConnectApi.CredentialInput input = new ConnectApi.CredentialInput();
input.externalCredential = 'MyCred';
input.principalType = ConnectApi.CredentialPrincipalType.NamedPrincipal;
input.principalName = 'NamedPrincipal';
input.authenticationProtocol = ConnectApi.CredentialAuthenticationProtocol.Basic;
// Map of credential values (username, password, or custom params)
Map<String, ConnectApi.CredentialValueInput> creds = new Map<String, ConnectApi.CredentialValueInput>();
ConnectApi.CredentialValueInput val = new ConnectApi.CredentialValueInput();
val.encrypted = true;
val.value = 'the-secret-value';
creds.put('password', val);
input.credentials = creds;
ConnectApi.NamedCredentials.createCredential(input);
```

Then grant user access via `SetupEntityAccess`:

```apex
SetupEntityAccess sea = new SetupEntityAccess();
sea.ParentId = [SELECT Id FROM PermissionSet WHERE Name = 'O_G_All_Access' LIMIT 1].Id;
sea.SetupEntityId = principalId; // from Connect API response
insert sea;
```

### D. Enhancement ROI Matrix

| Enhancement | Effort | Impact | Timeline |
|---|---|---|---|
| Slack HSE Alerts | Low | High (safety) | Week 1 |
| Commodity Pricing | Low | Medium | Week 1 |
| SCADA Integration | Medium | High (ops) | Week 3 |
| Experience Cloud Portal | High | High (partners) | Week 8 |
| Einstein Predictions | Medium | High | Week 7 |
| Data Cloud | High | Transformative | Week 12 |
| Regulatory API Filing | Medium | Medium (compliance) | Week 5 |
| PDF Statements | Low | Medium | Week 2 |
| **Sales Cloud (Stages/Pipelines)** | Low | Medium | Week 8 |
| **Service Cloud (Field Service)** | High | High (ops efficiency) | Week 10 |
| **Marketing Cloud (Journeys)** | Medium | Medium (engagement) | Week 10 |
| **Agentforce Agent** | Medium | High (productivity) | Week 14 |
| **Einstein Bots** | Medium | Medium (self-service) | Week 14 |
| **Carbon Tracking** | Medium | High (ESG) | Week 15 |
| **IoT Sensor Integration** | High | Transformative | Week 16 |
| **Weather API Integration** | Low | Medium (safety) | Week 14 |
| **ESG Automated Reporting** | Medium | High (compliance) | Week 18 |
