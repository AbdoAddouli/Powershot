public with sharing class WellStatusService {

    private static final Map<String, Set<String>> VALID_TRANSITIONS = new Map<String, Set<String>>{
        'Permitted' => new Set<String>{ 'Drilling', 'Cancelled' },
        'Drilling' => new Set<String>{ 'Producing', 'Suspended', 'Plugged', 'Abandoned' },
        'Producing' => new Set<String>{ 'Shut-In', 'Suspended', 'Plugged', 'Abandoned' },
        'Shut-In' => new Set<String>{ 'Producing', 'Suspended', 'Plugged', 'Abandoned' },
        'Suspended' => new Set<String>{ 'Producing', 'Shut-In', 'Plugged', 'Abandoned' },
        'Plugged' => new Set<String>{ 'Abandoned' },
        'Abandoned' => new Set<String>{}
    };

    public static void transitionWellStatus(Id wellId, String newStatus) {
        Well__c well = [
            SELECT Id, Status__c, Name
            FROM Well__c
            WHERE Id = :wellId
            LIMIT 1
        ];

        String currentStatus = well.Status__c;

        if (!isValidTransition(currentStatus, newStatus)) {
            throw new WellStatusException(
                'Invalid status transition from "' + currentStatus + '" to "' + newStatus + '".'
            );
        }

        well.Status__c = newStatus;
        well.Status_Change_Date__c = Date.today();
        update well;

        createWellOperationOnStatusChange(wellId, newStatus);
    }

    public static Boolean isValidTransition(String currentStatus, String newStatus) {
        if (String.isBlank(currentStatus) || String.isBlank(newStatus)) return false;
        if (currentStatus == newStatus) return true;

        Set<String> allowed = VALID_TRANSITIONS.get(currentStatus);
        return allowed != null && allowed.contains(newStatus);
    }

    public static void createWellOperationOnStatusChange(Id wellId, String newStatus) {
        Well__c well = [
            SELECT Id, Name, Status__c, Status_Change_Date__c
            FROM Well__c
            WHERE Id = :wellId
            LIMIT 1
        ];

        Well_Operation__c operation = new Well_Operation__c(
            Well__c = wellId,
            Operation_Type__c = 'Status Change',
            Status__c = newStatus,
            Operation_Date__c = Date.today(),
            Description__c = 'Well status changed to "' + newStatus + '"',
            Performed_By__c = UserInfo.getUserId()
        );

        insert operation;
    }

    public static List<Well__c> getWellsDueForAbandonment() {
        Date cutoffDate = Date.today().addMonths(-24);
        return [
            SELECT Id, Name, Status__c, Status_Change_Date__c,
                   Last_Production_Date__c, Regulatory_District__c
            FROM Well__c
            WHERE Status__c = 'Shut-In'
                AND Status_Change_Date__c <= :cutoffDate
            ORDER BY Status_Change_Date__c ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Production_Allocation__c> getWellProduction(Id wellId) {
        return [
            SELECT Id, Period_Start__c, Period_End__c, Oil_Volume_bbls__c,
                   Gas_Volume_MCF__c, Water_Volume_bbls__c, Days_On_Production__c
            FROM Production_Allocation__c
            WHERE Well__c = :wellId
            ORDER BY Period_End__c DESC
        ];
    }

    public class WellStatusException extends Exception {}
}
