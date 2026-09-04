# DocuSign Integration Plan (JV Agreement e-Signature in Partner Portal)

Status: **Planned — not yet implemented** (stored for later execution)

## Objective

Add DocuSign eSignature (REST API v2.1) so JV partners sign the Joint Venture agreement
embedded inside the Experience Cloud portal. Salesforce learns of signing via a DocuSign
**Connect** webhook (HMAC-verified) and stores the signed PDF on the JV record.

### Decisions (confirmed)
- **First rollout:** Joint Venture Agreement signed in the portal.
- **Completion events:** DocuSign Connect webhook → new guest `@RestResource` (exact
  `WhatsAppWebhookHandler` HMAC fail-closed pattern).
- **Signing experience:** Embedded / captive recipient signing inside the portal (opens DocuSign
  in a new tab).

### Hard dependency
- Embedded signing requires a **JV-partner Community user** — this is the still-blocked task
  **1F**. Create that user as part of rollout (or else only the backend/webhook halves work).

### Prerequisites (external, DocuSign console — not in repo)
1. DocuSign account (demo initially) + eSignature enabled.
2. **Integration Key** (app) with OAuth 2.0 JWT grant: RSA key pair, user ID, consent, scopes
   `signature` + `impersonation`.
3. Data-center REST base URL (e.g. `https://demo.docusign.net/restapi`, could be `na2`, `eu`, …).
4. One **DocuSign template** "JV Agreement": a signer role (e.g. `JVSigner`), merge/data fields
   (JV name, operator, WI/NRI %, accounting method), `clientUserId` used for captive signing.
5. **Connect configuration:** URL `https://<org>.my.salesforce.com/services/apexrest/api/docusign/connect`,
   events Sent/Delivered/Completed/Declined/Voided, payload **JSON**, a shared **HMAC secret**.

---

## Current State (what already exists)

| Piece | File | Notes |
|---|---|---|
| Inbound webhook template | `WhatsAppWebhookHandler.cls` | `without sharing` + `@RestResource`, HMAC-SHA256 header, fail-closed, fast 200; `X-Hub-Signature-256` vs ours `X-DocuSign-Signature-1/-2` |
| Guest webhook Site | `sites/whatssapp_webhook.site-meta.xml` | Live guest Site exposing Apex REST — clone for DocuSign |
| Callout infra | `namedCredentials/`, `externalCredentials/`, `remoteSiteSettings/`, `cspTrustedSites/` | House pattern ships all four (`PetrelAPI` Basic; `GTM_API` OAuth w/ NamedPrincipal) |
| Config settings | `WhatsApp_Config__c`, `API_Key_Settings__c`, `GTM_Config__c` | Custom Setting pattern for `DocuSign_Config__c` |
| JV record | `Joint_Venture__c` | `JV_Agreement_Document__c` is Text(255) doc ref only — no file fields | Portal | `networks/PowerShot.network-meta.xml` | Live Experience Cloud site; pages built manually in Experience Builder (not in source) |

Notes:
- No DocuSign/signature code exists yet. No `ContentVersion` handling anywhere (signed-PDF
  storage is a new capability).
- `O_G_Portal_Access` permission set is where portal-facing FLS goes.

---

## Phase 1 — Schema (new fields)

### New object `Document_Envelope__c` (persistence, mirrors `WhatsApp_Message__c`)
- `Envelope_Key__c` — Text(255), **unique, ExternalId, indexed** → webhook idempotency
- `Joint_Venture__c` — Lookup(`Joint_Venture__c`)
- `Account__c` — Lookup(`Account__c`)
- `Related_Object_Type__c` / `Related_Record_Id__c` — Text, for future signable objects
- `Template_Id__c` — Text
- `Status__c` — Picklist: `Draft`, `Sent`, `Delivered`, `Completed`, `Declined`, `Voided`, `Error`
- `Signer_Contact__c` — Lookup(`Contact__c`), `Signer_Name__c`, `Signer_Email__c`
- `Sent_Date__c`, `Completed_Date__c`
- `Signed_Document_Id__c` — File reference (ContentVersion id)
- `Last_Connect_Event__c` (DateTime), `Connect_Event_Count__c`
- `Error_Message__c`

### `Joint_Venture__c`
- Extend `Status__c` picklist: add `Awaiting Signature`, `Executed`
- Add `Signed_Date__c` (Date), `Latest_Envelope__c` (Lookup `Document_Envelope__c`)

### `DocuSign_Config__c` Custom Setting (hierarchy — mirrors `WhatsApp_Config__c`)
- `Enabled__c` (Checkbox), `Connect_Secret__c` (Text), `Account_Id__c` (Text),
  `Api_Base_Url__c` (Text, e.g. `https://demo.docusign.net/restapi`),
  `Default_Template_Id__c` (Text), `Portal_Return_Url__c` (Text)

### Permission sets
- `O_G_Portal_Access`: FLS read on portal-facing `Document_Envelope__c` fields + JV status/signed-date
- Profiles: update `Admin` for new object/fields if needed

---

## Phase 2 — Credentials (mirror existing metadata exactly)

- `namedCredentials\DocuSign.namedCredential-meta.xml` — clone `GTM_API`/`PetrelAPI` structure:
  `Url = https://demo.docusign.net/restapi/v2.1`, `generateAuthorizationHeader=true`,
  `ExternalCredential = DocuSign`
- `externalCredentials\DocuSign.externalCredential-meta.xml` — `authenticationProtocol = Oauth`,
  authProvider `DocuSign_OAuth`, `NamedPrincipal` scope `signature impersonation` (layout of `GTM_API` EC)
- `remoteSiteSettings\DocuSign.remoteSite-meta.xml` — `https://demo.docusign.net`
- `cspTrustedSites\DocuSign.cspTrustedSite-meta.xml`
- Org-level manual entry (cannot be source-controlled): authorize principal, set client secret / RSA
  key on the principal/PerRequesterAuthProvider so tokens mint at runtime

---

## Phase 3 — `DocuSignService.cls` (Apex callout layer — EIAPricingService/GTMService style)

`with sharing`, base `callout:DocuSign`, try/catch → `Error_Message__c`.

- `createEnvelope(Id jvId, Id signerContactId)` →
  `POST /accounts/{accountId}/envelopes`
  - body: `templateId`, `templateRoles` (role `JVSigner`, email/name from Contact,
    `clientUserId` = Contact Id for captive signing), `customFields` carrying
    `jvId` + `envelopeType`, `status: 'sent'`
  - upserts `Document_Envelope__c` (Envelope_Key) and flips JV → `Awaiting Signature`
- `getRecipientViewUrl(Id envelopeId, Id userId)` →
  `POST /accounts/{a}/envelopes/{e}/views/recipient`
  - returns signing URL; `returnUrl` = `DocuSign_Config__c.Portal_Return_Url__c`
- `fetchCombinedPdf(Id envelopeId)` →
  `GET /accounts/{a}/envelopes/{e}/documents/combined?_fallback=true` → base64

---

## Phase 4 — Connect webhook (reuse WhatsApp end-to-end)

- `DocuSignConnectWebhook.cls` — `global without sharing` + `@RestResource(urlMapping='/api/docusign/connect')`:
  1. Read raw body; validate `X-DocuSign-Signature-1` (and `-2`) via HMAC-SHA256 with
     `Connect_Secret__c` — `Crypto.generateMac` + constant-time compare (copy
     `WhatsAppWebhookHandler.isSignatureValid`). **Fail-closed 401** if missing/blank/unconfigured.
  2. Idempotency: upsert `Document_Envelope__c` by `Envelope_Key__c`; track `Connect_Event_Count__c` /
     `Last_Connect_Event__c`, ignore stale/duplicate events.
  3. On `Completed`: update envelope + `Joint_Venture__c`
     (`Status__c='Executed'`, `Signed_Date__c`), ensure portal sharing with partner Account,
     then enqueue **`DocuSignPdfFetchQueueable`** (callout in Interface+R) →
     `DocuSignService.fetchCombinedPdf` → `ContentVersion`
     (`FirstPublishLocationId` = JV record, `PathOnClient` = `JV_Agreement_Signed.pdf`) → set `Signed_Document_Id__c`.
- `sites\docusign_webhook.site-meta.xml` — clone `whatssapp_webhook`; grant guest profile
  access to `Document_Envelope__c` + the new `@RestResource`. Auth = HMAC, not guest profile
  (same security model WhatsApp already uses).
- **DocuSign console (Connect):** URL as above, events Sent/Delivered/Completed/Declined/Voided,
  JSON payload, enable commits, set the HMAC secret.

---

## Phase 5 — Portal UX (presentation-only, existing mockup design tokens)

- `DocuSignController.cls`:
  - `@AuraEnabled(cacheable=true) getEnvelopes()` — envelopes for JV records shared to the
    current portal user (via `$user.contactId` → Account → JV)
  - `@AuraEnabled getSigningUrl(Id envelopeId)` → `DocuSignService.getRecipientViewUrl`
- `portalDocuSign` LWC — JV agreement status cards (boarding style of `portalCompliance`) +
  **Sign Now** → `window.open(url,'_blank')` → status refresh after return; signed PDF opens
  the stored File.
- Mount component in Experience Builder portal nav (manual UI step — pages not in source control).

---

## Phase 6 — Tests (`HttpCalloutMock`, house patterns)

- `TestDocuSignConfig` — config/setup
- `TestDocuSignService` — envelope create + recipient-view callouts (assert endpoint/method/body),
  error path
- `TestDocuSignConnectWebhook`:
  - valid HMAC → Completed → envelope + JV updated, PDF queueable enqueued
  - bad / missing signature → 401
  - duplicate event → single update (idempotent)
  - Voided / Declined statuses accepted
  - unconfigured secret → fail-closed
- `TestDocuSignPdfFetchQueueable` — mocked PDF response → ContentVersion created
- Re-run `TestPortalPageControllers` — must stay 13/13 green; full-suite sanity.

---

## Phase 7 — Deploy & configure

```
sf project deploy start -d "force-app\main\default\objects\Document_Envelope__c" -d "force-app\main\default\objects\Joint_Venture__c" -d "force-app\main\default\customSettingTemplates" -d "force-app\main\default\namedCredentials" -d "force-app\main\default\externalCredentials" -d "force-app\main\default\permissionSetExternalCredentials" -d "force-app\main\default\remoteSiteSettings" -d "force-app\main\default\cspTrustedSites" -d "force-app\main\default\sites" -d "force-app\main\default\classes" -d "force-app\main\default\lwc" -d "force-app\main\default\permissionsets" -d "force-app\main\default\profiles" -o "ouil gas"
sf apex run test --class-names "TestDocuSignService,TestDocuSignConnectWebhook,TestDocuSignPdfFetchQueueable,TestPortalPageControllers" --synchronous -o "ouil gas"
```

- Anonymous Apex: insert `DocuSign_Config__c` (Enabled, Connect_Secret, Account_Id, Api_Base_Url,
  Default_Template_Id, Portal_Return_Url). Nothing to schedule (webhook-driven).
- Manual end-to-end: DocuSign sandbox — create template, enable Connect, sign a real envelope as
  a portal user, confirm event lands and signed PDF attaches to the JV record.

---

## Reference patterns in this repo

- `WhatsAppWebhookHandler.cls` — HMAC-SHA256 fail-closed inbound webhook + `without sharing`
- `sites/whatssapp_webhook.site-meta.xml` — guest Site exposing Apex REST
- `namedCredentials/GTM_API.*`, `externalCredentials/GTM_API.*` — OAuth NamedPrincipal callout setup
- `WhatsApp_Config__c`, `API_Key_Settings__c` — Custom Setting config pattern
- `EIAPricingService.cls` / `GTMService.cls` — callout base URL + `HttpRequest` builder style

---

## Future extensions (out of scope now)

- Other signable objects (`Service_Contract__c`, `Supply_Agreement__c`, `Lease__c`,
  `Regulatory_Permit__c`, `Permit_to_Work__c`) via the generic `Related_Object_Type__c`
  pointer fields.
- Scheduled polling fallback (`DocuSignSyncScheduler`) if Connect is undesired for an object.
- DocuSign templates per agreement type (map by `Template_Id__c` + object type).