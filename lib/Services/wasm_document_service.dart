import 'dart:ui';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:universal_html/html.dart' as html;

class WasmDocumentService {
  const WasmDocumentService._();

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

  static Future<Uint8List> compressImage({
    required Uint8List imageBytes,
    int maxWidth = 1920,
    int maxHeight = 1920,
    int quality = 80,
    img.Format outputFormat = img.Format.jpg,
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
    img.Format outputFormat = img.Format.jpg,
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
          pageFormat: pw.PdfPageFormat.a4,
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
    required img.Format outputFormat,
    required int quality,
  }) {
    switch (outputFormat) {
      case img.Format.png:
        return img.encodePng(image, level: 6);
      case img.Format.webp:
        return img.encodeWebp(image, quality: quality);
      case img.Format.bmp:
        return img.encodeBmp(image);
      case img.Format.tiff:
        return img.encodeTiff(image);
      case img.Format.gif:
        return img.encodeGif(image);
      case img.Format.jpg:
      default:
        return img.encodeJpg(image, quality: quality);
    }
  }
}
