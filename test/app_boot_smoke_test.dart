import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Widgets/minimal_bootstrap_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Minimal bootstrap app renders without throwing', (tester) async {
    await tester.pumpWidget(const MinimalBootstrapApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('GETREADYJOB V1.1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Minimal app shell mounts without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('GETREADYJOB V1.1')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('GETREADYJOB V1.1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
