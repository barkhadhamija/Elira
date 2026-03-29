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

/// A navigator key shared between GoRouter and the SOS overlay.
/// The SOS button lives outside GoRouter's widget subtree, so it needs
/// this key to obtain a valid Navigator/Overlay for showDialog.
final GlobalKey<NavigatorState> sosNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: sosNavigatorKey,
  initialLocation: '/splash',
  // Any URL that doesn't match a defined route (e.g. Firebase Auth reCAPTCHA
  // callback deep links that slip through) will redirect to /login silently.
  errorBuilder: (context, state) {
    // Firebase Auth callback URLs start with our URL scheme; let the SDK handle
    // them. For anything else, just go home.
    return const SplashScreen();
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/pin',
      builder: (context, state) => const PinScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/record',
      builder: (context, state) => const RecordScreen(),
    ),
    GoRoute(
      path: '/review',
      builder: (context, state) => const ReviewScreen(),
    ),
    GoRoute(
      path: '/upload',
      builder: (context, state) => const UploadScreen(),
    ),
    GoRoute(
      path: '/testimony/:id',
      builder: (context, state) => TestimonyDetailScreen(
        evidenceId: state.pathParameters['id']!,
      ),
    ),
  ],
);


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
    _navigate();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    final hasLocalSession = await SessionManager.getSession();
    if (!mounted) return;

    // Guard: also require a valid Firebase Auth token. A stale SharedPreferences
    // flag (e.g. from before Firebase was integrated, or after a sign-out) must
    // not let an unauthenticated user bypass the login screen.
    if (!hasLocalSession || !AuthService.isFirebaseSignedIn) {
      await SessionManager.clearSession(); // remove any stale flag
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
    return Scaffold(
      backgroundColor: AppColours.primaryBackground,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ELIRA',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 52,
                  color: AppColours.textLight,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your safety, your voice',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: AppColours.textLight.withOpacity(0.45),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
