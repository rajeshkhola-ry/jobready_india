import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_config.dart';

class RemotePhotoRenderException implements Exception {
  final String message;

  const RemotePhotoRenderException(this.message);

  @override
  String toString() => message;
}

/// Offloads large-canvas (A2/A3 poster, 2K+) photo preset rendering to the
/// server (sharp/libvips). Flutter Web's compute()/Isolate.run do not provide
/// real background-thread execution on the standard (non-Wasm) web build, so
/// heavy resize/encode work for these presets would otherwise block the
/// browser's UI thread for several seconds. Callers must always catch
/// [RemotePhotoRenderException] and fall back to the existing local pipeline.
class RemotePhotoRenderService {
  const RemotePhotoRenderService();

  static const Duration _renderTimeout = Duration(seconds: 55);

  Future<Uint8List> renderPreset({
    required Uint8List bytes,
    required String fileName,
    required int width,
    required int height,
    required String backgroundColor,
    required bool enableHdMode,
    required String dpi,
    required int maxTargetKb,
    required bool enforceFileSizeLimit,
    required String outputFormat,
  }) async {
    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final uri = Uri.parse('$base${ApiConfig.photoRenderPresetEndpoint}');

      final request = http.MultipartRequest('POST', uri)
        ..fields['width'] = width.toString()
        ..fields['height'] = height.toString()
        ..fields['backgroundColor'] = backgroundColor
        ..fields['enableHdMode'] = enableHdMode.toString()
        ..fields['dpi'] = dpi
        ..fields['maxTargetKb'] = maxTargetKb.toString()
        ..fields['enforceFileSizeLimit'] = enforceFileSizeLimit.toString()
        ..fields['outputFormat'] = outputFormat
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: fileName,
            contentType: _mediaTypeForFileName(fileName),
          ),
        );

      final streamed = await request.send().timeout(_renderTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw RemotePhotoRenderException('Remote photo rendering failed (status: ${response.statusCode}).');
      }

      final output = response.bodyBytes;
      if (output.isEmpty) {
        throw const RemotePhotoRenderException('Remote photo rendering returned an empty file.');
      }

      return output;
    } on TimeoutException {
      throw const RemotePhotoRenderException('Remote photo rendering timed out.');
    } on RemotePhotoRenderException {
      rethrow;
    } catch (error) {
      throw RemotePhotoRenderException('Remote photo rendering failed: $error');
    }
  }

  /// Sends [bytes] to the server's lightweight (sharp-only, no ML model)
  /// background-removal endpoint and returns a transparent PNG. See
  /// compression_server.js's removeImageBackground() for why a classical
  /// color-distance cutout was used instead of an ONNX-based model (both
  /// suggested options held a ~1GB resident model in memory once loaded,
  /// incompatible with the endpoint's <150MB budget).
  Future<Uint8List> removeBackground({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final base = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final uri = Uri.parse('$base${ApiConfig.removeBackgroundEndpoint}');

      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: fileName,
            contentType: _mediaTypeForFileName(fileName),
          ),
        );

      final streamed = await request.send().timeout(_renderTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw RemotePhotoRenderException('Background removal failed (status: ${response.statusCode}).');
      }

      final output = response.bodyBytes;
      if (output.isEmpty) {
        throw const RemotePhotoRenderException('Background removal returned an empty file.');
      }

      return output;
    } on TimeoutException {
      throw const RemotePhotoRenderException('Background removal timed out.');
    } on RemotePhotoRenderException {
      rethrow;
    } catch (error) {
      throw RemotePhotoRenderException('Background removal failed: $error');
    }
  }

  MediaType _mediaTypeForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return MediaType('image', 'jpeg');
    return MediaType('application', 'octet-stream');
  }
}
