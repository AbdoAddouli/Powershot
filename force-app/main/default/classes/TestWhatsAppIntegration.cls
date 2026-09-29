/**
 * TestWhatsAppIntegration
 * =======================
 * Tests the WhatsApp webhook endpoint (WhatsAppWebhookHandler) and its backing
 * service (WhatsAppMessageService): webhook verification handshake, HMAC
 * signature validation, message persistence, idempotency, Contact matching,
 * and E.164 phone normalization.
 */
@IsTest
public with sharing class TestWhatsAppIntegration {

    private static final String TEST_VERIFY_TOKEN = 'PowerShot_Verify_5';
    private static final String TEST_APP_SECRET = '3c21be88aa5a946abf475b445498d11f';

    // =========================================================================
    // Test data helpers
    // =========================================================================

    /** Creates the hierarchy custom setting the webhook reads its config from. */
    private static WhatsApp_Config__c createConfig() {
        WhatsApp_Config__c config = new WhatsApp_Config__c(
            SetupOwnerId = UserInfo.getUserId(),
            Verify_Token__c = TEST_VERIFY_TOKEN,
            App_Secret__c = TEST_APP_SECRET,
            Phone_Number_ID__c = '1292156103977471'
        );
        insert config;
        return config;
    }

    /**
     * Builds a realistic Meta webhook delivery JSON for a text message.
     * @param messageId  Unique message ID (drives idempotency)
     * @param fromPhone  Sender phone as reported by WhatsApp (E.164)
     * @param body  Message text body
     */
    private static String buildPayload(String messageId, String fromPhone, String body) {
        return JSON.serialize(new Map<String, Object>{
            'object' => 'whatsapp_business_account',
            'entry' => new List<Object>{
                new Map<String, Object>{
                    'id' => '1584532923379883',
                    'changes' => new List<Object>{
                        new Map<String, Object>{
                            'field' => 'messages',
                            'value' => new Map<String, Object>{
                                'messaging_product' => 'whatsapp',
                                'metadata' => new Map<String, Object>{
                                    'display_phone_number' => '+15551234567',
                                    'phone_number_id' => '1292156103977471'
                                },
                                'contacts' => new List<Object>{
                                    new Map<String, Object>{
                                        'profile' => new Map<String, Object>{ 'name' => 'John Doe' },
                                        'wa_id' => fromPhone
                                    }
                                },
                                'messages' => new List<Object>{
                                    new Map<String, Object>{
                                        'from' => fromPhone,
                                        'id' => messageId,
                                        'timestamp' => '1720000000',
                                        'type' => 'text',
                                        'text' => new Map<String, Object>{ 'body' => body }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        });
    }

    /** Computes the X-Hub-Signature-256 header value for a given body. */
    private static String signBody(String body, String appSecret) {
        Blob hmac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(body),
            Blob.valueOf(appSecret)
        );
        return 'sha256=' + EncodingUtil.convertToHex(hmac);
    }

    /** Runs the POST endpoint in an isolated REST context and returns its status. */
    private static Integer callPost(String body, String signature) {
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        if (String.isNotBlank(signature)) {
            req.addHeader('X-Hub-Signature-256', signature);
        }
        req.addHeader('Content-Type', 'application/json');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhookHandler.doPost();
        Test.stopTest();

        return res.statusCode;
    }

    // =========================================================================
    // Webhook verification (GET)
    // =========================================================================

    @IsTest
    static void testVerificationSuccess() {
        createConfig();

        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.params.put('hub.mode', 'subscribe');
        req.params.put('hub.verify_token', TEST_VERIFY_TOKEN);
        req.params.put('hub.challenge', 'challenge_abc_123');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhookHandler.doGet();
        Test.stopTest();

        Assert.areEqual(200, res.statusCode, 'Verification should succeed with correct token');
        Assert.areEqual(
            'challenge_abc_123',
            res.responseBody.toString(),
            'Handler should echo hub.challenge unquoted'
        );
    }

    @IsTest
    static void testVerificationRejectsWrongToken() {
        createConfig();

        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.params.put('hub.mode', 'subscribe');
        req.params.put('hub.verify_token', 'wrong-token');
        req.params.put('hub.challenge', 'challenge_abc_123');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhookHandler.doGet();
        Test.stopTest();

        Assert.areEqual(403, res.statusCode, 'Wrong verify token must fail closed');
    }

    // =========================================================================
    // Signature validation (POST)
    // =========================================================================

    @IsTest
    static void testPostRejectsInvalidSignature() {
        createConfig();
        String body = buildPayload('wamid.INVALID_SIG', '+15551234567', 'Hi');

        Integer status = callPost(body, 'sha256=deadbeef');
        Assert.areEqual(403, status, 'Tampered signature must be rejected');

        Assert.areEqual(
            0, [SELECT COUNT() FROM WhatsApp_Message__c],
            'No message should be stored when the signature is invalid'
        );
    }

    @IsTest
    static void testPostRejectsWhenNotConfigured() {
        String body = buildPayload('wamid.NO_CONFIG', '+15551234567', 'Hi');

        Integer status = callPost(body, signBody(body, TEST_APP_SECRET));
        Assert.areEqual(403, status, 'Missing app secret must fail closed');
    }

    // =========================================================================
    // Message persistence & Contact matching
    // =========================================================================

    @IsTest
    static void testPostInsertsMessageAndMatchesContact() {
        createConfig();

        Account acct = new Account(Name = 'WhatsApp Test Operator');
        insert acct;

        Contact contact = new Contact(
            AccountId = acct.Id,
            FirstName = 'John',
            LastName = 'Doe',
            Phone = '+15551234567'
        );
        insert contact;

        String body = buildPayload('wamid.CONTACT_MATCH', '+15551234567', 'Hello from WhatsApp');

        Integer status = callPost(body, signBody(body, TEST_APP_SECRET));
        Assert.areEqual(200, status, 'Valid delivery should be acknowledged');

        List<WhatsApp_Message__c> stored = [
            SELECT WhatsApp_Message_ID__c, Sender_Phone__c, Sender_Name__c,
                   Message_Body__c, Message_Type__c, Direction__c, Status__c,
                   Timestamp__c, Contact__c, Account__c
            FROM WhatsApp_Message__c
        ];
        Assert.areEqual(1, stored.size(), 'One message should be stored');

        WhatsApp_Message__c message = stored[0];
        Assert.areEqual('wamid.CONTACT_MATCH', message.WhatsApp_Message_ID__c);
        Assert.areEqual('+15551234567', message.Sender_Phone__c);
        Assert.areEqual('John Doe', message.Sender_Name__c);
        Assert.areEqual('Hello from WhatsApp', message.Message_Body__c);
        Assert.areEqual('Text', message.Message_Type__c);
        Assert.areEqual('Inbound', message.Direction__c);
        Assert.areEqual(contact.Id, message.Contact__c, 'Contact should be linked by phone');
        Assert.areEqual(acct.Id, message.Account__c, 'Account should be resolved via Contact');
        Assert.isNotNull(message.Timestamp__c, 'Unix timestamp should convert to DateTime');
    }

    @IsTest
    static void testPostSkipsDuplicateMessageId() {
        createConfig();

        // Pre-existing message with the same Meta message ID (from a prior retry).
        insert new WhatsApp_Message__c(
            WhatsApp_Message_ID__c = 'wamid.DUPLICATE',
            Sender_Phone__c = '+15551234567',
            Direction__c = 'Inbound',
            Status__c = 'Delivered'
        );

        String body = buildPayload('wamid.DUPLICATE', '+15551234567', 'Retry delivery');

        Integer status = callPost(body, signBody(body, TEST_APP_SECRET));
        Assert.areEqual(200, status, 'Duplicate delivery should still be acknowledged');

        Assert.areEqual(
            1, [SELECT COUNT() FROM WhatsApp_Message__c],
            'Re-delivered message ID must not create a second record (idempotency)'
        );
    }

    // =========================================================================
    // Phone normalization
    // =========================================================================

    @IsTest
    static void testNormalizePhoneVariants() {
        Assert.areEqual('+15551234567', WhatsAppMessageService.normalizePhone('(555) 123-4567'));
        Assert.areEqual('+15551234567', WhatsAppMessageService.normalizePhone('5551234567'));
        Assert.areEqual('+33123456789', WhatsAppMessageService.normalizePhone('+33 1 23 45 67 89'));
        Assert.areEqual('+212612345678', WhatsAppMessageService.normalizePhone('+212-612-345678'));
        Assert.areEqual('', WhatsAppMessageService.normalizePhone(''));
        Assert.areEqual('', WhatsAppMessageService.normalizePhone(null));
    }
}
