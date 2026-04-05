import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/testimony_model.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _syncDisabled = false;

  static bool _isMissingDefaultDbError(Object error) {
    if (error is! FirebaseException) return false;
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    return code == 'not-found' &&
        message.contains('database (default) does not exist');
  }

  static Future<void> saveEvidence(Map<String, dynamic> data) async {
    if (_syncDisabled) return;

    final evidenceId = (data['evidenceId'] as String?)?.trim();
    if (evidenceId == null || evidenceId.isEmpty) {
      throw ArgumentError('evidenceId is required');
    }

    try {
      await _firestore
          .collection('evidence')
          .doc(evidenceId)
          .set(data, SetOptions(merge: true));
    } catch (error) {
      if (_isMissingDefaultDbError(error)) {
        _syncDisabled = true;
        return;
      }
      rethrow;
    }
  }

  static Future<List<TestimonyModel>> getEvidenceByUser(String userId) async {
    if (_syncDisabled) return <TestimonyModel>[];

    final safeUserId = userId.trim();
    if (safeUserId.isEmpty) return <TestimonyModel>[];

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestore
          .collection('evidence')
          .where('userId', isEqualTo: safeUserId)
          .get();
    } catch (error) {
      if (_isMissingDefaultDbError(error)) {
        _syncDisabled = true;
        return <TestimonyModel>[];
      }
      rethrow;
    }

    final items = snapshot.docs
        .map((doc) => _fromFirestore(doc.data()))
        .whereType<TestimonyModel>()
        .toList();

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  static TestimonyModel? _fromFirestore(Map<String, dynamic> data) {
    try {
      final arweave = (data['arweave'] as Map<String, dynamic>? ?? {});
      final blockchain = (data['blockchain'] as Map<String, dynamic>? ?? {});
      final encryption = (data['encryption'] as Map<String, dynamic>? ?? {});
      final metadata = (data['metadata'] as Map<String, dynamic>? ?? {});
      final ai = (data['ai'] as Map<String, dynamic>? ?? {});
      final entities = (ai['entities'] as Map<String, dynamic>? ?? {});
      final location = (metadata['location'] as Map<String, dynamic>?);

      return TestimonyModel(
        evidenceId: (data['evidenceId'] ?? '').toString(),
        caseId: (data['caseId'] ?? '').toString(),
        userId: (data['userId'] ?? '').toString(),
        type: (data['type'] ?? 'document').toString(),
        title: (data['title'] ?? 'Untitled').toString(),
        arweave: ArweaveData(
          txId: (arweave['txId'] ?? '').toString(),
          url: (arweave['url'] ?? '').toString(),
        ),
        blockchain: BlockchainData(
          fileHash: (blockchain['fileHash'] ?? '').toString(),
          polygonTxHash: (blockchain['polygonTxHash'] ?? '').toString(),
        ),
        encryption: EncryptionData(
          keyId: (encryption['keyId'] ?? '').toString(),
          status: (encryption['status'] ?? '').toString(),
          keyHex: (encryption['keyHex'] ?? data['keyHex'] ?? '').toString(),
          ivHex: (encryption['ivHex'] ?? data['ivHex'] ?? '').toString(),
        ),
        metadata: MetadataModel(
          timestamp: (metadata['timestamp'] ?? '').toString(),
          location: location == null
              ? null
              : LocationData(
                  lat: (location['lat'] as num?)?.toDouble() ?? 0,
                  lng: (location['lng'] as num?)?.toDouble() ?? 0,
                ),
          duration: (metadata['duration'] as num?)?.toInt(),
          size: (metadata['size'] as num?)?.toInt() ?? 0,
        ),
        ai: AiData(
          transcript: (ai['transcript'] ?? '').toString(),
          summary: (ai['summary'] ?? '').toString(),
          entities: EntitiesData(
            persons: (entities['persons'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList(),
            dates: (entities['dates'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList(),
            locations: (entities['locations'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList(),
          ),
        ),
        status: (data['status'] ?? 'uploading').toString(),
        createdAt: (data['createdAt'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
