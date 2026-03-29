import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _keyLoggedIn = 'loggedIn';
  static const _keyExpiry = 'expiry';
  static const _keyOnboarding = 'onboardingComplete';
  static const _keyPin = 'userPin';
  static const _keyContacts = 'sosContacts';
  static const _keyGpsConsent = 'gpsConsent';
  static const _keyBiometric = 'biometricEnabled';

  static Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now()
        .add(const Duration(days: 30))
        .millisecondsSinceEpoch;
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setInt(_keyExpiry, expiry);
  }

  static Future<bool> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_keyLoggedIn) ?? false;
    final expiry = prefs.getInt(_keyExpiry) ?? 0;
    if (!loggedIn) return false;
    if (DateTime.now().millisecondsSinceEpoch > expiry) {
      await clearSession();
      return false;
    }
    return true;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyExpiry);
  }

  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarding, true);
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboarding) ?? false;
  }

  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPin, pin);
  }

  static Future<String?> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPin);
  }

  static Future<void> saveContacts(List<String> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyContacts, contacts);
  }

  static Future<List<String>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyContacts) ?? [];
  }

  static Future<void> setGpsConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGpsConsent, value);
  }

  static Future<bool> getGpsConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGpsConsent) ?? false;
  }

  static Future<void> saveBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometric, value);
  }

  static Future<bool> getBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometric) ?? false;
  }
}
