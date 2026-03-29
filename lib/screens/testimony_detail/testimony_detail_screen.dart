import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colours.dart';
import '../../store/app_store.dart';
import '../../data/mock_data.dart';
import '../../models/testimony_model.dart';

class TestimonyDetailScreen extends ConsumerStatefulWidget {
  final String evidenceId;
  const TestimonyDetailScreen({super.key, required this.evidenceId});

  @override
  ConsumerState<TestimonyDetailScreen> createState() =>
      _TestimonyDetailScreenState();
}

class _TestimonyDetailScreenState extends ConsumerState<TestimonyDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  TestimonyModel? _findTestimony() {
    final storeTestimonies = ref.read(appProvider).testimonies;
    final all = [...storeTestimonies, ...mockTestimonies];
    try {
      return all.firstWhere((t) => t.evidenceId == widget.evidenceId);
    } catch (_) {
      return null;
    }
  }

  String _formatFullDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $hour:$minute';
    } catch (_) {
      return iso;
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m min $s sec';
  }

  String _truncateTx(String tx) {
    if (tx.length <= 18) return tx;
    return '${tx.substring(0, 8)}...${tx.substring(tx.length - 8)}';
  }

  void _copyToClipboard(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied to clipboard',
          style: GoogleFonts.dmSans(fontSize: 14),
        ),
        backgroundColor: AppColours.primaryBackground,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color textColor;
    switch (status) {
      case 'uploading':
        bg = AppColours.badgeUploading;
        textColor = const Color(0xFF92400E);
        break;
      case 'anchored':
        bg = AppColours.badgeAnchored;
        textColor = Colors.white;
        break;
      case 'certified':
        bg = AppColours.badgeCertified;
        textColor = Colors.white;
        break;
      default:
        bg = AppColours.textMuted;
        textColor = Colors.white;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildMediaPlaceholder(String type) {
    IconData icon;
    String tapLabel;
    switch (type) {
      case 'video':
        icon = Icons.play_circle_outline;
        tapLabel = 'Tap to play';
        break;
      case 'image':
        icon = Icons.image_outlined;
        tapLabel = 'Tap to view';
        break;
      default:
        icon = Icons.description_outlined;
        tapLabel = 'Tap to view';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: AppColours.primaryBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 52),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tapLabel,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColours.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildEntityChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColours.accentTeal),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppColours.accentTeal,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColours.textDark,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final testimony = _findTestimony();

    if (testimony == null) {
      return Scaffold(
        backgroundColor: AppColours.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColours.textDark,
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Evidence not found',
                    style: TextStyle(color: AppColours.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isPending = testimony.arweave.txId.startsWith('pending_');
    final location = testimony.metadata.location;
    final duration = testimony.metadata.duration;
    final type = testimony.type;

    String subtitle = _formatFullDate(testimony.metadata.timestamp);
    if (duration != null) {
      subtitle += ' · ${_formatDuration(duration)}';
    } else if (type == 'image') {
      subtitle += ' · Image';
    } else if (type == 'pdf' || type == 'document') {
      subtitle += ' · Document';
    }

    return Scaffold(
      backgroundColor: AppColours.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColours.textDark,
                      ),
                      iconSize: 24,
                      padding: const EdgeInsets.all(12),
                    ),
                    const Spacer(),
                    _buildStatusBadge(testimony.status),
                    // Space so SOS button doesn't overlap
                    const SizedBox(width: 60),
                  ],
                ),
              ),
            ),
          ),

          // Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    testimony.title,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 28,
                      color: AppColours.textDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppColours.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColours.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location != null
                            ? '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}'
                            : 'No location recorded',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppColours.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Media placeholder
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: type == 'audio'
                  ? _buildMediaPlaceholder('audio')
                  : _buildMediaPlaceholder(type),
            ),
          ),

          // AI Summary section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: _buildSection(
                '',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI Generated Summary',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColours.textDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColours.accentTeal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'AI',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (testimony.ai.summary.toLowerCase().contains('pending'))
                      ...[
                      Text(
                        testimony.ai.summary,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: AppColours.textMuted,
                          fontStyle: FontStyle.italic,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColours.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Analysis in progress',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColours.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        testimony.ai.summary,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: AppColours.textDark,
                          height: 1.6,
                        ),
                      ),
                    ],
                    if (testimony.ai.entities.persons.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'People mentioned:',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColours.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: testimony.ai.entities.persons
                            .map(_buildEntityChip)
                            .toList(),
                      ),
                    ],
                    if (testimony.ai.entities.dates.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Dates mentioned:',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColours.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: testimony.ai.entities.dates
                            .map(_buildEntityChip)
                            .toList(),
                      ),
                    ],
                    if (testimony.ai.entities.locations.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Locations:',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColours.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: testimony.ai.entities.locations
                            .map(_buildEntityChip)
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Blockchain Record section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Blockchain Record',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColours.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isPending)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColours.accentTeal.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) => Opacity(
                              opacity: _pulseAnimation.value,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColours.accentTeal,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Blockchain anchoring in progress',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColours.accentTeal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This evidence is being secured to Arweave and Polygon',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: AppColours.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _buildTxRow(
                      context,
                      label: 'Arweave',
                      fullValue: testimony.arweave.txId,
                    ),
                    const SizedBox(height: 8),
                    _buildTxRow(
                      context,
                      label: 'Polygon',
                      fullValue: testimony.blockchain.polygonTxHash,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Certificate button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Certificate download coming in Phase 5',
                          style: GoogleFonts.dmSans(fontSize: 14),
                        ),
                        backgroundColor: AppColours.primaryBackground,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColours.accentTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.download_outlined, size: 20),
                  label: Text(
                    'Download Certificate',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxRow(BuildContext context,
      {required String label, required String fullValue}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColours.textDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _truncateTx(fullValue),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColours.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => _copyToClipboard(context, fullValue, label),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.copy_outlined,
                size: 16,
                color: AppColours.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
