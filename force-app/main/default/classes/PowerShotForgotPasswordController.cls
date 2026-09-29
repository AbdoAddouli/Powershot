public with sharing class PowerShotForgotPasswordController {

    /**
     * Déclenche l'envoi d'un lien de réinitialisation de mot de passe
     * via les mécanismes natifs Experience Cloud (Site.forgotPassword).
     *
     * Anti-énumération : on renvoie TOUJOURS un message générique, que le
     * compte existe ou non. Le LWC redirige vers la page "Check Email"
     * même quand isSent est false, afin de ne jamais confirmer l'existence
     * d'une adresse.
     *
     * @param email Adresse saisie par l'utilisateur.
     * @return ForgotPasswordResult contenant isSent et un message générique.
     */
    @AuraEnabled
    public static ForgotPasswordResult forgotPassword(String email) {
        ForgotPasswordResult result = new ForgotPasswordResult();
        String safeEmail = email == null ? '' : email.trim();

        if (safeEmail.isWhitespace()) {
            result.isSent = false;
            result.message = 'Please enter your work email address.';
            return result;
        }

        try {
            // Faux (adresse inconnue, throttling…) ou vrai : on renvoie pareil.
            result.isSent = Site.forgotPassword(safeEmail);
            result.message = 'If an account is associated with this address, a reset link has just been sent to you.';
        } catch (Exception ex) {
            result.isSent = false;
            result.message = 'We could not process your request. Please try again.';
        }
        return result;
    }

    public with sharing class ForgotPasswordResult {
        @AuraEnabled public Boolean isSent;
        @AuraEnabled public String message;
    }
}