import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colours.dart';
import '../../store/app_store.dart';
import '../../data/mock_data.dart';
import '../../models/testimony_model.dart';

class TestimonyLibraryScreen extends ConsumerStatefulWidget {
  const TestimonyLibraryScreen({super.key});

  @override
  ConsumerState<TestimonyLibraryScreen> createState() =>
      _TestimonyLibraryScreenState();
}

class _TestimonyLibraryScreenState
    extends ConsumerState<TestimonyLibraryScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Video', 'Audio', 'Document', 'Image'];

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.videocam_outlined;
      case 'audio':
        return Icons.mic_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'document':
        return Icons.description_outlined;
      default:
        return Icons.attach_file_outlined;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'certified':
        return AppColours.badgeCertified;
      case 'anchored':
        return AppColours.badgeAnchored;
      case 'uploading':
        return AppColours.badgeUploading;
      default:
        return AppColours.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeTestimonies = ref.watch(appProvider).testimonies;
    final all = [...storeTestimonies, ...mockTestimonies];
    final filtered = _filter == 'All'
        ? all
        : all
            .where((t) =>
                t.type.toLowerCase() == _filter.toLowerCase())
            .toList();

    return Scaffold(
      backgroundColor: AppColours.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
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
            ),

            // ── Title section ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColours.accentLavenderSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ARCHIVE MANAGEMENT',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColours.brandBlue,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Testimony Library',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColours.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${filtered.length} encrypted record${filtered.length == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColours.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Filter chips ──────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _filters.length,
                itemBuilder: (_, i) {
                  final f = _filters[i];
                  final active = f == _filter;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColours.brandBlue
                            : AppColours.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? AppColours.brandBlue
                              : AppColours.divider,
                        ),
                      ),
                      child: Text(
                        f,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : AppColours.textMuted,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // ── List of testimonies ───────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_outlined,
                              size: 52, color: AppColours.borderLight),
                          const SizedBox(height: 16),
                          Text(
                            'No records yet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppColours.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your encrypted testimonies will appear here.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColours.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final t = filtered[i];
                        final duration = t.metadata.duration;
                        return _TestimonyRow(
                          testimony: t,
                          typeIcon: _typeIcon(t.type),
                          dateText: _formatDate(t.metadata.timestamp),
                          durationText:
                              duration != null ? _formatDuration(duration) : '',
                          statusColor: _statusColor(t.status),
                          onTap: () =>
                              context.go('/testimony/${t.evidenceId}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── Bottom bar ────────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(context),

      // ── Record FAB ────────────────────────────────────────────────────
      floatingActionButton: GestureDetector(
        onTap: () => context.go('/record'),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: AppColours.brandBlue,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColours.brandBlue.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'RECORD',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final tabs = [
      (Icons.home_outlined, Icons.home_rounded, 'HOME', '/home'),
      (Icons.folder_outlined, Icons.folder_rounded, 'TESTIMONIES', '/library'),
      (Icons.settings_outlined, Icons.settings_rounded, 'SETTINGS', '/settings'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColours.surface,
        border: Border(top: BorderSide(color: AppColours.divider)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: tabs.asMap().entries.map((entry) {
              final i = entry.key;
              final (outlineIcon, filledIcon, label, route) = entry.value;
              final isActive = i == 1; // Testimonies tab active
              return Expanded(
                child: GestureDetector(
                  onTap: () => context.go(route),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? filledIcon : outlineIcon,
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
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Row card for a single testimony ──────────────────────────────────────────
class _TestimonyRow extends StatelessWidget {
  final TestimonyModel testimony;
  final IconData typeIcon;
  final String dateText;
  final String durationText;
  final Color statusColor;
  final VoidCallback onTap;

  const _TestimonyRow({
    required this.testimony,
    required this.typeIcon,
    required this.dateText,
    required this.durationText,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColours.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColours.divider),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColours.accentLavenderSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: AppColours.brandBlue, size: 22),
            ),
            const SizedBox(width: 14),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    testimony.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColours.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    durationText.isNotEmpty
                        ? '$dateText · $durationText'
                        : dateText,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColours.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Status + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    testimony.status[0].toUpperCase() +
                        testimony.status.substring(1),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right,
                    color: AppColours.textMuted, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
