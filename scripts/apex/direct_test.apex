// Direct SOQL test
System.debug('=== DIRECT SOQL TEST ===');

// Try querying Commodity__c directly
try {
    List<Supply_Agreement__c> results = Database.query('SELECT Id, Commodity__c FROM Supply_Agreement__c LIMIT 1');
    System.debug('Dynamic SOQL with Commodity__c: SUCCESS - rows=' + results.size());
} catch (Exception e) {
    System.debug('Dynamic SOQL with Commodity__c FAILED: ' + e.getMessage());
}

// Try describe via SObject describe call directly
Schema.DescribeSObjectResult supplyDescribe = Supply_Agreement__c.SObjectType.getDescribe();
Map<String, Schema.SObjectField> fieldMap = supplyDescribe.fields.getMap();
System.debug('Via SObjectType: Has Commodity__c: ' + fieldMap.containsKey('Commodity__c'));
System.debug('Via SObjectType: Fields: ' + fieldMap.keySet());
