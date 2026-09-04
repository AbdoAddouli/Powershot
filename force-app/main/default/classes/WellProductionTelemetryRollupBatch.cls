/**
 * WellProductionTelemetryRollupBatch
 * ===================================
 * Nightly batch that aggregates raw well telemetry (Measurement__c from the PI
 * Historian) into monthly Production_Allocation__c records, and updates
 * Well__c.Last_Production_Date__c with the most recent reading date.
 *
 * Business Process: SCADA/PI Telemetry Rollup (Midstream/Upstream)
 *   Measurement__c → group by Well × calendar month → Production_Allocation__c
 *
 * Scheduling (recommended — nightly 01:00):
 *   System.schedule('Well Production Telemetry Rollup', '0 0 1 * * ?',
 *                   new WellProductionTelemetryRollupBatch());
 *
 * Design notes
 * - Aggregates only Well-linked, PI-source measurements within the window.
 * - Monthly allocations are keyed by (Well__c, Period_End__c = month end) and
 *   recomputed idempotently: the same (Well, month) always maps to the same key,
 *   so rerunning the job does not duplicate rows.
 * - Existing allocations keep their working/revenue interest; new allocations are
 *   seeded from the parent Lease's WI/NRI (avoids the <=100% WI conflict).
 * - Source_System__c = 'PI Historian' only, so manual/SCADA entries are untouched.
 */
public without sharing class WellProductionTelemetryRollupBatch
        implements Database.Batchable<SObject>, Schedulable {

    // --- Constants -----------------------------------------------------------
    public static final String PI_SOURCE = 'PI Historian';           // Only aggregate PI-Historian telemetry
    public static final String TYPE_OIL = 'Oil Flow';                // Measurement_Type__c picklist values →
    public static final String TYPE_GAS = 'Gas Flow';                // map 1:1 to the allocation volume fields
    public static final String TYPE_WATER = 'Water Flow';
    public static final Integer OVERLAP_WINDOW_MONTHS = 1;           // Re-read last month so late/reordered
                                                                     // PI records still land in the right year

    // The earliest Reading_DateTime__c considered by this run. Kept in an instance
    // field so the Schedulable entry point and the batch share the same window.
    private final Date startDate;

    /**
     * No-arg ctor used by the scheduled job. Defaults the window to the start of
     * the previous month, giving a full month of history plus one month of overlap.
     */
    public WellProductionTelemetryRollupBatch() {
        this.startDate = Date.today().toStartOfMonth().addMonths(-OVERLAP_WINDOW_MONTHS);
    }

    /**
     * Explicit-window ctor — used for ad-hoc backfills or a narrow test window.
     * @param startDate  first date from which measurements are aggregated
     */
    public WellProductionTelemetryRollupBatch(Date startDate) {
        this.startDate = startDate;
    }

    // --- Schedulable ----------------------------------------------------------
    // Nightly CronTrigger entry point; simply hands the window off to a batch run.
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new WellProductionTelemetryRollupBatch(startDate));
    }

    // --- Batchable: start ------------------------------------------------------
    // Selects candidate Wells. Instead of iterating every Well in the org, we use a
    // semi-join so only Wells that actually produced PI telemetry inside the window
    // are picked up. Each execute() scope then owns the aggregation for those wells.
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Well__c
            WHERE Id IN (
                SELECT Well__c FROM Measurement__c
                WHERE Well__c != null
                  AND Source_System__c = :PI_SOURCE
                  AND Reading_DateTime__c >= :startDate
            )
        ]);
    }

    // --- Batchable: execute ----------------------------------------------------
    /**
     * For a scope of Wells: pull their PI measurements, aggregate into per-Well ×
     * per-calendar-month accumulators, then upsert one Production_Allocation__c per
     * (Well, month-end) and refresh each Well's Last_Production_Date__c.
     */
    public void execute(Database.BatchableContext bc, List<Well__c> wells) {
        if (wells == null || wells.isEmpty()) {
            return;
        }

        // Extract plain Ids so we can use them in the queries below.
        Set<Id> wellIds = new Set<Id>();
        for (Well__c w : wells) {
            wellIds.add(w.Id);
        }

        // wellId -> latest reading date seen; drives the Well__c.Last_Production_Date__c update.
        Map<Id, Date> wellLastProductionDate = new Map<Id, Date>();
        // 'WellId|PeriodEnd' -> accumulator holding the summed volumes for that month.
        Map<String, WellMonthAgg> aggsByKey = new Map<String, WellMonthAgg>();

        // Query all PI-source, well-linked measurements for this scope, looping in
        // batches to stay within the SOQL row limit. Aggregation is done in Apex
        // (not GROUP BY) so we can keep the distinct reading-date set per month.
        for (List<Measurement__c> batch : [
            SELECT Id, Well__c, Reading_DateTime__c, Gross_Volume__c, Measurement_Type__c
            FROM Measurement__c
            WHERE Well__c IN :wellIds
              AND Source_System__c = :PI_SOURCE
              AND Reading_DateTime__c >= :startDate
        ]) {
            for (Measurement__c m : batch) {
                // Use the GMT calendar date so month boundaries are identical no
                // matter which user/region the job runs under.
                Date readingDate = m.Reading_DateTime__c != null
                    ? m.Reading_DateTime__c.dateGMT() : null;
                if (readingDate == null) continue;

                // Calendar month end (e.g. 2026-08-03 → 2026-08-31) is the idempotency key.
                Date periodEnd = readingDate.toStartOfMonth().addMonths(1).addDays(-1);
                String key = m.Well__c + '|' + periodEnd;

                // Get-or-create the accumulator for this (well, month) and fold the reading in.
                if (!aggsByKey.containsKey(key)) {
                    aggsByKey.put(key, new WellMonthAgg(m.Well__c, periodEnd));
                }
                WellMonthAgg agg = aggsByKey.get(key);
                agg.addReading(m.Measurement_Type__c, m.Gross_Volume__c, readingDate);

                // Track the max reading date per well for the Last_Production_Date update.
                if (!wellLastProductionDate.containsKey(m.Well__c)
                    || readingDate > wellLastProductionDate.get(m.Well__c)) {
                    wellLastProductionDate.put(m.Well__c, readingDate);
                }
            }
        }

        if (aggsByKey.isEmpty()) {
            return;
        }

        // Bulk-load the parents so new allocations can be seeded with Lease + WI/NRI.
        Map<Id, Well__c> wellsById = new Map<Id, Well__c>([
            SELECT Id, Lease__c,
                   Lease__r.Working_Interest_Percent__c,
                   Lease__r.Revenue_Interest_Percent__c
            FROM Well__c WHERE Id IN :wellIds
        ]);

        // Load any allocations the scoped wells already have for these months. Keying
        // them the same way ('WellId|PeriodEnd') implements the "upsert by (Well, month)"
        // in-memory, since Production_Allocation__c has no usable unique external ID.
        Map<String, Production_Allocation__c> existingByKey = new Map<String, Production_Allocation__c>();
        for (Production_Allocation__c alloc : [
            SELECT Id, Well__c, Period_End__c, Period_Start__c, Oil_Volume_bbls__c,
                   Gas_Volume_MCF__c, Water_Volume_bbls__c, Days_On_Production__c
            FROM Production_Allocation__c
            WHERE Well__c IN :wellIds
              AND Period_End__c >= :startDate.toStartOfMonth()
        ]) {
            existingByKey.put(alloc.Well__c + '|' + alloc.Period_End__c, alloc);
        }

        List<Production_Allocation__c> toUpsert = new List<Production_Allocation__c>();
        for (WellMonthAgg agg : aggsByKey.values()) {
            Production_Allocation__c alloc = existingByKey.get(agg.wellId + '|' + agg.periodEnd);
            Well__c well = wellsById.get(agg.wellId);

            if (alloc == null) {
                // Brand-new allocation: seed the period bounds and lease-derived WI/NRI.
                // (The ProductionAllocationTrigger will also derive Account__c from the Well.)
                alloc = new Production_Allocation__c(
                    Well__c = agg.wellId,
                    Lease__c = well != null ? well.Lease__c : null,
                    Period_Start__c = agg.periodStart,
                    Period_End__c = agg.periodEnd,
                    Working_Interest_Share__c =
                        well != null ? well.Lease__r.Working_Interest_Percent__c : null,
                    Net_Revenue_Interest_Share__c =
                        well != null ? well.Lease__r.Revenue_Interest_Percent__c : null
                );
            }
            // Existing allocations keep their WI/NRI untouched (avoids the ≤100% WI
            // conflict) — we only recompute the production volumes and days on production.
            alloc.Oil_Volume_bbls__c = agg.oilVolume;
            alloc.Gas_Volume_MCF__c = agg.gasVolume;
            alloc.Water_Volume_bbls__c = agg.waterVolume;
            alloc.Days_On_Production__c = agg.getDaysOnProduction();
            toUpsert.add(alloc);
        }

        // Single bulk upsert: records already holding an Id update in place, new ones
        // insert. Because the (Well, month-end) key is deterministic, rerunning the job
        // for the same window converges instead of growing.
        if (!toUpsert.isEmpty()) {
            upsert toUpsert;
        }

        // Stamp the most recent producing date on each well (partial update — only the
        // two fields below change; Status etc. are left alone so WellTrigger stays silent).
        List<Well__c> wellsToUpdate = new List<Well__c>();
        for (Id wellId : wellLastProductionDate.keySet()) {
            wellsToUpdate.add(new Well__c(
                Id = wellId,
                Last_Production_Date__c = wellLastProductionDate.get(wellId)
            ));
        }
        if (!wellsToUpdate.isEmpty()) {
            update wellsToUpdate;
        }
    }

    // --- Batchable: finish -------------------------------------------------
    // No post-processing needed; kept for the Database.Batchable contract.
    public void finish(Database.BatchableContext bc) {
    }

    // --- Helper: per-(Well, month) accumulator -----------------------------
    /** In-memory accumulator for one Well × calendar month. */
    private class WellMonthAgg {
        public Id wellId;
        public Date periodStart;   // first day of the month (mm/01)
        public Date periodEnd;     // last day of the month (mm/31) — the idempotency key
        public Decimal oilVolume = 0;
        public Decimal gasVolume = 0;
        public Decimal waterVolume = 0;
        // Distinct reading dates; its size becomes Days_On_Production__c.
        public final Set<Date> readingDates = new Set<Date>();

        public WellMonthAgg(Id wellId, Date periodEnd) {
            this.wellId = wellId;
            this.periodEnd = periodEnd;
            this.periodStart = periodEnd.toStartOfMonth();
        }

        /**
         * Adds a reading to the running totals. Routed by Measurement_Type__c:
         * Oil/Gas/Water Flow land in their matching volume field; Pressure,
         * Temperature, etc. are ignored for allocation purposes.
         */
        public void addReading(String type, Decimal volume, Date readingDate) {
            if (TYPE_OIL.equals(type)) {
                oilVolume += (volume != null ? volume : 0);
            } else if (TYPE_GAS.equals(type)) {
                gasVolume += (volume != null ? volume : 0);
            } else if (TYPE_WATER.equals(type)) {
                waterVolume += (volume != null ? volume : 0);
            }
            readingDates.add(readingDate);
        }

        public Integer getDaysOnProduction() {
            return readingDates.size();
        }
    }
}
