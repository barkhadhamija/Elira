import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../main.dart' show SosModal;
import '../../theme/app_colours.dart';
import '../../store/app_store.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);

    // Guard: redirect to PIN if not verified
    if (!state.isPinVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/pin');
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: AppColours.surface,
      body: _buildSanctuaryTab(),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildSOSButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBottomNav() {
    final tabs = [
      (Icons.home_outlined, Icons.home_rounded, 'HOME'),
      (Icons.folder_outlined, Icons.folder_rounded, 'TESTIMONIES'),
      (Icons.settings_outlined, Icons.settings_rounded, 'SETTINGS'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColours.surface,
        border: Border(top: BorderSide(color: AppColours.divider, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: tabs.asMap().entries.map((entry) {
              final i = entry.key;
              final (outlinedIcon, filledIcon, label) = entry.value;
              final isActive = i == 0; // Home is always active here
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i == 1) context.go('/library');
                    if (i == 2) context.go('/settings');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: isActive
                        ? BoxDecoration(
                            color: AppColours.accentLavenderSoft,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? filledIcon : outlinedIcon,
                          color: isActive
                              ? AppColours.brandBlue
                              : AppColours.textMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isActive
                                ? AppColours.brandBlue
                                : AppColours.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.black87,
          barrierDismissible: false,
          builder: (_) => const SosModal(),
        );
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColours.dangerRed,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColours.dangerRed.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'SOS',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSanctuaryTab() {
    return SafeArea(
      child: Column(
        children: [
          // AppBar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Lock icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColours.accentLavenderSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                      child: Icon(Icons.lock_outline,
                        color: AppColours.brandBlue, size: 18),
                ),
                Text(
                  'ELIRA',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColours.textDark,
                    letterSpacing: 1.5,
                  ),
                ),
                // Avatar — opens Settings
                GestureDetector(
                  onTap: () => context.go('/settings'),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(0xFFBBD0FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 100),
              children: [
                // Greeting
                Text(
                  'Good evening, Sarah.',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColours.textDark,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your sanctuary is secure.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColours.textMuted,
                  ),
                ),
                const SizedBox(height: 28),

                // Start Recording — full width card
                GestureDetector(
                  onTap: () => context.go('/record'),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColours.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColours.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColours.accentLavenderSoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.mic_rounded,
                                    color: AppColours.brandBlue, size: 24),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Start Recording',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColours.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Capture thoughts or ambient audio in an encrypted session.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColours.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Waveform illustration
                        const SizedBox(width: 16),
                        _buildWaveform(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2-column grid
                Row(
                  children: [
                    // Testimony Library
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.go('/library'),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColours.cardBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColours.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F0F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.menu_book_outlined,
                                    color: AppColours.textMuted, size: 20),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Testimony\nLibrary',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColours.textDark,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Review your journey.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColours.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Upload Docs
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.go('/upload'),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColours.cardBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColours.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F0F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.upload_file_outlined,
                                    color: AppColours.textMuted, size: 20),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Upload\nDocs',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColours.textDark,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Evidence protection.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColours.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Daily reflection card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColours.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColours.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAILY REFLECTION',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColours.brandBlue,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'What is recorded\ncannot be denied.',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColours.textDark,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () {},
                        child: Row(
                          children: [
                            Text(
                              'Reflect now',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColours.brandBlue,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward,
                              color: AppColours.brandBlue, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Cloud backup indicator
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColours.badgeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cloud backup active & encrypted',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColours.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.cloud_done_outlined,
                        color: AppColours.textMuted, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    final heights = [12.0, 20.0, 8.0, 28.0, 16.0, 8.0, 24.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: heights.asMap().entries.map((e) {
        return Container(
          width: 3,
          height: e.value,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: AppColours.brandBlue.withOpacity(0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}
