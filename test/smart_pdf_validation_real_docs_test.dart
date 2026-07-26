import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/compression_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smart PDF real-doc validation', () {
    test('collect real compression results for available PDFs', () async {
      final service = CompressionService();

      final documents = <String, String>{
        'Audit Report PDF': 'lib/V1_V2_V3_Audit_Report_2026-07-14.pdf',
        'Sample PDF': 'test_assets/sample.pdf',
        'Benchmark Small 0.5MB': 'compression_benchmark/test_small_0.5MB_20260712_201022.pdf',
        'Benchmark Small 0.3MB': 'compression_benchmark/test_small_0.3MB_20260712_201022.pdf',
        'Benchmark Medium 12.5MB': 'compression_benchmark/test_medium_12.5MB_20260712_201022.pdf',
      };

      final targetProfiles = <String, ({PdfCompressionMode mode, int targetBytes})>{
        'Small Size': (mode: PdfCompressionMode.smallSize, targetBytes: 100 * 1024),
        'Recommended': (mode: PdfCompressionMode.recommended, targetBytes: 300 * 1024),
        'High Quality': (mode: PdfCompressionMode.highQuality, targetBytes: 500 * 1024),
      };

      final rows = <String>[];

      for (final entry in documents.entries) {
        final file = File(entry.value);
        expect(file.existsSync(), isTrue, reason: 'Missing file: ${entry.value}');

        final source = await file.readAsBytes();
        final sourcePages = _safePageCount(source);

        for (final profile in targetProfiles.entries) {
          final result = await service
              .compressPdfSmart(
                source,
                profile.value.targetBytes,
                entry.key,
                mode: profile.value.mode,
              )
              .timeout(
                const Duration(seconds: 60),
                onTimeout: () => PdfCompressionResult(
                  bytes: source,
                  targetMet: false,
                  message: 'Timed out after 60s; returning source for validation logging.',
                ),
              );

          final outputPages = _safePageCount(result.bytes);
          final pagesOk = sourcePages > 0 && outputPages == sourcePages;
          final reductionPct = ((source.length - result.bytes.length) / source.length) * 100;

          rows.add([
            entry.key,
            profile.key,
            _formatBytes(source.length),
            _formatBytes(profile.value.targetBytes),
            _formatBytes(result.bytes.length),
            '${reductionPct.toStringAsFixed(1)}%',
            result.targetMet ? 'YES' : 'NO',
            pagesOk ? 'YES' : 'NO',
            result.message,
          ].join(' | '));

          expect(result.bytes.isNotEmpty, isTrue);
        }
      }

      // ignore: avoid_print
      print('DOC | PROFILE | ORIGINAL | TARGET | OUTPUT | REDUCTION | TARGET_MET | PAGES_OK | NOTE');
      for (final row in rows) {
        // ignore: avoid_print
        print(row);
      }
    });
  });
}

int _safePageCount(Uint8List bytes) {
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

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
}
