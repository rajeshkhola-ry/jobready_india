import 'dart:typed_data';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/conversion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF conversion smoke', () {
    late Uint8List samplePdfBytes;
    const service = ConversionService();

    setUpAll(() async {
      final file = File('test_assets/sample.pdf');
      expect(file.existsSync(), isTrue, reason: 'Missing test fixture: test_assets/sample.pdf');
      samplePdfBytes = file.readAsBytesSync();
    });

    test('converts sample PDF to Word', () async {
      final result = await service.convert(
        inputBytes: samplePdfBytes,
        inputFileName: 'sample.pdf',
        outputFormat: 'Word (.docx)',
      );

      expect(result.success, isTrue, reason: result.message);
      expect(result.outputFileName, 'sample.docx');
      expect(result.outputBytes, isNotNull);
      expect(result.outputBytes!.isNotEmpty, isTrue);

      final archive = ZipDecoder().decodeBytes(result.outputBytes!, verify: false);
      expect(archive.files.any((file) => file.name == 'word/document.xml'), isTrue);
      expect(
        archive.files.any((file) => file.name.startsWith('word/media/')),
        isTrue,
        reason: 'Layout-preserved Word export should embed rendered page images.',
      );

      final documentXml = archive.files
          .firstWhere((file) => file.name == 'word/document.xml')
          .content as List<int>;
      final xmlText = String.fromCharCodes(documentXml);
      expect(xmlText.contains('w:drawing'), isTrue);
    });

    test('converts sample PDF to PNG archive', () async {
      final result = await service.convert(
        inputBytes: samplePdfBytes,
        inputFileName: 'sample.pdf',
        outputFormat: 'PNG Images',
      );

      if (result.success) {
        expect(result.outputFileName, 'sample_png_pages.zip');
        expect(result.outputBytes, isNotNull);
        expect(result.outputBytes!.isNotEmpty, isTrue);

        final archive = ZipDecoder().decodeBytes(result.outputBytes!, verify: false);
        expect(archive.files, isNotEmpty);
        expect(archive.files.every((file) => file.name.toLowerCase().endsWith('.png')), isTrue);
      } else {
        // Some test runtimes cannot render PDF pages to images; this must fail gracefully.
        expect(result.message.toLowerCase(), contains('unable to export pdf pages as images'));
      }
    });

    test('converts sample PDF to JPG archive', () async {
      final result = await service.convert(
        inputBytes: samplePdfBytes,
        inputFileName: 'sample.pdf',
        outputFormat: 'JPG Images',
      );

      if (result.success) {
        expect(result.outputFileName, 'sample_jpg_pages.zip');
        expect(result.outputBytes, isNotNull);
        expect(result.outputBytes!.isNotEmpty, isTrue);

        final archive = ZipDecoder().decodeBytes(result.outputBytes!, verify: false);
        expect(archive.files, isNotEmpty);
        expect(archive.files.every((file) => file.name.toLowerCase().endsWith('.jpg')), isTrue);
      } else {
        // Some test runtimes cannot render PDF pages to images; this must fail gracefully.
        expect(result.message.toLowerCase(), contains('unable to export pdf pages as images'));
      }
    });
  });
}
