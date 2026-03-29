import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

    // Check biometric availability on mount
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final biometricPref = await SessionManager.getBiometricEnabled();
      // Must check both pref AND whether biometrics are actually enrolled.
      // If user set biometricEnabled=true but later un-enrolled, fall to PIN.
      final biometricEnrolled = await BiometricService.isAvailable();
      if (!mounted) return;
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
    } else {
      // Biometric failed — stay on biometric view so user can retry or switch to PIN
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
      backgroundColor: AppColours.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _showingBiometric && !_usePinInstead
              ? _buildBiometricView()
              : _buildPinView(),
        ),
      ),
    );
  }

  Widget _buildBiometricView() {
    return Column(
      children: [
        const SizedBox(height: 48),
        Text(
          'ELIRA',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 28,
            color: AppColours.textLight,
            letterSpacing: 3,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _triggerBiometric,
          child: const Icon(
            Icons.fingerprint,
            size: 72,
            color: AppColours.accentTeal,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Touch to unlock',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: AppColours.textMuted,
          ),
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: _switchToPin,
          child: Text(
            'Use PIN instead',
            style: GoogleFonts.dmSans(
              color: AppColours.textMuted,
              fontSize: 14,
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
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ELIRA',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 28,
                    color: AppColours.textLight,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(width: 8),
                _BiometricToggleButton(),
              ],
            ),
            const Spacer(),
            Text(
              'Enter your PIN',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 28,
                color: AppColours.textLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasError
                  ? 'Incorrect PIN. Try again.'
                  : 'Type your 4-digit PIN',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: _hasError
                    ? AppColours.dangerRed
                    : AppColours.textLight.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 40),
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
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? AppColours.accentTeal
                          : Colors.transparent,
                      border: Border.all(
                        color: _hasError
                            ? AppColours.dangerRed
                            : AppColours.textLight.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 20),
            _buildNumpad(),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(
                'Sign in with a different account',
                style: GoogleFonts.dmSans(
                  color: AppColours.textLight.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 24),
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
      ['', '0', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((label) {
              if (label.isEmpty) {
                return const SizedBox(width: 80, height: 56);
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
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isBackspace
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: GoogleFonts.dmSans(
                        fontSize: isBackspace ? 20 : 22,
                        fontWeight: FontWeight.w500,
                        color: isBackspace
                            ? AppColours.textLight.withValues(alpha: 0.5)
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
}

// ---------------------------------------------------------------------------
// _BiometricToggleButton — small fingerprint icon next to the ELIRA title
// on the PIN screen. Tapping it toggles Face ID / fingerprint on or off.
// Only visible on devices that have biometric hardware.
// ---------------------------------------------------------------------------
class _BiometricToggleButton extends StatefulWidget {
  const _BiometricToggleButton();

  @override
  State<_BiometricToggleButton> createState() => _BiometricToggleButtonState();
}

class _BiometricToggleButtonState extends State<_BiometricToggleButton> {
  bool _hardwareAvailable = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hw = await BiometricService.isHardwareSupported();
    final pref = await SessionManager.getBiometricEnabled();
    if (mounted) setState(() { _hardwareAvailable = hw; _enabled = pref; });
  }

  Future<void> _toggle() async {
    final next = !_enabled;
    await SessionManager.saveBiometricEnabled(next);
    if (mounted) setState(() => _enabled = next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next
              ? 'Face ID / fingerprint enabled'
              : 'Face ID / fingerprint disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hardwareAvailable) return const SizedBox.shrink();
    return Tooltip(
      message: _enabled ? 'Disable biometric unlock' : 'Enable Face ID / fingerprint',
      child: GestureDetector(
        onTap: _toggle,
        child: Icon(
          _enabled ? Icons.fingerprint : Icons.fingerprint_outlined,
          color: _enabled
              ? AppColours.accentTeal
              : AppColours.textLight.withValues(alpha: 0.3),
          size: 22,
        ),
      ),
    );
  }
}
