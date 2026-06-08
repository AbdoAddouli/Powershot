/**
 * InventoryBalanceService
 * ========================
 * Manages fuel inventory tracking at terminals: records receipts, deliveries,
 * transfers, and reconciliations, and alerts when inventory drops below the
 * configured minimum threshold.
 *
 * Business Process: Inventory Management (Downstream)
 *   Product Receipt → Storage → Delivery / Transfer → Consumption
 *   → Reconciliation → Low-Inventory Alerts
 */
public with sharing class InventoryBalanceService {

    /**
     * @AuraEnabled LWC-facing method returning tanks at a terminal.
     * @param terminalId  The Terminal__c Id
     * @param maxRows  Maximum number of rows to return
     * @return  Tank inventory records ordered by tank number
     */
    @AuraEnabled(cacheable=true)
    public static List<Fuel_Inventory__c> getTankInventory(Id terminalId, Integer maxRows) {
        return [
            SELECT Id, Name, Product__c, Current_Volume__c, Tank_Capacity__c,
                   Available_Volume__c, Tank_Number__c, Status__c
            FROM Fuel_Inventory__c
            WHERE Terminal__c = :terminalId
            ORDER BY Tank_Number__c ASC
            LIMIT :maxRows
        ];
    }

    /**
     * Records an inventory movement (Receipt / Delivery / Transfer / Consumption),
     * updates the tank's Current_Volume__c, and creates an Inventory_Transaction__c audit record.
     * @param inventoryId  The Fuel_Inventory__c Id
     * @param volumeChange  Volume change amount (positive)
     * @param movementType  Receipt, Delivery, Transfer-In, Transfer-Out, Consumption
     */
    public static void recordInventoryMovement(Id inventoryId, Decimal volumeChange, String movementType) {
        Fuel_Inventory__c inventory = [
            SELECT Id, Current_Volume__c, Product_Type__c, Storage_Location__c,
                   Minimum_Threshold__c, Unit__c
            FROM Fuel_Inventory__c
            WHERE Id = :inventoryId
            LIMIT 1
        ];

        Decimal newVolume = inventory.Current_Volume__c != null ? inventory.Current_Volume__c : 0;

        if (movementType == 'Receipt' || movementType == 'Transfer-In') {
            newVolume += volumeChange;
        } else if (movementType == 'Delivery' || movementType == 'Transfer-Out' || movementType == 'Consumption') {
            newVolume -= volumeChange;
            if (newVolume < 0) {
                newVolume = 0;
            }
        }

        inventory.Current_Volume__c = newVolume;
        update inventory;

        Inventory_Transaction__c txn = new Inventory_Transaction__c(
            Fuel_Inventory__c = inventoryId,
            Movement_Type__c = movementType,
            Volume_Change__c = volumeChange,
            Volume_Before__c = inventory.Current_Volume__c - volumeChange,
            Volume_After__c = newVolume,
            Transaction_Date__c = DateTime.now(),
            Transacted_By__c = UserInfo.getUserId()
        );
        insert txn;
    }

    /**
     * Returns the current volume for a given inventory record (or 0 if null).
     * @param inventoryId  The Fuel_Inventory__c Id
     * @return  Current volume
     */
    public static Decimal getCurrentInventory(Id inventoryId) {
        Fuel_Inventory__c inventory = [
            SELECT Id, Current_Volume__c
            FROM Fuel_Inventory__c
            WHERE Id = :inventoryId
            LIMIT 1
        ];
        return inventory.Current_Volume__c != null ? inventory.Current_Volume__c : 0;
    }

    /**
     * Returns tanks whose Current_Volume__c is at or below the Minimum_Threshold__c.
     * @param thresholdPercent  Unused (reserved for percentage-based threshold)
     * @return  Tanks needing replenishment
     */
    public static List<Fuel_Inventory__c> getLowInventoryAlerts(Decimal thresholdPercent) {
        List<Fuel_Inventory__c> allInventory = [
            SELECT Id, Name, Product_Type__c, Current_Volume__c, Maximum_Capacity__c,
                   Minimum_Threshold__c, Storage_Location__c, Unit__c
            FROM Fuel_Inventory__c
            WHERE Minimum_Threshold__c != null
            ORDER BY Current_Volume__c ASC
            LIMIT 10000
        ];
        List<Fuel_Inventory__c> alerts = new List<Fuel_Inventory__c>();
        for (Fuel_Inventory__c inv : allInventory) {
            if (inv.Current_Volume__c <= inv.Minimum_Threshold__c) {
                alerts.add(inv);
            }
        }
        return alerts;
    }

    /**
     * Performs a physical-count reconciliation: records the discrepancy as an
     * Inventory_Transaction__c (type 'Reconciliation'), updates the tank volume,
     * and flags significant discrepancies (>5 % variance).
     * @param inventoryId  The Fuel_Inventory__c Id
     * @param physicalCount  Actual measured volume
     */
    public static void reconcileInventory(Id inventoryId, Decimal physicalCount) {
        Fuel_Inventory__c inventory = [
            SELECT Id, Current_Volume__c, Product_Type__c, Storage_Location__c
            FROM Fuel_Inventory__c
            WHERE Id = :inventoryId
            LIMIT 1
        ];

        Decimal systemVolume = inventory.Current_Volume__c != null ? inventory.Current_Volume__c : 0;
        Decimal discrepancy = physicalCount - systemVolume;

        Inventory_Transaction__c reconciliation = new Inventory_Transaction__c(
            Fuel_Inventory__c = inventoryId,
            Movement_Type__c = 'Reconciliation',
            Volume_Change__c = discrepancy,
            Volume_Before__c = systemVolume,
            Volume_After__c = physicalCount,
            Transaction_Date__c = DateTime.now(),
            Transacted_By__c = UserInfo.getUserId(),
            Notes__c = 'Physical count: ' + physicalCount + ', System: ' + systemVolume +
                       ', Discrepancy: ' + discrepancy
        );
        insert reconciliation;

        inventory.Current_Volume__c = physicalCount;

        if (Math.abs(discrepancy) > 0) {
            inventory.Last_Reconciliation_Date__c = Date.today();
            inventory.Discrepancy_Flagged__c = Math.abs(discrepancy) > (systemVolume * 0.05);
        }

        update inventory;
    }
}
