import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/testimony_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../data/mock_data.dart';

/// Loads evidence from Firestore if the user is authenticated.
/// Falls back to mockTestimonies silently if:
///   - User is not logged in
///   - No cases found for the user
///   - Firestore returns empty evidence list
///   - Any Firestore error occurs
final evidenceProvider = FutureProvider<List<TestimonyModel>>((ref) async {
  final uid = AuthService.currentUid;
  if (uid == null) return mockTestimonies;

  try {
    final cases = await FirestoreService.getCasesForUser(uid);
    if (cases.isEmpty) return mockTestimonies;

    final caseId = cases.first['caseId'] as String;
    final evidence = await FirestoreService.getEvidenceForCase(caseId);

    return evidence.isEmpty ? mockTestimonies : evidence;
  } catch (_) {
    return mockTestimonies;
  }
});
