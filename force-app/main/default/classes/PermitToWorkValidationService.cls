/**
 * PermitToWorkValidationService
 * ==============================
 * Enforces safety validation rules for Permit-to-Work (PTW) including energy
 * isolation verification, gas test results, and multi-level authorization
 * chains based on risk level. Used by field services to determine permit readiness.
 *
 * Business Process: Permit to Work (Downstream / HSE)
 *   PTW Request → Risk Assessment → Isolation Verification → Gas Testing
 *   → Authorization Chain → Permit Issuance → Work Execution → Permit Closure
 */
public with sharing class PermitToWorkValidationService {

    /**
     * Validates energy isolation requirements: checks Isolation_Verified__c,
     * Lockout-Tagout for Electrical/Mechanical permits, and Zero Energy State.
     * @param permitId  The Permit_to_Work__c Id
     * @return  true if all isolation requirements are satisfied
     */
    public static Boolean validateIsolationRequirements(Id permitId) {
        Permit_to_Work__c permit = [
            SELECT Id, Isolation_Required__c, Isolation_Verified__c,
                   Energy_Isolation_Type__c, Lockout_Tagout_Completed__c,
                   Zero_Energy_State_Verified__c, Permit_Type__c
            FROM Permit_to_Work__c
            WHERE Id = :permitId
            LIMIT 1
        ];

        if (permit.Isolation_Required__c == false) return true;
        if (permit.Isolation_Verified__c == false) return false;

        if (permit.Permit_Type__c == 'Electrical' || permit.Permit_Type__c == 'Mechanical') {
            if (permit.Lockout_Tagout_Completed__c == false) return false;
            if (permit.Zero_Energy_State_Verified__c == false) return false;
        }

        if (permit.Energy_Isolation_Type__c == 'Electrical Isolation' &&
            permit.Lockout_Tagout_Completed__c == false) {
            return false;
        }

        return true;
    }

    /**
     * Validates gas test results against safe limits: O2 (19.5-23.5 %),
     * LEL (<=10 %), H2S (<=10 ppm), CO (<=25 ppm). Also checks that gas
     * testing was completed and did not fail.
     * @param permitId  The Permit_to_Work__c Id
     * @return  true if all gas test criteria are within safe ranges
     */
    public static Boolean validateGasTestResults(Id permitId) {
        Permit_to_Work__c permit = [
            SELECT Id, Gas_Test_Required__c, Gas_Test_Completed__c,
                   Oxygen_Level_Pct__c, LEL_Pct__c, H2S_Level_Ppm__c,
                   CO_Level_Ppm__c, Gas_Test_Result__c, Permit_Type__c
            FROM Permit_to_Work__c
            WHERE Id = :permitId
            LIMIT 1
        ];

        if (permit.Gas_Test_Required__c == false) return true;
        if (permit.Gas_Test_Completed__c == false) return false;
        if (permit.Gas_Test_Result__c == 'Fail') return false;

        if (permit.Oxygen_Level_Pct__c != null) {
            if (permit.Oxygen_Level_Pct__c < 19.5 || permit.Oxygen_Level_Pct__c > 23.5) return false;
        }

        if (permit.LEL_Pct__c != null && permit.LEL_Pct__c > 10) return false;

        if (permit.H2S_Level_Ppm__c != null && permit.H2S_Level_Ppm__c > 10) return false;

        if (permit.CO_Level_Ppm__c != null && permit.CO_Level_Ppm__c > 25) return false;

        return true;
    }

    /**
     * Validates that the permit has sufficient approvals based on risk level:
     *   1 approval for Low, 2 for Medium/High, 3 for Critical.
     * Confined Space/Hot Work/Electrical/Excavation types always require >= 2.
     * @param permitId  The Permit_to_Work__c Id
     * @return  true if the required number of authorizations have been obtained
     */
    public static Boolean validateAuthorizationChain(Id permitId) {
        Permit_to_Work__c permit = [
            SELECT Id, Permit_Type__c, Risk_Level__c, Location__c,
                   Authorizer__c, Authorizer_2__c, Authorizer_3__c,
                   Authorization_Date__c, Authorization_2_Date__c,
                   Authorization_3_Date__c, Status__c
            FROM Permit_to_Work__c
            WHERE Id = :permitId
            LIMIT 1
        ];

        Map<String, Integer> authLevels = new Map<String, Integer>{
            'Low' => 1,
            'Medium' => 2,
            'High' => 3,
            'Critical' => 4
        };

        Integer requiredApprovals = 1;
        String riskLevel = permit.Risk_Level__c != null ? permit.Risk_Level__c : 'Low';

        if (authLevels.containsKey(riskLevel)) {
            Integer level = authLevels.get(riskLevel);
            if (level >= 4) {
                requiredApprovals = 3;
            } else if (level >= 3) {
                requiredApprovals = 2;
            } else if (level >= 2) {
                requiredApprovals = 2;
            }
        }

        String permitType = permit.Permit_Type__c;
        if (permitType == 'Confined Space Entry' || permitType == 'Hot Work' ||
            permitType == 'Electrical' || permitType == 'Excavation') {
            if (requiredApprovals < 2) requiredApprovals = 2;
        }

        if (permit.Authorizer__c == null || permit.Authorization_Date__c == null) {
            return false;
        }

        if (requiredApprovals >= 2 && (permit.Authorizer_2__c == null || permit.Authorization_2_Date__c == null)) {
            return false;
        }

        if (requiredApprovals >= 3 && (permit.Authorizer_3__c == null || permit.Authorization_3_Date__c == null)) {
            return false;
        }

        return true;
    }

    /**
     * @AuraEnabled LWC-facing method returning permits related to a well,
     * pipeline station, terminal, or refinery.
     * @param parentId  The parent record Id
     * @return  Permits ordered by creation date descending
     */
    @AuraEnabled(cacheable=true)
    public static List<Permit_to_Work__c> getPermitsToWork(Id parentId) {
        return [SELECT Id, Name, Permit_Type__c, Status__c, Holder__c, Holder__r.Name,
                       Description__c, Location__c, Start_DateTime__c, End_DateTime__c
                FROM Permit_to_Work__c
                WHERE Well__c = :parentId OR Pipeline_Station__c = :parentId
                   OR Terminal__c = :parentId OR Refinery__c = :parentId
                ORDER BY CreatedDate DESC];
    }

    /**
     * @AuraEnabled LWC-facing method to update a permit's status.
     * @param permitId  The Permit_to_Work__c Id
     * @param newStatus  The new status value
     */
    @AuraEnabled
    public static void updatePermitStatus(Id permitId, String newStatus) {
        Permit_to_Work__c permit = new Permit_to_Work__c(Id = permitId, Status__c = newStatus);
        update permit;
    }

    /**
     * Returns a list of all missing or incomplete requirements for a permit,
     * including scope of work, dates, isolation, gas test, and authorizations.
     * @param permitId  The Permit_to_Work__c Id
     * @return  Human-readable list of missing prerequisites
     */
    public static List<String> getMissingRequirements(Id permitId) {
        List<String> missing = new List<String>();

        Permit_to_Work__c permit = [
            SELECT Id, Permit_Type__c, Risk_Level__c, Isolation_Required__c,
                   Isolation_Verified__c, Gas_Test_Required__c, Gas_Test_Completed__c,
                   Gas_Test_Result__c, Authorizer__c, Authorization_Date__c,
                   Authorizer_2__c, Authorization_2_Date__c,
                   Authorizer_3__c, Authorization_3_Date__c,
                   PTW_Number__c, Issuing_Authority__c, Scope_of_Work__c,
                   Valid_From__c, Valid_To__c
            FROM Permit_to_Work__c
            WHERE Id = :permitId
            LIMIT 1
        ];

        if (permit.Scope_of_Work__c == null || permit.Scope_of_Work__c.length() < 10) {
            missing.add('Detailed scope of work description is required');
        }

        if (permit.Valid_From__c == null) {
            missing.add('Permit start date/time is required');
        }

        if (permit.Valid_To__c == null) {
            missing.add('Permit expiry date/time is required');
        }

        if (permit.Valid_From__c != null && permit.Valid_To__c != null &&
            permit.Valid_From__c >= permit.Valid_To__c) {
            missing.add('Permit expiry must be after start date');
        }

        if (permit.Issuing_Authority__c == null) {
            missing.add('Issuing authority must be specified');
        }

        if (!validateIsolationRequirements(permitId)) {
            if (permit.Isolation_Required__c == true && permit.Isolation_Verified__c == false) {
                missing.add('Isolation requirements not verified');
            }
            missing.add('Energy isolation / lockout-tagout not completed');
        }

        if (!validateGasTestResults(permitId)) {
            if (permit.Gas_Test_Required__c == true && permit.Gas_Test_Completed__c == false) {
                missing.add('Gas testing not completed');
            } else {
                missing.add('Gas test results outside safe limits');
            }
        }

        if (!validateAuthorizationChain(permitId)) {
            missing.add('Incomplete authorization chain - required approvals not obtained');
        }

        if (permit.PTW_Number__c == null) {
            missing.add('PTW number must be assigned');
        }

        return missing;
    }
}
