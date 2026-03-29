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
        constraints: const BoxConstraints(minHeight: 72),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColours.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColours.accentTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _typeIcon(testimony.type),
                color: AppColours.accentTeal,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    testimony.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColours.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(testimony.metadata.timestamp)}  ·  $subtitle',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColours.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    testimony.status[0].toUpperCase() +
                        testimony.status.substring(1),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppColours.textMuted,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
