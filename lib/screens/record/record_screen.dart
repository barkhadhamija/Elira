import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:record/record.dart';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../main.dart' show SosModal;
import '../../store/app_store.dart';
import '../../theme/app_colours.dart';

// ── Mode selection ──────────────────────────────────────────────────────────
enum _RecordMode { video, audio }

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with TickerProviderStateMixin {
  // ── Mode ─────────────────────────────────────────────────────────────────
  _RecordMode _mode = _RecordMode.video;

  // ── Camera ──────────────────────────────────────────────────────────────────
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  String? _cameraError;
  int _selectedCameraIndex = 0;

  // ── Recording ───────────────────────────────────────────────────────────────
  bool _isRecording = false;
  bool _isFlipping = false;
  bool _processingVideo = false;
  String _processingMessage = 'Processing video...';
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  final List<String> _segments = [];

  // ── Audio recording ──────────────────────────────────────────────────────
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isAudioRecording = false;
  bool _processingAudio = false;
  int _audioDuration = 0;
  Timer? _audioTimer;

  // ── Pulse animation for mic button ──────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim1;
  late Animation<double> _pulseAnim2;

  // ── Timestamp overlay ────────────────────────────────────────────────────
  String _timestampText = '';
  Timer? _clockTimer;

  // ── GPS ──────────────────────────────────────────────────────────────────
  Map<String, double>? _gpsCoordinates;

  // ── Reflection prompts ───────────────────────────────────────────────────
  final List<String> _reflectionPrompts = [
    '"What is one small thing that brought you peace today?"',
    '"What are you proud of yourself for today?"',
    '"What do you need that you haven\'t given yourself lately?"',
    '"What would you tell a friend feeling the way you feel right now?"',
    '"What is one thing you\'re grateful for in this moment?"',
  ];
  late int _promptIndex;

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _formatTimestamp(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  $h:$m:$s';
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Init ─────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _promptIndex = math.Random().nextInt(_reflectionPrompts.length);

    // Pulse rings for audio mic button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseAnim1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _pulseAnim2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _pulseController.repeat();

    _timestampText = _formatTimestamp(DateTime.now());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _timestampText = _formatTimestamp(DateTime.now());
        });
      }
    });

    _initCamera();
    _initGps();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraError = 'no_camera');
        return;
      }
      final frontIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;
      await _startCamera(_selectedCameraIndex);
    } catch (e) {
      setState(() {
        _cameraError = kIsWeb ? 'web_denied' : 'permission_denied';
      });
    }
  }

  Future<void> _startCamera(int index) async {
    final previous = _controller;
    if (previous != null) await previous.dispose();

    final camera = _cameras[index];
    final controller = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isCameraInitialized = true;
        _cameraError = null;
        _selectedCameraIndex = index;
      });
    } on CameraException catch (e) {
      await controller.dispose();
      final code = e.code.toLowerCase();
      setState(() {
        _cameraError = (code.contains('permission') || code.contains('denied'))
            ? (kIsWeb ? 'web_denied' : 'permission_denied')
            : 'no_camera';
      });
    }
  }

  Future<void> _initGps() async {
    final gpsConsent = ref.read(appProvider).gpsConsent;
    if (!gpsConsent) return;
    try {
      await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _gpsCoordinates = {'lat': pos.latitude, 'lng': pos.longitude};
        });
      }
    } catch (_) {}
  }

  // ── Flip camera ───────────────────────────────────────────────────────────
  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _isFlipping || _processingVideo) return;
    _isFlipping = true;

    final currentDirection = _cameras[_selectedCameraIndex].lensDirection;
    final targetDirection = currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final targetIndex =
        _cameras.indexWhere((c) => c.lensDirection == targetDirection);
    final nextIndex = targetIndex != -1
        ? targetIndex
        : (_selectedCameraIndex + 1) % _cameras.length;

    if (_isRecording) {
      final ctrl = _controller;
      if (ctrl != null && ctrl.value.isRecordingVideo) {
        try {
          final xFile = await ctrl.stopVideoRecording();
          _segments.add(xFile.path);
        } catch (e) {
          debugPrint('Flip: error stopping segment: $e');
        }
      }
      setState(() => _isCameraInitialized = false);
      await _startCamera(nextIndex);
      final newCtrl = _controller;
      if (newCtrl != null && newCtrl.value.isInitialized) {
        try {
          await newCtrl.startVideoRecording();
        } catch (e) {
          debugPrint('Flip: error starting new segment: $e');
        }
      }
    } else {
      setState(() => _isCameraInitialized = false);
      await _startCamera(nextIndex);
    }

    _isFlipping = false;
  }

  // ── Recording ─────────────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      await ctrl.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingDuration++);
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    debugPrint('ELIRA DEBUG — Stop tapped at: ${DateTime.now().toIso8601String()}');
    final ctrl = _controller;

    XFile xFile;
    try {
      xFile = await ctrl!.stopVideoRecording();
    } catch (e) {
      debugPrint('Stop recording error: $e');
      return;
    }

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final duration = _recordingDuration;
    final gps = _gpsCoordinates;

    _segments.add(xFile.path);
    final filePath = _segments.isNotEmpty ? _segments.last : '';
    _segments.clear();

    if (!mounted) return;

    setState(() {
      _isRecording = false;
      _processingVideo = true;
      _processingMessage = 'Processing video...';
    });

    if (filePath.isEmpty) {
      if (mounted) setState(() => _processingVideo = false);
      return;
    }

    String finalPath = filePath;

    if (!kIsWeb) {
      final file = File(filePath);
      int previousSize = -1;
      int currentSize = await file.length();

      while (currentSize != previousSize) {
        previousSize = currentSize;
        await Future.delayed(const Duration(milliseconds: 500));
        currentSize = await file.length();
      }

      await Future.delayed(const Duration(milliseconds: 500));

      final finalSize = await file.length();
      if (finalSize < 1000) {
        if (mounted) {
          setState(() => _processingVideo = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording failed. Please try again.')),
          );
        }
        return;
      }

      if (mounted) setState(() => _processingMessage = 'Preparing video...');
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final copyPath = p.join(
          docsDir.path,
          'elira_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        await file.copy(copyPath);
        finalPath = copyPath;
      } catch (copyError) {
        debugPrint('ELIRA DEBUG — File copy failed: $copyError');
      }

      if (mounted) setState(() => _processingMessage = 'Almost ready...');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() => _processingVideo = false);
      context.go('/review', extra: {
        'filePath': finalPath,
        'title': '',
        'duration': duration,
        'gps': gps,
        'mimeType': 'video/mp4',
      });
    }
  }

  // ── SOS ───────────────────────────────────────────────────────────────────
  // Shows the countdown modal from main.dart which calls 112 + notifies
  // saved contacts when the timer reaches 0 (or user cancels it).
  void _showSosModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      barrierDismissible: false,
      builder: (_) => const SosModal(),
    );
  }

  // ── Audio recording methods ───────────────────────────────────────────────
  Future<void> _startAudioRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Microphone permission is required.')),
        );
      }
      return;
    }
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final outputPath = p.join(
        docsDir.path,
        'elira_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: outputPath,
      );
      setState(() {
        _isAudioRecording = true;
        _audioDuration = 0;
      });
      _audioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _audioDuration++);
      });
    } catch (e) {
      debugPrint('Audio start error: $e');
    }
  }

  Future<void> _stopAudioRecording() async {
    _audioTimer?.cancel();
    _audioTimer = null;
    final duration = _audioDuration;
    final gps = _gpsCoordinates;

    String? filePath;
    try {
      filePath = await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }

    if (!mounted) return;
    setState(() {
      _isAudioRecording = false;
      _processingAudio = true;
    });

    if (filePath == null || filePath.isEmpty) {
      setState(() => _processingAudio = false);
      return;
    }

    // Wait for file to finish writing
    final file = File(filePath);
    int previousSize = -1;
    int currentSize = await file.length();
    while (currentSize != previousSize) {
      previousSize = currentSize;
      await Future.delayed(const Duration(milliseconds: 300));
      currentSize = await file.length();
    }

    if (!mounted) return;
    setState(() => _processingAudio = false);

    context.go('/review', extra: {
      'filePath': filePath,
      'title': '',
      'duration': duration,
      'gps': gps,
      'mimeType': 'audio/aac',
    });
  }

  // ── Dispose ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _clockTimer?.cancel();
    _recordingTimer?.cancel();
    _audioTimer?.cancel();
    _audioRecorder.dispose();
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_cameraError != null && _mode == _RecordMode.video) {
      return _buildErrorState(_cameraError!);
    }

    return Scaffold(
      backgroundColor: AppColours.surface,
      body: _mode == _RecordMode.video
          ? _buildVideoFrame()
          : _buildAudioFrame(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIDEO FRAME
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildVideoFrame() {
    final bool gpsConsent = ref.watch(appProvider).gpsConsent;
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // ── Camera preview fills screen ──────────────────────────────────
        Positioned.fill(
          child: _isCameraInitialized && _controller != null
              ? _buildCameraPreview(gpsConsent)
              : _buildLoadingPreview(),
        ),

        // ── Top bar: back + timer + flip ─────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Back
                  GestureDetector(
                    onTap: () async {
                      _recordingTimer?.cancel();
                      final ctrl = _controller;
                      _controller = null;
                      await ctrl?.dispose();
                      if (mounted) context.go('/home');
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 18),
                    ),
                  ),

                  const Spacer(),

                  // Timer + live dot
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? AppColours.dangerRed
                                : Colors.white54,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isRecording
                              ? _formatDuration(_recordingDuration)
                              : '00:00',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Flip camera
                  GestureDetector(
                    onTap: _cameras.length > 1 ? _flipCamera : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.flip_camera_ios_rounded,
                        color: _cameras.length > 1
                            ? Colors.white
                            : Colors.white30,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── "LIVE ENCRYPTED STREAM" label ─────────────────────────────────
        Positioned(
          top: topPadding + 62,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'LIVE ENCRYPTED STREAM',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white60,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),

        // ── VIDEO / AUDIO toggle pill ─────────────────────────────────────
        Positioned(
          top: topPadding + 82,
          left: 0,
          right: 0,
          child: Center(child: _buildModeToggle(dark: true)),
        ),

        // ── Processing overlay ────────────────────────────────────────────
        if (_processingVideo)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColours.brandBlue,
                      strokeWidth: 2,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _processingMessage,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Bottom controls ───────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Camera icon — left
                  Expanded(child: _buildGpsTag(ref.watch(appProvider).gpsConsent)),

                  // Record / Stop — centre
                  _buildRecordButton(),

                  // Mic icon — right
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: Colors.white24, width: 1.5),
                        ),
                        child: const Icon(Icons.mic_none_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUDIO FRAME
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAudioFrame() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        // ── Top app bar ──────────────────────────────────────────────────
        SizedBox(
          height: topPadding + 56,
          child: Container(
            color: AppColours.surface,
            padding: EdgeInsets.only(
                top: topPadding, left: 16, right: 16, bottom: 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/home'),
                  child: const Icon(Icons.lock_outline,
                      color: AppColours.brandBlue, size: 22),
                ),
                const Spacer(),
                Text(
                  'ELIRA',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColours.brandBlue,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                // Avatar — opens Settings
                GestureDetector(
                  onTap: () => context.go('/settings'),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColours.accentLavenderSoft,
                    child: const Icon(Icons.person,
                        color: AppColours.brandBlue, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── VIDEO / AUDIO toggle ─────────────────────────────────────────
        const SizedBox(height: 12),
        _buildModeToggle(dark: false),
        const SizedBox(height: 24),

        // ── "Ready to record" heading ────────────────────────────────────
        Text(
          'Ready to record',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColours.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your sanctuary is listening. Speak\nfreely, this space is yours.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColours.textMuted,
            height: 1.6,
          ),
        ),

        const Spacer(),

        // ── Pulsing mic button ───────────────────────────────────────────
        _buildAudioMicButton(),

        const Spacer(),

        // ── Reflection prompt card ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColours.accentLavenderSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REFLECTION PROMPT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColours.brandBlue,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _reflectionPrompts[_promptIndex],
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColours.textDark,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Audio Settings + SOS ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.mic_none_rounded,
                    size: 18, color: AppColours.brandBlue),
                label: Text(
                  'Audio Settings',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColours.brandBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showSosModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColours.dangerRed,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColours.dangerRed.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'SOS',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Bottom nav bar ───────────────────────────────────────────────
        _buildBottomNav(),
      ],
    );
  }

  // ─── Pulsing microphone button ───────────────────────────────────────────
  Widget _buildAudioMicButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outermost pulse ring
              Opacity(
                opacity: (1.0 - _pulseAnim1.value) * 0.25,
                child: Container(
                  width: 200 + _pulseAnim1.value * 0,
                  height: 200 + _pulseAnim1.value * 0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColours.brandBlue
                        .withOpacity(0.08 + _pulseAnim1.value * 0.04),
                  ),
                ),
              ),
              // Middle pulse ring
              Opacity(
                opacity: (1.0 - _pulseAnim2.value) * 0.35,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColours.brandBlue
                        .withOpacity(0.10 + _pulseAnim2.value * 0.05),
                  ),
                ),
              ),
              // Static inner ring
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_isAudioRecording
                          ? AppColours.dangerRed
                          : AppColours.brandBlue)
                      .withOpacity(0.12),
                ),
              ),
              // Core mic button
              GestureDetector(
                onTap: _processingAudio
                    ? null
                    : (_isAudioRecording
                        ? _stopAudioRecording
                        : _startAudioRecording),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isAudioRecording
                        ? AppColours.dangerRed
                        : AppColours.brandBlue,
                    boxShadow: [
                      BoxShadow(
                        color: (_isAudioRecording
                                ? AppColours.dangerRed
                                : const Color(0xFF2B2DC8))
                            .withOpacity(0.34),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _processingAudio
                      ? const Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : _isAudioRecording
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatDuration(_audioDuration),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            )
                          : const Icon(Icons.mic_rounded,
                              color: Colors.white, size: 40),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Bottom nav bar ───────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      _NavItem(icon: Icons.home_outlined, label: 'Sanctuary', route: '/home'),
      _NavItem(icon: Icons.mic_none_rounded, label: 'Record', route: '/record'),
      _NavItem(icon: Icons.bar_chart_rounded, label: 'Timeline', route: '/timeline'),
      _NavItem(icon: Icons.lock_outline_rounded, label: 'Vault', route: '/vault'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColours.surface,
          border:
              Border(top: BorderSide(color: AppColours.divider, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final isActive = item.label == 'Record';
            return GestureDetector(
              onTap: () => context.go(item.route),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: isActive
                        ? BoxDecoration(
                            color: AppColours.accentLavenderSoft,
                            borderRadius: BorderRadius.circular(20),
                          )
                        : null,
                    child: Icon(
                      item.icon,
                      size: 22,
                      color: isActive
                          ? AppColours.brandBlue
                          : AppColours.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isActive
                          ? AppColours.brandBlue
                          : AppColours.textMuted,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Mode toggle ─────────────────────────────────────────────────────────
  Widget _buildModeToggle({required bool dark}) {
    final bg = dark ? Colors.black38 : const Color(0xFFEEEEEE);
    final activeText = dark ? Colors.white : Colors.white;
    final inactiveText = dark ? Colors.white60 : AppColours.textMuted;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleTab(
            label: 'VIDEO',
            icon: Icons.videocam_rounded,
            selected: _mode == _RecordMode.video,
            activeTextColor: activeText,
            inactiveTextColor: inactiveText,
            onTap: () => setState(() => _mode = _RecordMode.video),
          ),
          const SizedBox(width: 4),
          _buildToggleTab(
            label: 'AUDIO',
            icon: Icons.mic_rounded,
            selected: _mode == _RecordMode.audio,
            activeTextColor: activeText,
            inactiveTextColor: inactiveText,
            onTap: () => setState(() => _mode = _RecordMode.audio),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTab({
    required String label,
    required IconData icon,
    required bool selected,
    required Color activeTextColor,
    required Color inactiveTextColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColours.brandBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? activeTextColor : inactiveTextColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? activeTextColor : inactiveTextColor,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Camera preview ───────────────────────────────────────────────────────
  Widget _buildCameraPreview(bool gpsConsent) {
    final ctrl = _controller!;
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: ctrl.value.previewSize?.height ?? 1,
              height: ctrl.value.previewSize?.width ?? 1,
              child: CameraPreview(ctrl),
            ),
          ),

          // Timestamp overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _timestampText,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                    letterSpacing: 0.2),
              ),
            ),
          ),

          // GPS overlay
          Positioned(
            bottom: 120,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_pin,
                    size: 13,
                    color: _gpsCoordinates != null
                        ? AppColours.accentTeal
                        : AppColours.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _gpsCoordinates != null
                        ? 'Location on'
                        : (gpsConsent ? 'Locating…' : 'No location'),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: _gpsCoordinates != null
                          ? Colors.white
                          : AppColours.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPreview() {
    return Container(
      color: const Color(0xFF1C1A2E),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColours.brandBlue,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildGpsTag(bool gpsConsent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.location_on,
          size: 14,
          color: _gpsCoordinates != null
              ? AppColours.brandBlue
              : AppColours.textMuted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            _gpsCoordinates != null
                ? 'Tagged'
                : (gpsConsent ? 'Locating…' : 'No GPS'),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _gpsCoordinates != null
                  ? Colors.white
                  : AppColours.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    final bool ready =
        _isCameraInitialized && _controller != null && !_processingVideo;
    return GestureDetector(
      onTap: ready ? (_isRecording ? _stopRecording : _startRecording) : null,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ready ? Colors.white : Colors.white24,
          boxShadow: ready
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Center(
          child: _isRecording
              ? Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColours.dangerRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              : Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: ready
                        ? AppColours.dangerRed
                        : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }

  // ─── Error state ──────────────────────────────────────────────────────────
  Widget _buildErrorState(String code) {
    String heading;
    String body;
    switch (code) {
      case 'web_denied':
        heading = 'Camera access needed';
        body = 'Camera access denied. Please allow camera access in your browser.';
        break;
      case 'permission_denied':
        heading = 'Camera access needed';
        body = 'Please allow camera and microphone access in your device settings';
        break;
      case 'no_camera':
      default:
        heading = 'No camera found';
        body = 'No camera found on this device';
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1C1A2E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white, size: 56),
                const SizedBox(height: 24),
                Text(
                  heading,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColours.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: () => Geolocator.openAppSettings(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColours.brandBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Open settings',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nav item helper ──────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.route});
}
