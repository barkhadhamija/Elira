import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colours.dart';
import '../../store/app_store.dart';
import '../../utils/session_manager.dart';
import '../../utils/biometric_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0; // 0=location, 1=data, 2=contacts, 3=PIN, 4=biometric
  bool _gpsConsent = false;
  bool _dataConsent = false;

  // Contacts
  final List<Map<String, TextEditingController>> _contacts = [];

  // PIN setup
  String _newPin = '';
  String _confirmPin = '';
  bool _confirmingPin = false;
  String _pinError = '';
  final _pinFocusNode = FocusNode();

  // Biometric sub-step
  bool _biometricEnabled = true; // default ON

  @override
  void initState() {
    super.initState();
    _contacts.add({
      'name': TextEditingController(),
      'phone': TextEditingController(),
    });
  }

  @override
  void dispose() {
    for (final c in _contacts) {
      c['name']!.dispose();
      c['phone']!.dispose();
    }
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _addContact() {
    if (_contacts.length >= 3) return;
    setState(() {
      _contacts.add({
        'name': TextEditingController(),
        'phone': TextEditingController(),
      });
    });
  }

  void _removeContact(int i) {
    setState(() {
      _contacts[i]['name']!.dispose();
      _contacts[i]['phone']!.dispose();
      _contacts.removeAt(i);
    });
  }

  Future<void> _saveAndFinish() async {
    await SessionManager.savePin(_confirmPin);
    await SessionManager.setOnboardingComplete();
    final contacts = _contacts
        .map((c) => '${c['name']!.text}|${c['phone']!.text}')
        .where((s) => s.trim() != '|')
        .toList();
    await SessionManager.saveContacts(contacts);
    if (!mounted) return;

    // Check if device has biometric hardware — show setup screen if so,
    // even if biometrics aren't enrolled yet (user can enroll after setup).
    final available = await BiometricService.isHardwareSupported();
    if (!mounted) return;
    if (available) {
      setState(() => _step = 4);
    } else {
      await SessionManager.saveBiometricEnabled(false);
      if (!mounted) return;
      context.go('/home');
    }
  }

  Future<void> _completeBiometricStep() async {
    await SessionManager.saveBiometricEnabled(_biometricEnabled);
    if (!mounted) return;
    context.go('/home');
  }

  void _appendPinDigit(String digit) {
    final current = _confirmingPin ? _confirmPin : _newPin;
    if (current.length >= 4) return;
    final next = current + digit;
    setState(() {
      _pinError = '';
      if (!_confirmingPin) {
        _newPin = next;
      } else {
        _confirmPin = next;
      }
    });
    if (next.length == 4) {
      if (!_confirmingPin) {
        setState(() {
          _confirmingPin = true;
          _newPin = next;
          _confirmPin = '';
        });
      } else {
        if (next == _newPin) {
          _confirmPin = next;
          _saveAndFinish(); // will advance to step 4 or /home
        } else {
          setState(() {
            _pinError = "PINs don't match — try again";
            _confirmingPin = false;
            _newPin = '';
            _confirmPin = '';
          });
        }
      }
    }
  }

  void _backspacePinDigit() {
    final current = _confirmingPin ? _confirmPin : _newPin;
    if (current.isEmpty) return;
    final next = current.substring(0, current.length - 1);
    setState(() {
      if (!_confirmingPin) {
        _newPin = next;
      } else {
        _confirmPin = next;
      }
    });
  }

  KeyEventResult _handlePinKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final digitKeys = {
      LogicalKeyboardKey.digit0: '0', LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2', LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4', LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6', LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8', LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0', LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2', LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4', LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6', LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8', LogicalKeyboardKey.numpad9: '9',
    };
    if (digitKeys.containsKey(event.logicalKey)) {
      _appendPinDigit(digitKeys[event.logicalKey]!);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _backspacePinDigit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
      if (_step == 3) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _pinFocusNode.requestFocus();
        });
      }
    }
  }

  void _back() {
    if (_step > 0 && _step < 4) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildStepIndicator(),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: _step == 4
                      ? _buildBiometricStep()
                      : [
                          _buildStep0(),
                          _buildStep1(),
                          _buildStep2(),
                          _buildStep3(),
                        ][_step],
                ),
              ),
              if (_step < 4) _buildNavButtons(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    // Show 4 dots for steps 0-3; step 4 (biometric) is a separate sub-step
    final displayStep = _step.clamp(0, 3);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _step == 4 ? 'Almost done' : 'Step ${displayStep + 1} of 4',
          style: GoogleFonts.dmSans(
            color: AppColours.textLight.withOpacity(0.5),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Row(
          children: List.generate(4, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == displayStep ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i <= displayStep
                    ? AppColours.accentTeal
                    : AppColours.textLight.withOpacity(0.15),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location tagging',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 30,
            color: AppColours.textLight,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'ELIRA can attach your GPS coordinates to each recording. This creates a verified location record that strengthens your testimony.',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            color: AppColours.textLight.withOpacity(0.7),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Location data is encrypted and only shared with your legal representative or law enforcement upon your explicit request.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppColours.textLight.withOpacity(0.45),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Enable location tagging',
                style: GoogleFonts.dmSans(
                  color: AppColours.textLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Switch(
                value: _gpsConsent,
                activeColor: AppColours.accentTeal,
                onChanged: (val) async {
                  setState(() => _gpsConsent = val);
                  await SessionManager.setGpsConsent(val);
                  ref.read(appProvider.notifier).setGpsConsent(val);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How we use your data',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 30,
            color: AppColours.textLight,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your recordings, transcripts, and personal details are encrypted end-to-end and stored on Arweave — a permanent, decentralised storage network.',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            color: AppColours.textLight.withOpacity(0.7),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 12),
        _dataPoint(Icons.lock_outline, 'Only you hold the encryption key'),
        _dataPoint(Icons.block, 'We cannot access, sell, or share your data'),
        _dataPoint(Icons.public_off, 'AI processing happens on-device'),
        _dataPoint(Icons.verified_outlined,
            'Blockchain hashes provide tamper-proof certification'),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: () => setState(() => _dataConsent = !_dataConsent),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _dataConsent,
                activeColor: AppColours.accentTeal,
                checkColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                onChanged: (val) =>
                    setState(() => _dataConsent = val ?? false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'I understand how ELIRA uses and protects my data',
                  style: GoogleFonts.dmSans(
                    color: AppColours.textLight.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dataPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColours.accentTeal, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                color: AppColours.textLight.withOpacity(0.65),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency contacts',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 30,
            color: AppColours.textLight,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Add up to 3 trusted people. They will be notified when you trigger an SOS alert.',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColours.textLight.withOpacity(0.6),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        ..._contacts.asMap().entries.map((entry) {
          final i = entry.key;
          final contact = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Contact ${i + 1}',
                      style: GoogleFonts.dmSans(
                        color: AppColours.textLight.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_contacts.length > 1)
                      GestureDetector(
                        onTap: () => _removeContact(i),
                        child: Icon(
                          Icons.close,
                          color: AppColours.textLight.withOpacity(0.3),
                          size: 18,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contact['name'],
                  style: GoogleFonts.dmSans(
                      color: AppColours.textDark, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Name',
                    hintStyle: GoogleFonts.dmSans(
                        color: AppColours.textMuted, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contact['phone'],
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.dmSans(
                      color: AppColours.textDark, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    hintStyle: GoogleFonts.dmSans(
                        color: AppColours.textMuted, fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        }),
        if (_contacts.length < 3) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _addContact,
            icon: const Icon(Icons.add_circle_outline,
                color: AppColours.accentTeal, size: 18),
            label: Text(
              'Add another contact',
              style: GoogleFonts.dmSans(
                  color: AppColours.accentTeal, fontSize: 14),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStep3() {
    final currentPin = _confirmingPin ? _confirmPin : _newPin;
    return Focus(
      focusNode: _pinFocusNode,
      autofocus: true,
      onKeyEvent: _handlePinKey,
      child: GestureDetector(
        onTap: () => _pinFocusNode.requestFocus(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _confirmingPin ? 'Confirm your PIN' : 'Create your PIN',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 30,
                color: AppColours.textLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _confirmingPin
                  ? 'Enter the same 4-digit PIN again'
                  : 'Choose a 4-digit PIN to protect your recordings',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColours.textLight.withOpacity(0.5),
              ),
            ),
            if (_pinError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _pinError,
                style: GoogleFonts.dmSans(
                  color: AppColours.dangerRed,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < currentPin.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColours.accentTeal : Colors.transparent,
                    border: Border.all(
                      color: AppColours.textLight.withOpacity(0.35),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),
            _buildPinNumpad(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPinNumpad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((label) {
              if (label.isEmpty) return const SizedBox(width: 80, height: 52);
              final isBack = label == '⌫';
              return GestureDetector(
                onTap: () => isBack ? _backspacePinDigit() : _appendPinDigit(label),
                child: Container(
                  width: 80,
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isBack
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: GoogleFonts.dmSans(
                        fontSize: isBack ? 20 : 22,
                        fontWeight: FontWeight.w500,
                        color: isBack
                            ? AppColours.textLight.withOpacity(0.5)
                            : AppColours.textLight,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavButtons() {
    final bool canProceed = () {
      switch (_step) {
        case 1:
          return _dataConsent;
        case 3:
          return false; // PIN entry handles navigation itself
        default:
          return true;
      }
    }();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _back,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColours.textLight,
                  minimumSize: const Size(0, 52),
                  side: BorderSide(
                    color: AppColours.textLight.withOpacity(0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Back',
                    style: GoogleFonts.dmSans(
                        fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          if (_step < 3)
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: canProceed ? _next : null,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor:
                      AppColours.accentTeal.withOpacity(0.3),
                ),
                child: Text(
                  _step == 2 ? 'Save & Continue' : 'Next',
                  style: GoogleFonts.dmSans(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (_step == 2)
            TextButton(
              onPressed: _next,
              child: Text(
                'Skip',
                style: GoogleFonts.dmSans(
                  color: AppColours.textLight.withOpacity(0.4),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBiometricStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick unlock',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 30,
            color: AppColours.textLight,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Unlock ELIRA instantly without entering your PIN each time.',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            color: AppColours.textLight.withOpacity(0.7),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable Face ID / fingerprint unlock',
                      style: GoogleFonts.dmSans(
                        color: AppColours.textLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unlock ELIRA instantly without entering your PIN',
                      style: GoogleFonts.dmSans(
                        color: AppColours.textLight.withOpacity(0.45),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: _biometricEnabled,
                activeColor: AppColours.accentTeal,
                onChanged: (val) => setState(() => _biometricEnabled = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _completeBiometricStep,
            child: Text(
              'Finish setup',
              style: GoogleFonts.dmSans(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () async {
              await SessionManager.saveBiometricEnabled(false);
              if (!mounted) return;
              context.go('/home');
            },
            child: Text(
              'Skip for now',
              style: GoogleFonts.dmSans(
                color: AppColours.textLight.withOpacity(0.4),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
