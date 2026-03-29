import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colours.dart';
import '../../store/app_store.dart';
import '../../components/testimony_card.dart';
import '../../providers/evidence_provider.dart';
import '../../data/mock_data.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);

    // Guard: redirect to PIN if not verified
    if (!state.isPinVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/pin');
      });
      return const SizedBox.shrink();
    }

    final evidenceAsync = ref.watch(evidenceProvider);

    return Scaffold(
      backgroundColor: AppColours.surface,
      appBar: AppBar(
        backgroundColor: AppColours.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        title: Text(
          'ELIRA',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 26,
            color: AppColours.textDark,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined, color: AppColours.textMuted),
            tooltip: 'Settings',
          ),
          // Space so SOS button doesn't overlap the settings icon
          const SizedBox(width: 60),
        ],
      ),
      body: evidenceAsync.when(
        loading: () => _buildList(context, state.testimonies, mockTestimonies),
        error: (_, __) => _buildList(context, state.testimonies, mockTestimonies),
        data: (firestoreEvidence) =>
            _buildList(context, state.testimonies, firestoreEvidence),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Record FAB
              GestureDetector(
                onTap: () => context.go('/record'),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColours.accentTeal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColours.accentTeal.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.videocam_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Upload FAB
              GestureDetector(
                onTap: () => context.go('/upload'),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColours.textDark,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.attach_file,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List newTestimonies,
    List firestoreEvidence,
  ) {
    final allFirestore = firestoreEvidence;
    final total = newTestimonies.length + allFirestore.length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        Text(
          'Your testimonies',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 22,
            color: AppColours.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$total recording${total == 1 ? '' : 's'} secured',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppColours.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        // Section: newly recorded (always shown first)
        if (newTestimonies.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'Recently added',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColours.textMuted,
              ),
            ),
          ),
          ...newTestimonies.map((t) => TestimonyCard(testimony: t)),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'Previous testimonies',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColours.textMuted,
              ),
            ),
          ),
        ],
        ...allFirestore.map((t) => TestimonyCard(testimony: t)),
        const SizedBox(height: 100), // space for FABs
      ],
    );
  }
}
