import 'package:flutter/material.dart';

import 'Pages/coming_soon_page.dart';
import 'Pages/compression_benchmark_page.dart';
import 'Pages/compression_tool_page.dart';
import 'Pages/convert_tool_page.dart';
import 'Pages/extract_tool_page.dart';
import 'Pages/home_page.dart';
import 'Pages/home_page_v2.dart';
import 'Pages/launch_readiness_page.dart';
import 'Pages/launch_runbook_page.dart';
import 'Pages/merge_tool_page.dart';
import 'Pages/pdf_tools_page.dart';
import 'Pages/pdf_edit_page.dart';
import 'Pages/post_launch_control_page.dart';
import 'Pages/split_tool_page.dart';
import 'Pages/system_check_page.dart';
import 'Pages/terms_conditions_page.dart';

void main() {
  runApp(const JobReadyCombinedLaunchApp());
}

class JobReadyCombinedLaunchApp extends StatelessWidget {
  const JobReadyCombinedLaunchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOBREADY Combined Launch',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
      ),
      // Lock public launch shell to Coming Soon while keeping merged V1+V2 tools/routes available internally.
      initialRoute: '/',
      routes: {
        '/': (_) => const ComingSoonPage(),
        '/home': (_) => const HomePageV2(),

        // Merged core tools
        '/compress': (_) => const CompressionToolPage(),
        '/convert': (_) => const ConvertToolPage(),
        '/merge': (_) => const MergeToolPage(),
        '/split': (_) => const SplitToolPage(),
        '/extract': (_) => const ExtractToolPage(),
        '/pdf-tools': (_) => const PdfToolsPage(),
        '/pdf-edit': (_) => const PdfEditPage(),

        // Validation and operations pages
        '/system-check': (_) => const SystemCheckPage(),
        '/benchmark': (_) => const CompressionBenchmarkPage(),
        '/launch-readiness': (_) => const LaunchReadinessPage(),
        '/launch-runbook': (_) => const LaunchRunbookPage(),
        '/post-launch': (_) => const PostLaunchControlPage(),
        '/terms': (_) => const TermsConditionsPage(),

        // Optional direct V1 access if required for comparison.
        '/home-v1': (_) => const HomePage(),
      },
    );
  }
}
