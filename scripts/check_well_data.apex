List<Well__c> wells = [SELECT Id, Name, Total_Oil_Volume_12M__c FROM Well__c ORDER BY CreatedDate DESC LIMIT 10];
System.debug('Found ' + wells.size() + ' wells');
for (Well__c w : wells) {
    System.debug('Well: ' + w.Name + ' Total Oil 12M: ' + w.Total_Oil_Volume_12M__c);
}
System.debug('Total Well count: ' + [SELECT COUNT() FROM Well__c]);
