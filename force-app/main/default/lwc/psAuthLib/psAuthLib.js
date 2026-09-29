const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_PATTERN = /^[0-9+()\-\s]{7,20}$/;

export function isRequired(value) {
  return Boolean(value && String(value).trim());
}

export function isValidEmail(value) {
  return EMAIL_PATTERN.test(String(value || "").trim());
}

export function isValidPhone(value) {
  if (!value) return true;
  return PHONE_PATTERN.test(String(value).trim());
}

export function firstErrorMessage(errors) {
  const keys = Object.keys(errors);
  return keys.length > 0 ? errors[keys[0]] : "";
}

export function sleep(ms) {
  // Ce helper est un placeholder temporaire en attendant le vrai appel Apex.
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, ms));
}