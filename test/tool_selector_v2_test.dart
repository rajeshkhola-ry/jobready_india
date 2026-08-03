import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobready_india/Widgets/tool_selector_v2.dart';

void main() {
  testWidgets('highlights the HD Photo and Resume cards as featured tools', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ToolSelectorV2(),
        ),
      ),
    );

    expect(find.text('AI Resume Builder'), findsOneWidget);
    expect(find.text('HD Photo Studio'), findsOneWidget);
    expect(find.text('Featured'), findsNWidgets(2));
  });
}
