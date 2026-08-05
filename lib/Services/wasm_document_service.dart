import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_render/pdf_render.dart' as pdf_render;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

enum WasmImageOutputFormat {
  jpg,
  png,
  bmp,
}

class WasmDocumentService {
  const WasmDocumentService._();

  static const _ocrWorkerMaxPages = 4;

  static const _tesseractWorkerScript = '''
self.onmessage = async (event) => {
  const payload = event.data || {};
  const images = Array.isArray(payload.images) ? payload.images : [];
  if (!images.length) {
    self.postMessage({ ok: false, error: 'No image payload for OCR.' });
    return;
  }

  try {
    importScripts('https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js');
    const worker = await Tesseract.createWorker('eng');
    const collected = [];

    for (let i = 0; i < images.length; i++) {
      const result = await worker.recognize(images[i]);
      const text = result && result.data && result.data.text ? result.data.text : '';
      collected.push(text);
      self.postMessage({ ok: true, progress: (i + 1) / images.length });
    }

    await worker.terminate();
    self.postMessage({ ok: true, text: collected.join('\\n\\n') });
  } catch (error) {
    const message = error && error.message ? error.message : String(error);
    self.postMessage({ ok: false, error: message });
  }
};
''';

  static Future<Uint8List> mergePdfDocuments(List<Uint8List> pdfFiles) async {
    if (pdfFiles.isEmpty) {
      throw ArgumentError('At least one PDF is required for merge.');
    }

    final merged = sfpdf.PdfDocument();
    try {
      for (final bytes in pdfFiles) {
        final source = sfpdf.PdfDocument(inputBytes: bytes);
        try {
          for (var pageIndex = 0; pageIndex < source.pages.count; pageIndex++) {
            final template = source.pages[pageIndex].createTemplate();
            final newPage = merged.pages.add();
            newPage.graphics.drawPdfTemplate(template, Offset.zero);
          }
        } finally {
          source.dispose();
        }
      }

      final mergedBytes = merged.saveSync();
      return Uint8List.fromList(mergedBytes);
    } finally {
      merged.dispose();
    }
  }

  static Future<List<Uint8List>> splitPdfDocument(Uint8List pdfBytes) async {
    final source = sfpdf.PdfDocument(inputBytes: pdfBytes);
    try {
      final output = <Uint8List>[];
      for (var pageIndex = 0; pageIndex < source.pages.count; pageIndex++) {
        final target = sfpdf.PdfDocument();
        try {
          final template = source.pages[pageIndex].createTemplate();
          final page = target.pages.add();
          page.graphics.drawPdfTemplate(template, Offset.zero);
          output.add(Uint8List.fromList(target.saveSync()));
        } finally {
          target.dispose();
        }
      }
      return output;
    } finally {
      source.dispose();
    }
  }

  static Future<Uint8List> splitPdfRange({
    required Uint8List pdfBytes,
    required int startPage,
    required int endPage,
  }) async {
    final source = sfpdf.PdfDocument(inputBytes: pdfBytes);
    try {
      if (source.pages.count == 0) {
        throw StateError('PDF has no pages.');
      }

      if (startPage < 1 || endPage < startPage || endPage > source.pages.count) {
        throw RangeError('Invalid page range. Requested $startPage-$endPage for ${source.pages.count} pages.');
      }

      final target = sfpdf.PdfDocument();
      try {
        for (var pageNumber = startPage; pageNumber <= endPage; pageNumber++) {
          final template = source.pages[pageNumber - 1].createTemplate();
          final page = target.pages.add();
          page.graphics.drawPdfTemplate(template, Offset.zero);
        }
        return Uint8List.fromList(target.saveSync());
      } finally {
        target.dispose();
      }
    } finally {
      source.dispose();
    }
  }

  static Future<Uint8List> compressPdfDocument({
    required Uint8List pdfBytes,
    int? targetBytes,
  }) async {
    // Pass 1: template rebuild keeps vector text when possible.
    final source = sfpdf.PdfDocument(inputBytes: pdfBytes);
    try {
      final rebuilt = sfpdf.PdfDocument();
      try {
        for (var pageIndex = 0; pageIndex < source.pages.count; pageIndex++) {
          final template = source.pages[pageIndex].createTemplate();
          final page = rebuilt.pages.add();
          page.graphics.drawPdfTemplate(template, Offset.zero);
        }

        final compressed = Uint8List.fromList(rebuilt.saveSync());
        if (targetBytes == null) {
          final adaptive = await _compressPdfByRasterizing(
            sourceBytes: compressed.length < pdfBytes.length ? compressed : pdfBytes,
            originalBytes: pdfBytes,
          );
          return adaptive.length < compressed.length ? adaptive : compressed;
        }

        if (compressed.length <= targetBytes || compressed.length < pdfBytes.length) {
          return await _reduceTowardTarget(
            candidateBytes: compressed,
            originalBytes: pdfBytes,
            targetBytes: targetBytes,
          );
        }

        return await _reduceTowardTarget(
          candidateBytes: pdfBytes,
          originalBytes: pdfBytes,
          targetBytes: targetBytes,
        );
      } finally {
        rebuilt.dispose();
      }
    } finally {
      source.dispose();
    }
  }

  static Future<Uint8List> compressImage({
    required Uint8List imageBytes,
    int maxWidth = 1920,
    int maxHeight = 1920,
    int quality = 80,
    WasmImageOutputFormat outputFormat = WasmImageOutputFormat.jpg,
  }) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw StateError('Unable to decode image bytes.');
    }

    final resized = img.copyResize(
      decoded,
      width: decoded.width > maxWidth ? maxWidth : decoded.width,
      height: decoded.height > maxHeight ? maxHeight : decoded.height,
      maintainAspect: true,
      interpolation: img.Interpolation.average,
    );

    final normalizedQuality = quality.clamp(25, 100);
    final encoded = _encodeImage(
      resized,
      outputFormat: outputFormat,
      quality: normalizedQuality,
    );

    return Uint8List.fromList(encoded);
  }

  static Future<Uint8List> buildPassportPhoto({
    required Uint8List imageBytes,
    int outputWidth = 413,
    int outputHeight = 531,
    int quality = 90,
    WasmImageOutputFormat outputFormat = WasmImageOutputFormat.jpg,
  }) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw StateError('Unable to decode image bytes.');
    }

    final sourceRatio = decoded.width / decoded.height;
    final targetRatio = outputWidth / outputHeight;

    img.Image cropped;
    if (sourceRatio > targetRatio) {
      final cropWidth = (decoded.height * targetRatio).round();
      final x = ((decoded.width - cropWidth) / 2).round();
      cropped = img.copyCrop(decoded, x: x, y: 0, width: cropWidth, height: decoded.height);
    } else {
      final cropHeight = (decoded.width / targetRatio).round();
      final y = ((decoded.height - cropHeight) / 2).round();
      cropped = img.copyCrop(decoded, x: 0, y: y, width: decoded.width, height: cropHeight);
    }

    final resized = img.copyResize(
      cropped,
      width: outputWidth,
      height: outputHeight,
      interpolation: img.Interpolation.average,
    );

    final encoded = _encodeImage(
      resized,
      outputFormat: outputFormat,
      quality: quality.clamp(25, 100),
    );

    return Uint8List.fromList(encoded);
  }

  static Future<Uint8List> createPdfFromImages(List<Uint8List> imageFiles) async {
    if (imageFiles.isEmpty) {
      throw ArgumentError('At least one image is required to create a PDF.');
    }

    final document = pw.Document();

    for (final bytes in imageFiles) {
      final provider = pw.MemoryImage(bytes);
      document.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat.a4,
          build: (context) {
            return pw.Center(
              child: pw.Image(provider, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    return document.save();
  }

  static Future<Uint8List> burnSignatureToPdf({
    required Uint8List pdfBytes,
    required Uint8List signatureImageBytes,
    required List<int> pageNumbers,
    double leftRatio = 0.62,
    double topRatio = 0.82,
    double widthRatio = 0.28,
    double heightRatio = 0.1,
  }) async {
    final source = sfpdf.PdfDocument(inputBytes: pdfBytes);
    try {
      if (source.pages.count == 0) {
        throw StateError('PDF has no pages.');
      }

      final clampedLeft = leftRatio.clamp(0.0, 1.0);
      final clampedTop = topRatio.clamp(0.0, 1.0);
      final clampedWidth = widthRatio.clamp(0.05, 1.0);
      final clampedHeight = heightRatio.clamp(0.03, 1.0);

      final targets = pageNumbers
          .where((page) => page >= 1 && page <= source.pages.count)
          .toSet()
          .toList(growable: false);
      if (targets.isEmpty) {
        throw ArgumentError('No valid PDF pages were selected for signature placement.');
      }

      final bitmap = sfpdf.PdfBitmap(signatureImageBytes);
      for (final pageNumber in targets) {
        final page = source.pages[pageNumber - 1];
        final width = page.size.width;
        final height = page.size.height;
        final left = width * clampedLeft;
        final top = height * clampedTop;
        final rectWidth = width * clampedWidth;
        final rectHeight = height * clampedHeight;
        page.graphics.drawImage(bitmap, Rect.fromLTWH(left, top, rectWidth, rectHeight));
      }

      return Uint8List.fromList(source.saveSync());
    } finally {
      source.dispose();
    }
  }

  static Future<Uint8List> protectPdfDocument({
    required Uint8List pdfBytes,
    required String userPassword,
    String? ownerPassword,
    bool allowCopy = false,
    bool allowPrint = false,
  }) async {
    final source = sfpdf.PdfDocument(inputBytes: pdfBytes);
    try {
      final output = sfpdf.PdfDocument();
      try {
        for (var pageIndex = 0; pageIndex < source.pages.count; pageIndex++) {
          final template = source.pages[pageIndex].createTemplate();
          final page = output.pages.add();
          page.graphics.drawPdfTemplate(template, Offset.zero);
        }

        output.security.algorithm = sfpdf.PdfEncryptionAlgorithm.aesx256Bit;
        output.security.userPassword = userPassword;
        output.security.ownerPassword =
            (ownerPassword == null || ownerPassword.trim().isEmpty) ? userPassword : ownerPassword;

        final allowed = <sfpdf.PdfPermissionsFlags>[];
        if (allowCopy) {
          allowed.add(sfpdf.PdfPermissionsFlags.copyContent);
        }
        if (allowPrint) {
          allowed.add(sfpdf.PdfPermissionsFlags.print);
        }

        output.security.permissions.add(allowed);
        return Uint8List.fromList(output.saveSync());
      } finally {
        output.dispose();
      }
    } finally {
      source.dispose();
    }
  }

  static Future<Uint8List> unlockPdfDocument({
    required Uint8List pdfBytes,
    required String password,
  }) async {
    final source = sfpdf.PdfDocument(inputBytes: pdfBytes, password: password);
    try {
      final output = sfpdf.PdfDocument();
      try {
        for (var pageIndex = 0; pageIndex < source.pages.count; pageIndex++) {
          final template = source.pages[pageIndex].createTemplate();
          final page = output.pages.add();
          page.graphics.drawPdfTemplate(template, Offset.zero);
        }
        return Uint8List.fromList(output.saveSync());
      } finally {
        output.dispose();
      }
    } finally {
      source.dispose();
    }
  }

  static Future<String> extractTextFromPdfLocally({
    required Uint8List pdfBytes,
  }) async {
    final source = sfpdf.PdfDocument(inputBytes: pdfBytes);
    try {
      final directText = sfpdf.PdfTextExtractor(source).extractText().trim();
      if (directText.isNotEmpty) {
        return directText;
      }
    } finally {
      source.dispose();
    }

    if (!kIsWeb) {
      return '';
    }

    final pageImages = await _renderPdfPagesAsPngDataUrls(pdfBytes, maxPages: _ocrWorkerMaxPages);
    if (pageImages.isEmpty) {
      return '';
    }

    return _extractViaTesseractWorker(pageImages);
  }

  static void triggerBrowserDownload({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    final blob = html.Blob(<Object>[bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
    anchor.remove();
  }

  static List<int> _encodeImage(
    img.Image image, {
    required WasmImageOutputFormat outputFormat,
    required int quality,
  }) {
    switch (outputFormat) {
      case WasmImageOutputFormat.png:
        return img.encodePng(image, level: 6);
      case WasmImageOutputFormat.bmp:
        return img.encodeBmp(image);
      case WasmImageOutputFormat.jpg:
      default:
        return img.encodeJpg(image, quality: quality);
    }
  }

  static Future<Uint8List> _reduceTowardTarget({
    required Uint8List candidateBytes,
    required Uint8List originalBytes,
    required int targetBytes,
  }) async {
    if (candidateBytes.length <= targetBytes) {
      return candidateBytes;
    }

    final adaptive = await _compressPdfByRasterizing(
      sourceBytes: candidateBytes,
      originalBytes: originalBytes,
      targetBytes: targetBytes,
    );
    if (adaptive.length <= targetBytes) {
      return adaptive;
    }

    if (adaptive.length < candidateBytes.length) {
      return adaptive;
    }

    return candidateBytes.length < originalBytes.length ? candidateBytes : originalBytes;
  }

  static Future<Uint8List> _compressPdfByRasterizing({
    required Uint8List sourceBytes,
    required Uint8List originalBytes,
    int? targetBytes,
  }) async {
    final sourceDoc = sfpdf.PdfDocument(inputBytes: sourceBytes);
    final pageSizes = <Size>[];
    try {
      for (var index = 0; index < sourceDoc.pages.count; index++) {
        pageSizes.add(sourceDoc.pages[index].size);
      }
    } finally {
      sourceDoc.dispose();
    }

    final renderDoc = await pdf_render.PdfDocument.openData(sourceBytes);
    try {
      Uint8List best = sourceBytes;
      final scales = <double>[1.0, 0.84, 0.7];
      final qualities = <int>[82, 70, 58, 46];

      for (final scale in scales) {
        for (final quality in qualities) {
          final rebuilt = sfpdf.PdfDocument();
          try {
            for (var i = 0; i < renderDoc.pageCount; i++) {
              final page = await renderDoc.getPage(i + 1);
              try {
                final targetWidth = (page.width * scale).round().clamp(180, 2200);
                final targetHeight = (page.height * scale).round().clamp(180, 3200);
                final rendered = await page.render(
                  width: targetWidth,
                  height: targetHeight,
                  backgroundFill: true,
                );

                final image = img.Image.fromBytes(
                  width: targetWidth,
                  height: targetHeight,
                  bytes: rendered.pixels.buffer,
                  bytesOffset: rendered.pixels.offsetInBytes,
                  numChannels: 4,
                  order: img.ChannelOrder.rgba,
                );

                final jpg = img.encodeJpg(image, quality: quality);
                final pdfPage = rebuilt.pages.add();
                final pageSize = i < pageSizes.length ? pageSizes[i] : const Size(595, 842);
                pdfPage.graphics.drawImage(
                  sfpdf.PdfBitmap(jpg),
                  Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
                );
                rendered.dispose();
              } finally {
                page.dispose();
              }
            }

            final candidate = Uint8List.fromList(rebuilt.saveSync());
            if (candidate.length < best.length) {
              best = candidate;
            }
            if (targetBytes != null && best.length <= targetBytes) {
              return best;
            }
          } finally {
            rebuilt.dispose();
          }
        }
      }

      if (best.length < sourceBytes.length && best.length < originalBytes.length) {
        return best;
      }
      if (best.length < sourceBytes.length) {
        return best;
      }
      return sourceBytes;
    } finally {
      await renderDoc.dispose();
    }
  }

  static Future<List<String>> _renderPdfPagesAsPngDataUrls(
    Uint8List pdfBytes, {
    required int maxPages,
  }) async {
    final renderDoc = await pdf_render.PdfDocument.openData(pdfBytes);
    try {
      final output = <String>[];
      final pageCount = renderDoc.pageCount < maxPages ? renderDoc.pageCount : maxPages;
      for (var i = 0; i < pageCount; i++) {
        final page = await renderDoc.getPage(i + 1);
        try {
          final targetWidth = page.width.round().clamp(320, 1800);
          final targetHeight = page.height.round().clamp(320, 2400);
          final rendered = await page.render(
            width: targetWidth,
            height: targetHeight,
            backgroundFill: true,
          );
          final image = img.Image.fromBytes(
            width: targetWidth,
            height: targetHeight,
            bytes: rendered.pixels.buffer,
            bytesOffset: rendered.pixels.offsetInBytes,
            numChannels: 4,
            order: img.ChannelOrder.rgba,
          );
          final png = img.encodePng(image, level: 6);
          output.add('data:image/png;base64,${base64Encode(png)}');
          rendered.dispose();
        } finally {
          page.dispose();
        }
      }
      return output;
    } finally {
      await renderDoc.dispose();
    }
  }

  static Future<String> _extractViaTesseractWorker(List<String> dataUrlImages) async {
    final scriptBlob = html.Blob(<Object>[_tesseractWorkerScript], 'application/javascript');
    final scriptUrl = html.Url.createObjectUrlFromBlob(scriptBlob);
    final worker = html.Worker(scriptUrl);
    html.Url.revokeObjectUrl(scriptUrl);

    final completer = Completer<String>();
    late StreamSubscription<html.MessageEvent> sub;
    sub = worker.onMessage.listen((event) {
      final payload = event.data;
      if (payload is! Map) {
        return;
      }
      final ok = payload['ok'] == true;
      final text = payload['text']?.toString() ?? '';
      final error = payload['error']?.toString() ?? '';
      if (ok && text.trim().isNotEmpty) {
        if (!completer.isCompleted) {
          completer.complete(text.trim());
        }
      } else if (!ok && error.isNotEmpty) {
        if (!completer.isCompleted) {
          completer.completeError(StateError(error));
        }
      }
    });

    worker.postMessage({'images': dataUrlImages});
    try {
      final text = await completer.future.timeout(const Duration(seconds: 90));
      return text;
    } catch (_) {
      return '';
    } finally {
      await sub.cancel();
      worker.terminate();
    }
  }
}
