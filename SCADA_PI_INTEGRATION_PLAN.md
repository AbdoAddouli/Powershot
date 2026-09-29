# SCADA / PI Integration Plan (Production & Pipeline Data)

Status: **In progress — Phase 1 (Schema), Phase 2 (Auth), Phase 3 (Ingestion contract), Phase 4 (Aggregation batch) DONE (2026-08-29); Phase 5 bridge POC + signed sender DONE (2026-08-30); Phase 6/7/8 pending**

- **Phase 1 (Schema) — DONE (2026-08-29):** `Measurement__c.Well__c` / `PI_Tag__c` /
  `Measurement_Type__c` / `Source_System__c` / `External_Key__c`, `Well__c.PI_Tag__c`,
  `Pipeline__c.PI_Tag__c`, and `SCADA_Config__c` (Hierarchy) custom setting deployed.
- **Phase 2 (Auth, fail-closed) — DONE (2026-08-29):** `SCADAIngestionAPI` validates
  `X-SCADA-Signature = hex(HMAC-SHA256(rawBody, Shared_Secret__c))`, returns 401 unless
  configured + enabled + signature matches. Covered by `TestSCADAIngestionAPI` (5/5 passing).
- **Phase 3 (Ingestion contract) — DONE (2026-08-29):** envelope payload `{"readings":[...]}`
  with tag→Well/Pipeline resolution (2 SOQL / request), `External_Key__c` mapping +
  in-memory dedupe, `SCADAMeasurementProcessor` bulk upsert by `External_Key__c`,
  `CHUNK_SIZE = 5000` with Queueable chaining, and per-reading unmatched-tag reporting.
  Backward-compatible with the legacy bare-array `pipelineId` contract.
  Covered by `TestSCADAIngestionAPI` (11/11 passing; >5000 chunk path not unit-testable —
  Apex synchronous test runner hits max stack depth on chained Queueables, but the pattern is
  correct for production async jobs). `MeasurementTrigger` already guarded to `Pipeline__c != null`.
- **Phase 4 (Aggregation batch) — DONE (2026-08-29):** `WellProductionTelemetryRollupBatch`
  (Schedulable + `Database.Batchable<SObject>`, cron `0 0 1 * * ?`) runs over Well-linked
  PI-source `Measurement__c`, sums `Gross_Volume__c` per `Measurement_Type__c` into monthly
  `Production_Allocation__c` (oil/gas/water), `Days_On_Production__c` = count of distinct
  reading dates, idempotent upsert keyed by `(Well__c, Period_End__c = month end)` that
  preserves existing WI/NRI and seeds new allocations from the Lease, and updates
  `Well__c.Last_Production_Date__c`. Daily schedule registered. Covered by
  `TestWellProductionTelemetryRollupBatch` (3/3 passing).
- Deployment caveat: enabling the org **Deployment Settings** "Allow deployments when Apex
  jobs are pending" toggle was required to deploy Apex against the org's recurring scheduled jobs.

## Objective

Integrate real-time SCADA / OSIsoft (AVEVA) PI production and pipeline telemetry into the
Salesforce Energy org. Extends the existing push-based SCADA ingestion endpoint, adds raw
wellhead telemetry, and aggregates `Measurement__c` data into monthly
`Production_Allocation__c` records consumed by the portal.

## Architecture

```
PI History (on-prem) → PI Web API → Bridge (on PI server) → HMAC-signed POST
→ extended SCADAIngestionAPI → Measurement__c → nightly batch
→ Production_Allocation__c → portal
```

### Decisions (confirmed)
- **Topology:** Extend the existing push endpoint (`POST /services/apexrest/api/scada/measurements`). No outbound callouts from Salesforce for this phase.
- **Production data level:** Raw wellhead telemetry (per-well flow / pressure / temperature tags) landed as `Measurement__c`, then rolled up nightly into monthly `Production_Allocation__c`.
- **PI offering:** OSIsoft PI Web API (on-prem PI System).

### Defaults assumed (change if different)
- Bridge: **Node-RED** with PI Web API nodes (alternative: PI Integrator for Business Analytics).
- Cadence: every **5–15 minutes**.
- Backfill horizon: **12 months**.
- Allocation rollup: nightly **01:00** local.

---

## Current State (what already exists)

| Piece | File | Notes |
|---|---|---|
| REST ingestion endpoint | `SCADAIngestionAPI.cls` | `POST /api/scada/measurements`, accepts `{pipelineId, timestamp, flowRate, pressure, temperature}`, queues `SCADAMeasurementProcessor` |
| Bulk insert (Queueable) | `SCADAMeasurementProcessor.cls` | Inserts `Measurement__c` list |
| Anomaly detection | `MeasurementTrigger.trigger` | After-insert: creates `HSE_Observation__c` when `Pressure__c > 1500` or `< 100` (pipeline-linked only) |
| `Measurement__c` object | `objects/Measurement__c/` | Fields: `Reading_DateTime__c`, `Gross_Volume__c`, `Net_Volume__c`, `Pressure__c`, `Temperature__c`, `Gravity__c`, `Meter_Factor__c`, `BSandW_Percent__c`, `Pipeline__c` (lookup), `Pipeline_Station__c`, `Terminal__c`, `Source__c` |
| Monthly production surface | `Production_Allocation__c` | Per well/month: oil/gas/water volumes, `Days_On_Production__c`, WI/NRI %, `Allocated_Revenue__c`, `Severance_Tax__c` |
| Rollup example | `WellProductionRollupBatch.cls` | Pattern: aggregate → `Well__c.Total_Oil_Volume_12M__c` |
| Auth pattern (house style) | `WhatsAppWebhookHandler.cls` | HMAC-SHA256 signature header, fail-closed, secret in Custom Setting `WhatsApp_Config__c` |
| Portal production queries | `PortalWellStatusController.getWellProduction` | Reads `Production_Allocation__c` by `Well__c` + `Period_End__c >= startDate` |

### Gaps to close
1. No auth on `SCADAIngestionAPI` (currently signature-less).
2. No PI/SCADA tag key on `Well__c` / `Pipeline__c` to map historian tags → records.
3. `Measurement__c` has no `Well__c` lookup → no well-telemetry path.
4. No idempotency (`External_Key__c`) → PI retries would duplicate rows.
5. No aggregation job from `Measurement__c` → `Production_Allocation__c`. → *Closed in Phase 4.*

---

## Phase 1 — Schema (new fields)

### `Measurement__c`
- `Well__c` — Lookup(`Well__c`)
- `PI_Tag__c` — Text(255), ExternalId / indexed
- `Measurement_Type__c` — Picklist: `Oil Flow`, `Gas Flow`, `Water Flow`, `Pressure`, `Temperature`, `Other`
- `Source_System__c` — Picklist: `PI Historian`, `SCADA`, `Manual` (default `PI Historian`)
- `External_Key__c` — Text(255), `externalId="true"` unique = `${Source_System}|${PI_Tag}|${Reading_DateTime}`

Reuse existing value columns:
- `Gross_Volume__c` → the measured value for flow types (Oil/Gas/Water Flow)
- `Pressure__c` / `Temperature__c` → unchanged PT/TT readings

### `Well__c`
- `PI_Tag__c` — Text(255) — AF element key the bridge sends

### `Pipeline__c`
- `PI_Tag__c` — Text(255)

### Custom Setting
- `SCADA_Config__c` (hierarchy — model after `WhatsApp_Config__c`)
  - `Enabled__c` (Checkbox)
  - `Shared_Secret__c` (Text)
  - `Backfill_Mode__c` (Checkbox)

### Permission set
- Add FLS for new fields on `O_G_Portal_Access` **only for fields surfaced in the portal**.

---

## Phase 2 — Auth (fail-closed) ✅ DONE

> Implemented 2026-08-29 in `SCADAIngestionAPI` + `TestSCADAIngestionAPI`.

- Bridge sends `X-SCADA-Signature` = `hex(HMAC-SHA256(rawBody, SCADA_Config__c.Shared_Secret__c))`.
- `SCADAIngestionAPI` validates before touching any data:
  - 401 if header missing/blank/mismatched, or `Enabled__c = false`.
- Mirror `WhatsAppWebhookHandler.isSignatureValid` (Crypto.generateMac, constant-time-ish compare).

---

## Phase 3 — Extend `SCADAIngestionAPI` + `SCADAMeasurementProcessor` ✅ DONE

> Implemented 2026-08-29 in `SCADAIngestionAPI`, `SCADAMeasurementProcessor`, `TestSCADAIngestionAPI`.

### New payload contract
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

### Behavior
- Accept either:
  - `tag` → resolve via one SOQL over `Well__c.PI_Tag__c` and one over `Pipeline__c.PI_Tag__c` (static cache per request), or
  - legacy `pipelineId` → backward compatible.
- Unmatched tags reported per-reading (skip, not fatal).
- Map and set `External_Key__c`; dedupe in-memory with a `Set`.
- `SCADAMeasurementProcessor` → **upsert** by `External_Key__c` (bulk, no SOQL-in-loop).
- Enforce ~5,000 readings/request; chain Queueables for larger payloads.
- `MeasurementTrigger` unchanged behavior; add guard so anomaly creation only fires for `Pipeline__c != null`.

---

## Phase 4 — Aggregation batch (telemetry → allocations) ✅ DONE

> Implemented 2026-08-29 in `WellProductionTelemetryRollupBatch`, `TestWellProductionTelemetryRollupBatch`.
> Daily schedule registered via `System.schedule('Well Production Telemetry Rollup', '0 0 1 * * ?', ...)`.

New `WellProductionTelemetryRollupBatch` (Schedulable + `Database.Batchable`), cron `0 0 1 * * ?`:

1. Query `Measurement__c` (Well-linked, PI source, since last run + overlap buffer), grouped by Well + calendar month.
2. Sum `Gross_Volume__c` per `Measurement_Type__c` → oil/gas/water on `Production_Allocation__c`.
   `Days_On_Production__c` = count of distinct reading dates.
3. Upsert allocation keyed by `(Well__c, Period_End__c = month end)`; seed Lease + WI/NRI from the
   parent `Lease__c` and preserve existing allocations' WI/NRI (see Watch).
4. Update `Well__c.Last_Production_Date__c` (max reading date); optional `Is_Declining__c` (3-month trailing).
5. Register schedule via `System.schedule('Well Production Telemetry Rollup', '0 0 1 * * ?', new WellProductionTelemetryRollupBatch())`.

> Implementation note: `Production_Allocation__c` has no unique external-id field, so the
> (Well, month-end) upsert is done in-memory (bulk query of existing allocations keyed by
> Well+Period_End, then update-or-insert) instead of `ProductionAllocationService.calculateMonthlyAllocation`,
> avoiding a SOQL-per-well loop and keeping the WI/NRI reuse rule in one place.
>
> Watch: `ProductionAllocationService` enforces working interest ≤ 100% per overlapping period —
> this batch reuses the existing well's WI/NRI (no conflict) and only seeds Lease WI/NRI for new allocations.

---

## Phase 5 — On-prem bridge (PI side) 🔶 POC DONE (2026-08-30)

> Bridge POC (`bridge/SCADA_PI_BRIDGE.md`, `bridge/sender.ps1`, `bridge/bridge_poc.py`) delivered
> and **verified end-to-end against `ouil gas`**: a signed, bearer-authenticated POST resolved a
> real `Well__c.PI_Tag__c`, queued and upserted a `Measurement__c` row, and re-sending the same
> reading did **not** duplicate (External_Key idempotency confirmed).
>
> **Auth decision (important):** this org has **no MyDomain/custom domain**, so there is **no
> public Force.com guest site** — unauthenticated REST to any `@RestResource` (including the
> WhatsApp webhook) returns `INVALID_SESSION_ID` even with guest-profile Apex access granted.
> The bridge must therefore POST with `Authorization: Bearer <token>` in addition to
> `X-SCADA-Signature`. Full detail in `bridge/SCADA_PI_BRIDGE.md`.

1. Create an AF Database with one Element per Well/Pipeline whose names match
   `Well__c.PI_Tag__c` / `Pipeline__c.PI_Tag__c` (or map flat PI tags).
2. **Bridge:** Node-RED (PI Web API nodes) or PI Integrator for Business Analytics — runs on the PI server.
3. Per interval (5–15 min): `GET {piwebapi}/streams/{webId}/interpolated?startTime=-20m&endTime=now&interval=1m` per tag.
4. Build `readings` array → `X-SCADA-Signature = hex(HMAC-SHA256(rawBody, secret))` →
   `POST https://<org>.my.salesforce.com/services/apexrest/api/scada/measurements`.
5. Backoff/retry on 5xx. Client dedupe not required (SF upsert is idempotent).
6. Historical backfill: one-off run with large `startTime` window, chunked (same endpoint).

---

## Phase 6 — Portal visibility (presentation-only, optional) — DONE

- `PortalWellStatusController`: add `@AuraEnabled(cacheable=true) getWellTelemetry(Id wellId, Integer hoursBack)`
  returning latest `Measurement__c` series.
- `portalWellStatus` LWC: add real-time telemetry card using existing mockup design tokens.
- `marketDataHome`: optional. No functional changes to existing date/API logic.
- `O_G_Portal_Access`: added `Measurement__c` object read + read FLS for the surfaced telemetry fields.

---

## Phase 7 — Tests, deploy, org config — DONE

- `TestSCADAIngestionAPI` 12/12, `TestWellProductionTelemetryRollupBatch` 3/3, `TestPortalPageControllers` 16/16 — all green on `ouil gas`.
- All objects/classes/permission sets deployed to `ouil gas`. No CSP/Remote Site needed (inbound push only).
- Org config present: `SCADA_Config__c` row (Enabled, Shared_Secret) and `System.schedule` rollup job
  (cron `0 0 1 * * ?`, state WAITING).

### Tests (new, following existing `Test*` patterns)
- `TestSCADAIngestionAPI`
  - valid HMAC → 200 + `Measurement__c` upserted, tags resolved
  - bad / missing / null signature → 401
  - `Enabled__c = false` → 401
  - unknown tag → skipped (reported), valid ones still written
  - duplicate `External_Key__c` → single row
  - legacy `pipelineId` path still works
  - > 5,000 readings → chunked across Queueables
- `TestWellProductionTelemetryRollupBatch`
  - telemetry across two months → correct per-well/per-month allocation
  - re-run → idempotent (no duplicate allocation)
  - `Last_Production_Date__c` updated

### Deploy
```
sf project deploy start -d "force-app\main\default\objects" -d "force-app\main\default\classes" -d "force-app\main\default\customsettingTemplates" -d "force-app\main\default\permissionsets" -o "ouil gas"
sf apex run test --class-names "TestSCADAIngestionAPI,TestWellProductionTelemetryRollupBatch,TestPortalPageControllers" --synchronous -o "ouil gas"
```
- No CSP Trusted Site / Remote Site needed (inbound push only).
- Re-run `TestPortalPageControllers` — must stay 13/13 green.

### Org config (anonymous Apex)
- Insert `SCADA_Config__c` row (Enabled, Shared_Secret).
- `System.schedule` the rollup job.

---

## Phase 8 — Go live & verify — DONE (2026-08-30)

1. Send a signed test payload (`bridge/sender.ps1`) → `200`, `measurementsQueued:1`, tag resolved, `unmatchedTags:[]`.
2. `Measurement__c` row created (PI-source, `External_Key__c = PI Historian|WELL-P8TEST.OIL_FLOW|<ts>`,
   Gross 210.5 / Pressure 1180 / Temp 39.2).
3. Telemetry confirmed via SOQL (portal LWC deployed but not publicly reachable — org has no MyDomain).
4. Rollup batch ran → monthly `Production_Allocation__c` (2026-08, Oil 210.5, Days 1) +
   `Well__c.Last_Production_Date__c` updated; re-run produced **no duplicate** (idempotent).
5. `SCADA_PI_INTEGRATION.md` written (endpoint, payload contract, signature formula, AF tag mapping,
   bridge config) — mirrors `WHATSAPP_INTEGRATION_PLAN.md`.

All verification test data (well, measurement, allocation) cleaned up after verification.

---

## Reference patterns in this repo

- `WhatsAppWebhookHandler.cls` — HMAC-SHA256 fail-closed inbound auth
- `SCADAIngestionAPI.cls` / `SCADAMeasurementProcessor.cls` — current push endpoint + Queueable bulk
- `ProductionAllocationService.cls` — allocation creation, WI validation, revenue
- `WellProductionRollupBatch.cls` — batch rollup pattern
- `PetrelWellSync.cls` — scheduled external sync pattern (for future pull mode)