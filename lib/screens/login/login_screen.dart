// TESTING: Add test phone numbers in Firebase Console →
// Authentication → Sign-in method → Phone → Scroll to
// "Phone numbers for testing". Add +919900000999 with OTP 123456
// This avoids burning real SMS during development.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colours.dart';
import '../../utils/session_manager.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _step = 1;
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

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

    await AuthService.sendOtp(
      phoneNumber: fullNumber,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _step = 2;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _otpFocusNodes[0].requestFocus();
        });
      },
      onAutoVerified: () async {
        if (!mounted) return;
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
        // Show the raw Firebase error code so it's visible during testing.
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
      await SessionManager.saveSession();
      if (!mounted) return;
      final onboardingDone = await SessionManager.isOnboardingComplete();
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go(onboardingDone ? '/pin' : '/onboarding');
    } else {
      setState(() => _isLoading = false);
      // Clear OTP boxes
      for (final c in _otpControllers) {
        c.clear();
      }
      _otpFocusNodes[0].requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
      backgroundColor: AppColours.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: _step == 1 ? _buildStep1() : _buildStep2(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 48),
        Text(
          'ELIRA',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 48,
            color: AppColours.textLight,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your safety, your voice',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: AppColours.textLight.withOpacity(0.6),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 56),
        // Phone field with +91 prefix
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '+91',
                style: GoogleFonts.dmSans(
                  color: AppColours.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                style: GoogleFonts.dmSans(
                  color: AppColours.textDark,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '10-digit mobile number',
                  hintStyle: GoogleFonts.dmSans(
                    color: AppColours.textMuted,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _onContinue,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Continue',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(height: 24),
        Text(
          'We will send a one-time code to verify your number.\nNo personal data is stored without your consent.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColours.textLight.withOpacity(0.4),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 48),
        Text(
          'ELIRA',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 32,
            color: AppColours.textLight,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'Enter the 6-digit code',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 26,
            color: AppColours.textLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sent to +91 ${_phoneController.text.trim()}',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColours.textLight.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (i) {
            return Container(
              width: 44,
              height: 54,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _otpControllers[i],
                focusNode: _otpFocusNodes[i],
                keyboardType: TextInputType.number,
                maxLength: 1,
                textAlign: TextAlign.center,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColours.textDark,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColours.textMuted.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColours.textMuted.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColours.accentTeal,
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
          const CircularProgressIndicator(color: AppColours.accentTeal),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _step = 1;
            for (final c in _otpControllers) {
              c.clear();
            }
          }),
          child: Text(
            'Back',
            style: GoogleFonts.dmSans(
              color: AppColours.textLight.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}
