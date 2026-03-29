import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  /// Returns true if the device has biometric hardware (Face ID, Touch ID,
  /// fingerprint). Does NOT require biometrics to be enrolled — use this
  /// for the onboarding setup screen so users can opt-in even if they
  /// haven't enrolled yet.
  static Future<bool> isHardwareSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  /// Returns true if biometrics are enrolled AND the device supports them.
  /// Use this at the PIN screen to decide whether to show the biometric prompt.
  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final enrolled = await _auth.canCheckBiometrics;
      return enrolled;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to access your testimonies',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}
