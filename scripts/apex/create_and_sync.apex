// Check if fields exist NOW after deployment
SObjectType supplyType = Schema.getGlobalDescribe().get('Supply_Agreement__c');
Map<String, Schema.SObjectField> supplyFields = supplyType.getDescribe().fields.getMap();
System.debug('Has Commodity__c: ' + supplyFields.containsKey('Commodity__c'));
System.debug('Has Account__c: ' + supplyFields.containsKey('Account__c'));
System.debug('Has Current_Price__c: ' + supplyFields.containsKey('Current_Price__c'));

SObjectType fuelType = Schema.getGlobalDescribe().get('Fuel_Inventory__c');
Map<String, Schema.SObjectField> fuelFields = fuelType.getDescribe().fields.getMap();
System.debug('Has Product__c: ' + fuelFields.containsKey('Product__c'));
System.debug('Has EIA_National_Stock__c: ' + fuelFields.containsKey('EIA_National_Stock__c'));

// Try creating records
if (supplyFields.containsKey('Commodity__c')) {
    Supply_Agreement__c sa = new Supply_Agreement__c();
    sa.put('Commodity__c', 'Refined');
    insert sa;
    System.debug('Created Supply Agreement: ' + sa.Id);
    
    // Now run EIA sync
    EIAPricingService.syncPrices(new Set<Id>{sa.Id});
    System.debug('EIA syncPrices called for: ' + sa.Id);
}

if (fuelFields.containsKey('Product__c')) {
    Fuel_Inventory__c fi = new Fuel_Inventory__c();
    fi.put('Product__c', 'Gasoline');
    insert fi;
    System.debug('Created Fuel Inventory: ' + fi.Id);
    
    // Now run EIA sync
    EIAPricingService.syncStocks(new Set<Id>{fi.Id});
    System.debug('EIA syncStocks called for: ' + fi.Id);
}
