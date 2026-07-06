/**
 * PipelineIntegrityService
 * =========================
 * Monitors pipeline inspection compliance by checking overdue inspections,
 * flagging non-compliant pipelines, and calculating next due dates based on
 * required inspection intervals.
 *
 * Business Process: Pipeline Integrity (Midstream)
 *   Schedule Inspection → Conduct → Record Results → Evaluate Compliance
 *   → Flag Non-Compliant → Schedule Next Inspection
 */
public with sharing class PipelineIntegrityService {

    /**
     * Returns inspections whose due date has passed and are not completed/cancelled.
     * @return  Overdue inspections ordered by next due date ascending
     */
    public static List<Inspection__c> getOverdueInspections() {
        return [
            SELECT Id, Name, Pipeline__c, Pipeline__r.Name, Inspection_Type__c,
                   Scheduled_Date__c, Next_Due_Date__c, Status__c, Result__c,
                   Inspector__c, Inspection_Date__c
            FROM Inspection__c
            WHERE (Next_Due_Date__c < :Date.today()
                OR Scheduled_Date__c < :Date.today())
                AND Status__c != 'Completed'
                AND Status__c != 'Cancelled'
            ORDER BY Next_Due_Date__c ASC NULLS FIRST, Scheduled_Date__c ASC
        ];
    }

    /**
     * Checks whether a pipeline's last inspection is within the required interval.
     * @param pipelineId  The Pipeline__c Id
     * @return  true if the pipeline is compliant with inspection requirements
     */
    public static Boolean isInspectionCompliant(Id pipelineId) {
        Pipeline__c pipeline = [
            SELECT Id, Required_Inspection_Interval_Months__c,
                   Last_Inspection_Date__c, Compliance_Status__c
            FROM Pipeline__c
            WHERE Id = :pipelineId
            LIMIT 1
        ];

        if (pipeline.Last_Inspection_Date__c == null) return false;
        if (pipeline.Required_Inspection_Interval_Months__c == null) return true;

        Date nextDueDate = pipeline.Last_Inspection_Date__c.addMonths(
            Integer.valueOf(pipeline.Required_Inspection_Interval_Months__c)
        );

        return nextDueDate >= Date.today();
    }

    /**
     * Batch-updates Compliance_Status__c on all pipelines to 'Compliant' or
     * 'Non-Compliant' based on inspection recency.
     * Uses Database.Batchable internally for large data volumes.
     */
    public static void flagNonCompliantPipelines() {
        Database.executeBatch(new PipelineIntegrityBatch(), 200);
    }

    /**
     * Calculates the next required inspection date for a pipeline, defaulting
     * to 12-month interval when not specified and advancing past today if overdue.
     * @param pipelineId  The Pipeline__c Id
     * @return  The next due date
     */
    public static Date calculateNextInspectionDueDate(Id pipelineId) {
        Pipeline__c pipeline = [
            SELECT Id, Last_Inspection_Date__c, Required_Inspection_Interval_Months__c
            FROM Pipeline__c
            WHERE Id = :pipelineId
            LIMIT 1
        ];

        if (pipeline.Last_Inspection_Date__c == null) {
            return Date.today().addMonths(6);
        }

        Integer intervalMonths = pipeline.Required_Inspection_Interval_Months__c != null
            ? Integer.valueOf(pipeline.Required_Inspection_Interval_Months__c)
            : 12;

        Date nextDate = pipeline.Last_Inspection_Date__c.addMonths(intervalMonths);

        if (nextDate < Date.today()) {
            nextDate = Date.today().addMonths(intervalMonths);
        }

        return nextDate;
    }
}
