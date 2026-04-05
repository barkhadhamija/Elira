import 'package:flutter_riverpod/flutter_riverpod.dart';

final evidenceProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return <Map<String, dynamic>>[];
});
