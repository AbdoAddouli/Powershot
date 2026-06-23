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

## Appendices

### A. Apex Test Requirements

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
