/**
 * PipelineIntegrityStatusWrapper
 * ===============================
 * Invocable wrapper exposing pipeline integrity status to Agents, Flows, and
 * external MCP callers. Delegates to PipelineIntegrityService.
 */
public with sharing class PipelineIntegrityStatusWrapper {

    /**
     * @InvocableMethod Agent/Flow/MCP-facing wrapper returning the integrity
     * status for a pipeline (compliance, next due date, interval).
     * @param requests  List of @InvocableVariable PipelineIntegrityStatusRequest
     */
    @InvocableMethod(
        label='Get Pipeline Integrity Status'
        description='Returns inspection compliance status, last inspection date, and next due date for a pipeline.'
    )
    public static List<PipelineIntegrityStatusResult> getPipelineIntegrityStatuses(List<PipelineIntegrityStatusRequest> requests) {
        List<PipelineIntegrityStatusResult> results = new List<PipelineIntegrityStatusResult>();
        for (PipelineIntegrityStatusRequest req : requests) {
            PipelineIntegrityStatusResult result = new PipelineIntegrityStatusResult();
            result.pipelineId = req.pipelineId;
            result.success = true;
            try {
                if (req.pipelineId == null) {
                    throw new PipelineIntegrityWrapperException('Pipeline Id is required.');
                }
                PipelineIntegrityService.PipelineIntegrityStatus status =
                    PipelineIntegrityService.getPipelineIntegrityStatus(req.pipelineId);
                result.pipelineName = status.pipelineName;
                result.complianceStatus = status.complianceStatus;
                result.isCompliant = status.isCompliant;
                result.lastInspectionDate = status.lastInspectionDate;
                result.nextInspectionDueDate = status.nextInspectionDueDate;
                result.requiredIntervalMonths = status.requiredIntervalMonths;
                result.message = status.isCompliant
                    ? 'Pipeline is compliant. Next inspection due ' + status.nextInspectionDueDate + '.'
                    : 'Pipeline is NOT compliant. Next inspection due ' + status.nextInspectionDueDate + '.';
            } catch (Exception ex) {
                result.success = false;
                result.message = ex.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    public class PipelineIntegrityStatusRequest {
        @InvocableVariable(label='Pipeline Id' required=true description='The Pipeline__c record to check.')
        public Id pipelineId;
    }

    public class PipelineIntegrityStatusResult {
        @InvocableVariable(label='Pipeline Id')
        public Id pipelineId;
        @InvocableVariable(label='Pipeline Name')
        public String pipelineName;
        @InvocableVariable(label='Compliance Status')
        public String complianceStatus;
        @InvocableVariable(label='Is Compliant')
        public Boolean isCompliant;
        @InvocableVariable(label='Last Inspection Date')
        public Date lastInspectionDate;
        @InvocableVariable(label='Next Inspection Due Date')
        public Date nextInspectionDueDate;
        @InvocableVariable(label='Required Interval Months')
        public Integer requiredIntervalMonths;
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
    }

    public class PipelineIntegrityWrapperException extends Exception {}
}
