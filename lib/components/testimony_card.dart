import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/testimony_model.dart';
import '../theme/app_colours.dart';

class TestimonyCard extends StatelessWidget {
  final TestimonyModel testimony;
  const TestimonyCard({super.key, required this.testimony});

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s sec';
    return '$m min ${s.toString().padLeft(2, '0')} sec';
  }

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

  Color _badgeColor(String status) {
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

  IconData _typeIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.mic_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'document':
        return Icons.description_rounded;
      default:
        return Icons.attach_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor(testimony.status);
    final duration = testimony.metadata.duration;
    final subtitle = duration != null
        ? _formatDuration(duration)
        : testimony.type[0].toUpperCase() + testimony.type.substring(1);

    return GestureDetector(
      onTap: () => context.go('/testimony/${testimony.evidenceId}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColours.cardSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Type icon ───────────────────────────────────────────────────
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColours.accentLavenderSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _typeIcon(testimony.type),
                color: AppColours.brandBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // ── Title + metadata ────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    testimony.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColours.textDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_formatDate(testimony.metadata.timestamp)}  ·  $subtitle',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColours.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Status badge + chevron ──────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    testimony.status[0].toUpperCase() +
                        testimony.status.substring(1),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColours.textMuted.withOpacity(0.5),
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
