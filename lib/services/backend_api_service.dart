import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendApiService {
  static final Uri _baseUri = Uri.parse(_resolveBaseUrl());
  static const Duration _requestTimeout = Duration(seconds: 120);
  static const Duration _uploadTimeout = Duration(minutes: 15);

  static String _resolveBaseUrl() {
    const fromDefine = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;

    if (kIsWeb) {
      return 'http://localhost:5000';
    }

    if (Platform.isAndroid) {
      // Works on physical device when using: adb reverse tcp:5000 tcp:5000
      return 'http://127.0.0.1:5000';
    }

    return 'http://localhost:5000';
  }

  static String get baseUrl => _baseUri.toString();

  static Future<Map<String, dynamic>> registerCitizen({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final response = await http
        .post(
          _baseUri.resolve('/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            'phone': phone,
          }),
        )
        .timeout(_requestTimeout);

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
    final response = await http
        .post(
          _baseUri.resolve('/auth/profile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': userId,
            if (name != null) 'name': name,
            if (email != null) 'email': email,
            if (phone != null) 'phone': phone,
            if (gpsConsent != null) 'gpsConsent': gpsConsent,
            if (contacts != null) 'contacts': contacts,
            if (biometricEnabled != null) 'biometricEnabled': biometricEnabled,
            if (onboardingComplete != null)
              'onboardingComplete': onboardingComplete,
            if (pin != null) 'pin': pin,
          }),
        )
        .timeout(_uploadTimeout);

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
    final response = await http
        .post(
          _baseUri.resolve('/evidence/upload'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fileContent': base64Content,
            'fileType': fileType,
            'userId': userId,
          }),
        )
        .timeout(_uploadTimeout);

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

    final uri = _baseUri
        .resolve('/evidence/citizen')
        .replace(queryParameters: {'userId': safeUserId});

    final response = await http.get(uri).timeout(const Duration(seconds: 20));

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
