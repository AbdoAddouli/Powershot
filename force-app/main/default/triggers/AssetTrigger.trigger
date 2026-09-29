/**
 * AssetTrigger
 * =============
 * Before-insert / before-update: calculates Next_Inspection_Date__c and
 * Maintenance_Schedule__c from inspection frequency, and marks assets as
 * 'Beyond Expected Life' when age exceeds Expected_Lifespan_Days__c.
 */
trigger AssetTrigger on Asset (before insert, before update) {

    if (Trigger.isBefore) {
        for (Asset asset : Trigger.new) {
            if (asset.Last_Inspection_Date__c != null && asset.Inspection_Frequency_Days__c != null) {
                Date nextDate = asset.Last_Inspection_Date__c.addDays(
                    Integer.valueOf(asset.Inspection_Frequency_Days__c)
                );
                asset.Next_Inspection_Date__c = nextDate;

                if (asset.Inspection_Frequency_Days__c <= 30) {
                    asset.Maintenance_Schedule__c = 'Monthly';
                } else if (asset.Inspection_Frequency_Days__c <= 90) {
                    asset.Maintenance_Schedule__c = 'Quarterly';
                } else if (asset.Inspection_Frequency_Days__c <= 180) {
                    asset.Maintenance_Schedule__c = 'Semi-Annual';
                } else if (asset.Inspection_Frequency_Days__c <= 365) {
                    asset.Maintenance_Schedule__c = 'Annual';
                } else {
                    asset.Maintenance_Schedule__c = 'Custom';
                }
            }

            if (asset.PurchaseDate != null && asset.UsageEndDate == null) {
                Integer assetAgeInDays = asset.PurchaseDate.daysBetween(Date.today());
                if (asset.Expected_Lifespan_Days__c != null &&
                    assetAgeInDays > asset.Expected_Lifespan_Days__c) {
                    asset.Status__c = 'Beyond Expected Life';
                }
            }
        }
    }
}
