// Create test records for EIA sync
System.debug('=== Creating test records ===');

// Check Commodity__c field exists
SObjectType supplyType = Schema.getGlobalDescribe().get('Supply_Agreement__c');
Map<String, Schema.SObjectField> supplyFields = supplyType.getDescribe().fields.getMap();
System.debug('Has Commodity__c: ' + supplyFields.containsKey('Commodity__c'));

SObjectType fuelType = Schema.getGlobalDescribe().get('Fuel_Inventory__c');
Map<String, Schema.SObjectField> fuelFields = fuelType.getDescribe().fields.getMap();
System.debug('Has Product__c: ' + fuelFields.containsKey('Product__c'));
System.debug('Has EIA_National_Stock__c: ' + fuelFields.containsKey('EIA_National_Stock__c'));
System.debug('Has Current_Volume__c: ' + fuelFields.containsKey('Current_Volume__c'));

// Create Supply Agreement
Supply_Agreement__c sa = new Supply_Agreement__c(
    Name = 'EIA Test Agreement'
);
// Try to set Commodity__c if it exists
if (supplyFields.containsKey('Commodity__c')) {
    sa.put('Commodity__c', 'Refined');
}
insert sa;
System.debug('Created Supply Agreement: ' + sa.Id);

// Create Fuel Inventory
Fuel_Inventory__c fi = new Fuel_Inventory__c(
    Name = 'EIA Test Gasoline Inventory'
);
if (fuelFields.containsKey('Product__c')) {
    fi.put('Product__c', 'Gasoline');
}
insert fi;
System.debug('Created Fuel Inventory: ' + fi.Id);

System.debug('=== Records created ===');
