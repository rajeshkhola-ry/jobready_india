import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main site does not redirect to the decommissioned voice subdomain', () async {
    final repoRoot = Directory.current.path;
    final filesToCheck = [
      File('$repoRoot/lib/Pages/home_page_v1_1.dart'),
      File('$repoRoot/lib/Pages/user_dashboard_page.dart'),
      File('$repoRoot/render.yaml'),
    ];

    for (final file in filesToCheck) {
      expect(file.existsSync(), isTrue, reason: 'Missing file: ${file.path}');
      final content = await file.readAsString();
      expect(content, isNot(contains('https://voice.getreadyjob.com')),
          reason: 'The decommissioned voice subdomain should not be referenced in ${file.path}');
    }
  });
}
