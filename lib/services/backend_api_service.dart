import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendApiService {
  static Uri? _workingBaseUri;
  static final List<Uri> _candidateBaseUris = _buildCandidateBaseUris();
  static const Duration _requestTimeout = Duration(seconds: 120);
  static const Duration _uploadTimeout = Duration(minutes: 15);

  static List<Uri> _buildCandidateBaseUris() {
    const fromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final fromDefineUri =
        fromDefine.isNotEmpty ? Uri.tryParse(fromDefine) : null;

    List<Uri> defaults;

    if (kIsWeb) {
      defaults = <Uri>[Uri.parse('http://localhost:5000')];
    } else if (Platform.isAndroid) {
      // Try physical-device adb reverse first, then emulator host mapping.
      defaults = <Uri>[
        Uri.parse('http://127.0.0.1:5000'),
        Uri.parse('http://10.0.2.2:5000'),
        Uri.parse('http://localhost:5000'),
      ];
    } else {
      defaults = <Uri>[Uri.parse('http://localhost:5000')];
    }

    if (fromDefineUri == null) return defaults;
    return <Uri>[fromDefineUri, ...defaults.where((u) => u != fromDefineUri)];
  }

  static String get baseUrl =>
      (_workingBaseUri ?? _candidateBaseUris.first).toString();

  static Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(Uri baseUri) request,
    Duration timeout,
  ) async {
    final orderedCandidates = <Uri>[
      if (_workingBaseUri != null) _workingBaseUri!,
      ..._candidateBaseUris.where((u) => u != _workingBaseUri),
    ];

    Object? lastError;
    for (final baseUri in orderedCandidates) {
      try {
        final response = await request(baseUri).timeout(timeout);
        _workingBaseUri = baseUri;
        return response;
      } on SocketException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      }
    }

    throw Exception(
      'Local backend not reachable. Tried: '
      '${orderedCandidates.map((u) => u.toString()).join(', ')}'
      '${lastError != null ? '. Last error: $lastError' : ''}',
    );
  }

  static Future<Map<String, dynamic>> registerCitizen({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final response = await _sendWithFallback((baseUri) {
      return http.post(
        baseUri.resolve('/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
        }),
      );
    }, _requestTimeout);

    final body = _decodeJson(response.body);
    if (response.statusCode >= 400) {
      throw Exception(
        (body['message'] ?? 'Failed to register user').toString(),
      );
    }

    return body;
  }

  static Future<Map<String, dynamic>> upsertUserProfile({
    required String userId,
    String? name,
    String? email,
    String? phone,
    bool? gpsConsent,
    List<String>? contacts,
    bool? biometricEnabled,
    bool? onboardingComplete,
    String? pin,
  }) async {
    final payload = <String, dynamic>{'userId': userId};
    if (name != null) payload['name'] = name;
    if (email != null) payload['email'] = email;
    if (phone != null) payload['phone'] = phone;
    if (gpsConsent != null) payload['gpsConsent'] = gpsConsent;
    if (contacts != null) payload['contacts'] = contacts;
    if (biometricEnabled != null) {
      payload['biometricEnabled'] = biometricEnabled;
    }
    if (onboardingComplete != null) {
      payload['onboardingComplete'] = onboardingComplete;
    }
    if (pin != null) payload['pin'] = pin;

    final response = await _sendWithFallback((baseUri) {
      return http.post(
        baseUri.resolve('/auth/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    }, _uploadTimeout);

    final body = _decodeJson(response.body);
    if (response.statusCode >= 400) {
      throw Exception(
        (body['message'] ?? 'Failed to save user profile').toString(),
      );
    }

    return body;
  }

  static Future<Map<String, dynamic>> uploadEvidence({
    required String base64Content,
    required String fileType,
    required String userId,
  }) async {
    final response = await _sendWithFallback((baseUri) {
      return http.post(
        baseUri.resolve('/evidence/upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fileContent': base64Content,
          'fileType': fileType,
          'userId': userId,
        }),
      );
    }, _uploadTimeout);

    final body = _decodeJson(response.body);
    if (response.statusCode >= 400) {
      throw Exception(
        (body['message'] ?? 'Failed to upload evidence').toString(),
      );
    }

    return body;
  }

  static Future<List<Map<String, dynamic>>> listCitizenEvidence({
    required String userId,
  }) async {
    final safeUserId = userId.trim();
    if (safeUserId.isEmpty) {
      throw Exception('userId is required to fetch citizen evidence');
    }

    final response = await _sendWithFallback((baseUri) {
      final uri = baseUri
        .resolve('/evidence/citizen')
        .replace(queryParameters: {'userId': safeUserId});
      return http.get(uri);
    }, const Duration(seconds: 20));

    final body = _decodeJson(response.body);
    if (response.statusCode >= 400) {
      throw Exception(
        (body['message'] ?? 'Failed to fetch evidence').toString(),
      );
    }

    final raw = body['data'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _decodeJson(String rawBody) {
    if (rawBody.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(rawBody);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }
}
