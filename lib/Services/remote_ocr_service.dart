import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';

class RemoteOcrException implements Exception {
  final String message;
  final int? statusCode;
  final bool globalLimitReached;

  const RemoteOcrException(this.message, {this.statusCode, this.globalLimitReached = false});

  @override
  String toString() => statusCode == null ? message : '$message (status: $statusCode)';
}

/// Calls the shared Google Cloud Vision OCR backend for both scanned-PDF
/// tools: Scanned PDF -> Word (plain-text DOCX) and Scanned PDF -> Searchable
/// PDF. Both share one global monthly page cap enforced server-side; callers
/// should check [OcrQuotaService] BEFORE calling either method here to avoid
/// wasting a request against a plan quota that's already exhausted.
class RemoteOcrService {
  const RemoteOcrService();

  static const Duration _ocrTimeout = Duration(seconds: 180);

  Future<Uint8List> convertScannedPdfToDocx({
    required Uint8List bytes,
    required String fileName,
  }) {
    return _postPdf(
      endpoint: ApiConfig.convertScannedPdfToDocxEndpoint,
      bytes: bytes,
      fileName: fileName,
      failureLabel: 'Scanned PDF to Word (OCR)',
    );
  }

  Future<Uint8List> convertToSearchablePdf({
    required Uint8List bytes,
    required String fileName,
  }) {
    return _postPdf(
      endpoint: ApiConfig.ocrPdfEndpoint,
      bytes: bytes,
      fileName: fileName,
      failureLabel: 'Scanned PDF to Searchable PDF (OCR)',
    );
  }

  Future<Uint8List> _postPdf({
    required String endpoint,
    required Uint8List bytes,
    required String fileName,
    required String failureLabel,
  }) async {
    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final uri = Uri.parse('$base$endpoint');

      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
            contentType: MediaType('application', 'pdf'),
          ),
        );

      final streamed = await request.send().timeout(_ocrTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        var globalLimitReached = false;
        var errorMessage = response.body;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            globalLimitReached = decoded['globalLimitReached'] == true;
            if (decoded['message'] is String) {
              errorMessage = decoded['message'] as String;
            } else if (decoded['error'] is String) {
              errorMessage = decoded['error'] as String;
            }
          }
        } catch (_) {
          // Response body wasn't JSON - keep the raw text as-is.
        }

        throw RemoteOcrException(
          globalLimitReached ? errorMessage : '$failureLabel failed. $errorMessage',
          statusCode: response.statusCode,
          globalLimitReached: globalLimitReached,
        );
      }

      final output = response.bodyBytes;
      if (output.isEmpty) {
        throw RemoteOcrException('$failureLabel returned an empty file.');
      }

      return output;
    } on TimeoutException {
      throw RemoteOcrException('$failureLabel timed out. The document may be too large or the service is busy.');
    } on RemoteOcrException {
      rethrow;
    } catch (error) {
      throw RemoteOcrException('$failureLabel failed: $error');
    }
  }
}
