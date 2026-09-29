/**
 * WellStatusService
 * =================
 * Manages the lifecycle state machine for Well__c records. Enforces valid status
 * transitions, creates Well_Operation__c audit records on status changes, and
 * provides queries for wells due for abandonment.
 *
 * Business Process: Well Lifecycle (Upstream)
 *   Permitted → Drilling → Producing → Shut-In → Suspended → Plugged → Abandoned
 */
public with sharing class WellStatusService {

    /** Maps each well status to the set of allowed next statuses (state machine). */
    private static final Map<String, Set<String>> VALID_TRANSITIONS = new Map<String, Set<String>>{
        'Permitted' => new Set<String>{ 'Drilling', 'Cancelled' },
        'Drilling' => new Set<String>{ 'Producing', 'Suspended', 'Plugged', 'Abandoned' },
        'Producing' => new Set<String>{ 'Shut-In', 'Suspended', 'Plugged', 'Abandoned' },
        'Shut-In' => new Set<String>{ 'Producing', 'Suspended', 'Plugged', 'Abandoned' },
        'Suspended' => new Set<String>{ 'Producing', 'Shut-In', 'Plugged', 'Abandoned' },
        'Plugged' => new Set<String>{ 'Abandoned' },
        'Abandoned' => new Set<String>{}
    };

    /**
     * Transitions a single well to a new status. Throws WellStatusException
     * if the transition is not allowed by the state machine.
     * @param wellId  The Well__c record to update
     * @param newStatus  Target status value
     */
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

        createWellOperations(new List<Well__c>{ well });
    }

    /**
     * Checks whether a status transition is valid according to the state machine map.
     * @param currentStatus  The current status value
     * @param newStatus  The desired new status value
     * @return true if the transition is allowed
     */
    public static Boolean isValidTransition(String currentStatus, String newStatus) {
        if (String.isBlank(currentStatus) || String.isBlank(newStatus)) return false;
        if (currentStatus == newStatus) return true;

        Set<String> allowed = VALID_TRANSITIONS.get(currentStatus);
        return allowed != null && allowed.contains(newStatus);
    }

    /**
     * Creates Well_Operation__c audit records for each well that changed status.
     * Called by the trigger (bulk) and by transitionWellStatus (single).
     * @param wells  The wells whose status change should be recorded
     */
    public static void createWellOperations(List<Well__c> wells) {
        List<Well_Operation__c> operations = new List<Well_Operation__c>();
        for (Well__c well : wells) {
            operations.add(new Well_Operation__c(
                Well__c = well.Id,
                Operation_Type__c = 'Status Change',
                Status__c = well.Status__c,
                Operation_Date__c = Date.today(),
                Description__c = 'Well status changed to "' + well.Status__c + '"',
                Performed_By__c = UserInfo.getUserId()
            ));
        }
        if (!operations.isEmpty()) {
            insert operations;
        }
    }

    /**
     * Returns wells that have been Shut-In for 24+ months and are candidates
     * for abandonment under regulatory guidelines.
     * @return  List of Well__c records eligible for abandonment
     */
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

    /**
     * @AuraEnabled LWC-facing method returning production history for a well.
     * @param wellId  The Well__c Id
     * @return  Production allocations ordered by most recent period end
     */
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

    /**
     * @InvocableMethod Agent/Flow/MCP-facing wrapper for transitioning a well status.
     * Exposes the write path so an agent can update a well's lifecycle state.
     * @param requests  List of @InvocableVariable WellStatusChangeRequest
     */
    @InvocableMethod(
        label='Transition Well Status'
        description='Validates and applies a well lifecycle status transition (e.g. Producing to Shut-In).'
    )
    public static List<WellStatusChangeResult> transitionWellStatuses(List<WellStatusChangeRequest> requests) {
        List<WellStatusChangeResult> results = new List<WellStatusChangeResult>();
        for (WellStatusChangeRequest req : requests) {
            WellStatusChangeResult result = new WellStatusChangeResult();
            result.success = true;
            try {
                transitionWellStatus(req.wellId, req.newStatus);
                result.message = 'Well status updated to "' + req.newStatus + '".';
            } catch (Exception ex) {
                result.success = false;
                result.message = ex.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    public class WellStatusChangeRequest {
        @InvocableVariable(label='Well Id' required=true description='The Well__c record to transition.')
        public Id wellId;
        @InvocableVariable(label='New Status' required=true description='Target status value, e.g. Producing, Shut-In, Plugged.')
        public String newStatus;
    }

    public class WellStatusChangeResult {
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
    }

    public class WellStatusException extends Exception {}
}
