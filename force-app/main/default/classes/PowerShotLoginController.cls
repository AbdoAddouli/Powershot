public with sharing class PowerShotLoginController {

    @AuraEnabled
    public static LoginResult login(String username, String password, String startUrl) {
        LoginResult result = new LoginResult();
        String safeUsername = username == null ? '' : username.trim();
        String safePassword = password == null ? '' : password;
        String safeStartUrl = (startUrl == null || startUrl.isWhitespace()) ? '' : startUrl.trim();

        // Garde : identifiants vides -> échec immédiat, sans appeler Site.login
        // (qui, hors contexte communauté, peut renvoyer une PageReference sans
        // vérifier les identifiants au lieu de lever une exception).
        if (safeUsername == '' || safePassword == '') {
            result.isLoggedIn = false;
            result.message = 'Please enter your username and password.';
            return result;
        }

        try {
            ApexPages.PageReference pageRef = Site.login(safeUsername, safePassword, safeStartUrl);
            // Site.login renvoie null quand la session est établie sans redirection immédiate,
            // ou une PageReference de redirection. Une exception (identifiants invalides,
            // compte bloqué, hors site) est traitée comme un échec ci-dessous.
            result.isLoggedIn = true;
            result.redirectUrl = pageRef == null ? null : pageRef.getUrl();
        } catch (Exception ex) {
            result.isLoggedIn = false;
            result.message = 'Invalid username or password. Please try again.';
        }
        return result;
    }

    @AuraEnabled
    public static Boolean isAuthenticated() {
        return UserInfo.getUserType() != 'Guest';
    }

    /**
     * Invalide la session Experience Cloud et renvoie l'URL de logout.
     * Pas de méthode Site.logout() en Apex : on redirige vers l'URL de
     * logout du site (Network.getLogoutUrl, doc officielle LWR). Le LWC
     * fait un window.location.assign pour un déchargement complet.
     */
    @AuraEnabled
    public static String logout() {
        try {
            Id networkId = Network.getNetworkId();
            if (networkId != null) {
                String logoutUrl = Network.getLogoutUrl(networkId);
                if (String.isNotBlank(logoutUrl)) {
                    return logoutUrl;
                }
            }
        } catch (Exception ex) {
            // Hors contexte communauté : on bascule sur l'URL classique.
        }
        return '/secur/logout.jsp';
    }

    public with sharing class LoginResult {
        @AuraEnabled public Boolean isLoggedIn;
        @AuraEnabled public String message;
        @AuraEnabled public String redirectUrl;
    }
}