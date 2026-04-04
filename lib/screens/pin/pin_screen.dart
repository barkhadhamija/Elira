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

class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen>
    with SingleTickerProviderStateMixin {
  final _focusNode = FocusNode();
  String _pin = '';
  bool _hasError = false;
  bool _showingBiometric = false;
  bool _usePinInstead = false;
  bool _biometricAvailable = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final biometricPref = await SessionManager.getBiometricEnabled();
      final biometricEnrolled = await BiometricService.isAvailable();
      if (!mounted) return;
      setState(() => _biometricAvailable = biometricEnrolled);
      if (biometricPref && biometricEnrolled) {
        setState(() => _showingBiometric = true);
        _triggerBiometric();
      } else {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometric() async {
    final success = await BiometricService.authenticate();
    if (!mounted) return;
    if (success) {
      ref.read(appProvider.notifier).setPinVerified(true);
      context.go('/home');
    }
  }

  void _switchToPin() {
    setState(() {
      _usePinInstead = true;
      _showingBiometric = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _appendDigit(String digit) async {
    if (_pin.length >= 4) return;
    final newPin = _pin + digit;
    setState(() {
      _pin = newPin;
      _hasError = false;
    });
    if (newPin.length == 4) {
      await _checkPin(newPin);
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _hasError = false;
    });
  }

  Future<void> _checkPin(String pin) async {
    final savedPin = await SessionManager.getPin();
    if (!mounted) return;
    if (pin == savedPin) {
      ref.read(appProvider.notifier).setPinVerified(true);
      context.go('/home');
    } else {
      setState(() {
        _hasError = true;
        _pin = '';
      });
      _shakeController.forward();
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    final digitKeys = {
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.numpad9: '9',
    };

    if (digitKeys.containsKey(key)) {
      _appendDigit(digitKeys[key]!);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.surface,
      body: SafeArea(
        child: _showingBiometric && !_usePinInstead
            ? _buildBiometricView()
            : _buildPinView(),
      ),
    );
  }

  Widget _buildBiometricView() {
    return Column(
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
        const Spacer(),
        GestureDetector(
          onTap: _triggerBiometric,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColours.accentLavenderSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fingerprint,
              size: 48,
              color: AppColours.brandBlue,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Touch to unlock',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: AppColours.textMuted,
          ),
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: _switchToPin,
          child: Text(
            'Use PIN instead',
            style: GoogleFonts.inter(
              color: AppColours.brandBlue,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPinView() {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
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
                      'Verify Identity',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColours.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your secure access pin to continue',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColours.textMuted,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // PIN dots
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < _pin.length;
                          return Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: filled
                                  ? AppColours.brandBlue
                                  : Colors.transparent,
                              border: Border.all(
                                color: _hasError
                                    ? AppColours.dangerRed
                                    : (filled
                                        ? AppColours.brandBlue
                                        : AppColours.borderLight),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Numpad
                    _buildNumpad(),
                    const SizedBox(height: 24),

                    // Biometric prompt button
                    if (_biometricAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColours.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColours.divider),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.fingerprint,
                                color: AppColours.textMuted, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'BIOMETRIC PROMPT',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColours.textMuted,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _biometricAvailable ? _switchToPin : null,
                      child: Text(
                        'Use PIN instead',
                        style: GoogleFonts.inter(
                          color: AppColours.brandBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 12, color: AppColours.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'END-TO-END ENCRYPTED VAULT',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: AppColours.textMuted,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Demo shortcut
                    TextButton(
                      onPressed: () {
                        ref.read(appProvider.notifier).setPinVerified(true);
                        context.go('/home');
                      },
                      child: Text(
                        '⚡ Skip PIN (demo)',
                        style: GoogleFonts.inter(
                          color: AppColours.brandBlue.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['biometric', '0', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((label) {
              if (label == 'biometric') {
                return GestureDetector(
                  onTap: _biometricAvailable ? _triggerBiometric : null,
                  child: SizedBox(
                    width: 80,
                    height: 60,
                    child: Center(
                      child: Icon(
                        Icons.fingerprint,
                        color: _biometricAvailable
                            ? AppColours.brandBlue
                            : AppColours.borderLight,
                        size: 30,
                      ),
                    ),
                  ),
                );
              }
              final isBackspace = label == '⌫';
              return GestureDetector(
                onTap: () {
                  if (isBackspace) {
                    _backspace();
                  } else {
                    _appendDigit(label);
                  }
                },
                child: Container(
                  width: 80,
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: isBackspace
                        ? Icon(Icons.backspace_outlined,
                            color: AppColours.textMuted, size: 22)
                        : Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 28,
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
}

// ── SOS Button ───────────────────────────────────────────────────────────────
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

