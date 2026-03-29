import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/testimony_model.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  /// Get user document by uid
  static Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }

  /// Get cases for a user
  static Future<List<Map<String, dynamic>>> getCasesForUser(
      String userId) async {
    try {
      final snapshot = await _db
          .collection('cases')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 5));
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['caseId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get evidence for a case
  static Future<List<TestimonyModel>> getEvidenceForCase(
      String caseId) async {
    try {
      final snapshot = await _db
          .collection('evidence')
          .where('caseId', isEqualTo: caseId)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(const Duration(seconds: 5));

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final metadata = data['metadata'] as Map<String, dynamic>;
        final arweave = data['arweave'] as Map<String, dynamic>;
        final blockchain = data['blockchain'] as Map<String, dynamic>;
        final encryption = data['encryption'] as Map<String, dynamic>;
        final ai = data['ai'] as Map<String, dynamic>;
        final entities = ai['entities'] as Map<String, dynamic>;
        final locationData = metadata['location'];

        return TestimonyModel(
          evidenceId: doc.id,
          caseId: data['caseId'] ?? '',
          userId: data['userId'] ?? '',
          type: data['type'] ?? 'video',
          title: data['title'] ?? '',
          arweave: ArweaveData(
            txId: arweave['txId'] ?? '',
            url: arweave['url'] ?? '',
          ),
          blockchain: BlockchainData(
            fileHash: blockchain['fileHash'] ?? '',
            polygonTxHash: blockchain['polygonTxHash'] ?? '',
          ),
          encryption: EncryptionData(
            keyId: encryption['keyId'] ?? '',
            status: encryption['status'] ?? 'active',
          ),
          metadata: MetadataModel(
            timestamp: (metadata['timestamp'] as Timestamp?)
                    ?.toDate()
                    .toIso8601String() ??
                DateTime.now().toIso8601String(),
            location: locationData != null
                ? LocationData(
                    lat: (locationData['lat'] as num).toDouble(),
                    lng: (locationData['lng'] as num).toDouble(),
                  )
                : null,
            duration: metadata['duration'] as int?,
            size: (metadata['size'] as num?)?.toInt() ?? 0,
          ),
          ai: AiData(
            transcript: ai['transcript'] ?? '',
            summary: ai['summary'] ?? '',
            entities: EntitiesData(
              persons: List<String>.from(entities['persons'] ?? []),
              dates: List<String>.from(entities['dates'] ?? []),
              locations: List<String>.from(entities['locations'] ?? []),
            ),
          ),
          status: data['status'] ?? 'uploading',
          createdAt: (data['createdAt'] as Timestamp?)
                  ?.toDate()
                  .toIso8601String() ??
              DateTime.now().toIso8601String(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Save new evidence document
  static Future<String?> saveEvidence(Map<String, dynamic> data) async {
    try {
      final doc = await _db.collection('evidence').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          ...data['metadata'],
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
      return doc.id;
    } catch (e) {
      return null;
    }
  }

  /// Log SOS trigger — fail silently since the 112 call is more important
  static Future<void> logSos({
    required String userId,
    required String caseId,
    required List<String> contactsNotified,
    double? lat,
    double? lng,
  }) async {
    try {
      await _db.collection('sos_logs').add({
        'userId': userId,
        'caseId': caseId,
        'location': lat != null ? {'lat': lat, 'lng': lng} : null,
        'contactsNotified': contactsNotified,
        'triggeredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // fail silently — SOS call is more important than logging
    }
  }
}
