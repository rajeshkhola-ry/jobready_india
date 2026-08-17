import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf_render/pdf_render.dart' as pdf_render;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

enum PdfCompressionMode {
  smallSize,
  recommended,
  highQuality,
  targetSize,
}

enum CompressionPipelineMode {
  standard,
  highCompressionImageOnly,
}

class PdfCompressionResult {
  final Uint8List bytes;
  final bool targetMet;
  final String message;

  const PdfCompressionResult({
    required this.bytes,
    required this.targetMet,
    required this.message,
  });
}

class _PdfContentProfile {
  final bool likelyImageHeavy;
  final bool likelyLowColorScan;

  const _PdfContentProfile({
    required this.likelyImageHeavy,
    required this.likelyLowColorScan,
  });
}

class _RenderPlan {
  final int maxRenderDimension;
  final int startQuality;
  final int minQuality;
  final int qualityStep;
  final double pageTargetTolerance;

  const _RenderPlan({
    required this.maxRenderDimension,
    required this.startQuality,
    required this.minQuality,
    required this.qualityStep,
    required this.pageTargetTolerance,
  });
}

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
    {
    CompressionPipelineMode pipelineMode = CompressionPipelineMode.standard,
    }
  ) async {
    final result = await compressPdfSmart(
      bytes,
      targetBytes,
      fileName,
      mode: PdfCompressionMode.recommended,
      pipelineMode: pipelineMode,
    );
    return result.bytes;
  }

  Future<PdfCompressionResult> compressPdfSmart(
    Uint8List bytes,
    int targetBytes,
    String fileName, {
    PdfCompressionMode mode = PdfCompressionMode.recommended,
    CompressionPipelineMode pipelineMode = CompressionPipelineMode.standard,
  }) async {
    if (bytes.isEmpty || targetBytes <= 0) {
      return PdfCompressionResult(
        bytes: bytes,
        targetMet: false,
        message: 'Invalid file or target size.',
      );
    }

    if (bytes.length <= targetBytes) {
      return PdfCompressionResult(
        bytes: bytes,
        targetMet: true,
        message: 'Input is already below target size.',
      );
    }

    Uint8List best = bytes;
    final sourcePageCount = _tryGetPdfPageCount(bytes);
    final contentProfile = _profilePdfContent(bytes, sourcePageCount);

    if (pipelineMode == CompressionPipelineMode.highCompressionImageOnly) {
      final imageOnly = await _compressPdfImageOnlyHigh(
        bytes,
        targetBytes,
        sourcePageCount: sourcePageCount,
        contentProfile: contentProfile,
      );

      return PdfCompressionResult(
        bytes: imageOnly,
        targetMet: imageOnly.length <= targetBytes,
        message: imageOnly.length <= targetBytes
            ? 'High Compression (image-only) target achieved.'
            : 'High Compression (image-only) applied with metadata/object optimization. Best possible output returned.',
      );
    }

    final syncfusionPass = _compressPdfWithSyncfusion(best);
    if (_isBetterPdfCandidate(
      candidate: syncfusionPass,
      currentBest: best,
      expectedPageCount: sourcePageCount,
    )) {
      best = syncfusionPass;
    }
    if (best.length <= targetBytes && mode != PdfCompressionMode.smallSize) {
      return PdfCompressionResult(
        bytes: best,
        targetMet: true,
        message: 'Target achieved using resource/object compression.',
      );
    }

    final plans = _buildRenderPlans(
      sourceBytes: bytes.length,
      targetBytes: targetBytes,
      mode: mode,
      imageHeavy: contentProfile.likelyImageHeavy,
    );

    for (final plan in plans) {
      try {
        final rendered = await _compressPdfByRendering(
          bytes,
          targetBytes,
          maxRenderDimension: plan.maxRenderDimension,
          minQuality: plan.minQuality,
          qualityStep: plan.qualityStep,
          pageTargetTolerance: plan.pageTargetTolerance,
          startQuality: plan.startQuality,
          contentProfile: contentProfile,
        );

        if (_isBetterPdfCandidate(
          candidate: rendered,
          currentBest: best,
          expectedPageCount: sourcePageCount,
        )) {
          best = rendered;
        }

        final refined = _compressPdfWithSyncfusion(best);
        if (_isBetterPdfCandidate(
          candidate: refined,
          currentBest: best,
          expectedPageCount: sourcePageCount,
        )) {
          best = refined;
        }

        if (best.length <= targetBytes) {
          return PdfCompressionResult(
            bytes: best,
            targetMet: true,
            message: 'Target achieved with adaptive image and object optimization.',
          );
        }
      } catch (_) {
        // Continue with remaining render plans.
      }
    }

    if (best.length >= bytes.length) {
      try {
        final imageOnlyFallback = await _compressPdfImageOnlyHigh(
          bytes,
          targetBytes,
          sourcePageCount: sourcePageCount,
          contentProfile: contentProfile,
        );
        if (_isBetterPdfCandidate(
          candidate: imageOnlyFallback,
          currentBest: best,
          expectedPageCount: sourcePageCount,
        )) {
          best = imageOnlyFallback;
        }
      } catch (_) {
        // If image-only fallback fails, return best effort candidate.
      }
    }

    return PdfCompressionResult(
      bytes: best,
      targetMet: best.length <= targetBytes,
      message: best.length <= targetBytes
          ? 'Target achieved with best-effort optimization.'
          : 'Requested target could not be reached without severe quality loss. Returning best possible optimized output.',
    );
  }

  Future<Uint8List> forceCompressPdfToTarget(
    Uint8List bytes,
    int targetBytes,
    String fileName,
    {
    CompressionPipelineMode pipelineMode = CompressionPipelineMode.standard,
    }
  ) async {
    if (pipelineMode == CompressionPipelineMode.highCompressionImageOnly) {
      return _compressPdfImageOnlyHigh(
        bytes,
        targetBytes,
        sourcePageCount: _tryGetPdfPageCount(bytes),
        contentProfile: _profilePdfContent(bytes, _tryGetPdfPageCount(bytes)),
      );
    }

    final sourcePageCount = _tryGetPdfPageCount(bytes);
    Uint8List best = (await compressPdfSmart(
      bytes,
      targetBytes,
      fileName,
      mode: PdfCompressionMode.smallSize,
      pipelineMode: pipelineMode,
    ))
        .bytes;
    if (best.length <= targetBytes) {
      return best;
    }

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
        if (_isBetterPdfCandidate(
          candidate: forced,
          currentBest: best,
          expectedPageCount: sourcePageCount,
        )) {
          best = forced;
        }
        if (best.length <= targetBytes) {
          return best;
        }
      } catch (_) {
        // Keep trying progressively stronger profiles.
      }
    }

    final syncfusionCompressed = _compressPdfWithSyncfusion(best);
    if (_isBetterPdfCandidate(
      candidate: syncfusionCompressed,
      currentBest: best,
      expectedPageCount: sourcePageCount,
    )) {
      best = syncfusionCompressed;
    }

    return best;
  }

  Future<Uint8List> _compressPdfByRendering(
    Uint8List bytes,
    int targetBytes,
    {
    int maxRenderDimension = 1200,
    int? renderDpi,
    int startQuality = 80,
    int minQuality = 30,
    int qualityStep = 10,
    double pageTargetTolerance = 1.2,
    _PdfContentProfile contentProfile = const _PdfContentProfile(
      likelyImageHeavy: false,
      likelyLowColorScan: false,
    ),
  }) async {
    // `pdf_render` bridges to a JS/WASM PDF engine on Flutter Web. For some
    // PDFs (larger/more complex files in particular) that bridge can throw an
    // error outside Dart's normal synchronous try/catch reach, surfacing to
    // the UI as an uncaught PlatformException instead of being absorbed by
    // the caller's `catch (_) { continue }` retry loop. Never touch it on
    // web - the Syncfusion-based passes (and the server-side multi-pass
    // pipeline) already cover this tier safely.
    if (kIsWeb) {
      throw UnsupportedError('Rendering-based PDF compression is disabled on Flutter Web.');
    }

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

        int renderWidth = max(1, (originalWidth * renderScale).round());
        int renderHeight = max(1, (originalHeight * renderScale).round());
        if (renderDpi != null && renderDpi > 0) {
          final dpiScale = renderDpi / 72.0;
          renderWidth = max(1, (page.width * dpiScale).round());
          renderHeight = max(1, (page.height * dpiScale).round());
        }

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

        final jpegBytes = _compressRenderedPageImage(
          image,
          pageTarget: pageTarget,
          startQuality: startQuality,
          minQuality: minQuality,
          qualityStep: qualityStep,
          pageTargetTolerance: pageTargetTolerance,
          preferPng: contentProfile.likelyLowColorScan,
          aggressiveScaleDown: contentProfile.likelyImageHeavy,
        );

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
      return compressedOutput;
    } finally {
      await pdfDoc.dispose();
    }
  }

  bool _isBetterPdfCandidate({
    required Uint8List candidate,
    required Uint8List currentBest,
    required int expectedPageCount,
  }) {
    if (candidate.isEmpty || candidate.length >= currentBest.length) {
      return false;
    }

    final pageCount = _tryGetPdfPageCount(candidate);
    return pageCount > 0 && pageCount == expectedPageCount;
  }

  int _tryGetPdfPageCount(Uint8List bytes) {
    try {
      final doc = sfpdf.PdfDocument(inputBytes: bytes);
      try {
        return doc.pages.count;
      } finally {
        doc.dispose();
      }
    } catch (_) {
      return -1;
    }
  }

  List<_RenderPlan> _buildRenderPlans({
    required int sourceBytes,
    required int targetBytes,
    required PdfCompressionMode mode,
    required bool imageHeavy,
  }) {
    if (mode == PdfCompressionMode.highQuality) {
      return [
        _RenderPlan(
          maxRenderDimension: imageHeavy ? 1600 : 1800,
          startQuality: 88,
          minQuality: 60,
          qualityStep: 6,
          pageTargetTolerance: 1.35,
        ),
        _RenderPlan(
          maxRenderDimension: imageHeavy ? 1400 : 1600,
          startQuality: 82,
          minQuality: 52,
          qualityStep: 6,
          pageTargetTolerance: 1.25,
        ),
      ];
    }

    if (mode == PdfCompressionMode.smallSize) {
      return [
        _RenderPlan(
          maxRenderDimension: imageHeavy ? 1100 : 1300,
          startQuality: 72,
          minQuality: imageHeavy ? 18 : 24,
          qualityStep: 10,
          pageTargetTolerance: 1.15,
        ),
        _RenderPlan(
          maxRenderDimension: imageHeavy ? 860 : 1000,
          startQuality: imageHeavy ? 52 : 58,
          minQuality: imageHeavy ? 10 : 14,
          qualityStep: 8,
          pageTargetTolerance: 1.08,
        ),
        _RenderPlan(
          maxRenderDimension: imageHeavy ? 680 : 760,
          startQuality: imageHeavy ? 38 : 45,
          minQuality: 8,
          qualityStep: 6,
          pageTargetTolerance: 1.02,
        ),
      ];
    }

    if (mode == PdfCompressionMode.targetSize) {
      final ratio = targetBytes / sourceBytes;
      if (ratio <= 0.35) {
        return [
          _RenderPlan(
            maxRenderDimension: imageHeavy ? 980 : 1200,
            startQuality: imageHeavy ? 58 : 66,
            minQuality: imageHeavy ? 12 : 16,
            qualityStep: 10,
            pageTargetTolerance: 1.08,
          ),
          _RenderPlan(
            maxRenderDimension: imageHeavy ? 780 : 900,
            startQuality: imageHeavy ? 44 : 52,
            minQuality: imageHeavy ? 8 : 10,
            qualityStep: 8,
            pageTargetTolerance: 1.03,
          ),
          _RenderPlan(
            maxRenderDimension: imageHeavy ? 620 : 700,
            startQuality: imageHeavy ? 34 : 40,
            minQuality: 6,
            qualityStep: 6,
            pageTargetTolerance: 1.0,
          ),
        ];
      }

      return [
        _RenderPlan(
          maxRenderDimension: imageHeavy ? 1280 : 1500,
          startQuality: imageHeavy ? 70 : 78,
          minQuality: imageHeavy ? 26 : 34,
          qualityStep: 8,
          pageTargetTolerance: 1.2,
        ),
        _RenderPlan(
          maxRenderDimension: imageHeavy ? 980 : 1200,
          startQuality: imageHeavy ? 60 : 68,
          minQuality: imageHeavy ? 20 : 26,
          qualityStep: 8,
          pageTargetTolerance: 1.12,
        ),
        _RenderPlan(
          maxRenderDimension: imageHeavy ? 820 : 980,
          startQuality: imageHeavy ? 48 : 58,
          minQuality: imageHeavy ? 12 : 16,
          qualityStep: 8,
          pageTargetTolerance: 1.05,
        ),
      ];
    }

    return [
      _RenderPlan(
        maxRenderDimension: imageHeavy ? 1380 : 1600,
        startQuality: imageHeavy ? 76 : 84,
        minQuality: imageHeavy ? 32 : 44,
        qualityStep: 8,
        pageTargetTolerance: 1.28,
      ),
      _RenderPlan(
        maxRenderDimension: imageHeavy ? 1080 : 1300,
        startQuality: imageHeavy ? 64 : 74,
        minQuality: imageHeavy ? 24 : 34,
        qualityStep: 8,
        pageTargetTolerance: 1.18,
      ),
      _RenderPlan(
        maxRenderDimension: imageHeavy ? 900 : 1100,
        startQuality: imageHeavy ? 54 : 64,
        minQuality: imageHeavy ? 16 : 24,
        qualityStep: 8,
        pageTargetTolerance: 1.1,
      ),
    ];
  }

  _PdfContentProfile _profilePdfContent(Uint8List bytes, int pageCount) {
    try {
      final document = sfpdf.PdfDocument(inputBytes: bytes);
      try {
        final extracted = sfpdf.PdfTextExtractor(document).extractText().trim();
        final pages = pageCount > 0 ? pageCount : max(1, document.pages.count);
        final charsPerPage = extracted.length / pages;
        final bytesPerPage = bytes.length / pages;
        final likelyImageHeavy = charsPerPage < 60 && bytesPerPage > (180 * 1024);
        final likelyLowColorScan = charsPerPage < 30;
        return _PdfContentProfile(
          likelyImageHeavy: likelyImageHeavy,
          likelyLowColorScan: likelyLowColorScan,
        );
      } finally {
        document.dispose();
      }
    } catch (_) {
      return const _PdfContentProfile(
        likelyImageHeavy: false,
        likelyLowColorScan: false,
      );
    }
  }

  Uint8List _compressRenderedPageImage(
    img.Image source, {
    required int pageTarget,
    required int startQuality,
    required int minQuality,
    required int qualityStep,
    required double pageTargetTolerance,
    required bool preferPng,
    required bool aggressiveScaleDown,
  }) {
    Uint8List best = Uint8List.fromList(img.encodeJpg(source, quality: startQuality));
    final scaleOptions = aggressiveScaleDown
        ? <double>[1.0, 0.9, 0.8, 0.7, 0.6]
        : <double>[1.0, 0.95, 0.9, 0.85];

    for (final scale in scaleOptions) {
      final workingImage = _resizeForScale(source, scale);

      if (preferPng) {
        for (final level in [9, 7, 5, 3]) {
          final encoded = Uint8List.fromList(img.encodePng(workingImage, level: level));
          if (encoded.length < best.length) {
            best = encoded;
          }
          if (encoded.length <= pageTarget * pageTargetTolerance) {
            return encoded;
          }
        }
      }

      for (var quality = startQuality; quality >= minQuality; quality -= qualityStep) {
        final encoded = Uint8List.fromList(img.encodeJpg(workingImage, quality: quality));
        if (encoded.length < best.length) {
          best = encoded;
        }
        if (encoded.length <= pageTarget * pageTargetTolerance) {
          return encoded;
        }
      }
    }

    return best;
  }

  Uint8List _compressPdfWithSyncfusion(Uint8List bytes) {
    try {
      final document = sfpdf.PdfDocument(inputBytes: bytes);
      try {
        document.compressionLevel = sfpdf.PdfCompressionLevel.best;
        final output = Uint8List.fromList(document.saveSync());
        final outputPageCount = _tryGetPdfPageCount(output);
        if (outputPageCount <= 0) {
          return bytes;
        }
        return output.length < bytes.length ? output : bytes;
      } finally {
        document.dispose();
      }
    } catch (_) {
      return bytes;
    }
  }

  Future<Uint8List> _compressPdfImageOnlyHigh(
    Uint8List bytes,
    int targetBytes, {
    required int sourcePageCount,
    required _PdfContentProfile contentProfile,
  }) async {
    Uint8List best = bytes;

    final passes = <({int dpi, int quality, int minQuality, int step})>[
      (dpi: 150, quality: 55, minQuality: 40, step: 5),
      (dpi: 140, quality: 50, minQuality: 32, step: 6),
      (dpi: 130, quality: 44, minQuality: 28, step: 6),
    ];

    for (final pass in passes) {
      try {
        final rendered = await _compressPdfByRendering(
          best,
          targetBytes,
          renderDpi: pass.dpi,
          startQuality: pass.quality,
          minQuality: pass.minQuality,
          qualityStep: pass.step,
          pageTargetTolerance: 1.02,
          contentProfile: contentProfile,
        );

        if (_isBetterPdfCandidate(
          candidate: rendered,
          currentBest: best,
          expectedPageCount: sourcePageCount,
        )) {
          best = rendered;
        }

        final optimized = _compressPdfWithSyncfusion(best);
        if (_isBetterPdfCandidate(
          candidate: optimized,
          currentBest: best,
          expectedPageCount: sourcePageCount,
        )) {
          best = optimized;
        }

        if (best.length <= targetBytes) {
          return best;
        }
      } catch (_) {
        // Continue next high-compression pass.
      }
    }

    return best;
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
