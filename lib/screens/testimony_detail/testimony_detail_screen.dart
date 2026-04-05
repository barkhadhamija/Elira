import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../theme/app_colours.dart';
import '../../store/app_store.dart';
import '../../models/testimony_model.dart';
import '../../services/testimony_retrieval_service.dart';

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

  // ── Arweave retrieval ────────────────────────────────────────────────────
  bool _isLoadingFromArweave = false;
  String? _arweaveError;
  bool _isDownloadingFile = false;

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

    // Try local file first
    final filePath = testimony.localFilePath;
    if (filePath != null && File(filePath).existsSync()) {
      _initLocalVideo(filePath, testimony.metadata.duration ?? 0);
      return;
    }

    // Try Arweave if local doesn't exist but txId is available
    if (testimony.arweave.txId.isNotEmpty &&
        !testimony.arweave.txId.startsWith('pending')) {
      _loadArweaveVideo(testimony);
      return;
    }
  }

  Future<void> _initLocalVideo(String filePath, int expectedSecs) async {
    VideoPlayerController ctrl = VideoPlayerController.file(File(filePath));
    try {
      await ctrl.initialize();
      await ctrl.seekTo(Duration.zero);

      final reportedSecs = ctrl.value.duration.inSeconds;
      debugPrint('TestimonyDetail — expected: ${expectedSecs}s, reported: ${reportedSecs}s');

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

  /// Load video from Arweave and play it
  Future<void> _loadArweaveVideo(TestimonyModel testimony) async {
    if (!mounted) return;
    setState(() {
      _isLoadingFromArweave = true;
      _arweaveError = null;
    });

    try {
      debugPrint('[TestimonyDetail] Loading from Arweave: ${testimony.arweave.txId}');

      if (testimony.encryption.keyHex.isEmpty || testimony.encryption.ivHex.isEmpty) {
        throw Exception('Missing decryption keys for this testimony');
      }

      final decryptedBytes = await TestimonyRetrievalService.retrieveTestimonyFile(
        arweaveTxId: testimony.arweave.txId,
        keyHex: testimony.encryption.keyHex,
        ivHex: testimony.encryption.ivHex,
      );

      if (decryptedBytes == null) {
        throw Exception('Failed to decrypt file from Arweave');
      }

      // Create temporary file for video playback
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/testimony_${testimony.evidenceId}.mp4');
      await tempFile.writeAsBytes(decryptedBytes);

      // Initialize video player
      final ctrl = VideoPlayerController.file(tempFile);
      await ctrl.initialize();
      await ctrl.seekTo(Duration.zero);

      ctrl.setLooping(false);
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });

      if (mounted) {
        setState(() {
          _videoController = ctrl;
          _videoInitialized = true;
          _isLoadingFromArweave = false;
        });
      }

      debugPrint('[TestimonyDetail] Arweave video loaded successfully');
    } catch (e) {
      debugPrint('[TestimonyDetail] Arweave error: $e');
      if (mounted) {
        setState(() {
          _isLoadingFromArweave = false;
          _arweaveError = e.toString();
        });
      }
    }
  }

  /// Download testimony file from Arweave and save to device
  Future<void> _downloadTestimonyFile(TestimonyModel testimony) async {
    if (!mounted) return;
    setState(() => _isDownloadingFile = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Downloading from Arweave...',
            style: GoogleFonts.dmSans(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1A2A3A),
        ),
      );

      if (testimony.encryption.keyHex.isEmpty || testimony.encryption.ivHex.isEmpty) {
        throw Exception('Missing decryption keys for this testimony');
      }

      final decryptedBytes = await TestimonyRetrievalService.retrieveTestimonyFile(
        arweaveTxId: testimony.arweave.txId,
        keyHex: testimony.encryption.keyHex,
        ivHex: testimony.encryption.ivHex,
      );

      if (decryptedBytes == null) {
        throw Exception('Failed to download');
      }

      // Determine file extension
      String extension = '.bin';
      if (testimony.type == 'video') {
        extension = '.mp4';
      } else if (testimony.type == 'audio') {
        extension = '.m4a';
      } else if (testimony.type == 'pdf' || testimony.type == 'document') {
        extension = '.pdf';
      }

      // Save to Downloads (implementation depends on platform)
        final baseName = testimony.title.trim().isEmpty
          ? 'evidence_${testimony.evidenceId.substring(0, testimony.evidenceId.length > 8 ? 8 : testimony.evidenceId.length)}'
          : testimony.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final fileName = '${baseName}_download$extension';
        final targetFile = await _writeDownloadFile(fileName, decryptedBytes);
        debugPrint('[TestimonyDetail] Downloaded: ${targetFile.path} (${decryptedBytes.length} bytes)');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Saved: ${targetFile.path}',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
            backgroundColor: AppColours.accentTeal,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TestimonyDetail] Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Download failed: $e',
              style: GoogleFonts.dmSans(color: Colors.white),
            ),
            backgroundColor: AppColours.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingFile = false);
      }
    }
  }

  Future<File> _writeDownloadFile(String fileName, List<int> bytes) async {
    final candidates = await _downloadDirectoryCandidates();
    Object? lastError;

    for (final dir in candidates) {
      try {
        await dir.create(recursive: true);
        final file = File(p.join(dir.path, fileName));
        await file.writeAsBytes(bytes, flush: true);
        return file;
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception('Unable to save file on device. Last error: $lastError');
  }

  Future<List<Directory>> _downloadDirectoryCandidates() async {
    final dirs = <Directory>[];

    if (Platform.isAndroid) {
      dirs.add(Directory('/storage/emulated/0/Download'));

      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        dirs.add(Directory(p.join(externalDir.path, 'Download')));
        dirs.add(externalDir);
      }
    }

    dirs.add(await getApplicationDocumentsDirectory());
    return dirs;
  }

  Future<void> _replayFromStart(VideoPlayerController controller) async {
    await controller.seekTo(Duration.zero);
    await controller.play();
    if (mounted) {
      setState(() {});
    }
  }

  // ── Lookup testimony ─────────────────────────────────────────────────────
  TestimonyModel? _findTestimony() {
    final storeTestimonies = ref.read(appProvider).testimonies;
    try {
      return storeTestimonies.firstWhere((t) => t.evidenceId == widget.evidenceId);
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
    final hasArweaveId = testimony.arweave.txId.isNotEmpty && 
                         !testimony.arweave.txId.startsWith('pending');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                // ── Background ─────────────────────────────────────────
                if (isPlayable)
                  VideoPlayer(ctrl!)
                else
                  Container(color: const Color(0xFF1C1A2E)),

                // ── Loading indicator for Arweave ──────────────────────
                if (_isLoadingFromArweave)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppColours.accentTeal,
                          strokeWidth: 2.5,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading from Arweave...',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Error message ──────────────────────────────────────
                if (_arweaveError != null && !isPlayable)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white54,
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Failed to load from Arweave',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Placeholder overlay ────────────────────────────────
                if (!isPlayable && !_isLoadingFromArweave && _arweaveError == null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasArweaveId ? Icons.cloud_download_outlined : Icons.cloud_outlined,
                          color: Colors.white54,
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          hasArweaveId ? 'Tap to load from Arweave' : 'Waiting for Arweave upload...',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Load button (for Arweave videos) ───────────────────
                if (!isPlayable && hasArweaveId && !_isLoadingFromArweave)
                  GestureDetector(
                    onTap: () => _loadArweaveVideo(testimony),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),

                // ── Play/Pause button ──────────────────────────────────
                if (isPlayable)
                  GestureDetector(
                    onTap: () async {
                      if (isPlaying) {
                        ctrl!.pause();
                      } else {
                        final duration = ctrl!.value.duration;
                        final position = ctrl.value.position;
                        if (duration > Duration.zero &&
                            position >= duration - const Duration(milliseconds: 300)) {
                          await ctrl.seekTo(Duration.zero);
                        }
                        ctrl.play();
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

                // ── Progress bar ───────────────────────────────────────
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

                // ── Fullscreen button ──────────────────────────────────
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

                if (isPlayable)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _replayFromStart(ctrl!),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.replay_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                // ── Download button (for documents)  ───────────────────
                if (testimony.type != 'video' && hasArweaveId)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _downloadTestimonyFile(testimony),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isDownloadingFile ? Colors.grey : AppColours.accentTeal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _isDownloadingFile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.download_outlined,
                                color: Colors.white,
                                size: 18,
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

  // ── Download / Documents section ─────────────────────────────────────────
  Widget _buildDownloadSection(TestimonyModel testimony) {
    final txId = testimony.arweave.txId;
    final isPending = txId.isEmpty || txId.startsWith('pending');

    if (isPending) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.cloud_download_outlined,
              color: AppColours.textMuted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Stored on Arweave',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColours.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColours.accentTeal.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
            color: AppColours.accentTeal.withOpacity(0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          testimony.type == 'video'
                              ? 'Video Recording'
                              : testimony.type == 'audio'
                                  ? 'Audio Recording'
                                  : 'Document',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColours.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'TX: ${txId.substring(0, 16)}...',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColours.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _downloadTestimonyFile(testimony),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isDownloadingFile
                            ? Colors.grey.shade400
                            : AppColours.accentTeal,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _isDownloadingFile
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.download_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Download',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'View on Arweave: $txId',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                      action: SnackBarAction(
                        label: 'Copy',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: txId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'TX ID copied to clipboard',
                                style: GoogleFonts.dmSans(fontSize: 12),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                child: Text(
                  'View Arweave Transaction',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColours.accentTeal,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
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
            child: Padding(
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

  Widget _buildAiMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColours.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColours.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColours.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
        return Colors.green.shade700;
      case 'negative':
        return Colors.red.shade700;
      case 'neutral':
        return AppColours.brandBlue;
      case 'distressed':
        return Colors.orange.shade800;
      default:
        return AppColours.textDark;
    }
  }

  Color _getRiskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH':
        return Colors.red.shade800;
      case 'MEDIUM':
        return Colors.orange.shade700;
      case 'LOW':
        return Colors.green.shade700;
      default:
        return AppColours.textMuted;
    }
  }

  // ── Main build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Watch so we react if new testimonies are added
    final storeTestimonies = ref.watch(appProvider).testimonies;
    TestimonyModel? testimony;
    try {
      testimony = storeTestimonies.firstWhere((t) => t.evidenceId == widget.evidenceId);
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
                    icon: Icon(Icons.arrow_back, color: AppColours.textDark),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ),
              ),
              Expanded(
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
                      icon: Icon(Icons.arrow_back, color: AppColours.textDark),
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

          // ── Video / media section ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: type == 'video'
                  ? _buildVideoSection(testimony)
                  : _buildMediaPlaceholder(type),
            ),
          ),

          // ── Documents / Downloads section ───────────────────────────
          if (testimony.arweave.txId.isNotEmpty && 
              !testimony.arweave.txId.startsWith('pending'))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _buildDownloadSection(testimony),
              ),
            ),

          // ── AI Analysis Section ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'AI Evidence Analysis',
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
                  const SizedBox(height: 16),
                  
                  // Summary Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColours.accentLavenderSoft.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColours.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Executive Summary',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColours.brandBlue,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          testimony.ai.summary.isNotEmpty 
                            ? testimony.ai.summary 
                            : 'AI is analyzing this evidence...',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            color: AppColours.textDark,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Metadata Row: Sentiment & Risk
                  Row(
                    children: [
                      if (testimony.ai.sentiment.isNotEmpty)
                        Expanded(
                          child: _buildAiMetricCard(
                            label: 'Sentiment',
                            value: testimony.ai.sentiment.toUpperCase(),
                            icon: Icons.face_retouching_natural_rounded,
                            color: _getSentimentColor(testimony.ai.sentiment),
                          ),
                        ),
                      const SizedBox(width: 12),
                      if (testimony.ai.riskLevel.isNotEmpty)
                        Expanded(
                          child: _buildAiMetricCard(
                            label: 'Risk Level',
                            value: testimony.ai.riskLevel,
                            icon: Icons.warning_amber_rounded,
                            color: _getRiskColor(testimony.ai.riskLevel),
                          ),
                        ),
                    ],
                  ),

                  if (testimony.ai.transcript.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'AI Transcription',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColours.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColours.divider),
                      ),
                      child: Text(
                        testimony.ai.transcript,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: AppColours.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  if (testimony.ai.entities.persons.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Detected Entities',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColours.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      children: [
                        ...testimony.ai.entities.persons.map((p) => _buildEntityChip('Person: $p')),
                        ...testimony.ai.entities.dates.map((d) => _buildEntityChip('Date: $d')),
                        ...testimony.ai.keywords.map((k) => _buildEntityChip('Tag: $k')),
                      ],
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
                                decoration: BoxDecoration(
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
                      label: 'Evidence',
                      fullValue: testimony.evidenceId,
                    ),
                    const SizedBox(height: 8),
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
