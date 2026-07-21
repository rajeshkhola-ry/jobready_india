import 'package:flutter/material.dart';

import 'Pages/about_page.dart';
import 'Pages/admin_gate_page.dart';
import 'Pages/compression_tool_page.dart';
import 'Pages/coming_soon_page.dart';
import 'Pages/convert_tool_page.dart';
import 'Pages/contact_page.dart';
import 'Pages/cookie_policy_page.dart';
import 'Pages/disclaimer_page.dart';
import 'Pages/extract_tool_page.dart';
import 'Pages/faq_page.dart';
import 'Pages/home_page_v2.dart';
import 'Pages/merge_tool_page.dart';
import 'Pages/pdf_edit_page.dart';
import 'Pages/pdf_tools_page.dart';
import 'Pages/pricing_page.dart';
import 'Pages/privacy_policy_page.dart';
import 'Pages/split_tool_page.dart';
import 'Pages/support_page.dart';
import 'Pages/v2/converter/converter_workspace_page.dart';
import 'Pages/v2/history/history_page.dart';
import 'Pages/system_check_page.dart';
import 'Pages/terms_conditions_page.dart';
import 'Pages/testimonials_page.dart';

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
      title: 'GETREADYJOB V1.1',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePageV2(),
        '/home': (_) => const HomePageV2(),
        '/about': (_) => const AboutPage(),
        '/contact': (_) => const ContactPage(),
        '/pricing': (_) => const PricingPage(),
        '/faq': (_) => const FaqPage(),
        '/support': (_) => const SupportPage(),
        '/privacy': (_) => const PrivacyPolicyPage(),
        '/terms': (_) => const TermsConditionsPage(),
        '/cookie-policy': (_) => const CookiePolicyPage(),
        '/disclaimer': (_) => const DisclaimerPage(),
        '/testimonials': (_) => const TestimonialsPage(),
        '/compress': (_) => const CompressionToolPage(),
        '/convert': (_) => const ConvertToolPage(),
        '/merge': (_) => const MergeToolPage(),
        '/split': (_) => const SplitToolPage(),
        '/extract': (_) => const ExtractToolPage(),
        '/pdf-edit': (_) => const PdfEditPage(),
        '/pdf-tools': (_) => const PdfToolsPage(),
        '/history': (_) => const HistoryPage(),
        '/converter-workspace': (_) => const ConverterWorkspacePage(),
        '/admin': (_) => const AdminGatePage(targetRoute: '/system-check'),
        '/coming-soon': (_) => const ComingSoonPage(),
        '/system-check': (_) => const SystemCheckPage(),
      },
    );
  }
}
