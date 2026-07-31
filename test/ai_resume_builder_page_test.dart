import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Pages/ai_resume_builder_page.dart';

void main() {
  testWidgets('renders experience tiers, JD matcher, AI assist controls, and the new company insights flow', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiResumeBuilderPage()));

    expect(find.text('Experience Tier'), findsOneWidget);
    expect(find.text('0–5 yrs'), findsOneWidget);
    expect(find.text('5–15 yrs'), findsOneWidget);
    expect(find.text('15–30+ yrs'), findsOneWidget);
    expect(find.text('JD Matcher'), findsOneWidget);
    expect(find.text('Generate Resume'), findsOneWidget);
    expect(find.text('AI Assist'), findsWidgets);
    expect(find.text('Company Name'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Google');
    await tester.tap(find.text('Search'));
    await tester.pump();

    expect(find.textContaining('Company:'), findsOneWidget);

    await tester.tap(find.text('Generate Matching Cover Letter'));
    await tester.pump();

    expect(find.text('Cover Letter'), findsWidgets);

    await tester.tap(find.text('Generate Interview Questions'));
    await tester.pump();

    expect(find.text('Interview Questions'), findsWidgets);
  });
}
