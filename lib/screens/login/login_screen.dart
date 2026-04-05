// TESTING: Add test phone numbers in Firebase Console →
// Authentication → Sign-in method → Phone → Scroll to
// "Phone numbers for testing". Add +919900000999 with OTP 123456
// This avoids burning real SMS during development.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../main.dart' show SosModal;
import '../../theme/app_colours.dart';
import '../../utils/session_manager.dart';
import '../../services/auth_service.dart';
import '../../services/backend_api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _step = 1;
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  Future<void> _ensureBackendRegistration(String fullNumber) async {
    final digits = fullNumber.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    final email = 'user$digits@elira.local';
    final name = 'Elira User $last4';
    const password = 'elira_dev_pass_123';

    try {
      final response = await BackendApiService.registerCitizen(
        name: name,
        email: email,
        password: password,
        phone: fullNumber,
      );

      final data =
          response['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final userId = (data['id'] ?? digits).toString();
      final backendName = data['name'];
      final resolvedName =
          backendName is String && backendName.trim().isNotEmpty
          ? backendName.trim()
          : name;
      await SessionManager.saveUserProfile(
        userId: userId,
        phone: fullNumber,
        email: email,
        name: resolvedName,
      );
      return;
    } catch (e) {
      final message = e.toString();
      if (!message.contains('Email already registered')) {
        rethrow;
      }
    }

    await SessionManager.saveUserProfile(
      userId: digits,
      phone: fullNumber,
      email: email,
      name: name,
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _onContinue() async {
    final digits = _phoneController.text.trim();
    if (digits.length < 10) return;
    setState(() => _isLoading = true);

    final fullNumber = '+91$digits';

    AuthService.sendOtp(
      phoneNumber: fullNumber,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _step = 2;
        });
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _otpFocusNodes[0].requestFocus();
        });
      },
      onAutoVerified: () async {
        if (!mounted) return;
        try {
          await _ensureBackendRegistration(fullNumber);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Local backend not reachable. Start backend and try again.',
                ),
                backgroundColor: AppColours.dangerRed,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
        await SessionManager.saveSession();
        if (!mounted) return;
        final onboardingDone = await SessionManager.isOnboardingComplete();
        if (!mounted) return;
        setState(() => _isLoading = false);
        context.go(onboardingDone ? '/pin' : '/onboarding');
      },
      onError: (code, message) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        final display = code.isNotEmpty ? '[$code] $message' : message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(display),
            backgroundColor: AppColours.dangerRed,
            duration: const Duration(seconds: 6),
          ),
        );
      },
    );
  }

  Future<void> _onOtpComplete() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) return;
    setState(() => _isLoading = true);

    final success = await AuthService.verifyOtp(otp);
    if (!mounted) return;

    if (success) {
      final fullNumber = '+91${_phoneController.text.trim()}';
      try {
        await _ensureBackendRegistration(fullNumber);
      } catch (_) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Local backend not reachable. Start backend and try again.',
            ),
            backgroundColor: AppColours.dangerRed,
          ),
        );
        return;
      }
      await SessionManager.saveSession();
      if (!mounted) return;
      final onboardingDone = await SessionManager.isOnboardingComplete();
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go(onboardingDone ? '/pin' : '/onboarding');
    } else {
      setState(() => _isLoading = false);
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes[0].requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid OTP. Please try again.'),
          backgroundColor: AppColours.dangerRed,
        ),
      );
    }
  }

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length == 6) _onOtpComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.surface,
      body: SafeArea(child: _step == 1 ? _buildStep1() : _buildStep2()),
    );
  }

  // ── SPLASH / LEFT PANEL (step 1 — enter phone) ────────────────────────────
  Widget _buildStep1() {
    return Column(
      children: [
        // Top bar: ELIRA logo + SOS
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    color: AppColours.brandBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ELIRA',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColours.brandBlue,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              _SOSButton(),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 36),

                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'SECURE ACCESS NODE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColours.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Heading
                Text(
                  'Initialize Session',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColours.textDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter your registered mobile credentials to access\nthe forensic vault.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColours.textMuted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),

                // Phone number card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColours.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColours.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PHONE NUMBER',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColours.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColours.inputFill,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E8EC),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                '+91',
                                style: GoogleFonts.inter(
                                  color: AppColours.textDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                maxLength: 10,
                                style: GoogleFonts.inter(
                                  color: AppColours.textDark,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '98765 43210',
                                  hintStyle: GoogleFonts.inter(
                                    color: AppColours.textMuted,
                                    fontSize: 15,
                                  ),
                                  filled: false,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColours.brandBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(double.infinity, 54),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continue',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Verification label
                Text(
                  'VERIFICATION REQUIRED',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColours.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Encrypted Gateway info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColours.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColours.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColours.accentLavenderSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          color: AppColours.brandBlue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Encrypted Gateway',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColours.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'All sessions are audited and recorded for compliance and security forensics.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColours.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Demo Login
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
                          await SessionManager.saveSession();
                          if (!mounted) return;
                          final onboardingDone =
                              await SessionManager.isOnboardingComplete();
                          if (!mounted) return;
                          setState(() => _isLoading = false);
                          context.go(onboardingDone ? '/pin' : '/onboarding');
                        },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login, color: AppColours.brandBlue, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Demo Login',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColours.brandBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'VERSION 4.2.0-aForensic | Architecture Tier 1',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: AppColours.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 32),

                // Footer divider + copyright
                Container(height: 1, color: AppColours.divider),
                const SizedBox(height: 12),
                Text(
                  'ELIRA is a registered trademark of Forensic Systems Corp. © 2024',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppColours.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── OTP STEP ─────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    color: AppColours.brandBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ELIRA',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColours.brandBlue,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              _SOSButton(),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 48),
                Text(
                  'Verify Your Number',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColours.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to\n+91 ${_phoneController.text.trim()}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColours.textMuted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                // Dev hint
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Text(
                    '🔧 Dev mode — use OTP: 123456',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 46,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _otpControllers[i],
                        focusNode: _otpFocusNodes[i],
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColours.textDark,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          filled: true,
                          fillColor: AppColours.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColours.brandBlue,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (val) => _onOtpChanged(val, i),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),
                if (_isLoading)
                  CircularProgressIndicator(color: AppColours.brandBlue),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() {
                    _step = 1;
                    for (final c in _otpControllers) {
                      c.clear();
                    }
                  }),
                  child: Text(
                    '← Back',
                    style: GoogleFonts.inter(
                      color: AppColours.brandBlue,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── SOS Button widget ─────────────────────────────────────────────────────────
class _SOSButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.black87,
          barrierDismissible: false,
          builder: (_) => const SosModal(),
        );
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColours.dangerRed,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColours.dangerRed.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'SOS',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
