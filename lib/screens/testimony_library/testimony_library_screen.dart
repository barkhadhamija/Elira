import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:math' as math;

import '../../theme/app_colours.dart';
import '../../store/app_store.dart';
import '../../models/testimony_model.dart';
import '../../services/backend_api_service.dart';
import '../../utils/session_manager.dart';

class TestimonyLibraryScreen extends ConsumerStatefulWidget {
  const TestimonyLibraryScreen({super.key});

  @override
  ConsumerState<TestimonyLibraryScreen> createState() =>
      _TestimonyLibraryScreenState();
}

class _TestimonyLibraryScreenState
    extends ConsumerState<TestimonyLibraryScreen> {
  String _filter = 'All';
  bool _loading = true;
  final _filters = ['All', 'Video', 'Audio', 'Document', 'Image'];

  @override
  void initState() {
    super.initState();
    _refreshFromBackend();
  }

  Future<void> _refreshFromBackend() async {
    try {
      final uid = await SessionManager.getUserId();
      if (uid == null || uid.trim().isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final rawItems = await BackendApiService.listCitizenEvidence(userId: uid);
      final mapped = rawItems.map(_mapBackendEvidence).toList();

      if (!mounted) return;
      final existing = ref.read(appProvider).testimonies;
      final byId = <String, TestimonyModel>{
        for (final item in existing) item.evidenceId: item,
      };
      for (final item in mapped) {
        byId[item.evidenceId] = item;
      }
      ref.read(appProvider.notifier).setTestimonies(byId.values.toList());
    } catch (_) {
      // Keep local in-memory testimonies when backend list fails.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  TestimonyModel _mapBackendEvidence(Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString();
    final fileType = (item['fileType'] ?? 'application/octet-stream').toString();
    final createdAt = (item['createdAt'] ?? DateTime.now().toIso8601String()).toString();
    final txId = (item['arweaveTxId'] ?? '').toString();
    final hash = (item['fileHash'] ?? '').toString();
    final keyHex = (item['keyHex'] ?? '').toString();
    final ivHex = (item['ivHex'] ?? '').toString();

    final lower = fileType.toLowerCase();
    final type = lower.startsWith('video/')
        ? 'video'
        : lower.startsWith('audio/')
            ? 'audio'
            : lower.startsWith('image/')
                ? 'image'
                : 'document';

    final aiData = item['ai'] as Map<String, dynamic>? ?? {};
    final extracted = aiData['extractedData'] as Map<String, dynamic>? ?? {};
    final isSentimentType = type == 'audio' || type == 'video';

    final sentiment = isSentimentType
      ? (aiData['sentiment'] ?? '').toString()
      : '';
    final riskLevel = isSentimentType
      ? (aiData['riskLevel'] ?? '').toString()
      : '';
    final keywords = isSentimentType
      ? (aiData['keywords'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList()
      : <String>[];

    final summary = (aiData['summary'] ?? extracted['description'] ?? 'Uploaded to secure evidence backend.').toString();
    final transcript = isSentimentType
      ? (aiData['transcript'] ?? '').toString()
      : '';

    final dynamicTitle = (extracted['title'] ?? '').toString().trim();
    final displayTitle = dynamicTitle.isNotEmpty ? dynamicTitle : 'Evidence #$id';

    return TestimonyModel(
      evidenceId: id,
      caseId: 'default_case',
      userId: (item['userId'] ?? '').toString(),
      type: type,
      title: displayTitle,
      arweave: ArweaveData(
        txId: txId,
        url: txId.isEmpty ? '' : 'https://arweave.net/$txId',
      ),
      blockchain: BlockchainData(
        fileHash: hash,
        polygonTxHash: '',
      ),
      encryption: EncryptionData(
        keyId: 'server',
        status: 'active',
        keyHex: keyHex,
        ivHex: ivHex,
      ),
      metadata: MetadataModel(
        timestamp: createdAt,
        duration: null,
        size: 0,
      ),
      ai: AiData(
        transcript: transcript,
        summary: summary,
        sentiment: sentiment,
        riskLevel: riskLevel,
        keywords: keywords,
        entities: EntitiesData(
          persons: [if (extracted['personName'] != null) extracted['personName'].toString()],
          dates: [if (extracted['date'] != null) extracted['date'].toString()],
          locations: const [],
          title: extracted['title']?.toString(),
          description: extracted['description']?.toString(),
        ),
      ),
      status: 'anchored',
      createdAt: createdAt,
    );
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

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _formatSlashDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    return '$day / $month / $year';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _fileNameFromTestimony(TestimonyModel testimony) {
    final suffix = testimony.arweave.txId.isNotEmpty
        ? testimony.arweave.txId.substring(
            0,
            testimony.arweave.txId.length > 10
                ? 10
                : testimony.arweave.txId.length,
          )
        : testimony.evidenceId;

    switch (testimony.type.toLowerCase()) {
      case 'video':
        return 'evidence_$suffix.mp4';
      case 'audio':
        return 'evidence_$suffix.m4a';
      case 'image':
        return 'evidence_$suffix.jpg';
      default:
        return 'evidence_$suffix.pdf';
    }
  }

  String _build65BCertificate({
    required List<TestimonyModel> testimonies,
    required String portalName,
    required String certifierName,
    required String username,
    required String role,
    required String place,
    required String designation,
    required String organization,
    required String contact,
    required DateTime retrieval,
  }) {
    final records = testimonies
      .asMap()
      .entries
      .map((entry) {
        final index = entry.key + 1;
        final testimony = entry.value;
        final txId = testimony.arweave.txId.isEmpty ? 'N/A' : testimony.arweave.txId;
        final fileName = _fileNameFromTestimony(testimony);
        final fileType = testimony.type.toUpperCase();
        final fileHash = testimony.blockchain.fileHash.isEmpty
          ? 'N/A'
          : testimony.blockchain.fileHash;
        final gatewayUrl = testimony.arweave.url.isEmpty ? 'N/A' : testimony.arweave.url;

        return '''
     Record $index:
     - Evidence ID: ${testimony.evidenceId}
     - Arweave Transaction ID (TXID): $txId
     - File Name: $fileName
     - File Type: $fileType
     - File Hash (SHA-256): $fileHash
     - Gateway URL (if applicable): $gatewayUrl
  ''';
      })
      .join('\n');

    final retrievalTimestamp =
        '${_formatSlashDate(retrieval)} ${_formatTime(retrieval)}';
    final dateNow = _formatSlashDate(DateTime.now());
    final recordCount = testimonies.length;

    return '''CERTIFICATE UNDER SECTION 65B OF THE INDIAN EVIDENCE ACT, 1872

I, $certifierName, hereby certify as follows:

1. I am the Administrator / Authorized Officer responsible for the operation and management of the electronic system known as $portalName, which is used for storage, retrieval, and management of electronic records.

2. The computer system and server infrastructure used for retrieving the electronic record are under my lawful control and are regularly used in the ordinary course of activities.

3. On ${_formatSlashDate(retrieval)} at ${_formatTime(retrieval)} (time), I accessed the administrative portal using the following credentials:

   - Username: $username
   - Role/Designation: $role

4. Through the above system, I retrieved the following electronic record:

     Total Records Covered: $recordCount
     Retrieval Timestamp: $retrievalTimestamp
  $records

  5. The electronic record(s) were originally stored on a decentralized storage network (Arweave), and were retrieved using the controlled administrative interface of the above-mentioned system.

  6. The computer system used for retrieval was operating properly at the time of retrieval, and the process of downloading, storing, and producing the copy was carried out in the ordinary course of activities.

  7. The copy/copies of the electronic record(s) annexed herewith is/are true and accurate reproductions of the data retrieved from the system, without any alteration or modification.

  8. The information contained in this certificate is derived from the electronic records maintained in the ordinary course of activities of the system.

  I hereby certify that the above statements are true to the best of my knowledge and belief, and this certificate is issued in compliance with Section 65B(4) of the Indian Evidence Act, 1872.

  Place: $place
  Date: $dateNow

  Signature: ___________________________
  Name: $certifierName
  Designation: $designation
  Organization: $organization
  Contact Details: $contact''';
    }

    Future<File> _download65BCertificatePdf({
      required String certificate,
      required int recordCount,
    }) async {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (_) => [
            pw.Text(
              'Section 65B Certificate',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              certificate,
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.3),
            ),
          ],
        ),
      );

      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'elira_65b_${recordCount}_records_$stamp.pdf';
      final bytes = await pdf.save();

      return _writeDownloadFile(fileName, bytes);
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

      throw Exception('Unable to save certificate PDF. Last error: $lastError');
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

    Future<void> _open65BCertificateDialog({
      required List<TestimonyModel> testimonies,
      required String title,
    }) async {
      if (testimonies.isEmpty) return;

      final userName = await SessionManager.getUserName();
      final userEmail = await SessionManager.getUserEmail();
      final userPhone = await SessionManager.getUserPhone();
      final userId = await SessionManager.getUserId();

      if (!mounted) return;

      final resolvedUserName = (userName ?? '').trim();
      final resolvedUserEmail = (userEmail ?? '').trim();
      final resolvedUserPhone = (userPhone ?? '').trim();
      final resolvedUserId = (userId ?? '').trim();

      final portalController =
          TextEditingController(text: 'ELIRA Administrative Portal');
      final certifierNameController =
          TextEditingController(text: resolvedUserName.isEmpty ? 'ELIRA Authorized Officer' : resolvedUserName);
      final usernameController = TextEditingController(
        text: resolvedUserEmail.isNotEmpty
          ? resolvedUserEmail
          : (resolvedUserId.isNotEmpty ? resolvedUserId : 'elira_user'),
      );
      final roleController = TextEditingController(text: 'Citizen / Evidence Owner');
      final placeController = TextEditingController(text: 'India');
      final designationController = TextEditingController(text: 'Authorized Signatory');
      final organizationController = TextEditingController(text: 'ELIRA');
      final contactController = TextEditingController(
        text: resolvedUserPhone.isNotEmpty
            ? resolvedUserPhone
            : (resolvedUserEmail.isNotEmpty ? resolvedUserEmail : 'N/A'),
      );

      try {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final size = MediaQuery.of(ctx).size;
            final dialogWidth = math.min(size.width * 0.94, 760.0);
            final dialogHeight = math.min(size.height * 0.9, 860.0);

            return StatefulBuilder(
              builder: (context, setStateDialog) {
                final certificate = _build65BCertificate(
                  testimonies: testimonies,
                  portalName: portalController.text.trim(),
                  certifierName: certifierNameController.text.trim(),
                  username: usernameController.text.trim(),
                  role: roleController.text.trim(),
                  place: placeController.text.trim(),
                  designation: designationController.text.trim(),
                  organization: organizationController.text.trim(),
                  contact: contactController.text.trim(),
                  retrieval: DateTime.now(),
                );

                return Dialog(
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  backgroundColor: AppColours.cardSurface,
                  child: SizedBox(
                    width: dialogWidth,
                    height: dialogHeight,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: AppColours.textDark,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColours.cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColours.divider),
                                  ),
                                  child: Text(
                                    'Certificate will include ${testimonies.length} evidence record(s).',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColours.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _certInput(
                                  controller: portalController,
                                  label: 'Portal Name',
                                  onChanged: (_) => setStateDialog(() {}),
                                ),
                                const SizedBox(height: 8),
                                _certInput(
                                  controller: certifierNameController,
                                  label: 'Certifier Name',
                                  onChanged: (_) => setStateDialog(() {}),
                                ),
                                const SizedBox(height: 8),
                                _certInput(
                                  controller: usernameController,
                                  label: 'Username',
                                  onChanged: (_) => setStateDialog(() {}),
                                ),
                                const SizedBox(height: 8),
                                _certInput(
                                  controller: roleController,
                                  label: 'Role / Designation (portal)',
                                  onChanged: (_) => setStateDialog(() {}),
                                ),
                                const SizedBox(height: 8),
                                _certInput(
                                  controller: placeController,
                                  label: 'Place',
                                  onChanged: (_) => setStateDialog(() {}),
                                ),
                                const SizedBox(height: 8),
                                _certInput(
                                  controller: designationController,
                                  label: 'Final Designation',
                                  onChanged: (_) => setStateDialog(() {}),
                                ),
                                const SizedBox(height: 8),
                                _certInput(
                                  controller: organizationController,
                                  label: 'Organization',
                                  onChanged: (_) => setStateDialog(() {}),
                                ),
                                const SizedBox(height: 8),
                                _certInput(
                                  controller: contactController,
                                  label: 'Contact Details',
                                  onChanged: (_) => setStateDialog(() {}),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Certificate Preview',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColours.textDark,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColours.cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColours.divider),
                                  ),
                                  child: SelectableText(
                                    certificate,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      height: 1.45,
                                      color: AppColours.textDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.inter(
                                    color: AppColours.textMuted,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(ctx);
                                  try {
                                    final file = await _download65BCertificatePdf(
                                      certificate: certificate,
                                      recordCount: testimonies.length,
                                    );
                                    if (!ctx.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '65B PDF saved: ${file.path}',
                                        ),
                                        backgroundColor: AppColours.brandBlue,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!ctx.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to save 65B PDF: $e',
                                        ),
                                        backgroundColor: AppColours.dangerRed,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: const Text('Download PDF'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      } finally {
        portalController.dispose();
        certifierNameController.dispose();
        usernameController.dispose();
        roleController.dispose();
        placeController.dispose();
        designationController.dispose();
        organizationController.dispose();
        contactController.dispose();
      }
    }

    Future<void> _show65BCertificateDialog(TestimonyModel testimony) async {
      await _open65BCertificateDialog(
        testimonies: [testimony],
        title: 'Generate 65B Certificate',
      );
    }

    Future<void> _show65BAllDialog(List<TestimonyModel> testimonies) async {
      await _open65BCertificateDialog(
        testimonies: testimonies,
        title: 'Generate 65B Certificate (All Evidence)',
      );
    }

  Widget _certInput({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.inter(
        fontSize: 13,
        color: AppColours.textDark,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
      ),
    );
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
    final all = [...storeTestimonies];
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

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColours.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColours.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Section 65B Certificate',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColours.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Generate one consolidated legal certificate for all visible evidence at once.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColours.textMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: filtered.isEmpty
                                  ? null
                                  : () => _show65BAllDialog(filtered),
                              icon: const Icon(Icons.verified_outlined, size: 18),
                              label: const Text('Generate 65B (All Visible)'),
                            ),
                          ),
                          if (filtered.isEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'No evidence available yet. Upload or record testimony first.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColours.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                separatorBuilder: (_, _) => const SizedBox(width: 8),
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
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColours.brandBlue,
                        strokeWidth: 2,
                      ),
                    )
                  : filtered.isEmpty
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
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 12),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final t = filtered[i];
                        final duration = t.metadata.duration;
                        return _TestimonyRow(
                          testimony: t,
                          evidenceNumber: i + 1,
                          typeIcon: _typeIcon(t.type),
                          dateText: _formatDate(t.metadata.timestamp),
                          durationText:
                              duration != null ? _formatDuration(duration) : '',
                          statusColor: _statusColor(t.status),
                            onGenerate65B: () => _show65BCertificateDialog(t),
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
  final int evidenceNumber;
  final IconData typeIcon;
  final String dateText;
  final String durationText;
  final Color statusColor;
  final VoidCallback onGenerate65B;
  final VoidCallback onTap;

  const _TestimonyRow({
    required this.testimony,
    required this.evidenceNumber,
    required this.typeIcon,
    required this.dateText,
    required this.durationText,
    required this.statusColor,
    required this.onGenerate65B,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        'Evidence $evidenceNumber',
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onGenerate65B,
                icon: Icon(Icons.verified_outlined,
                    color: AppColours.brandBlue, size: 18),
                label: Text(
                  'Generate 65B Certificate',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColours.brandBlue,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColours.brandBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
