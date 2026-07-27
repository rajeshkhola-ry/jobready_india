import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'compression_service.dart';

class RemoteCompressionService {
  const RemoteCompressionService();

  Future<PdfCompressionResult> compressPdf({
    required Uint8List bytes,
    required String fileName,
    required int targetBytes,
    required PdfCompressionMode mode,
    required CompressionPipelineMode pipelineMode,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.compressionEndpoint}');
    final request = http.MultipartRequest('POST', uri)
      ..fields['quality'] = _qualityFor(mode, pipelineMode).toString()
      ..fields['format'] = 'jpeg'
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

    try {
      final streamed = await request.send().timeout(ApiConfig.receiveTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        return PdfCompressionResult(
          bytes: bytes,
          targetMet: bytes.length <= targetBytes,
          message: 'Remote compression API unavailable (${response.statusCode}). Using local fallback.',
        );
      }

      final output = response.bodyBytes;
      if (output.isEmpty || output.length >= bytes.length) {
        return PdfCompressionResult(
          bytes: bytes,
          targetMet: bytes.length <= targetBytes,
          message: 'Remote compression returned no size gain. Using local fallback.',
        );
      }

      return PdfCompressionResult(
        bytes: output,
        targetMet: output.length <= targetBytes,
        message: output.length <= targetBytes
            ? 'Compressed through remote API and target achieved.'
            : 'Compressed through remote API. Best remote result returned.',
      );
    } on TimeoutException {
      return PdfCompressionResult(
        bytes: bytes,
        targetMet: bytes.length <= targetBytes,
        message: 'Remote compression timed out. Using local fallback.',
      );
    } catch (_) {
      return PdfCompressionResult(
        bytes: bytes,
        targetMet: bytes.length <= targetBytes,
        message: 'Remote compression failed. Using local fallback.',
      );
    }
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
