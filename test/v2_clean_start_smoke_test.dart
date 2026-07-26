import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Services/conversion_service.dart';
import 'package:jobready_india/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V2 clean-start smoke', () {
    testWidgets('major tool pages open from home', (tester) async {
      await tester.pumpWidget(const JobReadyApp());
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('GET READY JOB'), findsOneWidget);

      Future<void> openAndBack({
        required String entryLabel,
        required String expectedTitle,
      }) async {
        final matches = find.text(entryLabel);
        expect(matches, findsWidgets);
        final target = matches.first;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text(expectedTitle), findsOneWidget);

        await tester.pageBack();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      await openAndBack(entryLabel: 'PDF Tools', expectedTitle: 'PDF Tools');
      await openAndBack(entryLabel: 'Convert', expectedTitle: 'Convert File');
      await openAndBack(entryLabel: 'Compress', expectedTitle: 'Compress File');
      await openAndBack(entryLabel: 'Merge', expectedTitle: 'Merge PDFs');
      await openAndBack(entryLabel: 'Split', expectedTitle: 'Split PDF');
      await openAndBack(entryLabel: 'Edit PDF', expectedTitle: 'PDF to PDF (Edit)');
    });

    test('one sample conversion works', () async {
      final service = const ConversionService();
      final input = Uint8List.fromList(utf8.encode('JOBREADY sample conversion'));

      final result = await service.convert(
        inputBytes: input,
        inputFileName: 'sample.txt',
        outputFormat: 'PDF (.pdf)',
      );

      expect(result.success, isTrue);
      expect(result.outputBytes, isNotNull);
      expect(result.outputBytes!.isNotEmpty, isTrue);
      expect(result.outputFileName, endsWith('.pdf'));
    });
  });
}
