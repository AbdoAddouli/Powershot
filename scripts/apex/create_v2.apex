// Test with direct field assignment
try {
    Supply_Agreement__c sa = new Supply_Agreement__c(Commodity__c = 'Refined');
    insert sa;
    System.debug('SUCCESS - Created Supply Agreement: ' + sa.Id);
    
    // Check current price before sync
    Supply_Agreement__c check = [SELECT Id, Current_Price__c, Commodity__c FROM Supply_Agreement__c WHERE Id = :sa.Id];
    System.debug('Before sync - Current_Price__c: ' + check.Current_Price__c);
    
} catch (Exception e) {
    System.debug('ERROR creating Supply Agreement: ' + e.getMessage());
}

try {
    Fuel_Inventory__c fi = new Fuel_Inventory__c(Product__c = 'Gasoline');
    insert fi;
    System.debug('SUCCESS - Created Fuel Inventory: ' + fi.Id);
    
} catch (Exception e) {
    System.debug('ERROR creating Fuel Inventory: ' + e.getMessage());
}
