import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'compression_service.dart';

class RemoteCompressionException implements Exception {
  final String message;
  final int? statusCode;

  const RemoteCompressionException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode == null ? message : '$message (status: $statusCode)';
}

class RemoteCompressionService {
  const RemoteCompressionService();

  static const Duration _compressionTimeout = Duration(seconds: 110);

  Future<PdfCompressionResult> compressPdf({
    required Uint8List bytes,
    required String fileName,
    required int targetBytes,
    required PdfCompressionMode mode,
    required CompressionPipelineMode pipelineMode,
  }) async {
    if (bytes.isEmpty) {
      throw const RemoteCompressionException('File has no readable data to compress.');
    }

    try {
      final endpoints = _buildEndpointCandidates();
      http.Response? response;

      for (var i = 0; i < endpoints.length; i++) {
        final request = _buildRequest(
          uri: endpoints[i],
          bytes: bytes,
          fileName: fileName,
          targetBytes: targetBytes,
          mode: mode,
          pipelineMode: pipelineMode,
        );

        final streamed = await request.send().timeout(_compressionTimeout);
        response = await http.Response.fromStream(streamed);

        // Retry once on legacy endpoint if the preferred endpoint is not found.
        if (response.statusCode == 404 && i < endpoints.length - 1) {
          continue;
        }
        break;
      }

      if (response == null) {
        throw const RemoteCompressionException('Remote compression did not return a response.');
      }

      if (response.statusCode != 200) {
        throw RemoteCompressionException(
          'Remote compression failed. ${response.body}',
          statusCode: response.statusCode,
        );
      }

      final output = response.bodyBytes;
      if (output.isEmpty) {
        throw const RemoteCompressionException('Remote compression returned an empty file.');
      }

      return PdfCompressionResult(
        bytes: output,
        targetMet: output.length <= targetBytes,
        message: output.length <= targetBytes
            ? 'Compression success via Render API (target achieved).'
            : 'Compression success via Render API (best API result returned).',
      );
    } on TimeoutException {
      throw const RemoteCompressionException(
        'Remote compression timed out. The service may be busy or unreachable.',
      );
    } on RemoteCompressionException {
      rethrow;
    } catch (error) {
      final normalized = '$error'.toLowerCase();
      if (normalized.contains('xmlhttprequest') ||
          normalized.contains('network') ||
          normalized.contains('cors') ||
          normalized.contains('timeout') ||
          normalized.contains('socket')) {
        throw const RemoteCompressionException(
          'Remote compression request failed due to network/CORS transport issues.',
        );
      }
      throw RemoteCompressionException(
        'Remote compression failed: $error',
      );
    }
  }

  /// Compresses a raster image (JPG/PNG/WEBP/BMP) entirely server-side -
  /// mirrors [compressPdf] so callers never need to touch browser-memory
  /// image processing on the primary path.
  Future<PdfCompressionResult> compressImage({
    required Uint8List bytes,
    required String fileName,
    required int targetBytes,
  }) async {
    if (bytes.isEmpty) {
      throw const RemoteCompressionException('File has no readable data to compress.');
    }

    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final uri = Uri.parse('$base${ApiConfig.compressionEndpoint}');

      final lowerName = fileName.toLowerCase();
      final format = lowerName.endsWith('.png') ? 'webp' : 'jpeg';

      final request = http.MultipartRequest('POST', uri)
        ..fields['quality'] = '80'
        ..fields['format'] = format
        ..fields['targetBytes'] = targetBytes.toString()
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
          ),
        );

      final streamed = await request.send().timeout(_compressionTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw RemoteCompressionException(
          'Remote image compression failed. ${response.body}',
          statusCode: response.statusCode,
        );
      }

      final output = response.bodyBytes;
      if (output.isEmpty) {
        throw const RemoteCompressionException('Remote image compression returned an empty file.');
      }

      return PdfCompressionResult(
        bytes: output,
        targetMet: output.length <= targetBytes,
        message: output.length <= targetBytes
            ? 'Compression success via Render API (target achieved).'
            : 'Compression success via Render API (best API result returned).',
      );
    } on TimeoutException {
      throw const RemoteCompressionException(
        'Remote image compression timed out. The service may be busy or unreachable.',
      );
    } on RemoteCompressionException {
      rethrow;
    } catch (error) {
      final normalized = '$error'.toLowerCase();
      if (normalized.contains('xmlhttprequest') ||
          normalized.contains('network') ||
          normalized.contains('cors') ||
          normalized.contains('timeout') ||
          normalized.contains('socket')) {
        throw const RemoteCompressionException(
          'Remote image compression request failed due to network/CORS transport issues.',
        );
      }
      throw RemoteCompressionException(
        'Remote image compression failed: $error',
      );
    }
  }

  List<Uri> _buildEndpointCandidates() {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    return [
      Uri.parse('$base/compress-pdf'),
      Uri.parse('$base${ApiConfig.compressionEndpoint}'),
    ];
  }

  http.MultipartRequest _buildRequest({
    required Uri uri,
    required Uint8List bytes,
    required String fileName,
    required int targetBytes,
    required PdfCompressionMode mode,
    required CompressionPipelineMode pipelineMode,
  }) {
    return http.MultipartRequest('POST', uri)
      ..fields['quality'] = _qualityFor(mode, pipelineMode).toString()
      ..fields['format'] = 'jpeg'
      ..fields['targetBytes'] = targetBytes.toString()
      ..fields['compressionMode'] =
          pipelineMode == CompressionPipelineMode.highCompressionImageOnly
              ? 'high-compression'
              : 'standard'
      ..fields['max_dimension'] =
          pipelineMode == CompressionPipelineMode.highCompressionImageOnly ? '1600' : '1920'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );
  }

  int _qualityFor(
    PdfCompressionMode mode,
    CompressionPipelineMode pipelineMode,
  ) {
    if (pipelineMode == CompressionPipelineMode.highCompressionImageOnly) {
      return 55;
    }

    return switch (mode) {
      PdfCompressionMode.smallSize => 58,
      PdfCompressionMode.recommended => 68,
      PdfCompressionMode.highQuality => 80,
      PdfCompressionMode.targetSize => 62,
    };
  }
}
