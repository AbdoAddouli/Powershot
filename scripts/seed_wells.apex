List<Well__c> wells = new List<Well__c>();
List<String> wellTypes = new List<String>{'Oil', 'Gas', 'Injection', 'Water Disposal'};
List<String> formations = new List<String>{'Bakken', 'Eagle Ford', 'Permian', 'Marcellus', 'Haynesville', 'Niobrara', 'Wolfcamp', 'Bone Spring'};

for (Integer i = 0; i < 400; i++) {
    Integer typeIdx = Math.mod(i, wellTypes.size());
    Integer formIdx = Math.mod(i, formations.size());
    wells.add(new Well__c(
        Name = 'Well-' + String.valueOf(i + 1).leftPad(4, '0'),
        Well_Type__c = wellTypes[typeIdx],
        Formation__c = formations[formIdx],
        API_Number__c = '42-' + String.valueOf(100000 + i),
        Total_Depth__c = 5000 + (Math.mod(i * 137, 15000)),
        Completion_Date__c = Date.today().addYears(-(Math.mod(i, 20) + 1))
    ));
}
insert wells;

System.debug('Created ' + wells.size() + ' Well__c records');

// Create 12 months of Production_Allocation__c for each well
List<Production_Allocation__c> allocs = new List<Production_Allocation__c>();
for (Well__c w : wells) {
    for (Integer m = 0; m < 12; m++) {
        Decimal oilVol = 500 + Math.mod(Integer.valueOf(w.Total_Depth__c) * (m + 1), 2000);
        allocs.add(new Production_Allocation__c(
            Well__c = w.Id,
            Oil_Volume_bbls__c = oilVol,
            Gas_Volume_MCF__c = 1000 + Math.mod(Integer.valueOf(w.Total_Depth__c) * (m + 3), 5000),
            Period_Start__c = Date.today().addMonths(-12 + m).toStartOfMonth(),
            Period_End__c = Date.today().addMonths(-12 + m + 1).toStartOfMonth().addDays(-1)
        ));
    }
}
insert allocs;

System.debug('Created ' + allocs.size() + ' Production_Allocation__c records');
