import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'router.dart'; // also imports sosNavigatorKey
import 'theme/app_theme.dart';
import 'theme/app_colours.dart';
import 'utils/session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: EliraApp()));
}

class EliraApp extends StatelessWidget {
  const EliraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ELIRA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
      builder: (context, child) {
        return _SosWrapper(child: child!);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _SosWrapper — creates its OWN Overlay so the SOS button is always visible
// on every platform (web + iOS + Android).
//
// WHY: MaterialApp.router's builder callback provides a context that is ABOVE
// the Navigator/Overlay in the tree, so Overlay.maybeOf(context) always
// returns null there. The fix is to own the Overlay rather than find one.
// ---------------------------------------------------------------------------
class _SosWrapper extends StatefulWidget {
  final Widget child;
  const _SosWrapper({required this.child});

  @override
  State<_SosWrapper> createState() => _SosWrapperState();
}

class _SosWrapperState extends State<_SosWrapper> {
  // Two entries: child content first (bottom), SOS button on top.
  late final OverlayEntry _childEntry;
  late final OverlayEntry _sosEntry;

  @override
  void initState() {
    super.initState();
    _childEntry = OverlayEntry(builder: (_) => widget.child);
    _sosEntry   = OverlayEntry(builder: (_) => const _SosButtonOverlay());
  }

  @override
  void didUpdateWidget(_SosWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the router changes the child, force the entry to rebuild.
    _childEntry.markNeedsBuild();
  }

  // No dispose needed — the Overlay widget disposes its own entries.

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_childEntry, _sosEntry]);
  }
}

// ---------------------------------------------------------------------------
// _SosButtonOverlay — the red SOS circle, positioned top-right.
//
// IMPORTANT: showDialog MUST use sosNavigatorKey.currentContext, NOT the
// OverlayEntry's own build context. The OverlayEntry lives inside our private
// Overlay widget which has NO Navigator ancestor — GoRouter's Navigator is
// inside _childEntry (a sibling), not above this widget in the tree.
// Using the wrong context causes showDialog to throw/fail silently on web.
// ---------------------------------------------------------------------------
class _SosButtonOverlay extends StatelessWidget {
  const _SosButtonOverlay();

  void _showModal() {
    final ctx = sosNavigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      barrierColor: Colors.black87,
      barrierDismissible: false,
      builder: (_) => const _SosModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          // opaque so the web pointer-event layer never misses this widget
          behavior: HitTestBehavior.opaque,
          onTap: _showModal,
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColours.dangerRed,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SosModal — countdown dialog that calls 112 when it hits 0.
// Uses a for-loop + Future.delayed instead of Stream.periodic to avoid
// stream subscription leaks and double-fire edge-cases on iOS.
// ---------------------------------------------------------------------------
class _SosModal extends StatefulWidget {
  const _SosModal();

  @override
  State<_SosModal> createState() => _SosModalState();
}

class _SosModalState extends State<_SosModal> {
  int _countdown = 5;
  bool _cancelled = false;
  List<String> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _startCountdown();
  }

  Future<void> _loadContacts() async {
    final contacts = await SessionManager.getContacts();
    if (mounted) setState(() => _contacts = contacts);
  }

  Future<void> _startCountdown() async {
    for (int i = 4; i >= 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (_cancelled || !mounted) return;
      setState(() => _countdown = i);
    }

    if (_cancelled || !mounted) return;
    // Pop dialog then launch tel URI.
    Navigator.of(context).pop();
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _cancel() {
    _cancelled = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A0A0A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Emergency SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Calling 112 in',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Text(
              '$_countdown',
              style: const TextStyle(
                color: AppColours.dangerRed,
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_contacts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Notifying your contacts',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ..._contacts.map(
                (contact) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    contact,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: _cancel,
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
