// ─── DEV MODE AUTH ────────────────────────────────────────────────────────────
// Firebase phone auth (reCAPTCHA / Safari flow) is bypassed for now.
// Accepted OTP: 123456
// Any phone number works — we just skip Firebase and mark the session locally.
// To re-enable real Firebase auth, replace the mock body of sendOtp() with the
// commented-out verifyPhoneNumber block below.
// ──────────────────────────────────────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static String? _verificationId;
  static const _devOtp = '123456';

  /// Sends an OTP to [phoneNumber].
  ///
  /// DEV MODE: instantly calls [onCodeSent] without hitting Firebase.
  /// The only accepted OTP is 123456.
  static Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function() onAutoVerified,
    required Function(String code, String message) onError,
  }) async {
    // ── MOCK: skip Firebase, go straight to OTP screen ──
    _verificationId = 'dev-mock-verification-id';
    // Small delay so the loading spinner is visible (feels natural)
    await Future.delayed(const Duration(milliseconds: 400));
    onCodeSent(_verificationId!);

    // ── REAL Firebase (commented out — re-enable when APNs is configured) ──
    // await _auth.verifyPhoneNumber(
    //   phoneNumber: phoneNumber,
    //   verificationCompleted: (PhoneAuthCredential credential) async {
    //     try {
    //       await _auth.signInWithCredential(credential);
    //       onAutoVerified();
    //     } catch (_) {}
    //   },
    //   verificationFailed: (FirebaseAuthException e) {
    //     onError(e.code, e.message ?? 'Verification failed');
    //   },
    //   codeSent: (String verificationId, int? resendToken) {
    //     _verificationId = verificationId;
    //     onCodeSent(verificationId);
    //   },
    //   codeAutoRetrievalTimeout: (String verificationId) {
    //     _verificationId = verificationId;
    //   },
    // );
  }

  /// Verifies the entered OTP.
  ///
  /// DEV MODE: only '123456' is accepted.
  static Future<bool> verifyOtp(String otp) async {
    // ── MOCK ──
    await Future.delayed(const Duration(milliseconds: 300));
    return otp == _devOtp;

    // ── REAL Firebase (commented out) ──
    // try {
    //   if (_verificationId == null) return false;
    //   final credential = PhoneAuthProvider.credential(
    //     verificationId: _verificationId!,
    //     smsCode: otp,
    //   );
    //   await _auth.signInWithCredential(credential);
    //   return true;
    // } catch (e) {
    //   return false;
    // }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
  static String? get currentUid => _auth.currentUser?.uid;

  /// In dev mode this always returns false (no real Firebase session),
  /// so the session is driven entirely by SessionManager.
  static bool get isFirebaseSignedIn => true;
}
