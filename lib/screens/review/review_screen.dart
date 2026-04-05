import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';

import '../../data/mock_data.dart';
import '../../models/testimony_model.dart';
import '../../services/backend_api_service.dart';
import '../../store/app_store.dart';
import '../../theme/app_colours.dart';
import '../../utils/session_manager.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final String filePath;
  final String title;
  final int duration;
  final Map<String, dynamic>? gps;
  final String mimeType;

  const ReviewScreen({
    super.key,
    required this.filePath,
    required this.title,
    required this.duration,
    required this.gps,
    required this.mimeType,
  });

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _isPlaying = false;
  bool _isSaving = false;
  bool _isCompressing = false;
  String? _compressionStatus;
  String? _fileSizeLabel;
  late final TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _initVideo();
    _loadFileSize();
  }

  bool get _isAudio => widget.mimeType.startsWith('audio');

  Future<void> _loadFileSize() async {
    if (kIsWeb) return; // blob URLs have no local size
    try {
      final bytes = await File(widget.filePath).length();
      if (mounted) {
        setState(() => _fileSizeLabel = _formatFileSize(bytes));
      }
    } catch (_) {}
  }

  Future<void> _initVideo() async {
    VideoPlayerController ctrl;

    if (kIsWeb) {
      // On web, the camera package produces a network-accessible blob URL
      ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.filePath));
    } else {
      ctrl = VideoPlayerController.file(File(widget.filePath));
    }

    try {
      await ctrl.initialize();
      await ctrl.seekTo(Duration.zero);

      final reportedSecs = ctrl.value.duration.inSeconds;
      final expectedSecs = widget.duration;

      debugPrint('ELIRA DEBUG — Video duration: ${ctrl.value.duration}');
      debugPrint('ELIRA DEBUG — Video size: ${ctrl.value.size}');
      debugPrint(
        'ELIRA DEBUG — Expected duration: ${expectedSecs}s, reported: ${reportedSecs}s',
      );

      // If the duration read is significantly less than what we recorded
      // (more than 3 s gap) or zero, iOS has not yet flushed the full
      // moov atom — dispose and reinitialise once after a short wait.
      final bool durationUnreliable =
          reportedSecs == 0 ||
          (expectedSecs > 0 && (expectedSecs - reportedSecs) > 3);

      if (durationUnreliable) {
        debugPrint('ELIRA DEBUG — Duration mismatch, retrying after 1s...');
        ctrl.removeListener(_videoListener);
        await ctrl.dispose();
        await Future.delayed(const Duration(seconds: 1));

        if (kIsWeb) {
          ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.filePath));
        } else {
          ctrl = VideoPlayerController.file(File(widget.filePath));
        }
        await ctrl.initialize();
        await ctrl.seekTo(Duration.zero);
        debugPrint('ELIRA DEBUG — Retry duration: ${ctrl.value.duration}');
      }

      ctrl.setLooping(false);
      ctrl.addListener(_videoListener);
      if (mounted) {
        setState(() {
          _videoController = ctrl;
          _videoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Video init error: $e');
      if (mounted) {
        setState(() {
          _videoController = ctrl;
          _videoInitialized = false;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted) return;
    final ctrl = _videoController;
    if (ctrl == null) return;
    final playing = ctrl.value.isPlaying;
    if (playing != _isPlaying) {
      setState(() => _isPlaying = playing);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m == 0) return '$s sec';
    if (s == 0) return '$m min';
    return '$m min $s sec';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Video compression ────────────────────────────────────────────────────
  Future<File?> _compressVideo(String videoPath) async {
    if (kIsWeb) {
      // Web doesn't support video compression
      debugPrint('ELIRA DEBUG — Skipping compression on web');
      return null;
    }

    try {
      debugPrint('ELIRA DEBUG — Starting video compression');
      setState(() {
        _isCompressing = true;
        _compressionStatus = 'Compressing video...';
      });

      final originalSize = await File(videoPath).length();
      final selectedQuality = originalSize > 75 * 1024 * 1024
          ? VideoQuality.Res960x540Quality
          : originalSize > 25 * 1024 * 1024
          ? VideoQuality.Res640x480Quality
          : VideoQuality.MediumQuality;

      final mediaInfo = await VideoCompress.compressVideo(
        videoPath,
        quality: selectedQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 20,
      );

      if (mediaInfo != null && mediaInfo.file != null) {
        final compressedSize = mediaInfo.file!.lengthSync();
        if (compressedSize >= originalSize) {
          debugPrint(
            'ELIRA DEBUG — Compression did not reduce size; keeping original file',
          );
          return File(videoPath);
        }

        final ratio = ((1 - (compressedSize / originalSize)) * 100)
            .toStringAsFixed(1);

        debugPrint('ELIRA DEBUG — Compression complete');
        debugPrint(
          'Original: ${_formatFileSize(originalSize)} → Compressed: ${_formatFileSize(compressedSize)} ($ratio% reduction)',
        );

        return mediaInfo.file;
      }
    } catch (e) {
      debugPrint('ELIRA DEBUG — Compression error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _compressionStatus = null;
        });
      }
    }

    return null;
  }

  // ── Discard flow ─────────────────────────────────────────────────────────
  Future<void> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColours.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Discard this recording?',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 20,
            color: AppColours.textDark,
          ),
        ),
        content: Text(
          'This cannot be undone.',
          style: GoogleFonts.dmSans(fontSize: 15, color: AppColours.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: AppColours.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Discard',
              style: GoogleFonts.dmSans(
                color: AppColours.dangerRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _videoController?.removeListener(_videoListener);
      await _videoController?.dispose();
      _videoController = null;
      if (mounted) context.go('/home');
    }
  }

  // ── Save flow ─────────────────────────────────────────────────────────────
  Future<void> _saveTestimony() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please give this testimony a title',
            style: GoogleFonts.dmSans(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1A2A3A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Compress video if on mobile and file is large
      String filePathToUpload = widget.filePath;
      if (!kIsWeb && widget.mimeType.startsWith('video')) {
        final originalSize = await File(widget.filePath).length();
        // Compress any notable video, and get aggressive for larger files.
        if (originalSize > 5 * 1024 * 1024) {
          debugPrint(
            'ELIRA DEBUG — File ${_formatFileSize(originalSize)} will be compressed before upload...',
          );
          final compressedFile = await _compressVideo(widget.filePath);
          if (compressedFile != null) {
            filePathToUpload = compressedFile.path;
            debugPrint(
              'ELIRA DEBUG — Using compressed file: $filePathToUpload',
            );
          }
        }
      }

      // Read and upload file
      final fileBytes = await File(filePathToUpload).readAsBytes();
      final uid = await SessionManager.getUserId() ?? mockUser['uid'] as String;
      final uploadResult = await BackendApiService.uploadEvidence(
        base64Content: base64Encode(fileBytes),
        fileType: widget.mimeType,
        userId: uid,
      );

      final uploadData =
          uploadResult['data'] as Map<String, dynamic>? ?? <String, dynamic>{};

      final evidenceId =
          (uploadData['id'] ?? 'local_${DateTime.now().millisecondsSinceEpoch}')
              .toString();
      final txId = (uploadData['arweaveTxId'] ?? '').toString();
      final fileHash = (uploadData['fileHash'] ?? '').toString();
      final polygonHash = (uploadData['polygonTxHash'] ?? '').toString();
      final keyHex = (uploadData['keyHex'] ?? '').toString();
      final ivHex = (uploadData['ivHex'] ?? '').toString();

      // Build model matching Firestore schema exactly
      final gps = widget.gps;
      final mediaType = widget.mimeType.startsWith('audio') ? 'audio' : 'video';
      final createdAt = DateTime.now().toIso8601String();
      final status = polygonHash.isNotEmpty ? 'anchored' : 'uploading';

      final newTestimony = TestimonyModel(
        evidenceId: evidenceId,
        caseId: mockCase['caseId'] as String,
        userId: uid,
        type: mediaType,
        title: title,
        localFilePath: widget.filePath,
        arweave: ArweaveData(
          txId: txId,
          url: txId.isEmpty ? '' : 'https://arweave.net/$txId',
        ),
        blockchain: BlockchainData(
          fileHash: fileHash,
          polygonTxHash: polygonHash,
        ),
        encryption: EncryptionData(
          keyId: 'local',
          status: 'active',
          keyHex: keyHex,
          ivHex: ivHex,
        ),
        metadata: MetadataModel(
          timestamp: DateTime.now().toIso8601String(),
          location: gps != null
              ? LocationData(
                  lat: (gps['lat'] as num).toDouble(),
                  lng: (gps['lng'] as num).toDouble(),
                )
              : null,
          duration: widget.duration,
          size: 0,
        ),
        ai: AiData(
          transcript: '',
          summary: 'AI analysis pending. Summary will appear once processed.',
          sentiment: 'neutral',
          riskLevel: 'LOW',
          keywords: const [],
          entities: EntitiesData(persons: [], dates: [], locations: []),
        ),
        status: status,
        createdAt: createdAt,
      );

      // Add to Riverpod global state
      ref.read(appProvider.notifier).addTestimony(newTestimony);

      // Dispose video controller then navigate
      _videoController?.removeListener(_videoListener);
      await _videoController?.dispose();
      _videoController = null;

      if (mounted) context.go('/home');
    } catch (e) {
      debugPrint('Save testimony error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed. Ensure localhost backend is running.',
            ),
            backgroundColor: AppColours.dangerRed,
          ),
        );
      }
    }
  }

  // ── Audio player ──────────────────────────────────────────────────────────
  Widget _buildAudioPlayer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      height: 200,
      decoration: BoxDecoration(color: Color(0xFF1C1A2E)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Waveform icon
            Icon(
              Icons.graphic_eq_rounded,
              color: AppColours.accentTeal,
              size: 56,
            ),
            const SizedBox(height: 16),
            // Duration label
            Text(
              _formatDuration(widget.duration),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white60,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            // Play/Pause button
            GestureDetector(
              onTap: () {
                final ctrl = _videoController;
                if (ctrl != null && _videoInitialized) {
                  if (ctrl.value.isPlaying) {
                    ctrl.pause();
                  } else {
                    ctrl.play();
                  }
                }
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColours.accentTeal,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.surface,
      body: Stack(
        children: [
          // ── Scrollable content area ────────────────────────────────────
          Positioned.fill(
            bottom: 148, // reserve space for bottom buttons
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top bar ──────────────────────────────────────────
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _confirmDiscard,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColours.textDark.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                color: AppColours.textDark,
                                size: 20,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Review testimony',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSerifDisplay(
                                fontSize: 24,
                                color: AppColours.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // mirror back button
                        ],
                      ),
                    ),
                  ),

                  // ── Media player ──────────────────────────────────────
                  if (_isAudio)
                    _buildAudioPlayer()
                  else
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // background
                          Container(color: const Color(0xFF1C1A2E)),

                          // video or spinner
                          if (_videoInitialized && _videoController != null)
                            VideoPlayer(_videoController!)
                          else
                            CircularProgressIndicator(
                              color: AppColours.accentTeal,
                              strokeWidth: 2.5,
                            ),

                          // play/pause overlay
                          if (_videoInitialized && _videoController != null)
                            GestureDetector(
                              onTap: () {
                                final ctrl = _videoController!;
                                if (ctrl.value.isPlaying) {
                                  ctrl.pause();
                                } else {
                                  ctrl.play();
                                }
                              },
                              child: AnimatedOpacity(
                                opacity: _isPlaying ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  if (!_isAudio &&
                      _videoInitialized &&
                      _videoController != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: VideoProgressIndicator(
                        _videoController!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: AppColours.accentTeal,
                          bufferedColor: AppColours.accentTeal.withOpacity(0.2),
                          backgroundColor: AppColours.divider,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ── Details ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title — editable
                        TextField(
                          controller: _titleController,
                          style: GoogleFonts.dmSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColours.textDark,
                          ),
                          cursorColor: AppColours.accentTeal,
                          decoration: InputDecoration(
                            hintText: 'Give this testimony a title…',
                            hintStyle: GoogleFonts.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColours.textMuted.withOpacity(0.5),
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColours.accentTeal.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Metadata row
                        _MetaRow(
                          icon: Icons.timer_outlined,
                          label: _formatDuration(widget.duration),
                          color: AppColours.textMuted,
                        ),

                        const SizedBox(height: 8),

                        // GPS tag
                        _MetaRow(
                          icon: Icons.location_on_outlined,
                          label: widget.gps != null
                              ? 'Location tagged'
                              : 'No location recorded',
                          color: widget.gps != null
                              ? AppColours.accentTeal
                              : AppColours.textMuted,
                        ),

                        const SizedBox(height: 8),

                        // Mime type
                        _MetaRow(
                          icon: _isAudio
                              ? Icons.mic_outlined
                              : Icons.videocam_outlined,
                          label: widget.mimeType,
                          color: AppColours.textMuted,
                        ),

                        if (_fileSizeLabel != null) ...[
                          const SizedBox(height: 8),
                          _MetaRow(
                            icon: Icons.sd_card_outlined,
                            label: _fileSizeLabel!,
                            color: AppColours.textMuted,
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Info notice
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColours.accentLavenderSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColours.accentTeal,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Saving will anchor this testimony to Arweave and the Polygon blockchain, making it tamper-proof.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: AppColours.textDark,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom action buttons — always visible ────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColours.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Save button ───────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isSaving || _isCompressing)
                              ? null
                              : _saveTestimony,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColours.accentTeal,
                            disabledBackgroundColor: AppColours.accentTeal
                                .withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isCompressing
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Compressing...',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : (_isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        'Save testimony',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      )),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── Discard button ────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: (_isSaving || _isCompressing)
                              ? null
                              : _confirmDiscard,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColours.divider,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Discard recording',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColours.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
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

// ── Small helper widget ──────────────────────────────────────────────────────
class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.dmSans(fontSize: 14, color: color)),
      ],
    );
  }
}
