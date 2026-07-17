import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

class CompressionService {
  const CompressionService();

  Uint8List compressImage(
    Uint8List bytes,
    int targetBytes,
    String fileName,
  ) {
    if (targetBytes <= 0 || bytes.isEmpty) {
      return bytes;
    }

    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.png')) {
      return _compressPng(bytes, targetBytes);
    }

    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return _compressJpeg(bytes, targetBytes);
    }

    return bytes;
  }

  Future<Uint8List> compressPdf(
    Uint8List bytes,
    int targetBytes,
    String fileName,
  ) async {
    if (bytes.length <= targetBytes) {
      return bytes;
    }

    return _compressPdfWithSyncfusion(bytes);
  }

  Future<Uint8List> forceCompressPdfToTarget(
    Uint8List bytes,
    int targetBytes,
    String fileName,
  ) async {
    Uint8List best = await compressPdf(bytes, targetBytes, fileName);
    if (best.length <= targetBytes) {
      return best;
    }

    final syncfusionCompressed = _compressPdfWithSyncfusion(best);
    if (syncfusionCompressed.length < best.length) {
      best = syncfusionCompressed;
    }

    return best;
  }

  Uint8List _compressPdfWithSyncfusion(Uint8List bytes) {
    try {
      final document = sfpdf.PdfDocument(inputBytes: bytes);
      try {
        document.compressionLevel = sfpdf.PdfCompressionLevel.best;
        final output = Uint8List.fromList(document.saveSync());
        return output.length < bytes.length ? output : bytes;
      } finally {
        document.dispose();
      }
    } catch (_) {
      return bytes;
    }
  }

  Uint8List _compressJpeg(Uint8List bytes, int targetBytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    Uint8List best = bytes;

    for (final scale in [1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]) {
      final workingImage = _resizeForScale(image, scale);

      for (var quality = 90; quality >= 12; quality -= 6) {
        final encoded = Uint8List.fromList(
          img.encodeJpg(workingImage, quality: quality),
        );

        if (encoded.length < best.length) {
          best = encoded;
        }

        if (encoded.length <= targetBytes) {
          return encoded;
        }
      }
    }

    return best.length < bytes.length ? best : bytes;
  }

  Uint8List _compressPng(Uint8List bytes, int targetBytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    Uint8List best = bytes;

    for (final scale in [1.0, 0.85, 0.7, 0.55, 0.45, 0.35]) {
      final workingImage = _resizeForScale(image, scale);

      for (final level in [9, 8, 7, 6, 5, 4, 3]) {
        final encoded = Uint8List.fromList(
          img.encodePng(workingImage, level: level),
        );

        if (encoded.length < best.length) {
          best = encoded;
        }

        if (encoded.length <= targetBytes) {
          return encoded;
        }
      }
    }

    return best.length < bytes.length ? best : bytes;
  }

  img.Image _resizeForScale(img.Image source, double scale) {
    if (scale >= 0.999) {
      return source;
    }

    final width = max(1, (source.width * scale).round());
    final height = max(1, (source.height * scale).round());

    return img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
  }
}
