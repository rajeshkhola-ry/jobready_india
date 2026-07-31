import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Widgets/deferred_route_page.dart';

void main() {
  testWidgets('shows a loading state before the deferred content appears', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeferredRoutePage(
          loader: () async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          },
          builder: () => const Text('Deferred content ready'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Deferred content ready'), findsOneWidget);
  });
}
