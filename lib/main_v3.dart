import 'package:flutter/material.dart';

import 'Pages/about_page.dart';
import 'Pages/blog_page.dart';
import 'Pages/contact_page.dart';
import 'Pages/cookie_policy_page.dart';
import 'Pages/disclaimer_page.dart';
import 'Pages/faq_page.dart';
import 'Pages/home_page_v3.dart';
import 'Pages/pricing_page.dart';
import 'Pages/privacy_policy_page.dart';
import 'Pages/roadmap_page.dart';
import 'Pages/solutions_page.dart';
import 'Pages/support_page.dart';
import 'Pages/system_check_page.dart';
import 'Pages/testimonials_page.dart';
import 'Pages/terms_conditions_page.dart';
import 'Pages/user_dashboard_page.dart';
import 'Widgets/deferred_route_page.dart';
import 'Pages/compression_tool_page.dart' deferred as compressionToolPage;
import 'Pages/convert_tool_page.dart' deferred as convertToolPage;
import 'Pages/extract_tool_page.dart' deferred as extractToolPage;
import 'Pages/merge_tool_page.dart' deferred as mergeToolPage;
import 'Pages/pdf_edit_page.dart' deferred as pdfEditPage;
import 'Pages/pdf_tools_page.dart' deferred as pdfToolsPage;
import 'Pages/split_tool_page.dart' deferred as splitToolPage;
import 'Pages/v2/converter/converter_workspace_page.dart' deferred as converterWorkspacePage;
import 'Pages/v2/history/history_page.dart' deferred as historyPage;
import 'Pages/v2/photo/photo_hd_workspace_page.dart' deferred as photoHdWorkspacePage;
import 'Pages/v2/resume/resume_workspace_page.dart' deferred as resumeWorkspacePage;

void main() {
  runApp(const JobReadyV3App());
}

class JobReadyV3App extends StatelessWidget {
  const JobReadyV3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GETREADYJOB V2 (Separate)',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF3F7FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F2937),
          brightness: Brightness.light,
        ),
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
        '/': (_) => const HomePageV3(),
        '/home': (_) => const HomePageV3(),
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
        '/dashboard': (_) => const UserDashboardPage(),
        '/terms': (_) => const TermsConditionsPage(),
        '/resume': (_) => DeferredRoutePage(
          loader: () async {
            await resumeWorkspacePage.loadLibrary();
          },
          builder: () => resumeWorkspacePage.ResumeWorkspacePage(),
        ),
        '/converter-v2': (_) => DeferredRoutePage(
          loader: () async {
            await converterWorkspacePage.loadLibrary();
          },
          builder: () => converterWorkspacePage.ConverterWorkspacePage(),
        ),
        '/photo-hd': (_) => DeferredRoutePage(
          loader: () async {
            await photoHdWorkspacePage.loadLibrary();
          },
          builder: () => photoHdWorkspacePage.PhotoHdWorkspacePage(),
        ),
        '/history': (_) => DeferredRoutePage(
          loader: () async {
            await historyPage.loadLibrary();
          },
          builder: () => historyPage.HistoryPage(),
        ),
      },
    );
  }
}
