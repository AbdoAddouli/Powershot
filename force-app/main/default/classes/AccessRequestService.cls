public with sharing class AccessRequestService {

    public with sharing class SubmitResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message = '';
        @AuraEnabled public Id recordId;
    }

    @AuraEnabled
    public static SubmitResult submitRequest(
        String firstName,
        String lastName,
        String email,
        String company,
        String requestedProfile,
        String comments
    ) {
        SubmitResult result = new SubmitResult();
        result.success = false;

        String safeLastName = lastName == null ? '' : lastName.trim();
        String safeEmail = email == null ? '' : email.trim();

        if (safeLastName == '' || safeEmail == '') {
            result.message = 'Le nom et l\'email sont obligatoires.';
            return result;
        }

        if (!safeEmail.contains('@')) {
            result.message = 'Adresse email invalide.';
            return result;
        }

        String safeRequestedProfile = String.isBlank(requestedProfile)
            ? 'Partner Community User'
            : requestedProfile;

        try {
            Access_Request__c request = new Access_Request__c(
                First_Name__c = firstName == null ? '' : firstName.trim(),
                Last_Name__c = safeLastName,
                Email__c = safeEmail,
                Company__c = String.isBlank(company) ? null : company.trim(),
                Requested_Profile__c = safeRequestedProfile,
                Comments__c = comments,
                Status__c = 'New'
            );
            insert request;
            result.success = true;
            result.recordId = request.Id;
        } catch (DmlException ex) {
            result.message = ex.getDmlMessage(0);
        } catch (System.SecurityException ex) {
            result.message =
                'Vous n\'avez pas les droits suffisants pour créer une demande ' +
                'sur Access_Request__c (Vérifiez les permissions du guest profile).';
        }
        return result;
    }
}