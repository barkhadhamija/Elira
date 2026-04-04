import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../main.dart' show SosModal;
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
  bool _biometricEnabled = true;

  @override
  void initState() {
    super.initState();
    _contacts.add({
      'name': TextEditingController(),
      'phone': TextEditingController(),
    });
    _contacts.add({
      'name': TextEditingController(),
      'phone': TextEditingController(),
    });
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

  Future<void> _saveAndFinish() async {
    await SessionManager.savePin(_confirmPin);
    await SessionManager.setOnboardingComplete();
    final contacts = _contacts
        .map((c) => '${c['name']!.text}|${c['phone']!.text}')
        .where((s) => s.trim() != '|')
        .toList();
    await SessionManager.saveContacts(contacts);
    if (!mounted) return;

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
          _saveAndFinish();
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
      backgroundColor: AppColours.surface,
      body: SafeArea(
        child: _step == 4
            ? _buildBiometricStep()
            : _step == 3
                ? _buildPinStep()
                : _step == 2
                    ? _buildContactsStep()
                    : _step == 1
                        ? _buildDataConsentStep()
                        : _buildLocationStep(),
      ),
    );
  }

  // ── TOP NAV BAR ──────────────────────────────────────────────────────────────
  Widget _buildTopBar({bool showSos = true}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_outlined,
                  color: AppColours.brandBlue, size: 20),
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
          if (showSos) _SOSButton(),
        ],
      ),
    );
  }

  // ── STEP 0: LOCATION ─────────────────────────────────────────────────────────
  Widget _buildLocationStep() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 28),

                // Progress dots
                _buildProgressDots(0),
                const SizedBox(height: 28),

                // Map + phone illustration
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColours.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColours.divider),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Map placeholder
                      Container(
                        width: 140,
                        height: 120,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.map_outlined,
                                color: Color(0xFF5C6BC0), size: 40),
                            const SizedBox(height: 4),
                            Text(
                              'GPS Map',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: const Color(0xFF5C6BC0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Location pins
                      Positioned(
                        left: 52,
                        top: 30,
                        child: const Icon(Icons.location_on,
                            color: AppColours.dangerRed, size: 24),
                      ),
                      Positioned(
                        right: 60,
                        top: 48,
                        child: const Icon(Icons.location_on,
                            color: AppColours.brandBlue, size: 20),
                      ),
                      // Phone card
                      Positioned(
                        right: 24,
                        bottom: 14,
                        child: Container(
                          width: 72,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.smartphone,
                              color: Colors.white70, size: 36),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Title
                Text(
                  'Your safety, mapped.',
                  textAlign: TextAlign.left,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColours.textDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'To provide a sanctuary of care, Elira needs to understand where you are. GPS allows our rapid response team to reach you instantly in moments of crisis.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColours.textMuted,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 24),

                // Toggle card
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColours.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColours.divider),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location Services',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColours.textDark,
                            ),
                          ),
                          Text(
                            'Enable real-time safety monitoring',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColours.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _gpsConsent,
                        onChanged: (val) async {
                          setState(() => _gpsConsent = val);
                          await SessionManager.setGpsConsent(val);
                          ref.read(appProvider.notifier).setGpsConsent(val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Privacy note
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 14, color: AppColours.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your location data is encrypted and only shared with verified emergency contacts and professionals when an alert is triggered.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColours.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Bottom buttons
        _buildBottomButtons(
          primaryLabel: 'Continue to Profile',
          onPrimary: _next,
          secondaryLabel: 'Maybe Later',
          onSecondary: _next,
        ),
      ],
    );
  }

  // ── STEP 1: DATA CONSENT ─────────────────────────────────────────────────────
  Widget _buildDataConsentStep() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildProgressDots(1),
                const SizedBox(height: 24),

                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColours.accentLavenderSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ONBOARDING JOURNEY',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColours.brandBlue,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Data Integrity & Consent',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColours.textDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Please review how ELIRA secures your forensic data across decentralized networks to ensure immutable record-keeping.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColours.textMuted,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // Arweave card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColours.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColours.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColours.accentLavenderSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.cloud_upload_outlined,
                                color: AppColours.brandBlue, size: 18),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8E8EE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PERMANENT',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColours.textMuted,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Arweave Storage',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColours.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your evidentiary documents are encrypted and stored on the permaweb. This ensures that records cannot be altered, deleted, or censored by any centralized entity, providing a lifetime of data availability.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColours.textMuted,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColours.badgeGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'PROTOCOL ACTIVE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColours.badgeGreen,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Polygon card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColours.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColours.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.hub_outlined,
                            color: Color(0xFF8B5CF6), size: 18),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Polygon L2',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColours.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Identity verification and consent logs are timestamped on the Polygon blockchain for instant auditability.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColours.textMuted,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'GAS-LESS VERIFICATION',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColours.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Consent checkbox
                GestureDetector(
                  onTap: () =>
                      setState(() => _dataConsent = !_dataConsent),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _dataConsent
                              ? AppColours.brandBlue
                              : Colors.transparent,
                          border: Border.all(
                            color: _dataConsent
                                ? AppColours.brandBlue
                                : AppColours.borderLight,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: _dataConsent
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'I understand and agree to the data usage terms. I authorize ELIRA to anchor my encrypted data to Arweave and Polygon for the purpose of secure, permanent record-keeping.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColours.textDark,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Bottom buttons
        _buildBottomButtons(
          primaryLabel: 'Confirm and Secure Data →',
          onPrimary: _dataConsent ? _next : null,
          secondaryLabel: 'Review Legal Docs',
          onSecondary: () {},
        ),
      ],
    );
  }

  // ── STEP 2: EMERGENCY CONTACTS ───────────────────────────────────────────────
  Widget _buildContactsStep() {
    final contactLabels = ['PRIMARY CONTACT', 'CONTACT 02', 'CONTACT 03'];
    final isPrimary = [true, false, false];

    return Column(
      children: [
        _buildTopBar(showSos: false),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildProgressDots(2),
                const SizedBox(height: 24),

                // Icon + title
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFECEC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: AppColours.dangerRed, size: 26),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Emergency Contacts',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColours.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'In the event of an automated SOS alert, Elira will instantly notify these individuals with your precise coordinates and legal profile summary.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColours.textMuted,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Contact blocks
                for (int i = 0; i < 3; i++) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColours.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColours.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPrimary[i]
                                    ? AppColours.accentLavenderSoft
                                    : const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                contactLabels[i],
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isPrimary[i]
                                      ? AppColours.brandBlue
                                      : AppColours.textMuted,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            Icon(
                              isPrimary[i]
                                  ? Icons.person_outline
                                  : Icons.lock_outline,
                              color: AppColours.textMuted,
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'FULL NAME',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColours.textMuted,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _contacts[i]['name'],
                          style: GoogleFonts.inter(
                              color: AppColours.textDark, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: i == 0
                                ? 'e.g. Aarav Sharma'
                                : 'Optional Name',
                            hintStyle: GoogleFonts.inter(
                                color: AppColours.textMuted, fontSize: 14),
                            filled: true,
                            fillColor: AppColours.inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'PHONE NUMBER',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColours.textMuted,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _contacts[i]['phone'],
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(
                              color: AppColours.textDark, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '+91 98765 43210',
                            hintStyle: GoogleFonts.inter(
                                color: AppColours.textMuted, fontSize: 14),
                            filled: true,
                            fillColor: AppColours.inputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Encryption notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColours.accentLavenderSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColours.brandBlue.withOpacity(0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline,
                          color: AppColours.brandBlue, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Forensic Data Encryption',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColours.brandBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your contacts are stored in an end-to-end encrypted vault. They will only be contacted if you trigger an SOS event or if our AI detects a high-risk security breach during your session.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColours.brandBlue.withOpacity(0.7),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Bottom buttons
        _buildBottomButtons(
          primaryLabel: 'Establish Secure Protocol →',
          onPrimary: _next,
          secondaryLabel: 'Save as Draft',
          onSecondary: _next,
          secondaryIsOutlined: true,
        ),
      ],
    );
  }

  // ── STEP 3: PIN SETUP ─────────────────────────────────────────────────────────
  Widget _buildPinStep() {
    final currentPin = _confirmingPin ? _confirmPin : _newPin;
    return Focus(
      focusNode: _pinFocusNode,
      autofocus: true,
      onKeyEvent: _handlePinKey,
      child: GestureDetector(
        onTap: () => _pinFocusNode.requestFocus(),
        child: Scaffold(
          backgroundColor: AppColours.surface,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: AppColours.brandBlue, size: 20),
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
                      const Spacer(),
                      _SOSButton(),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const SizedBox(height: 36),
                        Text(
                          'Secure Access',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColours.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _confirmingPin
                              ? 'Re-enter your 4-digit code to confirm'
                              : 'Create a four-digit security code to protect your evidence records.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColours.textMuted,
                            height: 1.5,
                          ),
                        ),
                        if (_pinError.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _pinError,
                            style: GoogleFonts.inter(
                              color: AppColours.dangerRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),

                        // PIN dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (i) {
                            final filled = i < currentPin.length;
                            return Container(
                              width: 18,
                              height: 18,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? AppColours.brandBlue
                                    : Colors.transparent,
                                border: Border.all(
                                  color: filled
                                      ? AppColours.brandBlue
                                      : AppColours.borderLight,
                                  width: 2,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 32),
                        _buildPinNumpad(light: true),
                        const SizedBox(height: 24),

                        // FaceID toggle
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColours.cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColours.divider),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.face_outlined,
                                  color: AppColours.brandBlue, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FaceID Authentication',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColours.textDark,
                                      ),
                                    ),
                                    Text(
                                      'FAST & SECURE ACCESS',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColours.textMuted,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _biometricEnabled,
                                onChanged: (val) =>
                                    setState(() => _biometricEnabled = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Confirm PIN button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: currentPin.length == 4
                                ? () {
                                    if (!_confirmingPin) {
                                      setState(() {
                                        _confirmingPin = true;
                                        _newPin = currentPin;
                                        _confirmPin = '';
                                      });
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColours.brandBlue,
                              disabledBackgroundColor:
                                  AppColours.brandBlue.withOpacity(0.3),
                            ),
                            child: Text(
                              'CONFIRM PIN',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '© FORENSIC STANDARD SECURITY',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: AppColours.textMuted,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── STEP 4: BIOMETRIC ────────────────────────────────────────────────────────
  Widget _buildBiometricStep() {
    return Scaffold(
      backgroundColor: AppColours.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 40),
              Text(
                'Quick unlock',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColours.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Unlock ELIRA instantly without entering your PIN each time.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: AppColours.textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColours.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColours.divider),
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
                            style: GoogleFonts.inter(
                              color: AppColours.textDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Unlock ELIRA instantly without entering your PIN',
                            style: GoogleFonts.inter(
                              color: AppColours.textMuted,
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
                      onChanged: (val) =>
                          setState(() => _biometricEnabled = val),
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
                    style: GoogleFonts.inter(
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
                    style: GoogleFonts.inter(
                      color: AppColours.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SHARED HELPERS ──────────────────────────────────────────────────────────
  Widget _buildProgressDots(int activeStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: i == activeStep ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: i <= activeStep
                ? AppColours.brandBlue
                : AppColours.borderLight,
          ),
        );
      }),
    );
  }

  Widget _buildPinNumpad({bool light = false}) {
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
              if (label.isEmpty) return const SizedBox(width: 80, height: 56);
              final isBack = label == '⌫';
              return GestureDetector(
                onTap: () =>
                    isBack ? _backspacePinDigit() : _appendPinDigit(label),
                child: Container(
                  width: 80,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isBack
                        ? Icon(Icons.backspace_outlined,
                            color: AppColours.textMuted, size: 22)
                        : Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 26,
                              fontWeight: FontWeight.w400,
                              color: AppColours.textDark,
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

  Widget _buildBottomButtons({
    required String primaryLabel,
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool secondaryIsOutlined = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: AppColours.surface,
        border: Border(top: BorderSide(color: AppColours.divider)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColours.brandBlue,
                disabledBackgroundColor:
                    AppColours.brandBlue.withOpacity(0.35),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                primaryLabel,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: secondaryIsOutlined
                  ? OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColours.borderLight),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        secondaryLabel,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColours.textMuted,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: onSecondary,
                      child: Text(
                        secondaryLabel,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColours.textMuted,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── SOS Button ─────────────────────────────────────────────────────────────────
class _SOSButton extends StatelessWidget {
  const _SOSButton();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        barrierColor: Colors.black87,
        barrierDismissible: false,
        builder: (_) => const SosModal(),
      ),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColours.dangerRed,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColours.dangerRed.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'SOS',
            style: GoogleFonts.inter(
              fontSize: 12,
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
