/**
 * TestPortalControllers
 * ======================
 * Tests PortalDashboardController, PortalWellStatusController, and
 * PortalIncidentController for Experience Cloud portal data access.
 */
@IsTest
public class TestPortalControllers {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Test Operator');
        insert acct;

        Well__c well = new Well__c(
            Name = 'Test Well',
            Account__c = acct.Id,
            Status__c = 'Producing',
            API_Number__c = '42-123-45678',
            Well_Type__c = 'Oil'
        );
        insert well;

        Pipeline__c pipeline = new Pipeline__c(
            Name = 'Test Pipeline',
            Status__c = 'Active',
            Diameter_Inches__c = 24,
            Capacity_bpd__c = 50000
        );
        insert pipeline;

        Regulatory_Permit__c permit = new Regulatory_Permit__c(
            Name = 'Test Permit',
            Status__c = 'Active',
            Expiration_Date__c = Date.today().addDays(30),
            Account__c = acct.Id
        );
        insert permit;

        Production_Allocation__c pa = new Production_Allocation__c(
            Well__c = well.Id,
            Period_End__c = Date.today().addDays(-30),
            Oil_Volume_bbls__c = 1500,
            Gas_Volume_MCF__c = 3000
        );
        insert pa;

        HSE_Incident__c incident = new HSE_Incident__c(
            Incident_Type__c = 'Spill',
            Incident_Date__c = Date.today(),
            Severity__c = 'Medium',
            Status__c = 'Open',
            Location__c = 'Well Pad A',
            Description__c = 'Test spill incident',
            Spill_Volume__c = 250
        );
        insert incident;
    }

    @IsTest
    static void testGetDashboardSummary() {
        Test.startTest();
        Map<String, Object> result = PortalDashboardController.getDashboardSummary();
        Test.stopTest();

        Assert.isTrue(result.containsKey('totalWells'));
        Assert.isTrue(result.containsKey('activeIncidents'));
        Assert.isTrue(result.containsKey('criticalIncidents'));
        Assert.isTrue(result.containsKey('upcomingDeadlines'));
        Assert.isTrue(result.containsKey('activePipelines'));
        Assert.isTrue(result.containsKey('wellsByStatus'));
        Assert.areEqual(1, result.get('totalWells'));
    }

    @IsTest
    static void testGetRecentIncidents() {
        Test.startTest();
        List<HSE_Incident__c> incidents = PortalDashboardController.getRecentIncidents(5);
        Test.stopTest();

        Assert.isFalse(incidents.isEmpty());
        Assert.areEqual('Spill', incidents[0].Incident_Type__c);
    }

    @IsTest
    static void testGetUpcomingDeadlines() {
        Test.startTest();
        List<Regulatory_Permit__c> deadlines = PortalDashboardController.getUpcomingDeadlines(5);
        Test.stopTest();

        Assert.isFalse(deadlines.isEmpty());
    }

    @IsTest
    static void testGetProductionSummary() {
        Test.startTest();
        List<AggregateResult> summary = PortalDashboardController.getProductionSummary(6);
        Test.stopTest();

        Assert.isFalse(summary.isEmpty());
    }

    @IsTest
    static void testGetWells() {
        Test.startTest();
        List<Well__c> wells = PortalWellStatusController.getWells(null, 50);
        Test.stopTest();

        Assert.isFalse(wells.isEmpty());
        Assert.areEqual('Producing', wells[0].Status__c);
    }

    @IsTest
    static void testGetWellsFiltered() {
        Test.startTest();
        List<Well__c> wells = PortalWellStatusController.getWells('Producing', 50);
        Test.stopTest();

        Assert.areEqual(1, wells.size());
    }

    @IsTest
    static void testGetWellProduction() {
        Well__c well = [SELECT Id FROM Well__c LIMIT 1];
        Test.startTest();
        List<Production_Allocation__c> prod = PortalWellStatusController.getWellProduction(well.Id, 12);
        Test.stopTest();

        Assert.isFalse(prod.isEmpty());
        Assert.areEqual(1500, prod[0].Oil_Volume_bbls__c);
    }

    @IsTest
    static void testGetWellProductionNullId() {
        Test.startTest();
        Boolean threw = false;
        try {
            PortalWellStatusController.getWellProduction(null, 12);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        Assert.isTrue(threw, 'Null well ID must be rejected by the guard.');
    }

    @IsTest
    static void testGetWellStatusCounts() {
        Test.startTest();
        Map<String, Object> counts = PortalWellStatusController.getWellStatusCounts();
        Test.stopTest();

        Assert.isTrue(counts.containsKey('byStatus'));
        Assert.isTrue(counts.containsKey('total'));
        Assert.areEqual(1, counts.get('total'));
    }

    @IsTest
    static void testGetIncidents() {
        Test.startTest();
        List<HSE_Incident__c> incidents = PortalIncidentController.getIncidents(null, 50);
        Test.stopTest();

        Assert.isFalse(incidents.isEmpty());
    }

    @IsTest
    static void testGetIncidentsFiltered() {
        Test.startTest();
        List<HSE_Incident__c> incidents = PortalIncidentController.getIncidents('Medium', 50);
        Test.stopTest();

        Assert.areEqual(1, incidents.size());
    }

    @IsTest
    static void testCreateIncident() {
        HSE_Incident__c newIncident = new HSE_Incident__c(
            Incident_Type__c = 'Equipment Failure',
            Incident_Date__c = Date.today(),
            Severity__c = 'High',
            Location__c = 'Pipeline Section 3',
            Description__c = 'Equipment failure during inspection'
        );

        Test.startTest();
        Id incidentId = PortalIncidentController.createIncident(newIncident);
        Test.stopTest();

        Assert.isNotNull(incidentId);
        HSE_Incident__c created = [SELECT Id, Status__c FROM HSE_Incident__c WHERE Id = :incidentId];
        Assert.areEqual('Open', created.Status__c);
    }

    @IsTest
    static void testGetIncidentDetail() {
        HSE_Incident__c inc = [SELECT Id FROM HSE_Incident__c LIMIT 1];
        Test.startTest();
        HSE_Incident__c detail = PortalIncidentController.getIncidentDetail(inc.Id);
        Test.stopTest();

        Assert.areEqual(inc.Id, detail.Id);
        Assert.areEqual('Spill', detail.Incident_Type__c);
    }

    @IsTest
    static void testGetIncidentDetailNullId() {
        Test.startTest();
        Boolean threw = false;
        try {
            PortalIncidentController.getIncidentDetail(null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        Assert.isTrue(threw, 'Null incident ID must be rejected by the guard.');
    }
}
