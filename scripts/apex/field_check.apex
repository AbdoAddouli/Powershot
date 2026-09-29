// Check field availability after latest deployment
SObjectType supplyType = Schema.getGlobalDescribe().get('Supply_Agreement__c');
Map<String, Schema.SObjectField> supplyFields = supplyType.getDescribe().fields.getMap();
System.debug('=== FIELD CHECK ===');
System.debug('Has Commodity__c: ' + supplyFields.containsKey('Commodity__c'));
System.debug('Has Account__c: ' + supplyFields.containsKey('Account__c'));
System.debug('Has Current_Price__c: ' + supplyFields.containsKey('Current_Price__c'));

SObjectType fuelType = Schema.getGlobalDescribe().get('Fuel_Inventory__c');
Map<String, Schema.SObjectField> fuelFields = fuelType.getDescribe().fields.getMap();
System.debug('Has Product__c: ' + fuelFields.containsKey('Product__c'));
System.debug('Has Current_Volume__c: ' + fuelFields.containsKey('Current_Volume__c'));
System.debug('Has EIA_National_Stock__c: ' + fuelFields.containsKey('EIA_National_Stock__c'));
System.debug('=== FIELD CHECK END ===');
