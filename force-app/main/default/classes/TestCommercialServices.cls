/**
 * TestCommercialServices
 * =======================
 * Tests inventory management (receipt, delivery, reconciliation, low-inventory
 * alerts), production allocation creation and revenue retrieval, royalty
 * calculations (individual + monthly + statement generation), and the
 * working-interest validation in ProductionAllocationTrigger.
 */
@IsTest
public with sharing class TestCommercialServices {

    @TestSetup
    static void setup() {
        Account acct = new Account(Name = 'Test Operator');
        insert acct;

        Account partner = new Account(Name = 'JV Partner');
        insert partner;

        Account shipper = new Account(Name = 'Shipper');
        insert shipper;

        Lease__c lease = new Lease__c(
            Account__c = acct.Id,
            Status__c = 'Active',
            Royalty_Percent__c = 12.5,
            Working_Interest_Percent__c = 75,
            Revenue_Interest_Percent__c = 80
        );
        insert lease;

        Joint_Venture__c jv = new Joint_Venture__c(
            Account__c = acct.Id,
            Operator__c = partner.Id,
            Status__c = 'Active',
            Working_Interest_Percent__c = 25,
            Revenue_Interest_Percent__c = 20
        );
        insert jv;

        Well__c well = new Well__c(
            Name = 'Test Well',
            Lease__c = lease.Id,
            Account__c = acct.Id,
            Status__c = 'Permitted',
            API_Number__c = '42-123-45678'
        );
        insert well;

        Production_Allocation__c alloc = new Production_Allocation__c(
            Well__c = well.Id,
            Lease__c = lease.Id,
            Period_Start__c = Date.today().addMonths(-1),
            Period_End__c = Date.today(),
            Oil_Volume_bbls__c = 1000,
            Gas_Volume_MCF__c = 5000,
            Water_Volume_bbls__c = 200,
            Allocated_Revenue__c = 50000,
            Working_Interest_Share__c = 25,
            Net_Revenue_Interest_Share__c = 30
        );
        insert alloc;

        Terminal__c term = new Terminal__c(
            Account__c = acct.Id,
            Status__c = 'Operational',
            Storage_Capacity_bbls__c = 50000
        );
        insert term;
        Fuel_Inventory__c tank = new Fuel_Inventory__c(
            Terminal__c = term.Id,
            Product_Type__c = 'Crude',
            Current_Volume__c = 500,
            Maximum_Capacity__c = 10000,
            Minimum_Threshold__c = 1000,
            Unit__c = 'Barrels',
            Storage_Location__c = 'Tank Farm A'
        );
        insert tank;
    }

    @IsTest
    static void testInventoryMovementReceipt() {
        Fuel_Inventory__c tank = [SELECT Id, Current_Volume__c FROM Fuel_Inventory__c LIMIT 1];
        Decimal startingVolume = tank.Current_Volume__c;

        Test.startTest();
        InventoryBalanceService.recordInventoryMovement(tank.Id, 1000, 'Receipt');
        Test.stopTest();

        Fuel_Inventory__c updated = [SELECT Id, Current_Volume__c FROM Fuel_Inventory__c WHERE Id = :tank.Id];
        Assert.areEqual(startingVolume + 1000, updated.Current_Volume__c);

        List<Inventory_Transaction__c> txns = [SELECT Id, Movement_Type__c, Volume_Change__c, Volume_Before__c, Volume_After__c FROM Inventory_Transaction__c];
        Assert.areEqual(1, txns.size());
        Assert.areEqual('Receipt', txns[0].Movement_Type__c);
    }

    @IsTest
    static void testInventoryMovementDelivery() {
        Fuel_Inventory__c tank = [SELECT Id, Current_Volume__c FROM Fuel_Inventory__c LIMIT 1];

        Test.startTest();
        InventoryBalanceService.recordInventoryMovement(tank.Id, 200, 'Delivery');
        Test.stopTest();

        Fuel_Inventory__c updated = [SELECT Id, Current_Volume__c FROM Fuel_Inventory__c WHERE Id = :tank.Id];
        Assert.areEqual(300, updated.Current_Volume__c);
    }

    @IsTest
    static void testInventoryReconciliation() {
        Fuel_Inventory__c tank = [SELECT Id, Current_Volume__c FROM Fuel_Inventory__c LIMIT 1];

        Test.startTest();
        InventoryBalanceService.reconcileInventory(tank.Id, 480);
        Test.stopTest();

        Fuel_Inventory__c updated = [SELECT Id, Current_Volume__c, Last_Reconciliation_Date__c, Discrepancy_Flagged__c FROM Fuel_Inventory__c WHERE Id = :tank.Id];
        Assert.areEqual(480, updated.Current_Volume__c);
        Assert.areEqual(Date.today(), updated.Last_Reconciliation_Date__c);
    }

    @IsTest
    static void testGetLowInventoryAlerts() {
        Test.startTest();
        List<Fuel_Inventory__c> alerts = InventoryBalanceService.getLowInventoryAlerts(10);
        Test.stopTest();

        Assert.isFalse(alerts.isEmpty(), 'Tank below threshold should trigger alert');
    }

    @IsTest
    static void testGetCurrentInventory() {
        Fuel_Inventory__c tank = [SELECT Id, Current_Volume__c FROM Fuel_Inventory__c LIMIT 1];

        Test.startTest();
        Decimal vol = InventoryBalanceService.getCurrentInventory(tank.Id);
        Test.stopTest();

        Assert.areEqual(tank.Current_Volume__c, vol);
    }

    @IsTest
    static void testGetTankInventory() {
        Fuel_Inventory__c tank = [SELECT Id, Terminal__c FROM Fuel_Inventory__c LIMIT 1];

        Test.startTest();
        List<Fuel_Inventory__c> tanks = InventoryBalanceService.getTankInventory(tank.Terminal__c, 10);
        Test.stopTest();

        Assert.areEqual(1, tanks.size());
    }

    @IsTest
    static void testProductionAllocationCreate() {
        Well__c well = [SELECT Id, Lease__c, Lease__r.Working_Interest_Percent__c, Lease__r.Revenue_Interest_Percent__c FROM Well__c LIMIT 1];

        Test.startTest();
        ProductionAllocationService.calculateMonthlyAllocation(
            well.Id,
            Date.today().addMonths(-2),
            Date.today().addMonths(-1)
        );
        Test.stopTest();

        List<Production_Allocation__c> allocs = [SELECT Id, Well__c, Lease__c FROM Production_Allocation__c WHERE Period_Start__c >= :Date.today().addMonths(-2) AND Period_End__c <= :Date.today().addMonths(-1)];
        Assert.isFalse(allocs.isEmpty());
    }

    @IsTest
    static void testGetAllocatedRevenue() {
        Production_Allocation__c alloc = [SELECT Id, Allocated_Revenue__c FROM Production_Allocation__c LIMIT 1];

        Test.startTest();
        Decimal revenue = ProductionAllocationService.getAllocatedRevenue(alloc.Id);
        Test.stopTest();

        Assert.areEqual(alloc.Allocated_Revenue__c, revenue);
    }

    @IsTest
    static void testGetProductionHistory() {
        Well__c well = [SELECT Id FROM Well__c LIMIT 1];

        Test.startTest();
        List<Production_Allocation__c> history = ProductionAllocationService.getProductionHistory(well.Id, 6);
        Test.stopTest();

        Assert.isFalse(history.isEmpty());
    }

    @IsTest
    static void testRoyaltyCalculation() {
        Lease__c lease = [SELECT Id FROM Lease__c LIMIT 1];
        Production_Allocation__c alloc = [SELECT Id, Allocated_Revenue__c FROM Production_Allocation__c LIMIT 1];

        Test.startTest();
        Decimal payment = RoyaltyCalculationService.calculateRoyaltyPayment(lease.Id, alloc.Id);
        Test.stopTest();

        Assert.areNotEqual(0, payment);
    }

    @IsTest
    static void testCalculateMonthlyRoyalties() {
        Lease__c lease = [SELECT Id FROM Lease__c LIMIT 1];

        Test.startTest();
        Map<Id, Decimal> payments = RoyaltyCalculationService.calculateMonthlyRoyalties(
            lease.Id,
            Date.today().addMonths(-1),
            Date.today()
        );
        Test.stopTest();

        Assert.isFalse(payments.isEmpty());
    }

    @IsTest
    static void testGenerateRoyaltyStatements() {
        Lease__c lease = [SELECT Id FROM Lease__c LIMIT 1];

        Test.startTest();
        RoyaltyCalculationService.generateRoyaltyStatements(
            lease.Id,
            Date.today().addMonths(-1),
            Date.today()
        );
        Test.stopTest();

        List<Task> tasks = [SELECT Id, Subject FROM Task];
        Assert.isFalse(tasks.isEmpty());
    }

    @IsTest
    static void testProductionAllocationTriggerUpdateValid() {
        Production_Allocation__c alloc = [SELECT Id, Working_Interest_Share__c, Net_Revenue_Interest_Share__c FROM Production_Allocation__c LIMIT 1];
        alloc.Working_Interest_Share__c = 100;
        alloc.Net_Revenue_Interest_Share__c = 100;

        Test.startTest();
        update alloc;
        Test.stopTest();

        Production_Allocation__c result = [SELECT Id, Working_Interest_Share__c, Net_Revenue_Interest_Share__c FROM Production_Allocation__c WHERE Id = :alloc.Id];
        Assert.areEqual(100, result.Working_Interest_Share__c);
        Assert.areEqual(100, result.Net_Revenue_Interest_Share__c);
    }

    @IsTest
    static void testProductionAllocationTriggerUpdateInvalid() {
        Production_Allocation__c alloc = [SELECT Id, Working_Interest_Share__c, Net_Revenue_Interest_Share__c FROM Production_Allocation__c LIMIT 1];
        alloc.Working_Interest_Share__c = 150;
        alloc.Net_Revenue_Interest_Share__c = 100;

        Test.startTest();
        try {
            update alloc;
            Assert.fail('Should have thrown');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('200%'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testProductionAllocationTriggerValidatesWI() {
        Well__c well = [SELECT Id FROM Well__c LIMIT 1];

        Production_Allocation__c badAlloc = new Production_Allocation__c(
            Well__c = well.Id,
            Period_Start__c = Date.today().addMonths(-1),
            Period_End__c = Date.today(),
            Oil_Volume_bbls__c = 500,
            Working_Interest_Share__c = 80
        );

        Test.startTest();
        try {
            insert badAlloc;
            Assert.fail('Should have thrown for WI > 100%');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Working Interest'));
        }
        Test.stopTest();
    }
}
