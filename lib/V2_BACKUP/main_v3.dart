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
import 'Pages/v2/ai/ai_assistant_workspace_page.dart';
import 'Pages/v2/academic/academic_toolkit_page.dart';
import 'Pages/v2/home/v2_roadmap_hub_page.dart';
import 'Pages/v2/jobs/job_application_toolkit_page.dart';
import 'Pages/v2/ocr/document_intelligence_page.dart';
import 'Pages/v2/scale/v2_growth_modules_page.dart';
import 'Pages/v2/scale/v2_endgame_execution_page.dart';
import 'Pages/v2/workspace/smart_document_workspace_page.dart';
import 'Pages/v2/writing/ai_writing_studio_page.dart';
import 'Pages/v2/converter/converter_workspace_page.dart';
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
      title: 'JOBREADY V2 (Former V3 Separate)',
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
        '/ai-assistant': (_) => const AiAssistantWorkspacePage(),
        '/academic-toolkit': (_) => const AcademicToolkitPage(),
        '/ai-writing': (_) => const AiWritingStudioPage(),
        '/job-toolkit': (_) => const JobApplicationToolkitPage(),
        '/document-intelligence': (_) => const DocumentIntelligencePage(),
        '/v2-growth': (_) => const V2GrowthModulesPage(),
        '/v2-endgame': (_) => const V2EndgameExecutionPage(),
        '/document-workspace': (_) => const SmartDocumentWorkspacePage(),
        '/resume': (_) => const ResumeWorkspacePage(),
        '/v2-roadmap': (_) => const V2RoadmapHubPage(),
        '/converter-v2': (_) => const ConverterWorkspacePage(),
        '/photo-hd': (_) => const PhotoHdWorkspacePage(),
      },
    );
  }
}
