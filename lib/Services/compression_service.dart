import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf_render/pdf_render.dart' as pdf_render;
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

    if (kIsWeb) {
      return _compressPdfWithSyncfusion(bytes);
    }

    Uint8List best = bytes;

    // Try render-based recomposition first (when runtime supports pdf_render).
    try {
      final rendered = await _compressPdfByRendering(bytes, targetBytes);
      if (rendered.length < best.length) {
        best = rendered;
      }
      if (best.length <= targetBytes) {
        return best;
      }
    } catch (_) {
      // Continue to syncfusion fallback.
    }

    // Always try syncfusion compression as an additional pass.
    final syncfusionCompressed = _compressPdfWithSyncfusion(best);
    if (syncfusionCompressed.length < best.length) {
      best = syncfusionCompressed;
    }

    // On web, if render path is unavailable, this still returns best effort.
    if (kIsWeb) {
      return best;
    }

    return best;
  }

  Future<Uint8List> forceCompressPdfToTarget(
    Uint8List bytes,
    int targetBytes,
    String fileName,
  ) async {
    if (kIsWeb) {
      return _compressPdfWithSyncfusion(bytes);
    }

    Uint8List best = await compressPdf(bytes, targetBytes, fileName);
    if (best.length <= targetBytes) {
      return best;
    }

    // User-approved heavy quality reduction attempt.
    for (final dimension in [900, 700, 520, 380, 280]) {
      try {
        final forced = await _compressPdfByRendering(
          best,
          targetBytes,
          maxRenderDimension: dimension,
          minQuality: 6,
          qualityStep: 6,
          pageTargetTolerance: 1.0,
        );
        if (forced.length < best.length) {
          best = forced;
        }
        if (best.length <= targetBytes) {
          return best;
        }
      } catch (_) {
        // Keep trying next stronger profile.
      }
    }

    final syncfusionCompressed = _compressPdfWithSyncfusion(best);
    if (syncfusionCompressed.length < best.length) {
      best = syncfusionCompressed;
    }

    return best;
  }

  Future<Uint8List> _compressPdfByRendering(
    Uint8List bytes,
    int targetBytes,
    {
    int maxRenderDimension = 1200,
    int minQuality = 30,
    int qualityStep = 10,
    double pageTargetTolerance = 1.2,
  }) async {

    final pdfDoc = await pdf_render.PdfDocument.openData(bytes);
    try {
      final outputPdf = pdf.PdfDocument();
      final pageCount = pdfDoc.pageCount;
      final pageTarget = max(1, (targetBytes / pageCount).floor());

      for (var pageIndex = 1; pageIndex <= pageCount; pageIndex++) {
        final page = await pdfDoc.getPage(pageIndex);

        final int originalWidth = page.width.round();
        final int originalHeight = page.height.round();
        final renderScale = min(
          1.0,
          maxRenderDimension / max(originalWidth, originalHeight),
        );

        final int renderWidth = max(1, (originalWidth * renderScale).round());
        final int renderHeight = max(1, (originalHeight * renderScale).round());

        final pageImage = await page.render(
          width: renderWidth,
          height: renderHeight,
          backgroundFill: true,
        );

        final image = img.Image.fromBytes(
          width: renderWidth,
          height: renderHeight,
          bytes: pageImage.pixels.buffer,
          bytesOffset: pageImage.pixels.offsetInBytes,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );

        int quality = 80;
        Uint8List jpegBytes = Uint8List.fromList(
          img.encodeJpg(image, quality: quality),
        );
        while (quality > minQuality && jpegBytes.length > pageTarget * pageTargetTolerance) {
          quality -= qualityStep;
          if (quality < minQuality) {
            quality = minQuality;
          }
          jpegBytes = Uint8List.fromList(
            img.encodeJpg(image, quality: quality),
          );
          if (quality == minQuality) {
            break;
          }
        }

        final outputPage = pdf.PdfPage(
          outputPdf,
          pageFormat: pdf.PdfPageFormat(page.width, page.height),
        );

        final graphics = outputPage.getGraphics();
        final pdfImage = pdf.PdfImage.jpeg(
          outputPdf,
          image: jpegBytes,
        );

        graphics.drawImage(
          pdfImage,
          0,
          0,
          page.width,
          page.height,
        );

        pageImage.dispose();
      }

      final compressedOutput = await outputPdf.save();
      return compressedOutput.length < bytes.length
          ? compressedOutput
          : bytes;
    } finally {
      await pdfDoc.dispose();
    }
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
