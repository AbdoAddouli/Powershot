# SCADA/PI Integration Guide — PowerShot (Go-Live)

**Project:** Energy_Salesforce_project (PowerShot)
**Target Org:** `ouil gas` (addouliabdo9.76deae143000@agentforce.com)
**API Version:** 67.0
**Date:** August 2026
**Status:** Phase 8 — Go-Live Verified (2026-08-30)

---

## Overview

This is the **operator-facing go-live manual** for pushing real-time production telemetry
from the on-premise PI Historian (OSIsoft/AVEVA PI Web API) into Salesforce. It consolidates
the endpoint, the exact HMAC signature formula, the JSON payload contract, the AF tag-mapping
convention, and the bridge configuration. It mirrors `WHATSAPP_INTEGRATION_PLAN.md` and is the
companion to `SCADA_PI_INTEGRATION_PLAN.md`.

Runnable artifacts (all in `bridge/`):
- `sender.ps1` — PowerShell signed test-payload sender (proves the endpoint end-to-end).
- `bridge_poc.py` — Python reference bridge showing the poll → shape → sign → POST loop.
- `scada_bridge.env.example` — config template (copy to `scada_bridge.env`; never commit the secret).

---

## 1. Endpoint

```
POST https://orgfarm-4d94271bcc-dev-ed.develop.my.salesforce.com/services/apexrest/api/scada/measurements
```

- **Content-Type:** `application/json`
- **Auth header:** `X-SCADA-Signature: <hex HMAC-SHA256 of the exact raw request body>`
- **Auth header:** `Authorization: Bearer <Salesforce OAuth session/bearer token>` — **required**
- **Receiver:** `SCADAIngestionAPI` (fail-closed: returns 401 unless enabled AND signature valid)

### Why a bearer token is required (important)
This org has **no custom domain (MyDomain)** and therefore **no public Force.com site URL**, so
`@RestResource` endpoints cannot be reached as unauthenticated guests. Every unauthenticated POST
returns `INVALID_SESSION_ID` even with guest-profile Apex access granted. The bridge **must**
therefore send a valid `Authorization: Bearer` token on every request.

To obtain a token:
- **Testing:** the SFDX session token from `sf org display --target-org "ouil gas" --json` (sender.ps1
  does this automatically when `SCADA_ACCESS_TOKEN` is blank).
- **Production:** create a **Connected App** using OAuth 2.0 Client Credentials (or JWT Bearer) flow
  for a dedicated integration user, and mint/refresh the token programmatically. Never store the raw
  token in source control.

---

## 2. Signature formula (must match receiver exactly)

```
signature = lowercase( hex( HMAC_SHA256( key = Shared_Secret, data = <exact raw body bytes> ) ) )
```

Implementation notes:
- Hash the **byte-exact** request body as it is sent. Do not re-serialize/pretty-print the JSON after
  computing the HMAC, or the signature breaks.
- The receiver compares with `equalsIgnoreCase`, so upper/lowercase hex both work; stay lowercase.
- `Shared_Secret` is the value stored in `SCADA_Config__c.Shared_Secret__c`, shared with the operator
  **out-of-band**. It is **not** in the repo.

### PowerShell (sender.ps1)
```powershell
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$hmac = [System.Security.Cryptography.HMACSHA256]::new(
    [System.Text.Encoding]::UTF8.GetBytes($secret)
)
$signature = ($hmac.ComputeHash($bodyBytes) | ForEach-Object { $_.ToString('x2') }) -join ''
```

### Python (bridge_poc.py)
```python
import hashlib, hmac
sig = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
```

---

## 3. Payload contract

### Envelope (new, preferred — tag-based)

```json
{
  "readings": [
    {
      "tag": "WELL-123.OIL_FLOW",
      "timestamp": "2026-08-30T10:15:00Z",
      "value": 184.2,
      "pressure": 1220,
      "temperature": 41.5,
      "measurementType": "Oil Flow",
      "quality": "Good"
    }
  ]
}
```

### Reading fields

| Field | Type | Required | Description |
|---|---|---|---|
| `tag` | string | yes* | PI tag matching `Well__c.PI_Tag__c` or `Pipeline__c.PI_Tag__c`. |
| `timestamp` | ISO 8601 / DateTime | yes | Reading time (UTC). Used in the idempotency `External_Key__c`. |
| `value` | number | yes | Primary measured value. Routed: `measurementType=Pressure`→`Pressure__c`, `Temperature`→`Temperature__c`, flow/`Other`→`Gross_Volume__c`. |
| `pressure` | number | no | Secondary pressure reading (overrides `value` when present for pressure). |
| `temperature` | number | no | Secondary temperature reading (overrides `value` when present). |
| `measurementType` | string | no | `Oil Flow`, `Gas Flow`, `Water Flow`, `Pressure`, `Temperature`, `Other`. Defaults to `Other`. |
| `quality` | string | no | PI quality (`Good`/`Bad`/`Uncertain`). Not persisted by the receiver currently. |
| `pipelineId` | string | no | **Legacy only** (bare-array contract; `Source_System__c=SCADA`). |

\* `tag` is required for the new contract. The bare-array `pipelineId` path is still accepted for
backward compatibility but should be phased out so readings are attributed to **Wells** (required for
the monthly allocation rollup).

### Behavior summary (from `SCADAIngestionAPI`)
- **Unmatched tags** are reported per-request in `unmatchedTags` and skipped (non-fatal) — other
  readings still land.
- **Idempotent:** `External_Key__c = <Source_System>|<tag|pipelineId>|<timestamp>`, unique in the org,
  so bridge retries never create duplicates.
- **Chunking:** payloads are pre-chunked into ≤5000 readings per Queueable; a single request may
  exceed 5000 and the server splits them automatically.
- **Response 200:**
  ```json
  {
    "status": "accepted",
    "jobId": "707...",
    "jobCount": 1,
    "measurementsQueued": 12,
    "unmatchedTags": ["WELL-999.BADTAG"],
    "chunked": false
  }
  ```

---

## 4. AF Database / tag naming convention

Create one AF **Element** per Well and per Pipeline whose **name equals** `Well__c.PI_Tag__c` /
`Pipeline__c.PI_Tag__c`. Suggested flat tag scheme:

| Purpose | Tag pattern | Router value |
|---|---|---|
| Well oil flow | `WELL-<name>.OIL_FLOW` | `Oil Flow` |
| Well gas flow | `WELL-<name>.GAS_FLOW` | `Gas Flow` |
| Well water flow | `WELL-<name>.WATER_FLOW` | `Water Flow` |
| Well tubing pressure | `WELL-<name>.PT` | `Pressure` |
| Well temperature | `WELL-<name>.TT` | `Temperature` |
| Pipeline pressure | `PIPE-<name>.PT` | `Pressure` |
| Pipeline flow | `PIPE-<name>.FLOW` | `Other` |

**Rollup rule:** every tag that must contribute to the monthly `Production_Allocation__c` rollup
**must be a Well-linked `Oil Flow` / `Gas Flow` / `Water Flow`** reading. `WellProductionTelemetryRollupBatch`
sums those into oil/gas/water volumes. Pressure/temperature readings are stored for telemetry only and
ignored by the rollup.

---

## 5. Bridge configuration

Copy `bridge/scada_bridge.env.example` → `bridge/scada_bridge.env` and fill in:

| Variable | Description |
|---|---|
| `SCADA_SHARED_SECRET` | Value from `SCADA_Config__c.Shared_Secret__c` (shared out-of-band). |
| `SCADA_ENDPOINT` | The `/services/apexrest/api/scada/measurements` URL. |
| `SCADA_ACCESS_TOKEN` | SF OAuth bearer token (required; sender falls back to `sf org display` if blank). |
| `PIWEBAPI_URL` / `PIWEBAPI_USER` / `PIWEBAPI_PASS` | PI Web API connection (bridge POC only). |

Never commit `scada_bridge.env`. The repo-root `.env` already holds the secret + endpoint for the
sender and is gitignored.

---

## 6. Go-live checklist (verified 2026-08-30 on `ouil gas`)

1. ✅ `SCADA_Config__c` exists with `Enabled__c = true` and the shared secret.
2. ✅ `bridge/sender.ps1` → `200` + `measurementsQueued` (tag resolved, `unmatchedTags: []`).
3. ✅ `Measurement__c` row created via SOQL (tag-resolved, `External_Key__c` set).
4. ✅ Rollup batch ran → monthly `Production_Allocation__c` row (2026-08, `Oil_Volume_bbls__c=210.5`)
   and `Well__c.Last_Production_Date__c` updated.
5. ✅ Idempotency: re-running the rollup produced no duplicate allocation row.
6. ⚠️ `portalWellStatus` telemetry card — present and deployed (Phase 6); not exercisable via public
   URL because the org has no MyDomain. Verified the underlying controller query/SOQL returns the rows.

### Nightly schedule (already registered)
```
System.schedule('Well Production Telemetry Rollup', '0 0 1 * * ?', new WellProductionTelemetryRollupBatch());
```
CronTrigger `08egK00000dkkSuQAI`, cron `0 0 1 * * ?`, state `WAITING`.

---

## 7. Security notes

- The shared secret grants **write** access to `Measurement__c`. Keep it out of source control and
  rotate it in both `SCADA_Config__c` and the bridge config together.
- The HMAC authenticates the sender but does **not** encrypt the payload. HTTPS is always used on the
  Salesforce side; for confidentiality consider a VPN/private connect for the bridge.
- Restrict `SCADA_Config__c` / `Measurement__c` FLS via `O_G_Portal_Access` so guest/public access can
  never read the secret or forge readings.
