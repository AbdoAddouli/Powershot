// PowerShot — Full Sample Data Seeder
// Run via: sf apex run -f scripts/seed_all_powershot.apex -o "oil-gas_project"

System.debug('=== PowerShot Data Seeder Started ===');

// ── 1. Fetch existing Accounts ──
List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 10];
System.debug('Using ' + accounts.size() + ' existing Accounts');

// ── 2. Land_Parcel__c ──
List<Land_Parcel__c> parcels = new List<Land_Parcel__c>();
for (Integer i = 0; i < 3; i++) {
    parcels.add(new Land_Parcel__c(
        County__c = 'Midland',
        State__c = 'TX',
        Acreage__c = 640 + (i * 160),
        Mineral_Rights_Owner__c = accounts[Math.mod(i, accounts.size())].Id,
        Surface_Rights_Owner__c = accounts[Math.mod(i + 1, accounts.size())].Id,
        Coordinates__c = '32.0' + i + ', -102.0' + i,
        Legal_Description__c = 'Section ' + (i + 1) + ', Block ' + (i + 10) + ', T&R Survey'
    ));
}
insert parcels;
System.debug('Created ' + parcels.size() + ' Land_Parcel__c');

// ── 3. Lease__c ──
List<Lease__c> leases = new List<Lease__c>();
for (Integer i = 0; i < 5; i++) {
    leases.add(new Lease__c(
        Status__c = 'Active',
        Lease_Type__c = 'Paid-Up',
        Royalty_Percent__c = 12.5 + (i * 2),
        Working_Interest_Percent__c = 75 - (i * 5),
        Revenue_Interest_Percent__c = 70 - (i * 5),
        Primary_Term_End__c = Date.today().addYears(3 + i),
        Lease_End_Date__c = Date.today().addYears(5 + i),
        Term_Years__c = 5 + i,
        Delay_Rental_Amount__c = 5000 + (i * 1000),
        Account__c = accounts[Math.mod(i, accounts.size())].Id,
        Land_Parcel__c = parcels[Math.mod(i, parcels.size())].Id
    ));
}
insert leases;
System.debug('Created ' + leases.size() + ' Lease__c');

// ── 4. Well__c ──
List<String> wellTypes = new List<String>{'Oil', 'Gas', 'Injection', 'Water Disposal'};
List<String> formations = new List<String>{'Bakken', 'Eagle Ford', 'Permian', 'Marcellus', 'Haynesville', 'Niobrara', 'Wolfcamp', 'Bone Spring'};
List<String> prodStatuses = new List<String>{'Flowing', 'Artificial Lift', 'Shut-In', 'Abandoned'};

List<Well__c> wells = new List<Well__c>();
for (Integer i = 0; i < 10; i++) {
    wells.add(new Well__c(
        Name = 'Well-' + String.valueOf(i + 1).leftPad(4, '0'),
        Status__c = i < 7 ? 'Producing' : (i < 9 ? 'Drilling' : 'Permitted'),
        Well_Type__c = wellTypes[Math.mod(i, wellTypes.size())],
        Production_Status__c = i < 7 ? prodStatuses[Math.mod(i, 2)] : null,
        Formation__c = formations[Math.mod(i, formations.size())],
        API_Number__c = '42-' + String.valueOf(100000 + i),
        Total_Depth__c = 5000 + (Math.mod(i * 137, 15000)),
        True_Vertical_Depth__c = 4000 + (Math.mod(i * 89, 12000)),
        Spud_Date__c = Date.today().addMonths(-(12 + (i * 3))),
        Completion_Date__c = Date.today().addMonths(-(10 + (i * 3))),
        Is_Declining__c = Math.mod(i, 3) == 0 ? 'Yes' : 'No',
        Total_Oil_Volume_12M__c = 50000 - (i * 3000),
        Status_Change_Date__c = Date.today().addDays(-(i * 30)),
        Account__c = accounts[Math.mod(i, accounts.size())].Id,
        Lease__c = leases[Math.mod(i, leases.size())].Id
    ));
}
insert wells;
System.debug('Created ' + wells.size() + ' Well__c');

// ── 5. Well_Operation__c ──
List<String> opTypes = new List<String>{'Drilling', 'Completion', 'Workover', 'Plug and Abandon'};
List<String> opStatuses = new List<String>{'Planned', 'In Progress', 'Completed'};
List<Well_Operation__c> ops = new List<Well_Operation__c>();
for (Integer i = 0; i < 10; i++) {
    ops.add(new Well_Operation__c(
        Operation_Type__c = opTypes[Math.mod(i, opTypes.size())],
        Status__c = opStatuses[Math.mod(i, opStatuses.size())],
        Start_Date__c = Date.today().addMonths(-(i + 1)),
        End_Date__c = Date.today().addMonths(-i),
        Operation_Date__c = Date.today().addMonths(-(i)),
        AFE_Number__c = 'AFE-' + String.valueOf(20000 + i),
        AFE_Amount__c = 250000 + (i * 50000),
        Actual_Cost__c = 240000 + (i * 48000),
        Rig_Contractor__c = 'Precision Drilling',
        Description__c = 'Routine ' + opTypes[Math.mod(i, opTypes.size())] + ' operation',
        Well__c = wells[Math.mod(i, wells.size())].Id
    ));
}
insert ops;
System.debug('Created ' + ops.size() + ' Well_Operation__c');

// ── 6. Production_Allocation__c ──
List<Production_Allocation__c> allocs = new List<Production_Allocation__c>();
for (Well__c w : wells) {
    if (w.Status__c == 'Producing') {
        for (Integer m = 0; m < 6; m++) {
            Decimal oilVol = 500 + Math.mod(Integer.valueOf(w.Total_Depth__c) * (m + 1), 2000);
            allocs.add(new Production_Allocation__c(
                Well__c = w.Id,
                Lease__c = w.Lease__c,
                Oil_Volume_bbls__c = oilVol,
                Gas_Volume_MCF__c = 1000 + Math.mod(Integer.valueOf(w.Total_Depth__c) * (m + 3), 5000),
                Water_Volume_bbls__c = 100 + Math.mod(Integer.valueOf(w.Total_Depth__c) * (m + 5), 500),
                Working_Interest_Share__c = 75,
                Net_Revenue_Interest_Share__c = 70,
                Allocated_Revenue__c = oilVol * 75,
                Days_On_Production__c = 30,
                Period_Start__c = Date.today().addMonths(-6 + m).toStartOfMonth(),
                Period_End__c = Date.today().addMonths(-6 + m + 1).toStartOfMonth().addDays(-1)
            ));
        }
    }
}
insert allocs;
System.debug('Created ' + allocs.size() + ' Production_Allocation__c');

// ── 7. Pipeline__c ──
List<String> commodities = new List<String>{'Crude', 'Gas', 'NGL', 'Refined'};
List<Pipeline__c> pipelines = new List<Pipeline__c>();
for (Integer i = 0; i < 5; i++) {
    pipelines.add(new Pipeline__c(
        Name = 'Pipeline-' + String.valueOf(i + 1).leftPad(3, '0'),
        Status__c = i < 4 ? 'Active' : 'Idle',
        Commodity__c = commodities[Math.mod(i, commodities.size())],
        Capacity_bpd__c = 50000 + (i * 25000),
        Diameter_inches__c = 12 + (i * 4),
        Segment_Length_Miles__c = 25 + (i * 15),
        MAOP__c = 800 + (i * 100),
        Operating_Pressure__c = 600 + (i * 75),
        Compliance_Status__c = 'Compliant',
        Last_Inspection_Date__c = Date.today().addMonths(-(i + 1)),
        Required_Inspection_Interval_Months__c = 12,
        Account__c = accounts[Math.mod(i, accounts.size())].Id
    ));
}
insert pipelines;
System.debug('Created ' + pipelines.size() + ' Pipeline__c');

// ── 8. Pipeline_Station__c ──
List<String> stationTypes = new List<String>{'Pump', 'Compressor', 'Valve', 'Meter'};
List<Pipeline_Station__c> stations = new List<Pipeline_Station__c>();
for (Integer i = 0; i < 8; i++) {
    stations.add(new Pipeline_Station__c(
        Name = 'Station-' + String.valueOf(i + 1).leftPad(3, '0'),
        Station_Type__c = stationTypes[Math.mod(i, stationTypes.size())],
        Status__c = 'Active',
        Capacity__c = 30000 + (i * 5000),
        Horsepower__c = 1500 + (i * 500),
        Station_Location__c = 'Mile Marker ' + (10 + (i * 12)),
        Pipeline__c = pipelines[Math.mod(i, pipelines.size())].Id
    ));
}
insert stations;
System.debug('Created ' + stations.size() + ' Pipeline_Station__c');

// ── 9. Measurement__c ──
List<String> measureSources = new List<String>{'Custody Transfer', 'Check'};
List<Measurement__c> measurements = new List<Measurement__c>();
for (Integer i = 0; i < 10; i++) {
    measurements.add(new Measurement__c(
        Gross_Volume__c = 10000 + (i * 500),
        Net_Volume__c = 9800 + (i * 490),
        BSandW_Percent__c = 0.5 + (Math.mod(i, 5) * 0.1),
        Pressure__c = 600 + (i * 20),
        Temperature__c = 75 + (Math.mod(i, 10) * 2),
        Reading_DateTime__c = DateTime.now().addHours(-(i * 6)),
        Source__c = measureSources[Math.mod(i, measureSources.size())],
        Gravity__c = 38 + (Math.mod(i, 5)),
        Meter_Factor__c = 1.0 + (Math.mod(i, 10) * 0.01),
        Pipeline_Station__c = stations[Math.mod(i, stations.size())].Id
    ));
}
insert measurements;
System.debug('Created ' + measurements.size() + ' Measurement__c');

// ── 10. Refinery__c ──
List<Refinery__c> refineries = new List<Refinery__c>();
for (Integer i = 0; i < 3; i++) {
    refineries.add(new Refinery__c(
        Name = 'Refinery-' + String.valueOf(i + 1).leftPad(2, '0'),
        Status__c = 'Active',
        Capacity_bpd__c = 150000 + (i * 50000),
        Nelson_Complexity_Index__c = 9.5 + (i * 1.5),
        Units_List__c = 'Crude;Vacuum;FCC;Hydrocracker;Reformer',
        Account__c = accounts[Math.mod(i, accounts.size())].Id
    ));
}
insert refineries;
System.debug('Created ' + refineries.size() + ' Refinery__c');

// ── 11. Terminal__c ──
List<String> terminalCommodities = new List<String>{'Crude', 'Gas', 'NGL', 'Refined'};
List<Terminal__c> terminals = new List<Terminal__c>();
for (Integer i = 0; i < 4; i++) {
    terminals.add(new Terminal__c(
        Status__c = 'Active',
        Commodity_Type__c = terminalCommodities[Math.mod(i, terminalCommodities.size())],
        Storage_Capacity_bbls__c = 500000 + (i * 250000),
        Tank_Count__c = 10 + (i * 5),
        Rail_Truck_Marine_Access__c = 'Truck;Rail',
        Account__c = accounts[Math.mod(i, accounts.size())].Id
    ));
}
insert terminals;
System.debug('Created ' + terminals.size() + ' Terminal__c');

// ── 12. Retail_Outlet__c ──
List<Retail_Outlet__c> outlets = new List<Retail_Outlet__c>();
for (Integer i = 0; i < 5; i++) {
    outlets.add(new Retail_Outlet__c(
        Store_Type__c = i < 2 ? 'Company' : (i < 4 ? 'Dealer' : 'Jobber'),
        Status__c = i < 4 ? 'Active' : 'Under Construction',
        Brand__c = 'PowerShot Fuel',
        Fuel_Tank_Count__c = 4 + Math.mod(i, 3),
        Fuel_Volume_Monthly__c = 50000 + (i * 15000),
        C_Store__c = Math.mod(i, 2) == 0,
        Car_Wash__c = i == 0 || i == 3,
        Location__c = 'Highway ' + (i + 1) + ' Exit ' + (i + 10),
        Account__c = accounts[Math.mod(i, accounts.size())].Id
    ));
}
insert outlets;
System.debug('Created ' + outlets.size() + ' Retail_Outlet__c');

// ── 13. Fuel_Inventory__c ──
List<String> productTypes = new List<String>{'Crude Oil', 'Gasoline', 'Diesel', 'Jet Fuel', 'Natural Gas', 'NGL'};
List<String> gaugeTypes = new List<String>{'Manual', 'Automatic', 'Radar'};
List<Fuel_Inventory__c> fuelInv = new List<Fuel_Inventory__c>();
for (Integer i = 0; i < 8; i++) {
    fuelInv.add(new Fuel_Inventory__c(
        Product_Type__c = productTypes[Math.mod(i, productTypes.size())],
        Current_Volume__c = 30000 + (i * 2000),
        Maximum_Capacity__c = 50000 + (i * 5000),
        Minimum_Threshold__c = 10000 + (i * 1000),
        Available_Volume__c = 29500 + (i * 2000),
        Tank_Number__c = 'TK-' + String.valueOf(i + 1).leftPad(3, '0'),
        Gauge_Type__c = gaugeTypes[Math.mod(i, gaugeTypes.size())],
        Status__c = 'In Service',
        Terminal__c = terminals[Math.mod(i, terminals.size())].Id
    ));
}
insert fuelInv;
System.debug('Created ' + fuelInv.size() + ' Fuel_Inventory__c');

// ── 14. Inventory_Transaction__c ──
List<String> moveTypes = new List<String>{'Receipt', 'Delivery', 'Transfer-In', 'Transfer-Out', 'Consumption', 'Reconciliation'};
List<Inventory_Transaction__c> invTxns = new List<Inventory_Transaction__c>();
for (Integer i = 0; i < 10; i++) {
    invTxns.add(new Inventory_Transaction__c(
        Movement_Type__c = moveTypes[Math.mod(i, moveTypes.size())],
        Transaction_Date__c = DateTime.now().addDays(-(i + 1)),
        Volume_Before__c = 40000 + (i * 500),
        Volume_After__c = 38000 + (i * 500),
        Volume_Change__c = -2000,
        Notes__c = moveTypes[Math.mod(i, moveTypes.size())] + ' transaction #' + (i + 1),
        Fuel_Inventory__c = fuelInv[Math.mod(i, fuelInv.size())].Id
    ));
}
insert invTxns;
System.debug('Created ' + invTxns.size() + ' Inventory_Transaction__c');

// ── 15. Supply_Agreement__c ──
List<String> agreementTypes = new List<String>{'Term', 'Spot', 'Exchange'};
List<String> priceBasis = new List<String>{'WTI', 'Brent', 'HH', 'TTF', 'JKM'};
List<Supply_Agreement__c> agreements = new List<Supply_Agreement__c>();
for (Integer i = 0; i < 5; i++) {
    agreements.add(new Supply_Agreement__c(
        Agreement_Type__c = agreementTypes[Math.mod(i, agreementTypes.size())],
        Commodity_v2__c = commodities[Math.mod(i, commodities.size())],
        Status__c = 'Active',
        Price_Basis__c = priceBasis[Math.mod(i, priceBasis.size())],
        Current_Price__c = 75 + (i * 10),
        Volume__c = 10000 + (i * 5000),
        Term_Start__c = Date.today().addMonths(-(i * 6)),
        Term_End__c = Date.today().addYears(1 + i),
        Delivery_Point__c = 'Cushing, OK',
        Credit_Terms__c = 'Net 30',
        Account__c = accounts[Math.mod(i, accounts.size())].Id
    ));
}
insert agreements;
System.debug('Created ' + agreements.size() + ' Supply_Agreement__c');

// ── 16. Transportation_Nomination__c ──
List<Transportation_Nomination__c> nominations = new List<Transportation_Nomination__c>();
for (Integer i = 0; i < 5; i++) {
    nominations.add(new Transportation_Nomination__c(
        Status__c = i < 3 ? 'Scheduled' : 'Requested',
        Nomination_Period__c = 'July 2026',
        Requested_Volume__c = 25000 + (i * 5000),
        Confirmed_Volume__c = i < 3 ? 24000 + (i * 5000) : null,
        Contract_Reference__c = 'CONT-' + String.valueOf(5000 + i),
        Account__c = accounts[Math.mod(i, accounts.size())].Id,
        Pipeline__c = pipelines[Math.mod(i, pipelines.size())].Id
    ));
}
insert nominations;
System.debug('Created ' + nominations.size() + ' Transportation_Nomination__c');

// ── 17. Service_Contract__c ──
List<String> contractTypes = new List<String>{'Drilling', 'Workover', 'Well Service', 'Inspection', 'Cleaning'};
List<Service_Contract__c> contracts = new List<Service_Contract__c>();
for (Integer i = 0; i < 5; i++) {
    contracts.add(new Service_Contract__c(
        Contract_Type__c = contractTypes[Math.mod(i, contractTypes.size())],
        Status__c = 'Active',
        Start_Date__c = Date.today().addMonths(-(i * 2)),
        End_Date__c = Date.today().addYears(1).addMonths(i),
        Value__c = 100000 + (i * 50000),
        PO_Reference__c = 'PO-' + String.valueOf(30000 + i),
        Scope_of_Work__c = contractTypes[Math.mod(i, contractTypes.size())] + ' services for PowerShot operations',
        Insurance_Requirements__c = 'General Liability $2M, Workers Comp',
        Account__c = accounts[Math.mod(i, accounts.size())].Id,
        Contractor__c = accounts[Math.mod(i + 2, accounts.size())].Id
    ));
}
insert contracts;
System.debug('Created ' + contracts.size() + ' Service_Contract__c');

// ── 18. HSE_Incident__c ──
List<String> incidentTypes = new List<String>{'Spill', 'Injury', 'Fire', 'Safety Near Miss', 'Environmental'};
List<String> severities = new List<String>{'Low', 'Medium', 'High', 'Critical'};
List<String> injuryTypes = new List<String>{'First Aid', 'Medical Treatment', 'Lost Time', 'Life-Threatening', 'Permanent Disability'};
List<HSE_Incident__c> incidents = new List<HSE_Incident__c>();
for (Integer i = 0; i < 8; i++) {
    incidents.add(new HSE_Incident__c(
        Incident_Type__c = incidentTypes[Math.mod(i, incidentTypes.size())],
        Severity__c = severities[Math.mod(i, severities.size())],
        Status__c = i < 5 ? 'Investigating' : 'Closed',
        Incident_Date__c = Date.today().addDays(-(i + 1)),
        Fatality_Occurred__c = i == 3,
        LTI__c = Math.mod(i, 4) == 0,
        Recordable__c = i < 6,
        Regulatory_Reportable__c = i < 4,
        Spill_Volume__c = incidentTypes[Math.mod(i, incidentTypes.size())] == 'Spill' ? 50 + (i * 10) : null,
        Injury_Type__c = Math.mod(i, 3) == 0 ? injuryTypes[Math.mod(i, injuryTypes.size())] : null,
        Description__c = incidentTypes[Math.mod(i, incidentTypes.size())] + ' incident at location',
        Location__c = 'Pad ' + String.valueOf(i + 1),
        Corrective_Action__c = 'Root cause analysis completed, corrective measures implemented',
        Root_Cause__c = 'Equipment failure due to inadequate maintenance',
        Account__c = accounts[Math.mod(i, accounts.size())].Id,
        Well__c = wells[Math.mod(i, wells.size())].Id
    ));
}
insert incidents;
System.debug('Created ' + incidents.size() + ' HSE_Incident__c');

// ── 19. HSE_Observation__c ──
List<HSE_Observation__c> observations = new List<HSE_Observation__c>();
for (Integer i = 0; i < 6; i++) {
    observations.add(new HSE_Observation__c(
        Observation_Type__c = Math.mod(i, 2) == 0 ? 'Safe' : 'Unsafe',
        Status__c = Math.mod(i, 3) == 0 ? 'Open' : 'Closed',
        Description__c = 'Safety observation #' + (i + 1) + ' during routine inspection',
        Location__c = 'Well Pad ' + String.valueOf(i + 1),
        Corrective_Action_Taken__c = Math.mod(i, 2) == 0 ? null : 'Immediate corrective action taken',
        Account__c = accounts[Math.mod(i, accounts.size())].Id
    ));
}
insert observations;
System.debug('Created ' + observations.size() + ' HSE_Observation__c');

// ── 20. Permit_to_Work__c ──
List<String> permitTypes = new List<String>{'Hot Work', 'Confined Space Entry', 'Electrical', 'Mechanical', 'Excavation', 'Work at Height'};
List<String> riskLevels = new List<String>{'Low', 'Medium', 'High', 'Critical'};
List<Permit_to_Work__c> ptws = new List<Permit_to_Work__c>();
User activeUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
for (Integer i = 0; i < 8; i++) {
    ptws.add(new Permit_to_Work__c(
        Permit_Type__c = permitTypes[Math.mod(i, permitTypes.size())],
        Risk_Level__c = riskLevels[Math.mod(i, riskLevels.size())],
        Status__c = i < 3 ? 'Issued' : (i < 6 ? 'Requested' : 'Completed'),
        Start_DateTime__c = DateTime.now().addDays(i),
        End_DateTime__c = DateTime.now().addDays(i + 1),
        Valid_From__c = DateTime.now().addDays(i),
        Valid_To__c = DateTime.now().addDays(i + 1),
        PTW_Number__c = 'PTW-' + String.valueOf(1000 + i),
        Scope_of_Work__c = permitTypes[Math.mod(i, permitTypes.size())] + ' operations',
        Location__c = 'Location ' + String.valueOf(i + 1),
        Description__c = permitTypes[Math.mod(i, permitTypes.size())] + ' permit request',
        Gas_Test_Required__c = Math.mod(i, 2) == 0,
        Gas_Test_Completed__c = i < 4,
        Gas_Test_Result__c = i < 3 ? 'Pass' : null,
        Oxygen_Level_Pct__c = 20.9,
        LEL_Pct__c = 2.5,
        H2S_Level_Ppm__c = 1.0,
        CO_Level_Ppm__c = 5.0,
        Isolation_Required__c = Math.mod(i, 3) == 0,
        Isolation_Verified__c = Math.mod(i, 3) == 0 && i < 5,
        Lockout_Tagout_Completed__c = Math.mod(i, 3) == 0 && i < 5,
        Zero_Energy_State_Verified__c = Math.mod(i, 3) == 0 && i < 5,
        Energy_Isolation_Type__c = Math.mod(i, 3) == 0 ? 'Electrical Isolation' : null,
        Holder__c = activeUser.Id,
        Issuer__c = activeUser.Id,
        Authorizer__c = activeUser.Id,
        Well__c = wells[Math.mod(i, wells.size())].Id
    ));
}
insert ptws;
System.debug('Created ' + ptws.size() + ' Permit_to_Work__c');

// ── 21. Regulatory_Permit__c ──
List<String> permitTypes2 = new List<String>{'SPCC', 'Title V', 'NSPS', 'NPDES', 'Underground Injection'};
List<String> complianceStatuses = new List<String>{'Compliant', 'Non-Compliant', 'Expired', 'Approaching Expiration', 'Pending Review'};
List<Regulatory_Permit__c> regPermits = new List<Regulatory_Permit__c>();
for (Integer i = 0; i < 6; i++) {
    regPermits.add(new Regulatory_Permit__c(
        Name = 'PERMIT-' + String.valueOf(5000 + i),
        Permit_Type__c = permitTypes2[Math.mod(i, permitTypes2.size())],
        Status__c = i < 4 ? 'Active' : (i == 4 ? 'Approved' : 'Pending'),
        Compliance_Status__c = complianceStatuses[Math.mod(i, complianceStatuses.size())],
        Issue_Date__c = Date.today().addMonths(-(12 + (i * 3))),
        Expiration_Date__c = i == 2 ? Date.today().addDays(45) : Date.today().addYears(1 + i),
        Agency__c = i < 3 ? 'EPA' : 'State',
        Facility__c = 'Facility ' + String.valueOf(i + 1),
        Renewal_Reminder_Sent__c = i == 2,
        Account__c = accounts[Math.mod(i, accounts.size())].Id,
        Well__c = wells[Math.mod(i, wells.size())].Id
    ));
}
insert regPermits;
System.debug('Created ' + regPermits.size() + ' Regulatory_Permit__c');

// ── 22. Compliance_Report__c ──
List<Compliance_Report__c> reports = new List<Compliance_Report__c>();
for (Integer i = 0; i < 4; i++) {
    reports.add(new Compliance_Report__c(
        Status__c = i < 2 ? 'Pending' : 'Submitted',
        Due_Date__c = Date.today().addDays(30 + (i * 15)),
        Submitted_Date__c = i >= 2 ? Date.today().addDays(-(i * 5)) : null,
        Regulatory_Body__c = i < 2 ? 'EPA' : 'Texas RRC',
        Account__c = accounts[Math.mod(i, accounts.size())].Id,
        Regulatory_Permit__c = regPermits[Math.mod(i, regPermits.size())].Id
    ));
}
insert reports;
System.debug('Created ' + reports.size() + ' Compliance_Report__c');

// ── 23. Inspection__c ──
List<String> inspTypes = new List<String>{'Visual', 'NDT', 'Cathodic', 'Hydrotest', 'Internal'};
List<String> inspResults = new List<String>{'Pass', 'Fail', 'Conditional'};
List<Inspection__c> inspections = new List<Inspection__c>();
for (Integer i = 0; i < 8; i++) {
    inspections.add(new Inspection__c(
        Inspection_Type__c = inspTypes[Math.mod(i, inspTypes.size())],
        Status__c = i < 4 ? 'Completed' : (i < 6 ? 'In Progress' : 'Scheduled'),
        Result__c = i < 4 ? inspResults[Math.mod(i, inspResults.size())] : null,
        Scheduled_Date__c = Date.today().addDays(-(10 - i)),
        Inspection_Date__c = i < 4 ? Date.today().addDays(-(10 - i)) : null,
        Completed_Date__c = i < 4 ? Date.today().addDays(-(8 - i)) : null,
        Next_Due_Date__c = Date.today().addMonths(6 + i),
        Findings__c = i < 4 ? 'No critical findings' : 'Pending inspection',
        Is_Recurring__c = Math.mod(i, 2) == 0,
        Recurring_Interval_Days__c = Math.mod(i, 2) == 0 ? 180 : null,
        Account__c = accounts[Math.mod(i, accounts.size())].Id,
        Pipeline__c = pipelines[Math.mod(i, pipelines.size())].Id,
        Well__c = wells[Math.mod(i, wells.size())].Id
    ));
}
insert inspections;
System.debug('Created ' + inspections.size() + ' Inspection__c');

// ── 24. Joint_Venture__c ──
List<Joint_Venture__c> jvs = new List<Joint_Venture__c>();
for (Integer i = 0; i < 4; i++) {
    jvs.add(new Joint_Venture__c(
        Name = 'JV-' + String.valueOf(i + 1).leftPad(3, '0') + ' - Permian Basin',
        Status__c = 'Active',
        Working_Interest_Percent__c = 50 + (i * 10),
        Revenue_Interest_Percent__c = 45 + (i * 10),
        Partners__c = 'Partner A, Partner B',
        Account__c = accounts[Math.mod(i, accounts.size())].Id,
        Operator__c = accounts[Math.mod(i + 1, accounts.size())].Id
    ));
}
insert jvs;
System.debug('Created ' + jvs.size() + ' Joint_Venture__c');

// ── 25. Invoice__c ──
List<String> invoiceStatuses = new List<String>{'Pending', 'Paid', 'Overdue', 'Cancelled'};
List<Invoice__c> invoices = new List<Invoice__c>();
for (Integer i = 0; i < 5; i++) {
    invoices.add(new Invoice__c(
        Status__c = invoiceStatuses[Math.mod(i, invoiceStatuses.size())],
        Invoice_Date__c = Date.today().addMonths(-(i + 1)),
        Amount__c = 50000 + (i * 25000),
        JV__c = jvs[Math.mod(i, jvs.size())].Id
    ));
}
insert invoices;
System.debug('Created ' + invoices.size() + ' Invoice__c');

// ── Summary ──
System.debug('===== PowerShot Data Seeder Complete =====');
System.debug('Land_Parcel__c:          ' + parcels.size());
System.debug('Lease__c:                ' + leases.size());
System.debug('Well__c:                 ' + wells.size());
System.debug('Well_Operation__c:       ' + ops.size());
System.debug('Production_Allocation__c: ' + allocs.size());
System.debug('Pipeline__c:             ' + pipelines.size());
System.debug('Pipeline_Station__c:     ' + stations.size());
System.debug('Measurement__c:          ' + measurements.size());
System.debug('Refinery__c:             ' + refineries.size());
System.debug('Terminal__c:             ' + terminals.size());
System.debug('Retail_Outlet__c:        ' + outlets.size());
System.debug('Fuel_Inventory__c:       ' + fuelInv.size());
System.debug('Inventory_Transaction__c: ' + invTxns.size());
System.debug('Supply_Agreement__c:     ' + agreements.size());
System.debug('Transportation_Nomination__c: ' + nominations.size());
System.debug('Service_Contract__c:     ' + contracts.size());
System.debug('HSE_Incident__c:         ' + incidents.size());
System.debug('HSE_Observation__c:      ' + observations.size());
System.debug('Permit_to_Work__c:       ' + ptws.size());
System.debug('Regulatory_Permit__c:    ' + regPermits.size());
System.debug('Compliance_Report__c:    ' + reports.size());
System.debug('Inspection__c:           ' + inspections.size());
System.debug('Joint_Venture__c:        ' + jvs.size());
System.debug('Invoice__c:              ' + invoices.size());
Integer total = parcels.size() + leases.size() + wells.size() + ops.size() + allocs.size()
    + pipelines.size() + stations.size() + measurements.size() + refineries.size()
    + terminals.size() + outlets.size() + fuelInv.size() + invTxns.size() + agreements.size()
    + nominations.size() + contracts.size() + incidents.size() + observations.size()
    + ptws.size() + regPermits.size() + reports.size() + inspections.size() + jvs.size()
    + invoices.size();
System.debug('TOTAL records created:   ' + total);
