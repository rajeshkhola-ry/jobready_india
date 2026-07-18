import 'package:flutter/material.dart';

import 'Pages/compression_tool_page.dart';
import 'Pages/convert_tool_page.dart';
import 'Pages/extract_tool_page.dart';
import 'Pages/home_page_v3.dart';
import 'Pages/merge_tool_page.dart';
import 'Pages/pdf_tools_page.dart';
import 'Pages/split_tool_page.dart';
import 'Pages/system_check_page.dart';
import 'Pages/terms_conditions_page.dart';
import 'Pages/v2/converter/converter_workspace_page.dart';
import 'Pages/v2/history/history_page.dart';
import 'Pages/v2/photo/photo_hd_workspace_page.dart';
import 'Pages/v2/resume/resume_workspace_page.dart';

void main() {
  runApp(const JobReadyV3App());
}

class JobReadyV3App extends StatelessWidget {
  const JobReadyV3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOBREADY V2 (Separate)',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF3F7FC),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePageV3(),
        '/home': (_) => const HomePageV3(),
        '/compress': (_) => const CompressionToolPage(),
        '/convert': (_) => const ConvertToolPage(),
        '/merge': (_) => const MergeToolPage(),
        '/split': (_) => const SplitToolPage(),
        '/extract': (_) => const ExtractToolPage(),
        '/pdf-tools': (_) => const PdfToolsPage(),
        '/system-check': (_) => const SystemCheckPage(),
        '/terms': (_) => const TermsConditionsPage(),
        '/resume': (_) => const ResumeWorkspacePage(),
        '/converter-v2': (_) => const ConverterWorkspacePage(),
        '/photo-hd': (_) => const PhotoHdWorkspacePage(),
        '/history': (_) => const HistoryPage(),
      },
    );
  }
}
