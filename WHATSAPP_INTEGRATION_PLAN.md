# WhatsApp Integration Plan — PowerShot

**Project:** Energy_Salesforce_project  
**Target Org:** `ouil gas` (addouliabdo9.76deae143000@agentforce.com)  
**API Version:** 66.0  
**Date:** August 2026  
**Status:** TODO — Not yet started

---

## Overview

Build a custom Apex webhook integration that receives WhatsApp messages via Meta's WhatsApp Cloud API, stores them in a custom `WhatsApp_Message__c` object, and matches senders to existing Salesforce Contacts by phone number.

**Cost:** Inbound messages are always free. Within a 24-hour customer service window, replies are also free. No Meta setup fee.

---

## Prerequisites (Meta Side — Do First)

### Step 1: Create a Meta Developer Account & App

1. Go to [developers.facebook.com](https://developers.facebook.com) → Log in with your Facebook account
2. Click **My Apps** → **Create App**
3. Select **Business** type → Enter app name (e.g., "PowerShot WhatsApp")
4. Under **Add Products**, click **Set up** next to **WhatsApp**
5. This creates a **WhatsApp Business Account (WABA)** and gives you a test phone number

### Step 2: Get Your Credentials

Store these 4 values in `.env`:

| Credential | Where to find it |
|---|---|
| `WHATSAPP_PHONE_NUMBER_ID` | WhatsApp → Getting Started → Phone Number ID |
| `WHATSAPP_ACCESS_TOKEN` | WhatsApp → Getting Started → Temporary Access Token (or generate a System User token for production) |
| `WHATSAPP_VERIFY_TOKEN` | You create this yourself (any string, e.g., `powershot_verify_2026`) |
| `WHATSAPP_APP_SECRET` | App Settings → Basic → App Secret |

### Step 3: Register Your Webhook

Once the Salesforce endpoint is built (Steps 2-5 below), come back to:

- WhatsApp → Configuration → Webhooks → **Edit Callback URL**
- Paste your Salesforce public URL (e.g., `https://your-domain.force.com/services/apexrest/whatsapp/webhook`)
- Paste your verify token
- Click **Verify and Save**
- Subscribe to the **messages** field

---

## Salesforce Implementation

### Step 1: Create Custom Object `WhatsApp_Message__c`

**Object:** `WhatsApp_Message__c`  
**Label:** WhatsApp Message  
**Plural Label:** WhatsApp Messages  
**Name Format:** WA-{00000}

| Field | API Name | Type | Description |
|---|---|---|---|
| WhatsApp Message ID | `WhatsApp_Message_ID__c` | Text(100) | Meta's unique message ID (for idempotency) |
| Sender Phone | `Sender_Phone__c` | Phone | Sender's phone number (E.164 format) |
| Sender Name | `Sender_Name__c` | Text(255) | Profile name from WhatsApp |
| Message Body | `Message_Body__c` | Long Text Area(3000) | Text content of the message |
| Message Type | `Message_Type__c` | Picklist | Text, Image, Video, Document, Audio, Location, Sticker, Template, Reaction |
| Direction | `Direction__c` | Picklist | Inbound, Outbound |
| Status | `Status__c` | Picklist | Sent, Delivered, Read, Failed |
| Timestamp | `Timestamp__c` | DateTime | WhatsApp message timestamp |
| Contact | `Contact__c` | Lookup(Contact) | Matched Contact record |
| Account | `Account__c` | Lookup(Account) | Resolved Account (via Contact) |
| Raw Payload | `Raw_Payload__c` | Long Text Area(10000) | Full JSON from Meta (for debugging) |

**Compact Layout:** `WA_Compact_Layout` with `Sender_Name__c`, `Sender_Phone__c`, `Message_Type__c`, `Direction__c`, `Contact__c`

**List Views:** All, Inbound Messages, Outbound Messages

---

### Step 2: Create Apex REST Webhook Endpoint

**Class:** `WhatsAppWebhookHandler` (`@RestResource`)

```
@RestResource(urlMapping='/whatsapp/webhook')
```

**GET method** — Webhook verification:
- Meta sends `hub.mode`, `hub.verify_token`, `hub.challenge`
- If `verify_token` matches your configured token → return `hub.challenge` with 200
- Otherwise → return 403

**POST method** — Receive messages:
- Parse incoming JSON payload
- Extract: sender phone, message body, message type, timestamp, message ID
- **Idempotency check:** Query `WhatsApp_Message__c` where `WhatsApp_Message_ID__c = incoming ID` → skip if exists
- **Phone normalization:** Ensure E.164 format (prepend country code if missing)
- **Contact match:** Query `Contact` where `Phone = :normalizedPhone` OR `MobilePhone = :normalizedPhone`
- Create `WhatsApp_Message__c` record with all extracted fields
- If Contact found → set `Contact__c` and `Account__c` (via Contact.AccountId)
- Store full raw payload in `Raw_Payload__c`
- Return 200 OK immediately (Meta requires fast acknowledgment, <5s)

**Helper Class:** `WhatsAppMessageService`
- `normalizePhone(String phone)` → E.164 format
- `matchContact(String phone)` → Contact or null
- `parseAndStore(String jsonPayload)` → WhatsApp_Message__c

---

### Step 3: Expose Endpoint via Experience Cloud Site

Since Meta needs a **publicly accessible URL**, create a minimal **Experience Cloud (Force.com) site**:

1. **Setup** → **All Sites** → **Get Started**
2. Select **Customer Service** template (free)
3. Site Name: `WhatsApp Webhook`
4. Site Label: `WhatsApp Webhook`
5. After creation → go to **Workspaces** → **Administration** → **Pages** → **Public Access Settings**
6. Under **Apex Class Access** → Add `WhatsAppWebhookHandler`
7. Under **Profile** → ensure the guest profile has **no object access** (security)
8. Copy the site URL: `https://your-domain.force.com/services/apexrest/whatsapp/webhook`

---

### Step 4: Named Credential for Future Outbound Messages

**External Credential:** `WhatsApp_API`
```xml
<ExternalCredential>
    <authenticationProtocol>Basic</authenticationProtocol>
    <label>WhatsApp_API</label>
</ExternalCredential>
```

**Named Credential:** `WhatsApp_API`
```
URL: https://graph.facebook.com/v21.0
Auth: ExternalCredential → WhatsApp_API
```

**Remote Site Setting:** `https://graph.facebook.com` (backup for non-named-credential calls)

Store the access token in `.env` and populate it via Connect API (same pattern as existing OilPriceAPI setup).

---

### Step 5: Permission Set & Tab

**Permission Set:** `O_G_WhatsApp_Admin`

| Permission | Object | Access |
|---|---|---|
| Object Settings | WhatsApp_Message__c | Full CRUD |
| Apex Class Access | WhatsAppWebhookHandler | Enabled |

**Custom Tab:** `WhatsApp_Message__c` → Label: "WhatsApp Messages", Tab Style: Chat

---

### Step 6: Layout & FlexiPage

**Page Layout:** `WhatsApp_Message__c-WhatsApp Message Layout`
- Section: Message Details (Sender Phone, Sender Name, Message Body, Message Type)
- Section: Metadata (Direction, Status, Timestamp, WhatsApp Message ID)
- Section: Related Records (Contact, Account)
- Section: Debug (Raw Payload — read-only)

**FlexiPage:** `WhatsApp_Record_Page`
- Embed `WhatsApp_Message__c` record detail

---

## Deployment Commands

```bash
# Deploy custom object
sf project deploy start -d "force-app\main\default\objects\WhatsApp_Message__c" -o "ouil gas"

# Deploy Apex classes
sf project deploy start -d "force-app\main\default\classes" -o "ouil gas"

# Deploy named credential + external credential
sf project deploy start -d "force-app\main\default\namedCredentials\WhatsApp_API.namedCredential-meta.xml" -o "ouil gas"
sf project deploy start -d "force-app\main\default\externalCredentials\WhatsApp_API.externalCredential-meta.xml" -o "ouil gas"

# Deploy permission set
sf project deploy start -d "force-app\main\default\permissionsets\O_G_WhatsApp_Admin.permissionset-meta.xml" -o "ouil gas"

# Deploy tab
sf project deploy start -d "force-app\main\default\tabs\WhatsApp_Message__c.tab-meta.xml" -o "ouil gas"

# Deploy layout
sf project deploy start -d "force-app\main\default\layouts\WhatsApp_Message__c-WhatsApp Message Layout.layout-meta.xml" -o "ouil gas"

# Deploy flexipage
sf project deploy start -d "force-app\main\default\flexipages\WhatsApp_Record_Page.flexipage-meta.xml" -o "ouil gas"

# Run tests
sf apex run test -o "ouil gas" --test-level RunLocalTests -w 10
```

---

## New Files to Create

```
force-app/main/default/
├── objects/
│   └── WhatsApp_Message__c/
│       ├── WhatsApp_Message__c.object-meta.xml
│       ├── fields/
│       │   ├── WhatsApp_Message_ID__c.field-meta.xml
│       │   ├── Sender_Phone__c.field-meta.xml
│       │   ├── Sender_Name__c.field-meta.xml
│       │   ├── Message_Body__c.field-meta.xml
│       │   ├── Message_Type__c.field-meta.xml
│       │   ├── Direction__c.field-meta.xml
│       │   ├── Status__c.field-meta.xml
│       │   ├── Timestamp__c.field-meta.xml
│       │   ├── Contact__c.field-meta.xml
│       │   ├── Account__c.field-meta.xml
│       │   └── Raw_Payload__c.field-meta.xml
│       ├── compactLayouts/
│       │   └── WA_Compact_Layout.compactLayout-meta.xml
│       └── listViews/
│           ├── All.listView-meta.xml
│           ├── Inbound_Messages.listView-meta.xml
│           └── Outbound_Messages.listView-meta.xml
├── classes/
│   ├── WhatsAppWebhookHandler.cls
│   ├── WhatsAppWebhookHandler.cls-meta.xml
│   ├── WhatsAppMessageService.cls
│   ├── WhatsAppMessageService.cls-meta.xml
│   └── TestWhatsAppIntegration.cls
│   └── TestWhatsAppIntegration.cls-meta.xml
├── namedCredentials/
│   └── WhatsApp_API.namedCredential-meta.xml
├── externalCredentials/
│   └── WhatsApp_API.externalCredential-meta.xml
├── permissionsets/
│   └── O_G_WhatsApp_Admin.permissionset-meta.xml
├── tabs/
│   └── WhatsApp_Message__c.tab-meta.xml
├── layouts/
│   └── WhatsApp_Message__c-WhatsApp Message Layout.layout-meta.xml
└── flexipages/
    └── WhatsApp_Record_Page.flexipage-meta.xml
```

---

## Estimated Effort

| Step | Time |
|---|---|
| Meta Developer App setup (manual) | 30 min |
| Custom object + fields | 15 min |
| Apex webhook handler + service class | 45 min |
| Test class | 30 min |
| Experience Cloud site setup (manual) | 15 min |
| Named Credential + External Credential | 15 min |
| Permission set + tab + layout | 15 min |
| **Total** | **~2.5 hours** |

---

## Risks & Notes

1. **Public site exposure** — The Experience Cloud site exposes only the webhook Apex class. For production, add a client certificate on the site and validate `X-Hub-Signature-256` in the POST handler using your app secret.

2. **24-hour window** — When a customer messages you, you have 24 hours to reply with free-form messages. After that, you must use pre-approved templates (paid). Since you're storing only for now, this isn't an issue.

3. **Access token expiry** — Meta's temporary tokens expire in 24 hours. For production, create a **System User** in Meta Business Manager and generate a long-lived token.

4. **Idempotency** — Meta retries webhooks if no 200 is returned within 5s. The `WhatsApp_Message_ID__c` unique check prevents duplicate records.

5. **Phone normalization** — Different countries have different formats. The `normalizePhone()` method must handle +1, +33, +212, etc. Strip spaces, dashes, parentheses. Always store in E.164.

6. **Future enhancements** (not in scope now):
   - Auto-reply within 24h window
   - Send template messages for notifications
   - LWC chat component to view conversations
   - Flow automation on message received
   - Multi-media message handling (images, documents)
