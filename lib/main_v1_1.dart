import 'package:flutter/material.dart';

import 'Pages/about_page.dart';
import 'Pages/admin_dashboard_page.dart';
import 'Pages/admin_gate_page.dart';
import 'Pages/blog_page.dart';
import 'Pages/blog_detail_page.dart';
import 'Pages/coming_soon_page.dart';
import 'Pages/contact_page.dart';
import 'Pages/cookie_policy_page.dart';
import 'Pages/disclaimer_page.dart';
import 'Pages/faq_page.dart';
import 'Pages/home_page_v2.dart';
import 'Pages/pricing_page.dart';
import 'Pages/privacy_policy_page.dart';
import 'Pages/support_page.dart';
import 'Pages/system_check_page.dart';
import 'Pages/terms_conditions_page.dart';
import 'Pages/testimonials_page.dart';
import 'Pages/user_dashboard_page.dart';
import 'Pages/compression_tool_page.dart' deferred as compressionToolPage;
import 'Pages/convert_tool_page.dart' deferred as convertToolPage;
import 'Pages/extract_tool_page.dart' deferred as extractToolPage;
import 'Pages/merge_tool_page.dart' deferred as mergeToolPage;
import 'Pages/pdf_edit_page.dart' deferred as pdfEditPage;
import 'Pages/pdf_tools_page.dart' deferred as pdfToolsPage;
import 'Pages/split_tool_page.dart' deferred as splitToolPage;
import 'Pages/v2/converter/converter_workspace_page.dart' deferred as converterWorkspacePage;
import 'Pages/v2/history/history_page.dart' deferred as historyPage;
import 'Pages/v2/resume/resume_workspace_page.dart' deferred as resumeWorkspacePage;
import 'Widgets/deferred_route_page.dart';

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
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          iconTheme: IconThemeData(color: Color(0xFF334155)),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePageV2(),
        '/home': (_) => const HomePageV2(),
        '/about': (_) => const AboutPage(),
        '/blog': (_) => const BlogPage(),
        '/blog-detail': (_) => const BlogDetailPage(),
        '/contact': (_) => const ContactPage(),
        '/pricing': (_) => const PricingPage(),
        '/faq': (_) => const FaqPage(),
        '/support': (_) => const SupportPage(),
        '/privacy': (_) => const PrivacyPolicyPage(),
        '/terms': (_) => const TermsConditionsPage(),
        '/cookie-policy': (_) => const CookiePolicyPage(),
        '/disclaimer': (_) => const DisclaimerPage(),
        '/testimonials': (_) => const TestimonialsPage(),
        '/compress': (_) => DeferredRoutePage(
          loader: () async {
            await compressionToolPage.loadLibrary();
          },
          builder: () => compressionToolPage.CompressionToolPage(),
        ),
        '/convert': (_) => DeferredRoutePage(
          loader: () async {
            await convertToolPage.loadLibrary();
          },
          builder: () => convertToolPage.ConvertToolPage(),
        ),
        '/merge': (_) => DeferredRoutePage(
          loader: () async {
            await mergeToolPage.loadLibrary();
          },
          builder: () => mergeToolPage.MergeToolPage(),
        ),
        '/split': (_) => DeferredRoutePage(
          loader: () async {
            await splitToolPage.loadLibrary();
          },
          builder: () => splitToolPage.SplitToolPage(),
        ),
        '/extract': (_) => DeferredRoutePage(
          loader: () async {
            await extractToolPage.loadLibrary();
          },
          builder: () => extractToolPage.ExtractToolPage(),
        ),
        '/pdf-edit': (_) => DeferredRoutePage(
          loader: () async {
            await pdfEditPage.loadLibrary();
          },
          builder: () => pdfEditPage.PdfEditPage(),
        ),
        '/pdf-tools': (_) => DeferredRoutePage(
          loader: () async {
            await pdfToolsPage.loadLibrary();
          },
          builder: () => pdfToolsPage.PdfToolsPage(),
        ),
        '/history': (_) => DeferredRoutePage(
          loader: () async {
            await historyPage.loadLibrary();
          },
          builder: () => historyPage.HistoryPage(),
        ),
        '/resume': (_) => DeferredRoutePage(
          loader: () async {
            await resumeWorkspacePage.loadLibrary();
          },
          builder: () => resumeWorkspacePage.ResumeWorkspacePage(),
        ),
        '/converter-workspace': (_) => DeferredRoutePage(
          loader: () async {
            await converterWorkspacePage.loadLibrary();
          },
          builder: () => converterWorkspacePage.ConverterWorkspacePage(),
        ),
        '/admin': (_) => const AdminGatePage(targetRoute: '/admin-dashboard'),
        '/admin-dashboard': (_) => const AdminDashboardPage(),
        '/coming-soon': (_) => const ComingSoonPage(),
        '/system-check': (_) => const SystemCheckPage(),
        '/dashboard': (_) => const UserDashboardPage(),
      },
      onUnknownRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const HomePageV2(),
      ),
    );
  }
}
