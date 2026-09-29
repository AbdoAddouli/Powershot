/**
 * ComplianceDueDateService
 * =========================
 * Tracks regulatory permit renewals, overdue compliance reports, and sends
 * automated reminder emails to responsible parties. Used by
 * RegulatoryPermitTrigger to keep Compliance_Status__c current.
 *
 * Business Process: Regulatory Compliance (Cross-Domain)
 *   Permit Issued → Expiration Tracking → Reminder Notifications
 *   → Status Updates (Compliant / Non-Compliant / Expired) → Renewal
 */
public with sharing class ComplianceDueDateService {

    /**
     * Finds permits whose expiration date falls within the next N days.
     * @param daysAhead  The look-ahead window in days
     * @return  Permits approaching expiration, ordered by date ascending
     */
    public static List<Regulatory_Permit__c> getUpcomingRenewals(Integer daysAhead) {
        Date targetDate = Date.today().addDays(daysAhead);
        return [
            SELECT Id, Name, Permit_Type__c, Expiration_Date__c, Status__c,
                   Renewal_Reminder_Sent__c, Responsible_Party__c, Well__c, Facility__c
            FROM Regulatory_Permit__c
            WHERE Expiration_Date__c >= :Date.today()
                AND Expiration_Date__c <= :targetDate
                AND Status__c != 'Expired'
            ORDER BY Expiration_Date__c ASC
        ];
    }

    /**
     * Returns compliance reports that are past due and not yet submitted/waived.
     * @return  Overdue reports ordered by due date ascending
     */
    public static List<Compliance_Report__c> getOverdueReports() {
        return [
            SELECT Id, Name, Report_Type__c, Due_Date__c, Status__c,
                   Submitted_Date__c, Regulatory_Body__c, Assigned_To__c,
                   Days_Overdue__c
            FROM Compliance_Report__c
            WHERE Due_Date__c < :Date.today()
                AND Status__c != 'Submitted'
                AND Status__c != 'Waived'
            ORDER BY Due_Date__c ASC
            LIMIT 50000
        ];
    }

    /**
     * @AuraEnabled LWC-facing method returning permits for a given account.
     * @param accountId  The Account Id
     * @return  Permits ordered by expiration date ascending
     */
    @AuraEnabled(cacheable=true)
    public static List<Regulatory_Permit__c> getUpcomingDeadlines(Id accountId) {
        return [
            SELECT Id, Name, Permit_Type__c, Expiration_Date__c, Status__c,
                   Agency__c, Issue_Date__c, Responsible_Party__c, Well__c,
                   Facility__c, Account__c
            FROM Regulatory_Permit__c
            WHERE Account__c = :accountId
            ORDER BY Expiration_Date__c ASC
        ];
    }

    /**
     * Updates Compliance_Status__c on permits based on expiration date proximity
     * (Expired / Critical - Expiring Soon / Approaching Expiration) or status
     * changes (Compliant / Expired / Non-Compliant).
     * @param expiringPermitIds  Permits whose expiration date changed
     * @param statusChangedPermitIds  Permits whose Status__c changed
     */
    public static void updateComplianceStatuses(Set<Id> expiringPermitIds, Set<Id> statusChangedPermitIds) {
        if (!expiringPermitIds.isEmpty()) {
            List<Regulatory_Permit__c> expiringPermits = [
                SELECT Id, Name, Permit_Type__c, Expiration_Date__c,
                       Responsible_Party__c, Compliance_Status__c
                FROM Regulatory_Permit__c
                WHERE Id IN :expiringPermitIds
            ];

            for (Regulatory_Permit__c permit : expiringPermits) {
                if (permit.Expiration_Date__c <= Date.today()) {
                    permit.Compliance_Status__c = 'Expired';
                } else if (permit.Expiration_Date__c <= Date.today().addDays(30)) {
                    permit.Compliance_Status__c = 'Critical - Expiring Soon';
                } else {
                    permit.Compliance_Status__c = 'Approaching Expiration';
                }
            }

            if (!expiringPermits.isEmpty()) {
                update expiringPermits;
            }
        }

        if (!statusChangedPermitIds.isEmpty()) {
            List<Regulatory_Permit__c> statusChanged = [
                SELECT Id, Name, Status__c, Compliance_Status__c
                FROM Regulatory_Permit__c
                WHERE Id IN :statusChangedPermitIds
            ];

            for (Regulatory_Permit__c permit : statusChanged) {
                if (permit.Status__c == 'Active' || permit.Status__c == 'Approved') {
                    permit.Compliance_Status__c = 'Compliant';
                } else if (permit.Status__c == 'Expired') {
                    permit.Compliance_Status__c = 'Expired';
                } else if (permit.Status__c == 'Suspended' || permit.Status__c == 'Revoked') {
                    permit.Compliance_Status__c = 'Non-Compliant';
                }
            }

            if (!statusChanged.isEmpty()) {
                update statusChanged;
            }
        }
    }

    /**
     * Sends email reminders for upcoming permit renewals (60-day window) and
     * overdue compliance reports to the assigned responsible parties.
     */
    public static void sendRenewalReminders() {
        List<Regulatory_Permit__c> upcoming = getUpcomingRenewals(60);
        List<Compliance_Report__c> overdue = getOverdueReports();

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Regulatory_Permit__c permit : upcoming) {
            if (permit.Renewal_Reminder_Sent__c == true) continue;
            if (permit.Responsible_Party__c == null) continue;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(permit.Responsible_Party__c);
            mail.setSaveAsActivity(false);
            mail.setSubject('Permit Renewal Reminder: ' + permit.Name);
            mail.setPlainTextBody(
                'The following permit is approaching its expiration date:\n\n' +
                'Permit: ' + permit.Name + '\n' +
                'Type: ' + permit.Permit_Type__c + '\n' +
                'Expiration Date: ' + permit.Expiration_Date__c + '\n\n' +
                'Please initiate the renewal process.'
            );
            emails.add(mail);

            permit.Renewal_Reminder_Sent__c = true;
        }

        for (Compliance_Report__c report : overdue) {
            if (report.Assigned_To__c == null) continue;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(report.Assigned_To__c);
            mail.setSaveAsActivity(false);
            mail.setSubject('OVERDUE Compliance Report: ' + report.Name);
            mail.setPlainTextBody(
                'The following compliance report is past due:\n\n' +
                'Report: ' + report.Name + '\n' +
                'Type: ' + report.Report_Type__c + '\n' +
                'Due Date: ' + report.Due_Date__c + '\n' +
                'Regulatory Body: ' + report.Regulatory_Body__c + '\n\n' +
                'Please submit immediately to avoid penalties.'
            );
            emails.add(mail);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }

        if (!upcoming.isEmpty()) {
            update upcoming;
        }
    }

    /**
     * @InvocableMethod Agent/Flow/MCP-facing wrapper returning an overview of
     * upcoming permit renewals and overdue compliance reports.
     * @param requests  List of @InvocableVariable ComplianceOverviewRequest
     */
    @InvocableMethod(
        label='Get Compliance Overview'
        description='Returns permits expiring soon and compliance reports that are overdue.'
    )
    public static List<ComplianceOverview> getComplianceOverview(List<ComplianceOverviewRequest> requests) {
        List<ComplianceOverview> overviews = new List<ComplianceOverview>();
        for (ComplianceOverviewRequest req : requests) {
            ComplianceOverview overview = new ComplianceOverview();
            Integer daysAhead = req.daysAhead != null ? req.daysAhead : 30;
            try {
                overview.upcomingRenewals = getUpcomingRenewals(daysAhead);
                overview.overdueReports = getOverdueReports();
                overview.success = true;
                overview.message = 'Found ' + overview.upcomingRenewals.size() +
                    ' permit(s) expiring within ' + daysAhead + ' days and ' +
                    overview.overdueReports.size() + ' overdue report(s).';
            } catch (Exception ex) {
                overview.success = false;
                overview.message = ex.getMessage();
            }
            overviews.add(overview);
        }
        return overviews;
    }

    public class ComplianceOverviewRequest {
        @InvocableVariable(label='Days Ahead'
            description='Look-ahead window in days for expiring permits. Defaults to 30.')
        public Integer daysAhead;
    }

    public class ComplianceOverview {
        @InvocableVariable(label='Upcoming Renewals')
        public List<Regulatory_Permit__c> upcomingRenewals;
        @InvocableVariable(label='Overdue Reports')
        public List<Compliance_Report__c> overdueReports;
        @InvocableVariable(label='Success')
        public Boolean success;
        @InvocableVariable(label='Message')
        public String message;
    }
}
