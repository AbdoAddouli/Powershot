System.debug('=== SEED EIA TEST DATA ===');
try {
    Supply_Agreement__c sa = new Supply_Agreement__c(Commodity_v2__c = 'Refined');
    insert sa;
    System.debug('*** Created Supply Agreement (Refined): ' + sa.Id);
} catch (Exception e) {
    System.debug('*** ERROR creating Supply Agreement: ' + e.getMessage());
}

try {
    Fuel_Inventory__c fi = new Fuel_Inventory__c(Product__c = 'Crude');
    insert fi;
    System.debug('*** Created Fuel Inventory (Crude): ' + fi.Id);
} catch (Exception e) {
    System.debug('*** ERROR creating Fuel Inventory: ' + e.getMessage());
}

System.debug('=== SEED DONE ===');
