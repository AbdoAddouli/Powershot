public with sharing class AccessRequestAdminService {

    private static final Map<String, Set<String>> ALLOWED_TRANSITIONS =
        new Map<String, Set<String>>{
            'New' => new Set<String>{ 'In Review', 'Rejected' },
            'In Review' => new Set<String>{ 'Approved', 'Rejected' },
            'Approved' => new Set<String>(),
            'Rejected' => new Set<String>()
        };

    private static final String PARTNER_PROFILE_NAME = 'Partner Community User';
    private static final String USER_TIMEZONE = 'Europe/Paris';
    private static final String USER_LOCALE = 'fr_FR';
    private static final String USER_LANGUAGE = 'fr';

    public class ApprovalException extends Exception {}

    public with sharing class RequestView {
        @AuraEnabled public String name;
        @AuraEnabled public Id id;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String company;
        @AuraEnabled public String requestedProfile;
        @AuraEnabled public String status;
        @AuraEnabled public String comments;
        @AuraEnabled public Datetime createdDate;
    }

    public with sharing class StatusResult {
        @AuraEnabled public Boolean success = false;
        @AuraEnabled public String message = '';
        @AuraEnabled public String status;
    }

    @AuraEnabled(cacheable=true)
    public static List<RequestView> getRequests() {
        List<RequestView> views = new List<RequestView>();
        for (Access_Request__c r : [
            SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, Company__c,
                   Requested_Profile__c, Status__c, Comments__c, CreatedDate
            FROM Access_Request__c
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]) {
            RequestView v = new RequestView();
            v.name = r.Name;
            v.id = r.Id;
            v.firstName = r.First_Name__c;
            v.lastName = r.Last_Name__c;
            v.email = r.Email__c;
            v.company = r.Company__c;
            v.requestedProfile = r.Requested_Profile__c;
            v.status = r.Status__c;
            v.comments = r.Comments__c;
            v.createdDate = r.CreatedDate;
            views.add(v);
        }
        return views;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserAdmin() {
        Profile admin = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
              AND Id = :UserInfo.getProfileId()
            LIMIT 1
        ];
        if (admin != null) {
            return true;
        }
        return [
            SELECT Count()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSet.Name = 'AccessRequestAdmin'
        ] > 0;
    }

    @AuraEnabled
    public static StatusResult setStatus(Id recordId, String newStatus) {
        StatusResult result = new StatusResult();
        if (recordId == null || String.isBlank(newStatus)) {
            result.message = 'Parametres manquants (record ou statut).';
            return result;
        }
        List<Access_Request__c> records = [
            SELECT Id, Status__c, First_Name__c, Last_Name__c, Email__c, Company__c,
                   Requested_Profile__c
            FROM Access_Request__c
            WHERE Id = :recordId
        ];
        if (records.isEmpty()) {
            result.message = 'Demande introuvable.';
            return result;
        }
        Access_Request__c record = records[0];
        Set<String> allowed = ALLOWED_TRANSITIONS.get(record.Status__c);
        if (allowed == null || !allowed.contains(newStatus)) {
            result.message =
                'Transition non autorisee: ' + record.Status__c + ' -> ' + newStatus + '.';
            return result;
        }
        Savepoint sp = Database.setSavepoint();
        try {
            if (newStatus == 'Approved') {
                createPartnerUser(record);
            }
            record.Status__c = newStatus;
            Database.update(record, AccessLevel.SYSTEM_MODE);
            result.success = true;
            result.status = newStatus;
        } catch (DmlException ex) {
            Database.rollback(sp);
            result.message = ex.getDmlMessage(0);
        } catch (ApprovalException ex) {
            Database.rollback(sp);
            result.message = ex.getMessage();
        }
        return result;
    }

    @TestVisible
    static String lastCreatedUserId;
    @TestVisible
    static String lastCreatedUsername;

    private static void createPartnerUser(Access_Request__c record) {
        String email = String.isBlank(record.Email__c) ? '' : record.Email__c.trim().toLowerCase();
        if (String.isBlank(email) || !email.contains('@')) {
            throw new ApprovalException(
                'Adresse email manquante ou invalide, impossible de creer le compte.');
        }

        List<User> existing = [
            SELECT Id
            FROM User
            WHERE Email = :email AND IsActive = true
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new ApprovalException(
                'Un utilisateur actif existe deja pour cet email (' + email + ').');
        }

        Profile partnerProfile = [
            SELECT Id
            FROM Profile
            WHERE Name = :PARTNER_PROFILE_NAME
            LIMIT 1
        ];
        if (partnerProfile == null) {
            throw new ApprovalException('Profil ' + PARTNER_PROFILE_NAME + ' introuvable.');
        }

        String company = String.isBlank(record.Company__c) ? 'Partner' : record.Company__c;
        List<Account> accounts = [
            SELECT Id
            FROM Account
            WHERE Name = :company
            ORDER BY CreatedDate
            LIMIT 1
        ];
        Account account;
        if (accounts.isEmpty()) {
            account = new Account(Name = company);
            insert account;
        } else {
            account = accounts[0];
        }

        String firstName = record.First_Name__c;
        String lastName = String.isBlank(record.Last_Name__c) ? 'Partner' : record.Last_Name__c;

        List<Contact> contacts = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Email = :email
            ORDER BY CreatedDate
            LIMIT 1
        ];
        Contact contact;
        if (contacts.isEmpty()) {
            contact = new Contact(
                FirstName = firstName,
                LastName = lastName,
                Email = email,
                AccountId = account.Id
            );
            insert contact;
        } else {
            contact = contacts[0];
        }

        String base = normalizePart(firstName) + '.' + normalizePart(lastName);
        Database.DMLOptions options = new Database.DMLOptions();
        options.EmailHeader.triggerUserEmail = true;
        Integer n = 1;
        while (n <= 100) {
            String username = base + '@powershot.com';
            if (n > 1) {
                username = base + String.valueOf(n) + '@powershot.com';
            }
            if ([SELECT COUNT() FROM User WHERE Username = :username] > 0) {
                n++;
                continue;
            }
            User user = buildPartnerUser(record, contact, partnerProfile);
            user.Username = username;
            Database.SaveResult saveResult = Database.insert(user, options);
            if (saveResult.isSuccess()) {
                lastCreatedUserId = user.Id;
                lastCreatedUsername = user.Username;
                return;
            }
            if (saveResult.getErrors()[0].getStatusCode() != System.StatusCode.DUPLICATE_USERNAME) {
                throw new ApprovalException(
                    'Echec de la creation du compte portail: ' + saveResult.getErrors()[0].getMessage()
                );
            }
            n++;
        }
        throw new ApprovalException(
            'Impossible de generer un nom d\'utilisateur unique pour ce demandeur.'
        );
    }

    private static User buildPartnerUser(Access_Request__c request, Contact contact, Profile partnerProfile) {
        String email = request.Email__c;
        String firstName = request.First_Name__c;
        String lastName = String.isBlank(request.Last_Name__c) ? 'Partner' : request.Last_Name__c;
        String communityNickname = (email.substringBefore('@') + Math.mod(Crypto.getRandomLong().intValue(), 1000000)).left(40);
        return new User(
            FirstName = firstName,
            LastName = lastName,
            Alias = generateAlias(firstName, lastName),
            Email = email,
            CommunityNickname = communityNickname,
            ProfileId = partnerProfile.Id,
            ContactId = contact.Id,
            IsActive = true,
            TimeZoneSidKey = USER_TIMEZONE,
            LocaleSidKey = USER_LOCALE,
            LanguageLocaleKey = USER_LANGUAGE,
            EmailEncodingKey = 'UTF-8'
        );
    }

    private static String generateAlias(String firstName, String lastName) {
        String first = normalizePart(firstName);
        String last = normalizePart(lastName);
        if (String.isBlank(first)) {
            first = 'p';
        }
        if (String.isBlank(last)) {
            last = 'artner';
        }
        return (first.substring(0, 1) + last).left(8).toUpperCase();
    }

    @TestVisible
    static String buildUsernameForTest(String firstName, String lastName) {
        return buildUsername(firstName, lastName);
    }

    private static String buildUsername(String firstName, String lastName) {
        String first = normalizePart(firstName);
        String last = normalizePart(lastName);
        if (String.isBlank(first)) {
            first = 'partner';
        }
        if (String.isBlank(last)) {
            last = 'partner';
        }
        String local = first + '.' + last;
        Integer suffix = 1;
        String candidate = local + '@powershot.com';
        while (suffix < 10000) {
            if ([SELECT COUNT() FROM User WHERE Username = :candidate] == 0) {
                return candidate;
            }
            candidate = local + suffix + '@powershot.com';
            suffix++;
        }
        return local + '.' + Math.mod(Crypto.getRandomLong().intValue(), 99999) + '@powershot.com';
    }

    private static String normalizePart(String value) {
        if (String.isBlank(value)) {
            return '';
        }
        String v = value.trim().toLowerCase()
            .replace('à', 'a').replace('â', 'a').replace('ä', 'a')
            .replace('é', 'e').replace('è', 'e').replace('ê', 'e').replace('ë', 'e')
            .replace('î', 'i').replace('ï', 'i')
            .replace('ô', 'o').replace('ö', 'o')
            .replace('ù', 'u').replace('û', 'u').replace('ü', 'u')
            .replace('ç', 'c').replace('ñ', 'n');
        String out = '';
        for (String ch : v.split('')) {
            if (ch.isAlpha() || Pattern.matches('\\d', ch)) {
                out += ch;
            }
        }
        return out;
    }

    @AuraEnabled
    public static StatusResult deleteRequest(Id recordId) {
        StatusResult result = new StatusResult();
        if (recordId == null) {
            result.message = 'Parametres manquants (record).';
            return result;
        }
        List<Access_Request__c> records = [
            SELECT Id
            FROM Access_Request__c
            WHERE Id = :recordId
        ];
        if (records.isEmpty()) {
            result.message = 'Demande introuvable.';
            return result;
        }
        try {
            Database.delete(records[0], AccessLevel.SYSTEM_MODE);
            result.success = true;
        } catch (DmlException ex) {
            result.message = ex.getDmlMessage(0);
        }
        return result;
    }

    @AuraEnabled
    public static StatusResult saveComment(Id recordId, String comment) {
        StatusResult result = new StatusResult();
        if (recordId == null) {
            result.message = 'Parametres manquants (record).';
            return result;
        }
        List<Access_Request__c> records = [
            SELECT Id, Comments__c
            FROM Access_Request__c
            WHERE Id = :recordId
        ];
        if (records.isEmpty()) {
            result.message = 'Demande introuvable.';
            return result;
        }
        records[0].Comments__c = comment;
        try {
            Database.update(records[0], AccessLevel.SYSTEM_MODE);
            result.success = true;
        } catch (DmlException ex) {
            result.message = ex.getDmlMessage(0);
        }
        return result;
    }
}