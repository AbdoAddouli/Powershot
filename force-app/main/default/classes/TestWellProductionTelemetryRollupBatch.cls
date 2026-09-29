/**
 * TestWellProductionTelemetryRollupBatch
 * ======================================
 * Tests the nightly telemetry rollup: aggregates PI-source, well-linked
 * Measurement__c into monthly Production_Allocation__c (oil/gas/water by type,
 * days-on-production from distinct reading dates), reuses existing allocations
 * idempotently, seeds WI/NRI from the Lease, and updates Well.Last_Production_Date__c.
 */
@IsTest
public with sharing class TestWellProductionTelemetryRollupBatch {

    /**
     * Shared fixtures: one Account with a 80% WI / 75% NRI Lease and a single
     * Well linked to it. Each test method gets a fresh copy of these records.
     */
    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Telemetry Operator');
        insert acct;

        Lease__c lease = new Lease__c(
            Account__c = acct.Id,
            Status__c = 'Active',
            Working_Interest_Percent__c = 80,
            Revenue_Interest_Percent__c = 75
        );
        insert lease;

        Well__c well = new Well__c(
            Name = 'WELL-TL-01',
            Account__c = acct.Id,
            Lease__c = lease.Id,
            PI_Tag__c = 'WELL-TL-01.OIL_FLOW'
        );
        insert well;
    }

    /** Fetches the single fixture Well (Id, Lease, current Account + production date). */
    private static Well__c getWell() {
        return [SELECT Id, Lease__c, Account__c, Last_Production_Date__c FROM Well__c LIMIT 1];
    }

    /**
     * Builds a well-linked PI measurement with an always-unique External_Key so no
     * two test readings collide on the idempotency key.
     */
    private static void insertMeasurement(Id wellId, Date readingDate, String type, Decimal volume) {
        insert new Measurement__c(
            Well__c = wellId,
            Source_System__c = 'PI Historian',
            Measurement_Type__c = type,
            Gross_Volume__c = volume,
            Reading_DateTime__c = readingDate,
            External_Key__c = 'Test|' + readingDate + '|' + type + '|' + String.valueOf(Crypto.getRandomLong())
        );
    }

    /**
     * Core scenario: multiple oil/gas/water readings on two different days within
     * August 2026 must collapse into a single allocation for that month, with
     * volumes summed per type, days = number of distinct dates, WI/NRI taken from
     * the Lease, and the latest reading date stamped on the Well.
     */
    @IsTest
    static void testRollupCreatesMonthlyAllocation() {
        Well__c well = getWell();
        Date d1 = Date.newInstance(2026, 8, 3);
        Date d2 = Date.newInstance(2026, 8, 10);

        insertMeasurement(well.Id, d1, 'Oil Flow', 100);
        insertMeasurement(well.Id, d1, 'Gas Flow', 50);
        insertMeasurement(well.Id, d2, 'Oil Flow', 25);
        insertMeasurement(well.Id, d2, 'Water Flow', 10);

        // Run the batch synchronously inside startTest/stopTest so it completes here.
        Test.startTest();
        Database.executeBatch(new WellProductionTelemetryRollupBatch(Date.newInstance(2026, 8, 1)));
        Test.stopTest();

        List<Production_Allocation__c> allocs = [
            SELECT Well__c, Lease__c, Period_Start__c, Period_End__c,
                   Oil_Volume_bbls__c, Gas_Volume_MCF__c, Water_Volume_bbls__c,
                   Days_On_Production__c, Working_Interest_Share__c,
                   Net_Revenue_Interest_Share__c, Account__c
            FROM Production_Allocation__c
        ];
        Assert.areEqual(1, allocs.size(), 'One monthly allocation should be created');

        Production_Allocation__c a = allocs[0];
        Assert.areEqual(well.Id, a.Well__c);
        Assert.areEqual(well.Lease__c, a.Lease__c);
        Assert.areEqual(Date.newInstance(2026, 8, 1), a.Period_Start__c);
        Assert.areEqual(Date.newInstance(2026, 8, 31), a.Period_End__c);
        Assert.areEqual(125, a.Oil_Volume_bbls__c, 'Oil flow should be summed across readings');
        Assert.areEqual(50, a.Gas_Volume_MCF__c, 'Gas flow should be summed');
        Assert.areEqual(10, a.Water_Volume_bbls__c, 'Water flow should be summed');
        Assert.areEqual(2, a.Days_On_Production__c, 'Two distinct reading dates');
        Assert.areEqual(80, a.Working_Interest_Share__c, 'WI seeded from Lease');
        Assert.areEqual(75, a.Net_Revenue_Interest_Share__c, 'NRI seeded from Lease');
        Assert.areEqual(well.Account__c, a.Account__c, 'Account derived from Well via trigger');

        Well__c updated = [SELECT Last_Production_Date__c FROM Well__c WHERE Id = :well.Id];
        Assert.areEqual(d2, updated.Last_Production_Date__c, 'Well should reflect latest reading date');
    }

    /**
     * Idempotency scenario: an allocation already exists for the same (well, Aug-2026).
     * The batch must update that record (volumes recomputed from telemetry) rather than
     * insert a duplicate, and must NOT overwrite its deliberately different WI/NRI.
     */
    @IsTest
    static void testRollupUpsertsExistingAllocation() {
        Well__c well = getWell();
        Date d = Date.newInstance(2026, 8, 5);

        // Pre-existing allocation with 999 bbl / WI 60 / NRI 55 — simulates a prior run.
        insert new Production_Allocation__c(
            Well__c = well.Id,
            Lease__c = well.Lease__c,
            Period_Start__c = Date.newInstance(2026, 8, 1),
            Period_End__c = Date.newInstance(2026, 8, 31),
            Oil_Volume_bbls__c = 999,
            Days_On_Production__c = 1,
            Working_Interest_Share__c = 60,
            Net_Revenue_Interest_Share__c = 55
        );

        insertMeasurement(well.Id, d, 'Oil Flow', 75);

        Test.startTest();
        Database.executeBatch(new WellProductionTelemetryRollupBatch(Date.newInstance(2026, 8, 1)));
        Test.stopTest();

        List<Production_Allocation__c> allocs = [
            SELECT Oil_Volume_bbls__c, Days_On_Production__c,
                   Working_Interest_Share__c, Net_Revenue_Interest_Share__c
            FROM Production_Allocation__c
        ];
        Assert.areEqual(1, allocs.size(), 'Existing allocation must be reused, not duplicated');
        Assert.areEqual(75, allocs[0].Oil_Volume_bbls__c, 'Volume recomputed from telemetry');
        Assert.areEqual(1, allocs[0].Days_On_Production__c);
        Assert.areEqual(60, allocs[0].Working_Interest_Share__c, 'Existing WI must be preserved');
        Assert.areEqual(55, allocs[0].Net_Revenue_Interest_Share__c, 'Existing NRI must be preserved');
    }

    /**
     * Filter scenario: a well-linked PI reading is aggregated, but a well-linked
     * Manual reading and an unlinked PI reading must both be excluded from output.
     */
    @IsTest
    static void testRollupIgnoresNonPIAndUnlinkedReadings() {
        Well__c well = getWell();
        Date d = Date.newInstance(2026, 8, 7);

        // PI, well-linked (should count).
        insertMeasurement(well.Id, d, 'Oil Flow', 40);

        // Manual source, well-linked (must be ignored — only PI Historian is aggregated).
        insert new Measurement__c(
            Well__c = well.Id,
            Source_System__c = 'Manual',
            Measurement_Type__c = 'Oil Flow',
            Gross_Volume__c = 500,
            Reading_DateTime__c = d
        );

        // PI but not well-linked (must be ignored — no parent Well to attribute to).
        insert new Measurement__c(
            Source_System__c = 'PI Historian',
            Measurement_Type__c = 'Oil Flow',
            Gross_Volume__c = 999,
            Reading_DateTime__c = d
        );

        Test.startTest();
        Database.executeBatch(new WellProductionTelemetryRollupBatch(Date.newInstance(2026, 8, 1)));
        Test.stopTest();

        List<Production_Allocation__c> allocs = [SELECT Oil_Volume_bbls__c FROM Production_Allocation__c];
        Assert.areEqual(1, allocs.size(), 'Only the PI, well-linked reading should create an allocation');
        Assert.areEqual(40, allocs[0].Oil_Volume_bbls__c, 'Manual / unlinked readings must be excluded');
    }
}
