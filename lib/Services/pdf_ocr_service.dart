import 'dart:convert';
import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

import 'api_config.dart';

enum PdfExtractionMode { auto, forceOcr, tableAware }

class PdfOcrResult {
  final bool success;
  final String text;
  final String message;
  final bool usedEmbeddedText;
  final bool usedBackendOcr;

  const PdfOcrResult({
    required this.success,
    required this.text,
    required this.message,
    required this.usedEmbeddedText,
    required this.usedBackendOcr,
  });
}

class PdfOcrService {
  const PdfOcrService();

  Future<PdfOcrResult> extractText({
    required Uint8List pdfBytes,
    required String fileName,
    bool forceOcr = false,
    PdfExtractionMode mode = PdfExtractionMode.auto,
  }) async {
    if (mode == PdfExtractionMode.tableAware) {
      final tableText = _extractWithTableDetection(pdfBytes);
      if (tableText.trim().isNotEmpty) {
        return PdfOcrResult(
          success: true,
          text: tableText.trim(),
          message: 'Table-aware extraction completed. Rows formatted with | separators.',
          usedEmbeddedText: true,
          usedBackendOcr: false,
        );
      }
    }

    if (!forceOcr) {
      final embedded = _extractEmbeddedText(pdfBytes);
      if (embedded.trim().isNotEmpty) {
        return PdfOcrResult(
          success: true,
          text: embedded.trim(),
          message: 'Loaded embedded PDF text.',
          usedEmbeddedText: true,
          usedBackendOcr: false,
        );
      }
    }

    final backend = await _extractViaBackendOcr(pdfBytes: pdfBytes, fileName: fileName);
    if (backend != null && backend.trim().isNotEmpty) {
      return PdfOcrResult(
        success: true,
        text: backend.trim(),
        message: 'OCR text loaded from integration backend.',
        usedEmbeddedText: false,
        usedBackendOcr: true,
      );
    }

    final embeddedFallback = _extractEmbeddedText(pdfBytes);
    if (embeddedFallback.trim().isNotEmpty) {
      return PdfOcrResult(
        success: true,
        text: embeddedFallback.trim(),
        message: 'OCR backend not configured. Loaded embedded PDF text instead.',
        usedEmbeddedText: true,
        usedBackendOcr: false,
      );
    }

    return const PdfOcrResult(
      success: false,
      text: '',
      message:
          'No readable text found. For scanned PDFs, connect OCR backend via integration action extract_text.',
      usedEmbeddedText: false,
      usedBackendOcr: false,
    );
  }

  String _extractEmbeddedText(Uint8List pdfBytes) {
    try {
      final document = sfpdf.PdfDocument(inputBytes: pdfBytes);
      try {
        return sfpdf.PdfTextExtractor(document).extractText();
      } finally {
        document.dispose();
      }
    } catch (_) {
      return '';
    }
  }

  String _extractWithTableDetection(Uint8List pdfBytes) {
    try {
      final document = sfpdf.PdfDocument(inputBytes: pdfBytes);
      try {
        final extractor = sfpdf.PdfTextExtractor(document);
        final pageCount = document.pages.count;
        final pageBlocks = <String>[];

        for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
          final pageLines = extractor
              .extractTextLines(startPageIndex: pageIndex, endPageIndex: pageIndex);

          if (pageLines.isEmpty) {
            continue;
          }

          // Detect column alignment by grouping text elements at similar Y positions.
          final Map<int, List<sfpdf.TextLine>> rows = {};
          for (final line in pageLines) {
            final yBucket = (line.bounds.top / 8).round();
            rows.putIfAbsent(yBucket, () => []).add(line);
          }

          final sortedKeys = rows.keys.toList(growable: false)..sort();
          final renderedLines = <String>[];

          for (final key in sortedKeys) {
            final rowItems = rows[key]!;
            rowItems.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

            final texts = rowItems
                .map((item) => item.text.replaceAll(RegExp(r'\s+'), ' ').trim())
                .where((text) => text.isNotEmpty)
                .toList(growable: false);

            if (texts.isEmpty) {
              continue;
            }

            if (texts.length > 1) {
              // Multiple columns detected on same row — format as table row.
              renderedLines.add(texts.join(' | '));
            } else {
              renderedLines.add(texts.first);
            }
          }

          if (renderedLines.isNotEmpty) {
            pageBlocks.add('--- Page ${pageIndex + 1} ---\n${renderedLines.join('\n')}');
          }
        }

        return pageBlocks.join('\n\n');
      } finally {
        document.dispose();
      }
    } catch (_) {
      return _extractEmbeddedText(pdfBytes);
    }
  }

  Future<String?> _extractViaBackendOcr({
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    try {
      final cappedLength = pdfBytes.length > (2 * 1024 * 1024) ? (2 * 1024 * 1024) : pdfBytes.length;
      final cappedBytes = Uint8List.sublistView(pdfBytes, 0, cappedLength);

      final result = await ApiService.executeIntegrationAction(
        appId: 'ocr_engine',
        actionId: 'extract_text',
        payload: {
          'file_name': fileName,
          'file_size_bytes': pdfBytes.length,
          'encoding': 'base64',
          'content_sample_base64': base64Encode(cappedBytes),
          'sample_only': cappedLength != pdfBytes.length,
        },
      );

      final candidates = <dynamic>[
        result['ocr_text'],
        result['text'],
        result['content'],
        result['result_text'],
      ];

      for (final candidate in candidates) {
        final value = candidate?.toString() ?? '';
        if (value.trim().isNotEmpty) {
          return value;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
