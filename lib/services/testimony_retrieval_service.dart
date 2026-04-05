import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:http/http.dart' as http;

/// Service to retrieve and decrypt testimonies from Arweave
class TestimonyRetrievalService {
  static const List<String> _arweaveGateways = <String>[
    'https://arweave.net',
    'https://gateway.irys.xyz',
  ];

  /// Download encrypted file from Arweave
  static Future<Uint8List?> downloadFromArweave(String arweaveTxId) async {
    final txId = _normalizeTxId(arweaveTxId);
    if (txId.isEmpty) {
      print('[Retrieval] Empty Arweave TX id');
      return null;
    }

    try {
      for (final gateway in _arweaveGateways) {
        final url = '$gateway/$txId';
        print('[Retrieval] Downloading from Arweave: $url');

        // Short retry loop to handle intermittent gateway hiccups.
        for (var attempt = 1; attempt <= 3; attempt++) {
          try {
            final response = await http.get(Uri.parse(url)).timeout(
              const Duration(seconds: 45),
              onTimeout: () {
                throw TimeoutException('Arweave download timeout');
              },
            );

            if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
              if (_isLikelyGatewayErrorPayload(response)) {
                print('[Retrieval] Gateway returned non-media payload via $gateway (attempt $attempt), trying next source');
                continue;
              }

              print('[Retrieval] Download successful (${response.bodyBytes.length} bytes) via $gateway');
              return response.bodyBytes;
            }

            print('[Retrieval] Download failed via $gateway (attempt $attempt): ${response.statusCode}');
          } catch (e) {
            print('[Retrieval] Download error via $gateway (attempt $attempt): $e');
          }
        }
      }

      return null;
    } catch (e) {
      print('[Retrieval] Error downloading from Arweave: $e');
      return null;
    }
  }

  /// Decrypt content using AES-256-CBC with stored key and IV
  static Future<Uint8List?> decryptContent({
    required Uint8List encryptedData,
    required String keyHex,
    required String ivHex,
  }) async {
    try {
      print('[Retrieval] Decrypting ${encryptedData.length} bytes');

      // Convert hex strings to bytes
      final keyBytes = _hexToBytes(keyHex);
      final ivBytes = _hexToBytes(ivHex);

      print('[Retrieval] Key length: ${keyBytes.length}, IV length: ${ivBytes.length}');

      // Create cipher components
      final key = encrypt_pkg.Key(keyBytes);
      final iv = encrypt_pkg.IV(ivBytes);

      // Create encrypter with AES-256-CBC
      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(
          key,
          mode: encrypt_pkg.AESMode.cbc,
          padding: 'PKCS7',
        ),
      );

      // Convert encrypted data to Encrypted object
      final encrypted = encrypt_pkg.Encrypted(encryptedData);

      // Decrypt
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);

      // Backend encrypts base64 text, so convert decrypted UTF-8/base64 back to file bytes.
      final normalized = _tryDecodeBase64Payload(decrypted);
      print('[Retrieval] Decryption successful: ${normalized.length} bytes');
      return normalized;
    } catch (e) {
      print('[Retrieval] Error decrypting content: $e');
      return null;
    }
  }

  /// Full flow: Download from Arweave, decrypt, and return bytes
  static Future<Uint8List?> retrieveTestimonyFile({
    required String arweaveTxId,
    required String keyHex,
    required String ivHex,
  }) async {
    try {
      print('[Retrieval] Starting retrieval for TX: $arweaveTxId');

      // Download encrypted data
      final encryptedData = await downloadFromArweave(arweaveTxId);
      if (encryptedData == null) {
        print('[Retrieval] Download failed');
        return null;
      }

      // Decrypt
      final decryptedData = await decryptContent(
        encryptedData: encryptedData,
        keyHex: keyHex,
        ivHex: ivHex,
      );

      if (decryptedData != null) {
        print('[Retrieval] Retrieval complete');
        return decryptedData;
      }

      // Legacy/plain fallback: sometimes payload may be stored as plain base64 content.
      final directDecoded = _decodeBase64Payload(encryptedData);
      if (directDecoded != null && directDecoded.isNotEmpty) {
        print('[Retrieval] Fallback decode succeeded without AES decrypt');
        return directDecoded;
      }

      final jsonDecoded = _decodeJsonWrappedPayload(encryptedData);
      if (jsonDecoded != null && jsonDecoded.isNotEmpty) {
        print('[Retrieval] Fallback decode succeeded from JSON-wrapped payload');
        return jsonDecoded;
      }

      // Final fallback for legacy unencrypted uploads: return raw bytes instead
      // of failing completely. Download can still succeed; replay may fail if
      // the payload is not valid media bytes.
      if (encryptedData.isNotEmpty) {
        print('[Retrieval] Returning raw downloaded bytes as final fallback');
        return encryptedData;
      }

      if (_looksLikeKnownFile(encryptedData)) {
        print('[Retrieval] Fallback succeeded using raw downloaded bytes');
        return encryptedData;
      }

      print('[Retrieval] Decryption and fallback failed');
      return null;
    } catch (e) {
      print('[Retrieval] Error in retrieval flow: $e');
      return null;
    }
  }

  /// Generate direct Arweave URL for a transaction ID
  static String getArweaveUrl(String txId) {
    final normalized = _normalizeTxId(txId);
    return normalized.isEmpty ? '' : '${_arweaveGateways.first}/$normalized';
  }

  /// Helper: Convert hex string to bytes
  static Uint8List _hexToBytes(String hex) {
    final buffer = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      buffer[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return buffer;
  }

  static Uint8List _tryDecodeBase64Payload(List<int> decrypted) {
    final decoded = _decodeBase64Payload(decrypted);
    if (decoded != null && decoded.isNotEmpty) {
      return decoded;
    }

    return Uint8List.fromList(decrypted);
  }

  static Uint8List? _decodeBase64Payload(List<int> bytes) {
    try {
      var decodedText = utf8.decode(bytes, allowMalformed: true).trim();
      if (decodedText.isEmpty) return null;

      // Support quoted payloads: "AAAA..." or 'AAAA...'
      if ((decodedText.startsWith('"') && decodedText.endsWith('"')) ||
          (decodedText.startsWith("'") && decodedText.endsWith("'"))) {
        decodedText = decodedText.substring(1, decodedText.length - 1).trim();
      }

      // Support data URLs such as: data:video/mp4;base64,AAAA...
      final commaIndex = decodedText.indexOf(',');
      if (decodedText.startsWith('data:') && commaIndex > 0) {
        decodedText = decodedText.substring(commaIndex + 1);
      }

      var compact = decodedText.replaceAll(RegExp(r'\s+'), '');

      // Support base64url input.
      compact = compact.replaceAll('-', '+').replaceAll('_', '/');

      // Add padding if needed.
      final rem = compact.length % 4;
      if (rem != 0) {
        compact = compact.padRight(compact.length + (4 - rem), '=');
      }

      // If it looks like base64 text, decode to original binary payload.
      if (compact.isNotEmpty && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(compact)) {
        return Uint8List.fromList(base64Decode(compact));
      }
    } catch (_) {
      // ignore
    }

    return null;
  }

  static Uint8List? _decodeJsonWrappedPayload(List<int> bytes) {
    try {
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      if (text.isEmpty || !text.startsWith('{')) {
        return null;
      }

      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final candidates = <dynamic>[
        decoded['fileContent'],
        decoded['sourceContent'],
        decoded['content'],
        decoded['data'],
      ];

      for (final candidate in candidates) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          final parsed = _decodeBase64Payload(utf8.encode(candidate));
          if (parsed != null && parsed.isNotEmpty) {
            return parsed;
          }
        }
      }
    } catch (_) {
      // ignore and fall through
    }

    return null;
  }

  static bool _isLikelyGatewayErrorPayload(http.Response response) {
    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    final text = utf8.decode(response.bodyBytes, allowMalformed: true).trimLeft();

    if (contentType.contains('text/html')) {
      return true;
    }

    if (text.startsWith('<!DOCTYPE html') || text.startsWith('<html')) {
      return true;
    }

    if (contentType.contains('application/json') || text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('error') || decoded.containsKey('status') || decoded.containsKey('message')) {
            return true;
          }
        }
      } catch (_) {
        // Ignore malformed JSON, let normal decode flow handle it.
      }
    }

    return false;
  }

  static String _normalizeTxId(String value) {
    var tx = value.trim();
    if (tx.isEmpty) return '';

    if (tx.contains('/')) {
      final uri = Uri.tryParse(tx);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        tx = uri.pathSegments.last;
      } else {
        tx = tx.split('/').last;
      }
    }

    return tx.trim();
  }

  static bool _looksLikeKnownFile(Uint8List bytes) {
    if (bytes.length < 12) return false;

    // MP4: ftyp at bytes 4..7
    final hasFtyp =
        bytes.length > 8 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70;

    // PDF: %PDF
    final isPdf =
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;

    // JPEG: FF D8 FF
    final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;

    // PNG: 89 50 4E 47
    final isPng =
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;

    return hasFtyp || isPdf || isJpeg || isPng;
  }
}

/// Timeout exception for Arweave operations
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
