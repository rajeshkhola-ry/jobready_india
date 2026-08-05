import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

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

enum PassportBackgroundColor {
  white,
  blue,
  grey,
}

class WasmDocumentService {
  const WasmDocumentService._();

  static const _ocrWorkerMaxPages = 4;
  static const _onnxInputSize = 320;

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

  static const _onnxBackgroundRemovalWorkerScript = '''
self.onmessage = async (event) => {
  const payload = event.data || {};
  const imageDataUrl = payload.imageDataUrl;
  const modelUrl = payload.modelUrl;
  if (!imageDataUrl || !modelUrl) {
    self.postMessage({ ok: false, error: 'Missing image/model for ONNX hook.' });
    return;
  }

  try {
    importScripts('https://cdn.jsdelivr.net/npm/onnxruntime-web/dist/ort.min.js');
    const image = await loadImage(imageDataUrl);
    const canvas = new OffscreenCanvas(320, 320);
    const ctx = canvas.getContext('2d');
    ctx.drawImage(image, 0, 0, 320, 320);
    const imageData = ctx.getImageData(0, 0, 320, 320);
    const tensorData = new Float32Array(1 * 3 * 320 * 320);

    for (let i = 0; i < 320 * 320; i++) {
      const r = imageData.data[i * 4 + 0] / 255;
      const g = imageData.data[i * 4 + 1] / 255;
      const b = imageData.data[i * 4 + 2] / 255;
      tensorData[i] = r;
      tensorData[320 * 320 + i] = g;
      tensorData[2 * 320 * 320 + i] = b;
    }

    const tensor = new ort.Tensor('float32', tensorData, [1, 3, 320, 320]);
    const session = await ort.InferenceSession.create(modelUrl, {
      executionProviders: ['webgl', 'wasm']
    });

    const inputName = session.inputNames[0];
    const result = await session.run({ [inputName]: tensor });
    const outputName = session.outputNames[0];
    const mask = result[outputName];
    if (!mask || !mask.data) {
      self.postMessage({ ok: false, error: 'ONNX output mask missing.' });
      return;
    }

    const outCanvas = new OffscreenCanvas(image.width, image.height);
    const outCtx = outCanvas.getContext('2d');
    outCtx.drawImage(image, 0, 0);
    const outData = outCtx.getImageData(0, 0, image.width, image.height);

    for (let y = 0; y < image.height; y++) {
      for (let x = 0; x < image.width; x++) {
        const mx = Math.floor((x / image.width) * 320);
        const my = Math.floor((y / image.height) * 320);
        const mIndex = my * 320 + mx;
        const alpha = Math.max(0, Math.min(255, Math.round(mask.data[mIndex] * 255)));
        outData.data[(y * image.width + x) * 4 + 3] = alpha;
      }
    }

    outCtx.putImageData(outData, 0, 0);
    const blob = await outCanvas.convertToBlob({ type: 'image/png' });
    const reader = new FileReader();
    reader.onload = () => {
      self.postMessage({ ok: true, resultDataUrl: reader.result });
    };
    reader.readAsDataURL(blob);
  } catch (error) {
    const message = error && error.message ? error.message : String(error);
    self.postMessage({ ok: false, error: message });
  }
};

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = src;
  });
}
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

  static Future<Uint8List> removeImageBackgroundClientSide({
    required Uint8List imageBytes,
    bool preferOnnxWebGl = true,
    String onnxModelUrl = 'assets/models/isnet-general-use.onnx',
  }) async {
    if (preferOnnxWebGl && kIsWeb) {
      final onnxOutput = await _removeBackgroundViaOnnxWorker(
        imageBytes: imageBytes,
        modelUrl: onnxModelUrl,
      );
      if (onnxOutput != null) {
        return onnxOutput;
      }
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw StateError('Unable to decode image bytes for background removal.');
    }

    final rgba = decoded.convert(numChannels: 4);
    final background = _sampleDominantBorderColor(rgba);
    final threshold = 52;

    for (var y = 0; y < rgba.height; y++) {
      for (var x = 0; x < rgba.width; x++) {
        final pixel = rgba.getPixel(x, y);
        final distance = _colorDistance(
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
          background.$1,
          background.$2,
          background.$3,
        );

        if (distance <= threshold) {
          rgba.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 0);
        } else {
          rgba.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 255);
        }
      }
    }

    return Uint8List.fromList(img.encodePng(rgba, level: 6));
  }

  static Future<Uint8List> buildGovtPassportPhoto({
    required Uint8List imageBytes,
    PassportBackgroundColor background = PassportBackgroundColor.white,
    int dpi = 300,
    int widthMm = 35,
    int heightMm = 45,
    bool autoCrop = true,
    int quality = 92,
  }) async {
    final source = img.decodeImage(imageBytes);
    if (source == null) {
      throw StateError('Unable to decode image bytes.');
    }

    final pxWidth = ((widthMm / 25.4) * dpi).round().clamp(120, 3000);
    final pxHeight = ((heightMm / 25.4) * dpi).round().clamp(160, 3800);

    img.Image working = source;
    if (autoCrop) {
      working = _smartCenterCrop(source, pxWidth / pxHeight);
    }

    final resized = img.copyResize(
      working,
      width: pxWidth,
      height: pxHeight,
      interpolation: img.Interpolation.cubic,
    ).convert(numChannels: 4);

    final bg = _passportBgRgb(background);
    final flattened = img.Image(width: resized.width, height: resized.height, numChannels: 4);
    img.fill(flattened, color: img.ColorRgba8(bg.$1, bg.$2, bg.$3, 255));

    img.compositeImage(flattened, resized);
    final cleaned = _applyUnsharpMask(flattened, amount: 0.28, radius: 1, threshold: 3);
    return Uint8List.fromList(img.encodeJpg(cleaned, quality: quality.clamp(30, 100)));
  }

  static Future<Uint8List> upscaleAndSharpenImage({
    required Uint8List imageBytes,
    double scale = 2.0,
    int quality = 92,
  }) async {
    final source = img.decodeImage(imageBytes);
    if (source == null) {
      throw StateError('Unable to decode image bytes for upscaling.');
    }

    final safeScale = scale.clamp(1.0, 4.0);
    final width = (source.width * safeScale).round().clamp(source.width, 6400);
    final height = (source.height * safeScale).round().clamp(source.height, 6400);

    final upscaled = img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.cubic,
    );
    final sharpened = _applyUnsharpMask(upscaled, amount: 0.34, radius: 1, threshold: 3);
    return Uint8List.fromList(img.encodeJpg(sharpened, quality: quality.clamp(30, 100)));
  }

  static Future<String> convertPngToSimpleSvg({
    required Uint8List imageBytes,
    int maxDimension = 220,
  }) async {
    final source = img.decodeImage(imageBytes);
    if (source == null) {
      throw StateError('Unable to decode image for SVG conversion.');
    }

    final scale = maxDimension / (source.width > source.height ? source.width : source.height);
    final targetScale = scale < 1 ? scale : 1.0;
    final resized = img.copyResize(
      source,
      width: (source.width * targetScale).round().clamp(1, maxDimension),
      height: (source.height * targetScale).round().clamp(1, maxDimension),
      interpolation: img.Interpolation.average,
    ).convert(numChannels: 4);

    final sb = StringBuffer();
    sb.writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${resized.width} ${resized.height}" shape-rendering="crispEdges">');

    for (var y = 0; y < resized.height; y++) {
      var x = 0;
      while (x < resized.width) {
        final px = resized.getPixel(x, y);
        final r = _quantize(px.r.toInt(), 24);
        final g = _quantize(px.g.toInt(), 24);
        final b = _quantize(px.b.toInt(), 24);
        final a = px.a.toInt();

        var run = 1;
        while (x + run < resized.width) {
          final next = resized.getPixel(x + run, y);
          final nr = _quantize(next.r.toInt(), 24);
          final ng = _quantize(next.g.toInt(), 24);
          final nb = _quantize(next.b.toInt(), 24);
          final na = next.a.toInt();
          if (nr != r || ng != g || nb != b || na != a) {
            break;
          }
          run++;
        }

        if (a > 0) {
          final opacity = (a / 255).toStringAsFixed(3);
          sb.writeln('<rect x="$x" y="$y" width="$run" height="1" fill="${_rgbToHex(r, g, b)}" fill-opacity="$opacity"/>');
        }

        x += run;
      }
    }

    sb.writeln('</svg>');
    return sb.toString();
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

  static Future<Uint8List?> _removeBackgroundViaOnnxWorker({
    required Uint8List imageBytes,
    required String modelUrl,
  }) async {
    if (!kIsWeb) {
      return null;
    }

    final dataUrl = 'data:image/png;base64,${base64Encode(imageBytes)}';
    final scriptBlob = html.Blob(<Object>[_onnxBackgroundRemovalWorkerScript], 'application/javascript');
    final scriptUrl = html.Url.createObjectUrlFromBlob(scriptBlob);
    final worker = html.Worker(scriptUrl);
    html.Url.revokeObjectUrl(scriptUrl);

    final completer = Completer<Uint8List?>();
    late StreamSubscription<html.MessageEvent> sub;
    sub = worker.onMessage.listen((event) {
      final payload = event.data;
      if (payload is! Map) {
        return;
      }

      final ok = payload['ok'] == true;
      if (ok && payload['resultDataUrl'] != null) {
        final uri = Uri.parse(payload['resultDataUrl'].toString());
        final bytes = uri.data?.contentAsBytes();
        if (!completer.isCompleted) {
          completer.complete(bytes == null ? null : Uint8List.fromList(bytes));
        }
        return;
      }

      if (!ok && !completer.isCompleted) {
        completer.complete(null);
      }
    });

    worker.postMessage({
      'imageDataUrl': dataUrl,
      'modelUrl': modelUrl,
      'inputSize': _onnxInputSize,
    });

    try {
      return await completer.future.timeout(const Duration(seconds: 35));
    } catch (_) {
      return null;
    } finally {
      await sub.cancel();
      worker.terminate();
    }
  }

  static (int, int, int) _sampleDominantBorderColor(img.Image image) {
    var red = 0;
    var green = 0;
    var blue = 0;
    var count = 0;

    void take(int x, int y) {
      final p = image.getPixel(x, y);
      red += p.r.toInt();
      green += p.g.toInt();
      blue += p.b.toInt();
      count++;
    }

    for (var x = 0; x < image.width; x++) {
      take(x, 0);
      if (image.height > 1) take(x, image.height - 1);
    }
    for (var y = 1; y < image.height - 1; y++) {
      take(0, y);
      if (image.width > 1) take(image.width - 1, y);
    }

    if (count == 0) {
      return (255, 255, 255);
    }
    return (red ~/ count, green ~/ count, blue ~/ count);
  }

  static int _colorDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
    final dr = r1 - r2;
    final dg = g1 - g2;
    final db = b1 - b2;
    return math.sqrt((dr * dr + dg * dg + db * db).toDouble()).round();
  }

  static img.Image _smartCenterCrop(img.Image source, double targetRatio) {
    final sourceRatio = source.width / source.height;
    if (sourceRatio > targetRatio) {
      final cropWidth = (source.height * targetRatio).round();
      final x = ((source.width - cropWidth) / 2).round();
      return img.copyCrop(source, x: x, y: 0, width: cropWidth, height: source.height);
    }
    final cropHeight = (source.width / targetRatio).round();
    final y = ((source.height - cropHeight) / 2).round();
    return img.copyCrop(source, x: 0, y: y, width: source.width, height: cropHeight);
  }

  static (int, int, int) _passportBgRgb(PassportBackgroundColor background) {
    switch (background) {
      case PassportBackgroundColor.blue:
        return (179, 208, 255);
      case PassportBackgroundColor.grey:
        return (224, 224, 224);
      case PassportBackgroundColor.white:
      default:
        return (255, 255, 255);
    }
  }

  static img.Image _applyUnsharpMask(
    img.Image source, {
    double amount = 0.25,
    int radius = 1,
    int threshold = 2,
  }) {
    final blurred = img.gaussianBlur(source, radius: radius);
    final out = source.clone();

    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final o = source.getPixel(x, y);
        final b = blurred.getPixel(x, y);

        final dr = o.r.toInt() - b.r.toInt();
        final dg = o.g.toInt() - b.g.toInt();
        final db = o.b.toInt() - b.b.toInt();

        final nextR = dr.abs() < threshold
            ? o.r.toInt()
            : (o.r.toInt() + (dr * amount)).round().clamp(0, 255);
        final nextG = dg.abs() < threshold
            ? o.g.toInt()
            : (o.g.toInt() + (dg * amount)).round().clamp(0, 255);
        final nextB = db.abs() < threshold
            ? o.b.toInt()
            : (o.b.toInt() + (db * amount)).round().clamp(0, 255);

        out.setPixelRgba(x, y, nextR, nextG, nextB, o.a.toInt());
      }
    }
    return out;
  }

  static int _quantize(int value, int step) {
    if (step <= 1) {
      return value.clamp(0, 255);
    }
    final q = (value / step).round() * step;
    return q.clamp(0, 255);
  }

  static String _rgbToHex(int r, int g, int b) {
    final rs = r.toRadixString(16).padLeft(2, '0');
    final gs = g.toRadixString(16).padLeft(2, '0');
    final bs = b.toRadixString(16).padLeft(2, '0');
    return '#$rs$gs$bs';
  }
}
