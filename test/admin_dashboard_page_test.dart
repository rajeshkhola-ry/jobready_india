import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Pages/admin_dashboard_page.dart';

void main() {
  testWidgets('renders operational owner tools for pricing, promos, payments, analytics and resume management', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));

    expect(find.text('Pricing & plans'), findsOneWidget);
    expect(find.text('Promo codes'), findsOneWidget);
    expect(find.text('Payments & access'), findsOneWidget);
    expect(find.text('Analytics & logs'), findsOneWidget);
    expect(find.text('Resume builder'), findsOneWidget);
  });
}
