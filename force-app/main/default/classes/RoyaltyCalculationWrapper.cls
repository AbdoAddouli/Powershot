/**
 * RoyaltyCalculationWrapper
 * ==========================
 * Invocable wrapper exposing royalty calculation summaries to Agents, Flows,
 * and external MCP callers. Delegates to RoyaltyCalculationService.
 */
public with sharing class RoyaltyCalculationWrapper {

    /**
     * @InvocableMethod Agent/Flow/MCP-facing wrapper returning a royalty summary
     * for a lease over a given period, including the per-partner breakdown.
     * @param requests  List of @InvocableVariable RoyaltyCalculationRequest
     */
    @InvocableMethod(
        label='Calculate Royalty'
        description='Returns total allocated revenue, royalty rate, total royalty due, and per-partner shares for a lease and period.'
    )
    public static List<RoyaltyCalculationResult> calculateRoyalties(List<RoyaltyCalculationRequest> requests) {
        List<RoyaltyCalculationResult> results = new List<RoyaltyCalculationResult>();
        for (RoyaltyCalculationRequest req : requests) {
            RoyaltyCalculationResult result = new RoyaltyCalculationResult();
            result.leaseId = req.leaseId;
            result.success = true;
            try {
                if (req.leaseId == null) {
                    throw new RoyaltyWrapperException('Lease Id is required.');
                }
                Date periodStart = req.periodStart != null ? req.periodStart : Date.today().toStartOfMonth();
                Date periodEnd = req.periodEnd != null ? req.periodEnd : Date.today();
                RoyaltyCalculationService.RoyaltySummary summary =
                    RoyaltyCalculationService.getRoyaltySummary(req.leaseId, periodStart, periodEnd);
                result.leaseName = summary.leaseName;
                result.totalRoyalty = summary.totalRoyalty;
                result.totalAllocatedRevenue = summary.totalAllocatedRevenue;
                result.royaltyRatePercent = summary.royaltyRatePercent;
                result.message = 'Total royalty of $' + summary.totalRoyalty +
                    ' computed for ' + summary.partnerShares.size() + ' partner(s).';
            } catch (Exception ex) {
                result.success = false;
                result.message = ex.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    public class RoyaltyCalculationRequest {
        @InvocableVariable(label='Lease Id' required=true description='The Lease__c record to compute royalty for.')
        public Id leaseId;
        @InvocableVariable(label='Period Start' description='Start of the royalty period. Defaults to start of month.')
        public Date periodStart;
        @InvocableVariable(label='Period End' description='End of the royalty period. Defaults to today.')
        public Date periodEnd;
    }

    public class RoyaltyCalculationResult {
        @InvocableVariable(label='Lease Id')
        public Id leaseId;
        @InvocableVariable(label='Lease Name')
        public String leaseName;
        @InvocableVariable(label='Total Royalty')
        public Decimal totalRoyalty;
        @InvocableVariable(label='Total Allocated Revenue')
        public Decimal totalAllocatedRevenue;
        @InvocableVariable(label='Royalty Rate Percent')
        public Decimal royaltyRatePercent;
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
    }

    public class RoyaltyWrapperException extends Exception {}
}
