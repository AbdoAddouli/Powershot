public with sharing class ComplianceDueDateService {

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
        ];
    }

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

    public static void sendRenewalReminders() {
        List<Regulatory_Permit__c> upcoming = getUpcomingRenewals(60);
        List<Compliance_Report__c> overdue = getOverdueReports();

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Regulatory_Permit__c permit : upcoming) {
            if (permit.Renewal_Reminder_Sent__c == true) continue;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(permit.Responsible_Party__c);
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
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(report.Assigned_To__c);
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
}
