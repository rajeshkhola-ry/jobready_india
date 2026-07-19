import 'package:flutter/material.dart';

import 'Pages/compression_tool_page.dart';
import 'Pages/convert_tool_page.dart';
import 'Pages/extract_tool_page.dart';
import 'Pages/about_page.dart';
import 'Pages/blog_page.dart';
import 'Pages/contact_page.dart';
import 'Pages/cookie_policy_page.dart';
import 'Pages/disclaimer_page.dart';
import 'Pages/faq_page.dart';
import 'Pages/home_page_v3.dart';
import 'Pages/merge_tool_page.dart';
import 'Pages/pdf_edit_page.dart';
import 'Pages/pdf_tools_page.dart';
import 'Pages/pricing_page.dart';
import 'Pages/privacy_policy_page.dart';
import 'Pages/roadmap_page.dart';
import 'Pages/solutions_page.dart';
import 'Pages/split_tool_page.dart';
import 'Pages/support_page.dart';
import 'Pages/system_check_page.dart';
import 'Pages/testimonials_page.dart';
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F2937),
          brightness: Brightness.light,
        ),
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
        '/pdf-edit': (_) => const PdfEditPage(),
        '/pdf-tools': (_) => const PdfToolsPage(),
        '/about': (_) => const AboutPage(),
        '/contact': (_) => const ContactPage(),
        '/faq': (_) => const FaqPage(),
        '/pricing': (_) => const PricingPage(),
        '/privacy': (_) => const PrivacyPolicyPage(),
        '/cookie-policy': (_) => const CookiePolicyPage(),
        '/disclaimer': (_) => const DisclaimerPage(),
        '/support': (_) => const SupportPage(),
        '/testimonials': (_) => const TestimonialsPage(),
        '/roadmap': (_) => const RoadmapPage(),
        '/blog': (_) => const BlogPage(),
        '/solutions': (_) => const SolutionsPage(),
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
