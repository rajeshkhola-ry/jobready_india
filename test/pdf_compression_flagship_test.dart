import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/compression_benchmark.dart';
import 'package:jobready_india/Services/compression_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flagship scanned-style compression produces measurable reduction', () async {
    final benchmark = CompressionBenchmark();
    final service = CompressionService();
    final file = await benchmark.generateTestFile('flagship_scan', 1300 * 1024);

    try {
      final input = await file.readAsBytes();
      final sourcePages = _pageCount(input);

      final small = await service
          .compressPdfSmart(
            input,
            500 * 1024,
            'flagship_scan.pdf',
            mode: PdfCompressionMode.smallSize,
          )
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () => PdfCompressionResult(
              bytes: input,
              targetMet: false,
              message: 'Timed out after 90s.',
            ),
          );

      final outputPages = _pageCount(small.bytes);
      final reduction = ((input.length - small.bytes.length) / input.length) * 100;

      // ignore: avoid_print
      print('FLAGSHIP_COMPRESSION | original=${input.length} | output=${small.bytes.length} | reduction=${reduction.toStringAsFixed(1)}% | targetMet=${small.targetMet} | pagesOk=${sourcePages == outputPages} | note=${small.message}');

      expect(small.bytes.isNotEmpty, isTrue);
      expect(outputPages, sourcePages);
      expect(small.bytes.length <= input.length, isTrue);
    } finally {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  });
}

int _pageCount(List<int> bytes) {
  final doc = sfpdf.PdfDocument(inputBytes: bytes);
  try {
    return doc.pages.count;
  } finally {
    doc.dispose();
  }
}
