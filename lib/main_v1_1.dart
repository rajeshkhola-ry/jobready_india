import 'package:flutter/material.dart';

import 'Pages/admin_gate_page.dart';
import 'Pages/coming_soon_page.dart';
import 'Pages/home_page_v2.dart';
import 'Pages/system_check_page.dart';

void main() {
  runApp(const JobReadyV11App());
}

// Integration working copy derived from frozen V1 baseline.
class JobReadyV11App extends StatelessWidget {
  const JobReadyV11App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOBREADY V1.1',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePageV2(),
        '/home': (_) => const HomePageV2(),
        '/admin': (_) => const AdminGatePage(targetRoute: '/system-check'),
        '/coming-soon': (_) => const ComingSoonPage(),
        '/system-check': (_) => const SystemCheckPage(),
      },
    );
  }
}
