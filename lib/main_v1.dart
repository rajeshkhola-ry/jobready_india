import 'package:flutter/material.dart';
import 'Pages/coming_soon_page.dart';
import 'Pages/home_page_v2.dart';
import 'Pages/system_check_page.dart';

void main() {
  runApp(const JobReadyV1App());
}

class JobReadyV1App extends StatelessWidget {
  const JobReadyV1App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOBREADY V1',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const ComingSoonPage(),
        '/home': (_) => const HomePageV2(),
        '/system-check': (_) => const SystemCheckPage(),
      },
    );
  }
}
