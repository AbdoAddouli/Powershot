/**
 * WhatsAppWebhookHandler
 * ======================
 * REST webhook endpoint consumed by Meta's WhatsApp Cloud API.
 *
 *   GET  /services/apexrest/whatsapp/webhook  → webhook verification handshake
 *   POST /services/apexrest/whatsapp/webhook  → receive inbound messages
 *
 * Security model:
 *   - The GET verification succeeds only when hub.verify_token matches
 *     WhatsApp_Config__c.Verify_Token__c (fail closed otherwise).
 *   - Every POST payload is authenticated via the X-Hub-Signature-256 header,
 *     an HMAC-SHA256 of the raw body signed with WhatsApp_Config__c.App_Secret__c.
 *     The guest site profile therefore needs NO object access — the class runs
 *     `without sharing` solely so the unauthenticated webhook can persist records
 *     whose authenticity is enforced by the signature, not by the guest profile.
 *   - Meta requires a fast (<5s) acknowledgment. The handler always answers 200
 *     for valid deliveries so Meta stops retrying; business errors are logged.
 *
 * Business Process: WhatsApp Integration (Customer Engagement)
 *   Meta Verifies Webhook (GET) → Meta Delivers Message (POST)
 *   → Signature Validation → WhatsAppMessageService → HTTP 200
 */
@RestResource(urlMapping='/whatsapp/webhook')
global without sharing class WhatsAppWebhookHandler {

    /** Header Meta sends with each delivery: sha256=<hex HMAC of raw body>. */
    private static final String SIGNATURE_HEADER = 'X-Hub-Signature-256';
    private static final String SHA256_ALGORITHM = 'HmacSHA256';
    private static final String VERIFY_MODE = 'subscribe';

    /**
     * GET handler — completes Meta's webhook verification handshake.
     * Meta calls this with hub.mode=subscribe, hub.verify_token=<token> and
     * hub.challenge=<random string>. A matching token echoes the challenge back
     * with 200; anything else returns 403 so the webhook is never activated.
     *
     * The challenge is written to the response body as raw bytes — never returned
     * as a String (which Apex REST would JSON-quote, e.g. "12345" instead of 12345,
     * and Meta would reject).
     */
    @HttpGet
    global static void doGet() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;

        String mode = request.params.get('hub.mode');
        String verifyToken = request.params.get('hub.verify_token');
        String challenge = request.params.get('hub.challenge');

        WhatsApp_Config__c config = WhatsApp_Config__c.getInstance();

        if (VERIFY_MODE.equals(mode)
            && String.isNotBlank(verifyToken)
            && config != null
            && verifyToken.equals(config.Verify_Token__c)) {
            response.statusCode = 200;
            response.responseBody = Blob.valueOf(challenge);
            return;
        }

        // Fail closed: never reveal whether the token was wrong or unconfigured.
        response.statusCode = 403;
        response.responseBody = Blob.valueOf('Verification failed.');
    }

    /**
     * POST handler — receives and persists inbound WhatsApp messages.
     * Validates the HMAC signature first, then delegates parsing/persistence to
     * WhatsAppMessageService, and always acknowledges with 200 for valid
     * deliveries so Meta stops retrying.
     *
     * @return  JSON summary for debugging (inserted/duplicate counts)
     */
    @HttpPost
    global static String doPost() {
        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;

        String rawBody = request.requestBody == null ? '' : request.requestBody.toString();

        WhatsApp_Config__c config = WhatsApp_Config__c.getInstance();

        // Fail closed if signature validation cannot run (not configured yet).
        if (config == null || String.isBlank(config.App_Secret__c)) {
            response.statusCode = 403;
            return 'Signature validation not configured.';
        }

        String signature = request.headers.get(SIGNATURE_HEADER);
        if (String.isBlank(signature)
            || !isSignatureValid(signature, rawBody, config.App_Secret__c)) {
            response.statusCode = 403;
            return 'Invalid signature.';
        }

        WhatsAppMessageService.IngestionResult result =
            WhatsAppMessageService.handlePayload(rawBody);

        // Always acknowledge: a 200 tells Meta the delivery was consumed, which
        // prevents infinite retry loops. Processing errors are in the logs.
        response.statusCode = 200;
        return JSON.serialize(new Map<String, Object>{
            'status' => 'received',
            'inserted' => result.insertedCount,
            'duplicates' => result.duplicateCount
        });
    }

    /**
     * Validates the X-Hub-Signature-256 header against an HMAC-SHA256 of the
     * raw request body computed with the configured app secret. The comparison
     * is constant-time-ish via full-string equality on the hex digest.
     *
     * @param signature  The raw header value, e.g. "sha256=<hex>"
     * @param body  The exact request body bytes as a string
     * @param appSecret  The Meta app secret from WhatsApp_Config__c
     * @return  true when the signature matches, false otherwise
     */
    private static Boolean isSignatureValid(String signature, String body, String appSecret) {
        Blob hmacDigest = Crypto.generateMac(
            SHA256_ALGORITHM,
            Blob.valueOf(body),
            Blob.valueOf(appSecret)
        );

        String expected = 'sha256=' + EncodingUtil.convertToHex(hmacDigest);
        return expected.equalsIgnoreCase(signature.trim());
    }
}
