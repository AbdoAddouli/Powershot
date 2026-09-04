/**
 * ProductionHistoryWrapper
 * =========================
 * Invocable wrapper exposing production history for a well to Agents, Flows,
 * and external MCP callers. Delegates to ProductionAllocationService.
 */
public with sharing class ProductionHistoryWrapper {

    /**
     * @InvocableMethod Agent/Flow/MCP-facing wrapper returning production history
     * for a well over a look-back window in months.
     * @param requests  List of @InvocableVariable ProductionHistoryRequest
     */
    @InvocableMethod(
        label='Get Production History'
        description='Returns oil/gas/water production allocations for a well over the given look-back window.'
    )
    public static List<ProductionHistoryResult> getProductionHistory(List<ProductionHistoryRequest> requests) {
        List<ProductionHistoryResult> results = new List<ProductionHistoryResult>();
        for (ProductionHistoryRequest req : requests) {
            ProductionHistoryResult result = new ProductionHistoryResult();
            result.wellId = req.wellId;
            result.success = true;
            try {
                if (req.wellId == null) {
                    throw new ProductionHistoryException('Well Id is required.');
                }
                Integer months = req.months != null && req.months > 0 ? req.months : 12;
                result.allocations = ProductionAllocationService.getProductionHistory(req.wellId, months);
                result.message = 'Returned ' + result.allocations.size() + ' allocation record(s).';
            } catch (Exception ex) {
                result.success = false;
                result.message = ex.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    public class ProductionHistoryRequest {
        @InvocableVariable(label='Well Id' required=true description='The Well__c record to retrieve history for.')
        public Id wellId;
        @InvocableVariable(label='Months' description='Look-back window in months. Defaults to 12.')
        public Integer months;
    }

    public class ProductionHistoryResult {
        @InvocableVariable(label='Well Id')
        public Id wellId;
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Allocations')
        public List<Production_Allocation__c> allocations;
        @InvocableVariable(label='Message')
        public String message;
    }

    public class ProductionHistoryException extends Exception {}
}
