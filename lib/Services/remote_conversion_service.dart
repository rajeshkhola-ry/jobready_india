import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class RemoteConversionException implements Exception {
  final String message;
  final int? statusCode;

  const RemoteConversionException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode == null ? message : '$message (status: $statusCode)';
}

/// Calls the server-side LibreOffice-powered PDF -> DOCX conversion, which
/// preserves tables, multi-column layout, and fonts far better than the
/// local (client-side) OCR-text/image-embedding fallback. Callers should
/// always catch [RemoteConversionException] and fall back to the existing
/// local conversion path on failure.
class RemoteConversionService {
  const RemoteConversionService();

  static const Duration _conversionTimeout = Duration(seconds: 115);

  Future<Uint8List> convertPdfToDocx({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final uri = Uri.parse('$base${ApiConfig.convertPdfToDocxEndpoint}');

      final request = http.MultipartRequest('POST', uri)
        ..fields['tool'] = 'convert'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );

      final streamed = await request.send().timeout(_conversionTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw RemoteConversionException(
          'Remote PDF to Word conversion failed. ${response.body}',
          statusCode: response.statusCode,
        );
      }

      final output = response.bodyBytes;
      if (output.isEmpty) {
        throw const RemoteConversionException('Remote PDF to Word conversion returned an empty file.');
      }

      return output;
    } on TimeoutException {
      throw const RemoteConversionException(
        'Remote PDF to Word conversion timed out. The service may be busy or unreachable.',
      );
    } on RemoteConversionException {
      rethrow;
    } catch (error) {
      final normalized = '$error'.toLowerCase();
      if (normalized.contains('xmlhttprequest') ||
          normalized.contains('network') ||
          normalized.contains('cors') ||
          normalized.contains('timeout') ||
          normalized.contains('socket')) {
        throw const RemoteConversionException(
          'Remote PDF to Word conversion request failed due to network/CORS transport issues.',
        );
      }
      throw RemoteConversionException('Remote PDF to Word conversion failed: $error');
    }
  }

  /// Calls the generic server-side conversion endpoint for PDF -> Image
  /// (JPG/PNG) page export, rasterized via Ghostscript and returned as a ZIP
  /// archive - keeps large/complex PDFs out of browser memory entirely.
  Future<Uint8List> convertPdfToImages({
    required Uint8List bytes,
    required String fileName,
    required String targetFormat,
  }) async {
    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final uri = Uri.parse('$base${ApiConfig.convertGenericEndpoint}');

      final request = http.MultipartRequest('POST', uri)
        ..fields['tool'] = 'convert'
        ..fields['targetFormat'] = targetFormat
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );

      final streamed = await request.send().timeout(_conversionTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw RemoteConversionException(
          'Remote PDF to image conversion failed. ${response.body}',
          statusCode: response.statusCode,
        );
      }

      final output = response.bodyBytes;
      if (output.isEmpty) {
        throw const RemoteConversionException('Remote PDF to image conversion returned an empty file.');
      }

      return output;
    } on TimeoutException {
      throw const RemoteConversionException(
        'Remote PDF to image conversion timed out. The service may be busy or unreachable.',
      );
    } on RemoteConversionException {
      rethrow;
    } catch (error) {
      final normalized = '$error'.toLowerCase();
      if (normalized.contains('xmlhttprequest') ||
          normalized.contains('network') ||
          normalized.contains('cors') ||
          normalized.contains('timeout') ||
          normalized.contains('socket')) {
        throw const RemoteConversionException(
          'Remote PDF to image conversion request failed due to network/CORS transport issues.',
        );
      }
      throw RemoteConversionException('Remote PDF to image conversion failed: $error');
    }
  }
}
