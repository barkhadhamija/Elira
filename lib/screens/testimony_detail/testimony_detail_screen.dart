import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

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
  // ── Pulse animation for pending entries ──────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Video playback ───────────────────────────────────────────────────────
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) => _initVideo());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_videoInitialized) {
      _videoController?.dispose();
    }
    super.dispose();
  }

  // ── Video initialisation ─────────────────────────────────────────────────
  Future<void> _initVideo() async {
    final testimony = _findTestimony();
    if (testimony == null) return;

    // Only initialise for locally recorded entries that still exist on disk
    final filePath = testimony.localFilePath;
    if (filePath == null || !File(filePath).existsSync()) return;

    final expectedSecs = testimony.metadata.duration ?? 0;

    VideoPlayerController ctrl = VideoPlayerController.file(File(filePath));
    try {
      await ctrl.initialize();
      await ctrl.seekTo(Duration.zero);

      final reportedSecs = ctrl.value.duration.inSeconds;
      debugPrint('TestimonyDetail — expected: ${expectedSecs}s, reported: ${reportedSecs}s');

      // If the reported duration is significantly less than what was recorded
      // (more than 3 s gap) or zero, iOS has not yet flushed the moov atom —
      // dispose and reinitialise once after a short wait.
      final bool durationUnreliable = reportedSecs == 0 ||
          (expectedSecs > 0 && (expectedSecs - reportedSecs) > 3);

      if (durationUnreliable) {
        debugPrint('TestimonyDetail — Duration mismatch, retrying after 1s...');
        await ctrl.dispose();
        await Future.delayed(const Duration(seconds: 1));
        ctrl = VideoPlayerController.file(File(filePath));
        await ctrl.initialize();
        await ctrl.seekTo(Duration.zero);
        debugPrint('TestimonyDetail — Retry duration: ${ctrl.value.duration}');
      }

      ctrl.setLooping(false);
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });
      if (mounted) {
        setState(() {
          _videoController = ctrl;
          _videoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('TestimonyDetail — video init error: $e');
      ctrl.dispose();
    }
  }

  // ── Lookup testimony ─────────────────────────────────────────────────────
  TestimonyModel? _findTestimony() {
    final storeTestimonies = ref.read(appProvider).testimonies;
    final all = [...storeTestimonies, ...mockTestimonies];
    try {
      return all.firstWhere((t) => t.evidenceId == widget.evidenceId);
    } catch (_) {
      return null;
    }
  }

  // ── Formatting helpers ───────────────────────────────────────────────────
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
    if (m == 0) return '$s sec';
    if (s == 0) return '$m min';
    return '$m min $s sec';
  }

  String _truncateTx(String tx) {
    if (tx.length <= 18) return tx;
    return '${tx.substring(0, 8)}...${tx.substring(tx.length - 8)}';
  }

  void _copyToClipboard(String value) {
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

  // ── Status badge ─────────────────────────────────────────────────────────
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

  // ── Video section ─────────────────────────────────────────────────────────
  Widget _buildVideoSection(TestimonyModel testimony) {
    final isPlayable = _videoInitialized && _videoController != null;
    final ctrl = _videoController;
    final isPlaying = ctrl?.value.isPlaying ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                // ── Background / video frame ───────────────────────────
                if (isPlayable)
                  VideoPlayer(ctrl!)
                else
                  Container(color: const Color(0xFF1C1A2E)),

                // ── Placeholder overlay for non-playable entries ───────
                if (!isPlayable)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Available after Arweave upload',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Play / pause button for playable entries ───────────
                if (isPlayable)
                  GestureDetector(
                    onTap: () {
                      if (isPlaying) {
                        ctrl!.pause();
                      } else {
                        ctrl!.play();
                      }
                      setState(() {});
                    },
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Progress bar — only for playable entries ───────────
                if (isPlayable)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: VideoProgressIndicator(
                      ctrl!,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: AppColours.accentTeal,
                        bufferedColor: AppColours.accentTeal.withOpacity(0.2),
                        backgroundColor: Colors.white24,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),

                // ── Fullscreen button — only for playable entries ──────
                if (isPlayable)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          _FullscreenVideoRoute(videoController: ctrl!),
                        );
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Non-video media placeholder ───────────────────────────────────────────
  Widget _buildMediaPlaceholder(String type) {
    IconData icon;
    switch (type) {
      case 'image':
        icon = Icons.image_outlined;
        break;
      case 'audio':
        icon = Icons.mic_outlined;
        break;
      default:
        icon = Icons.description_outlined;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: AppColours.primaryBackground,
          child: Center(
            child: Icon(icon, color: Colors.white54, size: 52),
          ),
        ),
      ),
    );
  }

  // ── Entity chip ───────────────────────────────────────────────────────────
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

  // ── TX hash row ───────────────────────────────────────────────────────────
  Widget _buildTxRow({required String label, required String fullValue}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColours.accentLavenderSoft,
        borderRadius: BorderRadius.circular(12),
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
            onTap: () => _copyToClipboard(fullValue),
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

  // ── Main build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Watch so we react if new testimonies are added
    final storeTestimonies = ref.watch(appProvider).testimonies;
    final all = [...storeTestimonies, ...mockTestimonies];
    TestimonyModel? testimony;
    try {
      testimony = all.firstWhere((t) => t.evidenceId == widget.evidenceId);
    } catch (_) {
      testimony = null;
    }

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
                    icon: const Icon(Icons.arrow_back, color: AppColours.textDark),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
          // ── Top bar ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.arrow_back, color: AppColours.textDark),
                      iconSize: 24,
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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

          // ── Title ─────────────────────────────────────────────────────
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
                      const Icon(
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

          // ── Video / media section ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: type == 'video'
                  ? _buildVideoSection(testimony)
                  : _buildMediaPlaceholder(type),
            ),
          ),

          // ── AI Summary ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
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
                  if (testimony.ai.summary.toLowerCase().contains('pending')) ...[
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
                        const Icon(Icons.access_time,
                            size: 14, color: AppColours.textMuted),
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

          // ── Blockchain Record ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
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
                      label: 'Arweave',
                      fullValue: testimony.arweave.txId,
                    ),
                    const SizedBox(height: 8),
                    _buildTxRow(
                      label: 'Polygon',
                      fullValue: testimony.blockchain.polygonTxHash,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Certificate button ─────────────────────────────────────────
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
}

// ── Fullscreen video route ────────────────────────────────────────────────────
// Uses raw MaterialPageRoute with transparent-background to overlay fullscreen.
// Reuses the same VideoPlayerController — does NOT create a new one.
class _FullscreenVideoRoute extends PageRoute<void> {
  final VideoPlayerController videoController;

  _FullscreenVideoRoute({required this.videoController})
      : super(fullscreenDialog: false);

  @override
  bool get opaque => true;

  @override
  Color? get barrierColor => Colors.black;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => false;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _FullscreenVideoPage(controller: videoController);
  }
}

class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullscreenVideoPage({required this.controller});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final isPlaying = ctrl.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: ctrl.value.aspectRatio,
              child: VideoPlayer(ctrl),
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ),
          // Play/pause
          Center(
            child: GestureDetector(
              onTap: () {
                if (isPlaying) {
                  ctrl.pause();
                } else {
                  ctrl.play();
                }
                setState(() {});
              },
              child: AnimatedOpacity(
                opacity: isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ),
            ),
          ),
          // Progress bar
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 16,
            right: 16,
            child: VideoProgressIndicator(
              ctrl,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: AppColours.accentTeal,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
