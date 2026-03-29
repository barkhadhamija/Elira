import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static String? _verificationId;

  /// Sends an OTP to [phoneNumber].
  ///
  /// Callbacks:
  /// - [onCodeSent]     : SMS was sent; show OTP input screen.
  /// - [onAutoVerified] : Firebase silently verified the number (cached cred /
  ///                      instant verification). User is already signed in —
  ///                      navigate to the next screen directly; no OTP needed.
  /// - [onError]        : Verification failed with a human-readable message.
  static Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function() onAutoVerified,
    // code = FirebaseAuthException.code, message = human-readable description
    required Function(String code, String message) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _auth.signInWithCredential(credential);
          onAutoVerified();
        } catch (_) {}
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.code, e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  static Future<bool> verifyOtp(String otp) async {
    try {
      if (_verificationId == null) return false;
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _auth.signInWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
  static String? get currentUid => _auth.currentUser?.uid;

  /// Returns true only when BOTH the local session flag and the Firebase
  /// Auth token are valid. This prevents stale SharedPreferences from
  /// letting an unauthenticated user through.
  static bool get isFirebaseSignedIn => _auth.currentUser != null;
}
