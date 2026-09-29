public without sharing class PowerShotProfileController {

    // Classe délibérément en « without sharing » : les utilisateurs portal
    // doivent pouvoir éditer leur PROPRE Contact, même s'ils n'en sont pas
    // l'owner (l'owner est l'admin partenaire). La sécurité est garantie par
    // le garde strict ci-dessous : le Contact doit être celui lié au User
    // courant (UserInfo.getUserId) — jamais un autre enregistrement.

    private static final Pattern EMAIL_PATTERN =
        Pattern.compile('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$');

    @AuraEnabled(cacheable=true)
    public static ProfileData getProfile() {
        User caller = [
            SELECT Id, Username, Email, Name, ContactId, AccountId, LastLoginDate
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];

        ProfileData data = new ProfileData();
        data.username = caller.Username;
        data.userEmail = caller.Email;
        data.lastLoginDate = caller.LastLoginDate;

        if (caller.ContactId != null) {
            Contact c = [
                SELECT FirstName, LastName, Title, Email, Phone, MobilePhone,
                       MailingStreet, MailingCity, MailingState,
                       MailingPostalCode, MailingCountry, AccountId
                FROM Contact
                WHERE Id = :caller.ContactId
            ];
            data.contactId = c.Id;
            data.firstName = c.FirstName;
            data.lastName = c.LastName;
            data.title = c.Title;
            data.email = c.Email;
            data.phone = c.Phone;
            data.mobilePhone = c.MobilePhone;
            data.mailingStreet = c.MailingStreet;
            data.mailingCity = c.MailingCity;
            data.mailingState = c.MailingState;
            data.mailingPostalCode = c.MailingPostalCode;
            data.mailingCountry = c.MailingCountry;

            if (c.AccountId != null) {
                Account a = [
                    SELECT Name, Phone, BillingStreet, BillingCity, BillingState,
                           BillingPostalCode, BillingCountry
                    FROM Account
                    WHERE Id = :c.AccountId
                ];
                data.accountName = a.Name;
                data.accountPhone = a.Phone;
                data.billingStreet = a.BillingStreet;
                data.billingCity = a.BillingCity;
                data.billingState = a.BillingState;
                data.billingPostalCode = a.BillingPostalCode;
                data.billingCountry = a.BillingCountry;
            }
        }

        return data;
    }

    @AuraEnabled
    public static SaveResult updateContact(Map<String, Object> fields) {
        SaveResult result = new SaveResult();

        String firstName = safeString(fields.get('FirstName'));
        String lastName = safeString(fields.get('LastName'));
        if (String.isBlank(firstName) || String.isBlank(lastName)) {
            result.success = false;
            result.message = 'First and last name are required.';
            return result;
        }

        String email = safeString(fields.get('Email'));
        if (String.isNotBlank(email) && !EMAIL_PATTERN.matcher(email).matches()) {
            result.success = false;
            result.message = 'Enter a valid email address.';
            return result;
        }

        User caller = [
            SELECT Id, ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        Id callerContactId = caller.ContactId;

        List<Contact> owned = (callerContactId == null)
            ? new List<Contact>()
            : [
                SELECT Id
                FROM Contact
                WHERE Id = :callerContactId
            ];
        if (owned.isEmpty()) {
            result.success = false;
            result.message = 'No contact profile found for this user.';
            return result;
        }

        Contact toUpdate = new Contact(Id = owned[0].Id);
        toUpdate.FirstName = firstName;
        toUpdate.LastName = lastName;
        toUpdate.Title = safeString(fields.get('Title'));
        toUpdate.Email = email;
        toUpdate.Phone = safeString(fields.get('Phone'));
        toUpdate.MobilePhone = safeString(fields.get('MobilePhone'));
        toUpdate.MailingStreet = safeString(fields.get('MailingStreet'));
        toUpdate.MailingCity = safeString(fields.get('MailingCity'));
        toUpdate.MailingState = safeString(fields.get('MailingState'));
        toUpdate.MailingPostalCode = safeString(fields.get('MailingPostalCode'));
        toUpdate.MailingCountry = safeString(fields.get('MailingCountry'));

        try {
            update toUpdate;
            result.success = true;
            result.message = 'Profile updated successfully.';
        } catch (DmlException ex) {
            result.success = false;
            result.message = ex.getDmlMessage(0);
        }
        return result;
    }

    private static String safeString(Object value) {
        return value == null ? '' : String.valueOf(value).trim();
    }

    public class ProfileData {
        @AuraEnabled public String contactId;
        @AuraEnabled public String username;
        @AuraEnabled public String userEmail;
        @AuraEnabled public Datetime lastLoginDate;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String title;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String mobilePhone;
        @AuraEnabled public String mailingStreet;
        @AuraEnabled public String mailingCity;
        @AuraEnabled public String mailingState;
        @AuraEnabled public String mailingPostalCode;
        @AuraEnabled public String mailingCountry;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountPhone;
        @AuraEnabled public String billingStreet;
        @AuraEnabled public String billingCity;
        @AuraEnabled public String billingState;
        @AuraEnabled public String billingPostalCode;
        @AuraEnabled public String billingCountry;
    }

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }
}