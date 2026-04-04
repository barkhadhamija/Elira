import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_colours.dart';
import '../../store/app_store.dart';
import '../../models/testimony_model.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  PlatformFile? _pickedFile;
  final TextEditingController _titleController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;
  bool _isSuccess = false;

  final List<String> _categories = [
    'Medical',
    'Abuse Evidence',
    'Legal Document',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  bool get _canUpload =>
      _pickedFile != null &&
      _titleController.text.trim().isNotEmpty &&
      _selectedCategory != null;

  Future<void> _upload() async {
    if (!_canUpload) return;
    setState(() => _isLoading = true);

    final ext = (_pickedFile!.extension ?? '').toLowerCase();
    final now = DateTime.now();

    final newEntry = TestimonyModel(
      evidenceId: 'local_${now.millisecondsSinceEpoch}',
      caseId: 'case_001',
      userId: 'user_001',
      type: ext == 'pdf' ? 'pdf' : 'image',
      title: _titleController.text.trim(),
      arweave: ArweaveData(
        txId: 'pending_${now.millisecondsSinceEpoch}',
        url: '',
      ),
      blockchain: BlockchainData(
        fileHash: 'pending',
        polygonTxHash: 'pending',
      ),
      encryption: EncryptionData(keyId: 'local', status: 'active'),
      metadata: MetadataModel(
        timestamp: now.toIso8601String(),
        location: null,
        duration: null,
        size: _pickedFile!.size,
      ),
      ai: AiData(
        transcript: '',
        summary: 'Document uploaded. AI analysis pending.',
        entities: EntitiesData(persons: [], dates: [], locations: []),
      ),
      status: 'uploading',
      createdAt: now.toIso8601String(),
    );

    ref.read(appProvider.notifier).addTestimony(newEntry);
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isSuccess = true;
    });

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 72, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/home'),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: AppColours.textDark,
                    iconSize: 20,
                    padding: const EdgeInsets.all(12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                children: [
                  Text(
                    'Upload Evidence',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 28,
                      color: AppColours.textDark,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add images, PDFs or documents to your case',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: AppColours.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── File picker zone or preview ──────────────────────────
                  if (_pickedFile == null)
                    _DashedPickerZone(onTap: _pickFile)
                  else
                    _buildFilePreview(),

                  const SizedBox(height: 28),

                  // ── Title field ──────────────────────────────────────────
                  Text(
                    'Label this evidence',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColours.textMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: AppColours.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Medical prescription — Dr. Mehta',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: AppColours.textMuted.withOpacity(0.6),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: AppColours.divider, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: AppColours.divider, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColours.accentTeal,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Category selector ────────────────────────────────────
                  Text(
                    'Category',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColours.textMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final selected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          constraints: const BoxConstraints(minHeight: 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColours.accentTeal
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColours.accentTeal
                                  : AppColours.divider,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : AppColours.textMuted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 36),

                  // ── Upload button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _isSuccess
                        ? Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDF7F1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColours.badgeCertified
                                      .withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: AppColours.badgeCertified,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Evidence saved',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColours.badgeCertified,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton(
                            onPressed:
                                _canUpload && !_isLoading ? _upload : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColours.accentTeal,
                              disabledBackgroundColor:
                                  AppColours.divider,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Upload Evidence',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    final ext = (_pickedFile!.extension ?? '').toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);
    final path = _pickedFile!.path;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: isImage && path != null
              ? Image.file(
                  File(path),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                )
              : Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColours.accentLavenderSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_rounded,
                          color: AppColours.accentTeal, size: 40),
                      const SizedBox(height: 12),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _pickedFile!.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColours.accentTeal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _pickFile,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 36),
          ),
          child: Text(
            'Change file',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColours.accentTeal,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashed border picker zone
// ─────────────────────────────────────────────────────────────────────────────
class _DashedPickerZone extends StatelessWidget {
  final VoidCallback onTap;
  const _DashedPickerZone({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColours.accentTeal.withOpacity(0.3),
          radius: 16,
          dashWidth: 8,
          dashGap: 6,
        ),
        child: SizedBox(
          height: 180,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_upload_rounded,
                size: 48,
                color: AppColours.accentTeal.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap to select a file',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColours.accentTeal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Images and PDFs accepted',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColours.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashWidth : dashGap;
        if (draw) {
          final extracted =
              metric.extractPath(distance, distance + len);
          canvas.drawPath(extracted, paint);
        }
        distance += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashWidth != dashWidth ||
      old.dashGap != dashGap;
}
