/**
 * WhatsAppMessageService
 * ======================
 * Parses inbound Meta WhatsApp Cloud API webhook payloads and persists them as
 * WhatsApp_Message__c records. Handles idempotency (duplicate message IDs),
 * E.164 phone normalization, and Contact matching — all in a bulk-safe way
 * so a single webhook delivery stays comfortably within Apex governor limits.
 *
 * Business Process: WhatsApp Integration (Customer Engagement)
 *   Meta Webhook POST → Payload Parse → Idempotency Check → Phone Normalization
 *   → Contact Match → WhatsApp_Message__c Insert → HTTP 200 Acknowledgment
 *
 * Governor-limit safeguards:
 *   - One SOQL query for the idempotency lookup (IN clause on message IDs)
 *   - One SOQL query for Contact matching (IN clause on normalized phones)
 *   - A single bulk DML insert for all messages in the payload
 *   - Payload size capped per request; malformed fields degrade gracefully
 */
public without sharing class WhatsAppMessageService {

    /** Safety cap on messages processed in a single webhook request. */
    private static final Integer MAX_MESSAGES_PER_REQUEST = 50;

    /** Default country code (1 = US) applied to 10-digit numbers with no prefix. */
    private static final String DEFAULT_COUNTRY_CODE = '1';

    /**
     * Result of processing one webhook payload. Returned to the REST handler so
     * it can acknowledge Meta without exposing internal errors.
     */
    public class IngestionResult {
        public Integer insertedCount = 0;
        public Integer duplicateCount = 0;
        public String error;
    }

    /**
     * Parses the raw JSON body of a Meta webhook delivery and stores every new
     * inbound message. Existing message IDs are skipped (idempotency), so Meta's
     * automatic retries can never create duplicate records.
     *
     * @param jsonPayload  The raw request body from Meta
     * @return  IngestionResult with insert/duplicate counts (never throws)
     */
    public static IngestionResult handlePayload(String jsonPayload) {
        IngestionResult result = new IngestionResult();

        if (String.isBlank(jsonPayload)) {
            result.error = 'Empty payload';
            return result;
        }

        try {
            // 'from' and 'object' are Apex reserved words, so remap those JSON
            // keys before deserializing. Bare quoted keys only match actual
            // object keys, never string values (those keep escaped quotes).
            String safePayload = jsonPayload
                .replaceAll('"from"', '"fromNumber"')
                .replaceAll('"object"', '"objectValue"');

            WhatsAppWebhookPayload payload = (WhatsAppWebhookPayload)
                JSON.deserialize(safePayload, WhatsAppWebhookPayload.class);

            List<MessageInfo> messages = collectMessages(payload);
            if (messages.isEmpty()) {
                return result; // Not a message delivery (status update, etc.)
            }

            // Cap the number of messages to stay well inside governor limits.
            if (messages.size() > MAX_MESSAGES_PER_REQUEST) {
                List<MessageInfo> capped = new List<MessageInfo>();
                for (Integer i = 0; i < MAX_MESSAGES_PER_REQUEST; i++) {
                    capped.add(messages.get(i));
                }
                messages = capped;
            }

            Map<String, String> senderNamesByWaId = collectSenderNames(payload);

            // Single idempotency lookup: exclude IDs already persisted.
            Set<String> incomingIds = new Set<String>();
            for (MessageInfo message : messages) {
                incomingIds.add(message.id);
            }
            Set<String> existingMessageIds = new Set<String>();
            for (WhatsApp_Message__c existing : [
                SELECT WhatsApp_Message_ID__c
                FROM WhatsApp_Message__c
                WHERE WhatsApp_Message_ID__c IN :incomingIds
            ]) {
                existingMessageIds.add(existing.WhatsApp_Message_ID__c);
            }

            // Build records and the set of phones to resolve against Contacts.
            List<WhatsApp_Message__c> records = new List<WhatsApp_Message__c>();
            Set<String> phonesToMatch = new Set<String>();
            for (MessageInfo message : messages) {
                if (existingMessageIds.contains(message.id)) {
                    result.duplicateCount++;
                    continue;
                }

                String phone = normalizePhone(message.fromNumber);
                phonesToMatch.add(phone);

                records.add(new WhatsApp_Message__c(
                    WhatsApp_Message_ID__c = message.id,
                    Sender_Phone__c = phone,
                    Sender_Name__c = senderNamesByWaId.get(message.fromNumber),
                    Message_Body__c = extractBody(message),
                    Message_Type__c = message.type,
                    Direction__c = 'Inbound',
                    Status__c = 'Delivered',
                    Timestamp__c = toDateTime(message.timestamp),
                    Raw_Payload__c = jsonPayload
                ));
            }

            if (records.isEmpty()) {
                return result;
            }

            // Single Contact lookup for all phones, then link matches.
            Map<String, Contact> contactsByPhone = matchContacts(phonesToMatch);
            for (WhatsApp_Message__c record : records) {
                Contact contact = contactsByPhone.get(record.Sender_Phone__c);
                if (contact != null) {
                    record.Contact__c = contact.Id;
                    record.Account__c = contact.AccountId;
                }
            }

            insert records;
            result.insertedCount = records.size();

        } catch (Exception e) {
            // Never let a malformed payload bubble up: Meta would retry forever.
            // Log the root cause and let the handler still acknowledge the delivery.
            result.error = e.getMessage();
            System.debug(LoggingLevel.ERROR,
                'WhatsApp payload processing failed: ' + e.getMessage());
        }

        return result;
    }

    /**
     * Normalizes a phone number to E.164 format (+<country><number>).
     * Strips spaces, dashes, parentheses and dots; preserves a leading '+'.
     * A 10-digit number with no country prefix gets the default US country code.
     *
     * @param rawPhone  The phone as reported by WhatsApp / stored on a Contact
     * @return  Normalized E.164 phone string, or '' when input is blank
     */
    public static String normalizePhone(String rawPhone) {
        if (String.isBlank(rawPhone)) {
            return '';
        }

        String digitsOnly = rawPhone.replaceAll('[^0-9]', '');

        if (digitsOnly.length() == 10 && !rawPhone.startsWith('+')) {
            digitsOnly = DEFAULT_COUNTRY_CODE + digitsOnly;
        }

        return '+' + digitsOnly;
    }

    /**
     * Resolves a set of normalized E.164 phones to Contacts in one bulk query.
     * Matches against both Phone and MobilePhone, keyed by the normalized value
     * so the caller can look up by Sender_Phone__c.
     *
     * @param phones  Set of normalized E.164 phone strings
     * @return  Map of normalized phone → first matching Contact
     */
    public static Map<String, Contact> matchContacts(Set<String> phones) {
        Map<String, Contact> contactsByPhone = new Map<String, Contact>();

        if (phones == null || phones.isEmpty()) {
            return contactsByPhone;
        }

        for (Contact contact : [
            SELECT Id, AccountId, Phone, MobilePhone
            FROM Contact
            WHERE Phone IN :phones
                OR MobilePhone IN :phones
            LIMIT 50000
        ]) {
            String phone = normalizePhone(contact.Phone);
            if (phones.contains(phone) && !contactsByPhone.containsKey(phone)) {
                contactsByPhone.put(phone, contact);
            }

            String mobile = normalizePhone(contact.MobilePhone);
            if (phones.contains(mobile) && !contactsByPhone.containsKey(mobile)) {
                contactsByPhone.put(mobile, contact);
            }
        }

        return contactsByPhone;
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    /**
     * Flattens all messages across entries/changes/values in the payload.
     * Non-message deliveries (e.g. status updates) yield an empty list.
     */
    private static List<MessageInfo> collectMessages(WhatsAppWebhookPayload payload) {
        List<MessageInfo> messages = new List<MessageInfo>();

        if (payload == null || payload.entry == null) {
            return messages;
        }

        for (Entry entry : payload.entry) {
            if (entry.changes == null) {
                continue;
            }
            for (Change change : entry.changes) {
                if (change.value != null && change.value.messages != null) {
                    messages.addAll(change.value.messages);
                }
            }
        }

        return messages;
    }

    /**
     * Maps WhatsApp sender IDs (wa_id) to their profile names from the payload's
     * contacts array, so Sender_Name__c can be populated per message.
     */
    private static Map<String, String> collectSenderNames(WhatsAppWebhookPayload payload) {
        Map<String, String> senderNames = new Map<String, String>();

        if (payload == null || payload.entry == null) {
            return senderNames;
        }

        for (Entry entry : payload.entry) {
            if (entry.changes == null) {
                continue;
            }
            for (Change change : entry.changes) {
                if (change.value == null || change.value.contacts == null) {
                    continue;
                }
                for (ContactInfo contact : change.value.contacts) {
                    if (contact.profile != null && String.isNotBlank(contact.wa_id)) {
                        senderNames.put(contact.wa_id, contact.profile.name);
                    }
                }
            }
        }

        return senderNames;
    }

    /** Extracts the visible text body for a message, with a graceful fallback. */
    private static String extractBody(MessageInfo message) {
        if (message.text != null && String.isNotBlank(message.text.body)) {
            return message.text.body;
        }
        return '[' + message.type + ' message]';
    }

    /**
     * Converts a WhatsApp Unix timestamp (seconds since epoch, UTC) to a
     * Salesforce DateTime. Returns null for blank or malformed input.
     */
    private static DateTime toDateTime(String unixTimestamp) {
        if (String.isBlank(unixTimestamp)) {
            return null;
        }

        try {
            return DateTime.newInstance(Long.valueOf(unixTimestamp) * 1000);
        } catch (Exception e) {
            return null;
        }
    }

    // =========================================================================
    // Strongly-typed payload model (matches Meta WhatsApp Cloud API JSON shape)
    // =========================================================================

    private class WhatsAppWebhookPayload {
        public String objectValue;
        public List<Entry> entry;
    }

    private class Entry {
        public String id;
        public List<Change> changes;
    }

    private class Change {
        public String field;
        public Value value;
    }

    private class Value {
        public String messaging_product;
        public Metadata metadata;
        public List<ContactInfo> contacts;
        public List<MessageInfo> messages;
    }

    private class Metadata {
        public String display_phone_number;
        public String phone_number_id;
    }

    private class ContactInfo {
        public Profile profile;
        public String wa_id;
    }

    private class Profile {
        public String name;
    }

    private class MessageInfo {
        public String fromNumber;
        public String id;
        public String timestamp;
        public String type;
        public TextBody text;
    }

    private class TextBody {
        public String body;
    }
}
