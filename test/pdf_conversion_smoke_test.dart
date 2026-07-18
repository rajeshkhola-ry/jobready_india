import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/conversion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PDF conversion smoke', () {
    late Uint8List samplePdfBytes;
    const service = ConversionService();

    setUpAll(() async {
      final data = await rootBundle.load('test_assets/sample.pdf');
      samplePdfBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
    });

    test('converts sample PDF to PNG archive', () async {
      final result = await service.convert(
        inputBytes: samplePdfBytes,
        inputFileName: 'sample.pdf',
        outputFormat: 'PNG Images',
      );

      expect(result.success, isTrue, reason: result.message);
      expect(result.outputFileName, 'sample_png_pages.zip');
      expect(result.outputBytes, isNotNull);
      expect(result.outputBytes!.isNotEmpty, isTrue);

      final archive = ZipDecoder().decodeBytes(result.outputBytes!, verify: false);
      expect(archive.files, isNotEmpty);
      expect(archive.files.every((file) => file.name.toLowerCase().endsWith('.png')), isTrue);
    });

    test('converts sample PDF to JPG archive', () async {
      final result = await service.convert(
        inputBytes: samplePdfBytes,
        inputFileName: 'sample.pdf',
        outputFormat: 'JPG Images',
      );

      expect(result.success, isTrue, reason: result.message);
      expect(result.outputFileName, 'sample_jpg_pages.zip');
      expect(result.outputBytes, isNotNull);
      expect(result.outputBytes!.isNotEmpty, isTrue);

      final archive = ZipDecoder().decodeBytes(result.outputBytes!, verify: false);
      expect(archive.files, isNotEmpty);
      expect(archive.files.every((file) => file.name.toLowerCase().endsWith('.jpg')), isTrue);
    });
  });
}
