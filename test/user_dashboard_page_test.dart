import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Pages/user_dashboard_page.dart';

void main() {
  testWidgets('shows AI Resume Builder quick access on the dashboard', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UserDashboardPage()));
    await tester.pumpAndSettle();

    expect(find.text('AI Resume Builder'), findsOneWidget);
  });
}
