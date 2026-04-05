import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _keyLoggedIn = 'loggedIn';
  static const _keyExpiry = 'expiry';
  static const _keyOnboarding = 'onboardingComplete';
  static const _keyPin = 'userPin';
  static const _keyContacts = 'sosContacts';
  static const _keyGpsConsent = 'gpsConsent';
  static const _keyBiometric = 'biometricEnabled';
  static const _keyUserId = 'userId';
  static const _keyUserPhone = 'userPhone';
  static const _keyUserEmail = 'userEmail';
  static const _keyUserName = 'userName';
  static const _keyThemeMode = 'themeMode';

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
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyThemeMode);
  }

  /// ⚠️ DEV ONLY — wipes every key the app persists.
  /// Call once at startup to force a fresh onboarding flow, then remove.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyExpiry);
    await prefs.remove(_keyOnboarding);
    await prefs.remove(_keyPin);
    await prefs.remove(_keyContacts);
    await prefs.remove(_keyGpsConsent);
    await prefs.remove(_keyBiometric);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyThemeMode);
  }

  static Future<void> saveUserProfile({
    required String userId,
    required String phone,
    required String email,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyUserPhone, phone);
    await prefs.setString(_keyUserEmail, email);
    if (name != null && name.trim().isNotEmpty) {
      await prefs.setString(_keyUserName, name.trim());
    }
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserPhone);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<void> saveThemeMode(String themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, themeMode);
  }

  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'light';
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
