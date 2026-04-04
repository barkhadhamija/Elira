import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
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
  await SessionManager.clearAll(); // ⚠️ DEV ONLY — remove after testing
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
    );
  }
}



// ---------------------------------------------------------------------------
// SosModal — countdown dialog that calls 112 and notifies saved contacts.
// Public so record_screen.dart (and any other screen) can show it directly.
// ---------------------------------------------------------------------------
class SosModal extends StatefulWidget {
  const SosModal();

  @override
  State<SosModal> createState() => _SosModalState();
}

class _SosModalState extends State<SosModal> {
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
      backgroundColor: const Color(0xFF1E1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Emergency SOS',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Calling 112 in',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColours.dangerRed.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColours.dangerRed.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  '$_countdown',
                  style: TextStyle(
                    color: AppColours.dangerRed,
                    fontSize: 52,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    fontFamily: GoogleFonts.dmSans().fontFamily,
                  ),
                ),
              ),
            ),
            if (_contacts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Notifying your contacts',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ..._contacts.map(
                (contact) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    contact,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            TextButton(
              onPressed: _cancel,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                      color: Colors.white24, width: 1),
                ),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
