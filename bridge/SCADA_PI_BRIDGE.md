# SCADA/PI Bridge — Integration Guide (Phase 5)

**Project:** Energy_Salesforce_project (PowerShot)
**Target Org:** `ouil gas` (addouliabdo9.76deae143000@agentforce.com)
**API Version:** 67.0
**Date:** August 2026
**Status:** Phase 5 — bridge implementation

---

## Overview

This document is the **on-prem operator's reference** for the PI → Salesforce bridge. It
describes the delivery contract: what to fetch from the PI Historian (OSIsoft/AVEVA PI Web
API), how to shape each reading, how to sign the payload (HMAC-SHA256), and where to POST it.
It mirrors `WHATSAPP_INTEGRATION_PLAN.md` and is the Phase-8 companion to
`SCADA_PI_INTEGRATION_PLAN.md`.

Two runnable artifacts live in `bridge/`:
- `sender.ps1` — PowerShell **signed test-payload sender** (Phase 8 step 1: prove the endpoint
  works end-to-end before wiring the real bridge).
- `bridge_poc.py` — Python **reference bridge** showing the poll → shape → sign → POST loop.
- `scada_bridge.env.example` — config template (copy to `scada_bridge.env`; never commit the secret).

---

## Endpoint

```
POST https://orgfarm-4d94271bcc-dev-ed.develop.my.salesforce.com/services/apexrest/api/scada/measurements
```

- **Auth header:** `X-SCADA-Signature: <hex HMAC-SHA256 of the exact raw request body>`
- **Auth header:** `Authorization: Bearer <Salesforce OAuth session token>` — required.
- **Content-Type:** `application/json`
- **Receiver:** `SCADAIngestionAPI` (fail-closed — returns 401 unless enabled + signature valid)

> **Why a bearer token is required (important):** this org has **no custom domain (MyDomain)**
> and therefore **no public Force.com site URL**, so `@RestResource` endpoints cannot be reached
> as unauthenticated guests. Every unauthenticated POST (including the WhatsApp webhook) returns
> `INVALID_SESSION_ID`, even with Apex guest-profile access granted. The bridge must therefore
> send a valid `Authorization: Bearer` token with each request. If a MyDomain is later enabled,
> guest access could be switched on — but the authenticated path remains the recommended,
> more secure option.

> **Getting the token:** for tests, use the SFDX session token from `sf org display`. For the
> production bridge, create a **Connected App** with OAuth 2.0 Client Credentials (or JWT Bearer)
> flow for a dedicated integration user and mint/refresh the token programmatically. Never store
> the raw access token in source control.

---

## Signature formula (must match the receiver exactly)

```
signature = lowercase( hex( HMAC_SHA256( key = Shared_Secret, data = <exact raw body bytes> ) ) )
```

Implementation notes:
- Hash the **byte-exact** request body as it is sent (no trailing whitespace, no reformatting
  after signing). If you re-serialize the JSON after computing the HMAC, the signature breaks.
- The receiver compares using `equalsIgnoreCase`, so **upper or lower case hex both work**, but
  stay consistent lower-case to avoid ambiguity.
- `Shared_Secret` is the value stored in `SCADA_Config__c.Shared_Secret__c` (shared with the
  operator out-of-band — it is **not** in the repo).

---

## Payload contract

### Envelope (new, preferred)

```json
{
  "readings": [
    {
      "tag": "WELL-123.OIL_FLOW",
      "timestamp": "2026-08-27T10:15:00Z",
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
| `tag` | string | yes* | PI tag. Must match `Well__c.PI_Tag__c` or `Pipeline__c.PI_Tag__c`. |
| `timestamp` | ISO 8601 / DateTime | yes | Reading time (UTC). Used in the idempotency `External_Key__c`. |
| `value` | number | yes | Primary measured value. Route: `measurementType=Pressure`→`Pressure__c`, `Temperature`→`Temperature__c`, flow/`Other`→`Gross_Volume__c`. |
| `pressure` | number | no | Secondary pressure reading (overrides `value` when present for pressure). |
| `temperature` | number | no | Secondary temperature reading (overrides `value` when present). |
| `measurementType` | string | no | `Oil Flow`, `Gas Flow`, `Water Flow`, `Pressure`, `Temperature`, `Other`. Defaults to `Other` for volume routing. |
| `quality` | string | no | PI quality (`Good`, `Bad`, `Uncertain`). Not persisted by the receiver currently. |
| `pipelineId` | string | no | **Legacy only.** Bare-array contract; uses `Source_System__c=SCADA`. |

\* `tag` is required for the new contract. A bare-array with `pipelineId` is still accepted for
backward compatibility but should be phased out in favor of tag-based resolution so readings
can be attributed to **Wells** (required for the monthly allocation rollup).

### Behavior summary (from `SCADAIngestionAPI`)
- Unmatched tags are reported per-request in `unmatchedTags` and **skipped, not fatal** — other
  readings still land.
- **Idempotent:** `External_Key__c = <Source_System>|<tag|pipelineId>|<timestamp>`, unique in the
  org, so bridge retries never create duplicates.
- Payloads are **pre-chunked into ≤5000 readings** per Queueable (`CHUNK_SIZE`); a single request
  may exceed 5000 readings and the server splits them across jobs automatically.
- Response `200`:
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

## AF Database / tag naming convention

Create one AF **Element** per Well and per Pipeline whose **name equals the value** of
`Well__c.PI_Tag__c` / `Pipeline__c.PI_Tag__c`. Suggested flat tag scheme (matches the rollup):

| Purpose | Tag pattern | Router value |
|---|---|---|
| Well oil flow | `WELL-<name>.OIL_FLOW` | `Oil Flow` |
| Well gas flow | `WELL-<name>.GAS_FLOW` | `Gas Flow` |
| Well water flow | `WELL-<name>.WATER_FLOW` | `Water Flow` |
| Well tubing pressure | `WELL-<name>.PT` | `Pressure` |
| Well temperature | `WELL-<name>.TT` | `Temperature` |
| Pipeline pressure | `PIPE-<name>.PT` | `Pressure` |
| Pipeline flow | `PIPE-<name>.FLOW` | `Other` |

Every tag that must contribute to the monthly `Production_Allocation__c` rollup **must be a
Well-linked `Oil Flow` / `Gas Flow` / `Water Flow`** reading — the rollup
(`WellProductionTelemetryRollupBatch`) sums those into oil/gas/water volumes. Pressure and
temperature readings are stored for telemetry but ignored by the rollup.

---

## Bridge design

### Option A — Node-RED (recommended POC)
1. **PI Web API nodes** (community `node-red-contrib-pi-web-api` or raw `http request`) poll
   per tag:
   `GET {piwebapi}/streams/{webId}/interpolated?startTime=-20m&endTime=now&interval=1m`
2. For each returned value build a `readings[]` entry (tag, timestamp, value, type).
3. **Sign** the exact JSON body before every `http request` POST.
4. On `5xx` → exponential backoff and retry; on `200` → advance the last-polled watermark.
5. Backfill: one-off run with a large `startTime`, chunked to ≤5000 readings and reused across
   intervals.

### Option B — PI Integrator for Business Analytics
Alternative if a full Node-RED deployment isn't desired. It can output flat snapshots that a thin
Python sender (see `bridge_poc.py`) reads and posts. Kept out of scope here — the Python POC
already demonstrates the signing + posting half.

---

## Reading `.env`

Copy `bridge/scada_bridge.env.example` to `bridge/scada_bridge.env` and fill in:
- `SCADA_SHARED_SECRET` — the value from `SCADA_Config__c.Shared_Secret__c`.
- `SCADA_ENDPOINT` — the `/services/apexrest/api/scada/measurements` URL.
- `SCADA_ACCESS_TOKEN` — a Salesforce OAuth session/bearer token (required for authenticated POSTs;
  the sender falls back to fetching one from `sf org display` if this is blank).
- `PIWEBAPI_URL` / `PIWEBAPI_USER` / `PIWEBAPI_PASS` — PI Web API connection (bridge POC only).

Never commit `scada_bridge.env` (add to `.gitignore`). The repo's `.env` already contains the
secret for the sender and is gitignored.

---

## Phase 8 — Go-live & verify checklist

1. `SCADA_Config__c` row exists in `ouil gas` with `Enabled__c = true` and the shared secret.
2. Run `bridge/sender.ps1` with a test reading → expect `200` + `measurementsQueued`.
3. Confirm the `Measurement__c` row via SOQL (tag resolved, `External_Key__c` set).
4. Register the rollup schedule (Phase "Org config"):
   `System.schedule('Well Production Telemetry Rollup', '0 0 1 * * ?', new WellProductionTelemetryRollupBatch());`
5. Run the rollup → confirm monthly `Production_Allocation__c` rows.
6. (After Phase 6) confirm `portalWellStatus` telemetry card.

---

## Security notes

- The shared secret grants **write access** to `Measurement__c`. Keep it out of source control and
  rotate it in both `SCADA_Config__c` and the bridge config together.
- The signature authenticates the sender but does **not** encrypt the payload. If you need
  confidentiality in transit, terminate the Salesforce side behind HTTPS (always) and consider a
  VPN/private connect for the bridge — do not rely on the HMAC for secrecy.
- Restrict `SCADA_Config__c` and `Measurement__c` FLS via the `O_G_Portal_Access` permission set
  so public/guest access can never read the secret or forge readings.
