import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Pages/system_check_page.dart';
import 'package:jobready_india/Services/api_config.dart';
import 'package:jobready_india/main_v1_1.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V1.1 integration validation', () {
    testWidgets('theme consistency and root load', (tester) async {
      await tester.pumpWidget(const JobReadyV11App());
      await tester.pump(const Duration(milliseconds: 600));

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, 'JOBREADY V1.1');
      expect(app.theme?.scaffoldBackgroundColor, const Color(0xFFF8F9FA));
      expect(tester.takeException(), isNull);
    });

    testWidgets('responsive smoke does not throw for common widths', (tester) async {
      final view = tester.view;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      Future<void> pumpAtSize(Size logicalSize) async {
        view.devicePixelRatio = 1.0;
        view.physicalSize = logicalSize;
        await tester.pumpWidget(const JobReadyV11App());
        await tester.pump(const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
      }

      await pumpAtSize(const Size(390, 844));
      await pumpAtSize(const Size(768, 1024));
      await pumpAtSize(const Size(1366, 768));
    });

    testWidgets('navigation routes are registered and system check builds', (tester) async {
      await tester.pumpWidget(const JobReadyV11App());
      await tester.pump(const Duration(milliseconds: 600));

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.routes?.containsKey('/home'), isTrue);
      expect(app.routes?.containsKey('/system-check'), isTrue);
      expect(app.routes?.containsKey('/coming-soon'), isTrue);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const MaterialApp(home: SystemCheckPage()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('System Check'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('payment readiness helper uses local integration-ready state for paid plan', () {
      final readiness = ApiService.buildPaymentReadiness(
        gateway: '',
        planId: 'Monthly',
        amount: 1.99,
        currency: 'USD',
        usageType: 'Personal',
      );

      expect(readiness['status'], 'ready_for_integration');
      expect(readiness['label'], 'Ready for Integration');
    });

    testWidgets('home payment panel shows checkout readiness section', (tester) async {
      await tester.pumpWidget(const JobReadyV11App());
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.textContaining('Selected payment gateway:'), findsOneWidget);
      expect(find.text('Configuration Required'), findsOneWidget);
      expect(find.text('Continue to Payment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
