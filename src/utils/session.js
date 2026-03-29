const SESSION_KEY = "elira_session";
const ONBOARDING_KEY = "elira_onboarding_complete";
const PIN_KEY = "elira_pin";
const CONTACTS_KEY = "elira_contacts";

function jssaveSession() {
  const expiry = Date.now() + 30 * 24 * 60 * 60 * 1000; // 30 days
  const payload = { loggedIn: true, expiry };
  localStorage.setItem(SESSION_KEY, JSON.stringify(payload));
  return payload;
}

function getSession() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed.expiry !== "number") return null;
    if (parsed.expiry <= Date.now()) return null;
    return parsed;
  } catch {
    return null;
  }
}

function clearSession() {
  localStorage.removeItem(SESSION_KEY);
}

function setOnboardingComplete() {
  localStorage.setItem(ONBOARDING_KEY, "true");
}

function isOnboardingComplete() {
  return localStorage.getItem(ONBOARDING_KEY) === "true";
}

function savePIN(pin) {
  if (typeof pin !== "string") return;
  const normalized = pin.replace(/\D/g, "");
  if (normalized.length !== 4) return;
  localStorage.setItem(PIN_KEY, normalized);
}

function getPin() {
  const pin = localStorage.getItem(PIN_KEY);
  if (!pin) return null;
  const normalized = pin.replace(/\D/g, "");
  return normalized.length === 4 ? normalized : null;
}

function saveContacts(arr) {
  const payload = Array.isArray(arr) ? arr : [];
  localStorage.setItem(CONTACTS_KEY, JSON.stringify(payload));
}

function getContacts() {
  try {
    const raw = localStorage.getItem(CONTACTS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export {
  jssaveSession,
  getSession,
  clearSession,
  setOnboardingComplete,
  isOnboardingComplete,
  savePIN,
  getPin,
  saveContacts,
  getContacts,
};
