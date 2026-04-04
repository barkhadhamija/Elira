import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_colours.dart';
import 'utils/session_manager.dart';
import 'services/auth_service.dart';
import 'screens/login/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/record/record_screen.dart';
import 'screens/review/review_screen.dart';
import 'screens/upload/upload_screen.dart';
import 'screens/testimony_detail/testimony_detail_screen.dart';
import 'screens/pin/pin_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/testimony_library/testimony_library_screen.dart';

/// A navigator key shared between GoRouter and the SOS overlay.
final GlobalKey<NavigatorState> sosNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: sosNavigatorKey,
  initialLocation: '/splash',
  errorBuilder: (context, state) => const SplashScreen(),
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/pin', builder: (_, __) => const PinScreen()),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/record', builder: (_, __) => const RecordScreen()),
    GoRoute(path: '/library', builder: (_, __) => const TestimonyLibraryScreen()),
    GoRoute(
      path: '/review',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return ReviewScreen(
          filePath: extra['filePath'] as String,
          title: extra['title'] as String,
          duration: extra['duration'] as int,
          gps: extra['gps'] as Map<String, dynamic>?,
          mimeType: extra['mimeType'] as String,
        );
      },
    ),
    GoRoute(path: '/upload', builder: (_, __) => const UploadScreen()),
    GoRoute(
      path: '/testimony/:id',
      builder: (context, state) => TestimonyDetailScreen(
        evidenceId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Master timeline drives all staggered animations
  late AnimationController _master;

  // Slow-breathing orb loop (separate so it doesn't stop mid-way)
  late AnimationController _orbCtrl;

  late Animation<double> _orbFade;
  late Animation<double> _shieldFade;
  late Animation<Offset> _shieldSlide;
  late Animation<double> _wordFade;
  late Animation<double> _wordScale;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _dividerScale;
  late Animation<double> _subtextFade;

  @override
  void initState() {
    super.initState();

    // 3 500 ms master — drives all staggered animations
    _master = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);

    _orbFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.00, 0.25, curve: Curves.easeOut),
    );

    _shieldFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.04, 0.30, curve: Curves.easeOut),
    );
    _shieldSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _master,
      curve: const Interval(0.04, 0.30, curve: Curves.easeOutCubic),
    ));

    _wordFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.20, 0.55, curve: Curves.easeOut),
    );
    _wordScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _master,
        curve: const Interval(0.20, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _taglineFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.50, 0.80, curve: Curves.easeOut),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _master,
      curve: const Interval(0.50, 0.80, curve: Curves.easeOutCubic),
    ));

    _dividerScale = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.70, 1.00, curve: Curves.easeOut),
    );
    _subtextFade = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.80, 1.00, curve: Curves.easeOut),
    );

    _master.forward();
    _navigate();
  }

  @override
  void dispose() {
    _master.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 3800));
    final hasLocalSession = await SessionManager.getSession();
    if (!mounted) return;

    if (!hasLocalSession || !AuthService.isFirebaseSignedIn) {
      await SessionManager.clearSession();
      if (!mounted) return;
      context.go('/login');
      return;
    }

    final onboardingDone = await SessionManager.isOnboardingComplete();
    if (!mounted) return;
    context.go(onboardingDone ? '/pin' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A), // Deep Midnight
      body: Stack(
        children: [
          // ── Background Gradient ──────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Color(0xFF1A1A2E), // Lighter centre
                    Color(0xFF0A0A0F), // Darker edge
                  ],
                ),
              ),
            ),
          ),

          // ── Background glowing orbs ────────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_orbCtrl, _orbFade]),
            builder: (_, __) {
              final breathe = _orbCtrl.value;
              return Opacity(
                opacity: _orbFade.value,
                child: Stack(
                  children: [
                    // Top-left large orb (Deep Blue)
                    Positioned(
                      top: -size.height * 0.20 + breathe * 30,
                      left: -size.width * 0.30,
                      child: Container(
                        width: size.width * 0.9,
                        height: size.width * 0.9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF2B2DC8).withOpacity(0.15),
                              const Color(0xFF2B2DC8).withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom-right orb (Deep Purple/Amethyst)
                    Positioned(
                      bottom: -size.height * 0.10 - breathe * 20,
                      right: -size.width * 0.20,
                      child: Container(
                        width: size.width * 0.70,
                        height: size.width * 0.70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF6A1B9A).withOpacity(0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Centre subtle light wash (Teal/Silver)
                    Positioned(
                      top: size.height * 0.30 - breathe * 15,
                      left: size.width * 0.05,
                      child: Container(
                        width: size.width * 0.90,
                        height: size.width * 0.90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFBBD0FF).withOpacity(0.04),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Centred content ────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shield icon
                FadeTransition(
                  opacity: _shieldFade,
                  child: SlideTransition(
                    position: _shieldSlide,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2B2DC8).withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ELIRA wordmark
                FadeTransition(
                  opacity: _wordFade,
                  child: ScaleTransition(
                    scale: _wordScale,
                    child: Text(
                      'ELIRA',
                      style: GoogleFonts.inter(
                        fontSize: 60,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 22,
                        shadows: [
                          Shadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Tagline
                FadeTransition(
                  opacity: _taglineFade,
                  child: SlideTransition(
                    position: _taglineSlide,
                    child: Text(
                      'PRESERVE YOUR TRUTH.\nPROTECT YOUR VOICE.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 3.0,
                        height: 2.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                // Expanding divider
                AnimatedBuilder(
                  animation: _dividerScale,
                  builder: (_, __) => SizedBox(
                    width: 140 * _dividerScale.value,
                    height: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Subtext
                FadeTransition(
                  opacity: _subtextFade,
                  child: Text(
                    'SECURE \u00b7 ENCRYPTED \u00b7 VERIFIED',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.35),
                      letterSpacing: 2.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

