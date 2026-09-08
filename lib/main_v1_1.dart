import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:universal_html/html.dart' as html;

import 'Pages/about_page.dart';
import 'Pages/admin_dashboard_page.dart';
import 'Pages/admin_gate_page.dart';
import 'Pages/admin_two_factor_page.dart';
import 'Pages/blog_page.dart';
import 'Pages/blog_detail_page.dart';
import 'Pages/coming_soon_page.dart';
import 'Pages/contact_page.dart';
import 'Pages/cookie_policy_page.dart';
import 'Pages/csv_to_excel_page.dart' deferred as csvToExcelPage;
import 'Pages/disclaimer_page.dart';
import 'Pages/faq_page.dart';
import 'Pages/home_page_v1_1.dart';
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
import 'Pages/micro_canva_utilities_page.dart' deferred as microCanvaUtilitiesPage;
import 'Pages/pdf_edit_page.dart' deferred as pdfEditPage;
import 'Pages/pdf_tools_page.dart' deferred as pdfToolsPage;
import 'Pages/poster_banner_studio_page.dart' deferred as posterBannerStudioPage;
import 'Pages/privacy_masker_page.dart' deferred as privacyMaskerPage;
import 'Pages/govt_verifier_page.dart' deferred as govtVerifierPage;
import 'Pages/fraud_seal_page.dart' deferred as fraudSealPage;
import 'Pages/doc_packager_page.dart' deferred as docPackagerPage;
import 'Pages/resume_document_canvas_templates_page.dart' deferred as resumeDocumentCanvasTemplatesPage;
import 'Pages/smart_pdf_suite_page.dart' deferred as smartPdfSuitePage;
import 'Pages/split_tool_page.dart' deferred as splitToolPage;
import 'Pages/v2/history/history_page.dart' deferred as historyPage;
import 'Pages/v2/photo/photo_hd_workspace_page.dart' deferred as photoHdWorkspacePage;
import 'Pages/v2/resume/resume_workspace_page.dart' deferred as resumeWorkspacePage;
import 'Pages/voice_interview_page.dart' deferred as voiceInterviewPage;
import 'Widgets/deferred_route_page.dart';

void main() {
  usePathUrlStrategy();

  // Captured before Flutter's engine/Router has run at all, so this reflects
  // exactly what the browser was asked to load - independent of whatever
  // main_v1_1.dart's own Router/PlatformLocation does with it during boot.
  // See _JobReadyV11AppState's post-frame correction below.
  String? requestedPath;
  try {
    requestedPath = html.window.location.pathname;
  } catch (_) {
    requestedPath = null;
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}\n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('PlatformDispatcher error: $error\n$stack');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('ErrorWidget: ${details.exception}\n${details.stack}');
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('App failed to render. Please check the browser console.'),
        ),
      ),
    );
  };

  runApp(JobReadyV11App(requestedPath: requestedPath));
}

// Integration working copy derived from frozen V1 baseline.
class JobReadyV11App extends StatefulWidget {
  const JobReadyV11App({super.key, this.useMinimalBootstrap = false, this.requestedPath});

  final bool useMinimalBootstrap;

  /// The path the browser was actually asked to load, captured at the very
  /// top of main() before Flutter's engine touched anything.
  final String? requestedPath;

  @override
  State<JobReadyV11App> createState() => _JobReadyV11AppState();
}

class _JobReadyV11AppState extends State<JobReadyV11App> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _BootRouteObserver _routeObserver = _BootRouteObserver();

  @override
  void initState() {
    super.initState();

    // Workaround for a Flutter web framework-internal race: on a direct/deep
    // link, main_v1_1.dart's own compiled Router/PlatformLocation code fires
    // several history.replaceState/pushState calls within ~100ms of boot
    // while reconciling the initial route, and the LAST one occasionally
    // lands back on '/' - and critically, that can mean the Navigator's
    // ACTUAL current route (i.e. what's actually mounted and visible), not
    // just the address-bar string, ends up wrong. A correction that only
    // patches window.location leaves the wrong page rendered even though the
    // URL looks right (the address bar can settle back to the correct
    // string on its own by the time this runs, even when the mounted widget
    // didn't). So this checks the Navigator's real current route name via
    // _BootRouteObserver - not the URL - and if it disagrees with what was
    // actually requested, forces a real route replacement so the correct
    // page widget gets (re)built, not just a cosmetic URL patch.
    final requestedPath = widget.requestedPath;
    if (!widget.useMinimalBootstrap && requestedPath != null && requestedPath.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          try {
            final actualRouteName = _routeObserver.currentRouteName;
            if (actualRouteName != null && actualRouteName != requestedPath) {
              _navigatorKey.currentState?.pushNamedAndRemoveUntil(
                requestedPath,
                (route) => false,
              );
            } else {
              // Navigator's own route is already correct - but the address
              // bar can still independently disagree as a leftover cosmetic
              // artifact of the same boot race, so patch that too if needed.
              final currentPath = html.window.location.pathname;
              if (currentPath != null && currentPath != requestedPath) {
                html.window.history.replaceState(null, '', requestedPath);
              }
            }
          } catch (_) {
            // Best-effort only; never let this crash the app.
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useMinimalBootstrap) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'GETREADYJOB V1.1',
        home: Scaffold(
          body: Center(
            child: Text('GETREADYJOB V1.1'),
          ),
        ),
      );
    }

    final routeTable = <String, WidgetBuilder>{
        '/': (_) => const HomePageV11(),
        '/home': (_) => const HomePageV11(),
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
        '/micro-canva': (_) => DeferredRoutePage(
          loader: () async {
            await microCanvaUtilitiesPage.loadLibrary();
          },
          builder: () => microCanvaUtilitiesPage.MicroCanvaUtilitiesPage(),
        ),
        '/poster-banner-studio': (_) => DeferredRoutePage(
          loader: () async {
            await posterBannerStudioPage.loadLibrary();
          },
          builder: () => posterBannerStudioPage.PosterBannerStudioPage(),
        ),
        '/canvas-templates': (_) => DeferredRoutePage(
          loader: () async {
            await resumeDocumentCanvasTemplatesPage.loadLibrary();
          },
          builder: () => resumeDocumentCanvasTemplatesPage.ResumeDocumentCanvasTemplatesPage(),
        ),
        '/smart-pdf': (_) => DeferredRoutePage(
          loader: () async {
            await smartPdfSuitePage.loadLibrary();
          },
          builder: () => smartPdfSuitePage.SmartPdfSuitePage(),
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
        '/photo-hd': (_) => DeferredRoutePage(
          loader: () async {
            await photoHdWorkspacePage.loadLibrary();
          },
          builder: () => photoHdWorkspacePage.PhotoHdWorkspacePage(
            initialMode: photoHdWorkspacePage.PhotoWorkspaceMode.hdPhoto,
          ),
        ),
        '/poster-workspace': (_) => DeferredRoutePage(
          loader: () async {
            await photoHdWorkspacePage.loadLibrary();
          },
          builder: () => photoHdWorkspacePage.PhotoHdWorkspacePage(
            initialMode: photoHdWorkspacePage.PhotoWorkspaceMode.poster,
          ),
        ),
        '/privacy-masker': (_) => DeferredRoutePage(
          loader: () async {
            await privacyMaskerPage.loadLibrary();
          },
          builder: () => privacyMaskerPage.PrivacyMaskerPage(),
        ),
        '/govt-verifier': (_) => DeferredRoutePage(
          loader: () async {
            await govtVerifierPage.loadLibrary();
          },
          builder: () => govtVerifierPage.GovtVerifierPage(),
        ),
        '/csv-to-excel-converter': (_) => DeferredRoutePage(
          loader: () async {
            await csvToExcelPage.loadLibrary();
          },
          builder: () => csvToExcelPage.CsvToExcelPage(),
        ),
        '/fraud-seal': (_) => DeferredRoutePage(
          loader: () async {
            await fraudSealPage.loadLibrary();
          },
          builder: () => fraudSealPage.FraudSealPage(),
        ),
        '/doc-packager': (_) => DeferredRoutePage(
          loader: () async {
            await docPackagerPage.loadLibrary();
          },
          builder: () => docPackagerPage.DocPackagerPage(),
        ),
        '/ai-mock-interview': (_) => DeferredRoutePage(
          loader: () async {
            await voiceInterviewPage.loadLibrary();
          },
          builder: () => voiceInterviewPage.VoiceInterviewPage(),
        ),
        '/voice-interview': (_) => DeferredRoutePage(
          loader: () async {
            await voiceInterviewPage.loadLibrary();
          },
          builder: () => voiceInterviewPage.VoiceInterviewPage(),
        ),
        '/admin': (_) => const AdminGatePage(targetRoute: '/admin-dashboard'),
        '/admin-2fa': (_) => const AdminTwoFactorPage(),
        '/admin-dashboard': (_) => const AdminDashboardPage(),
        '/coming-soon': (_) => const ComingSoonPage(),
        '/system-check': (_) => const SystemCheckPage(),
        '/dashboard': (_) => const UserDashboardPage(),
    };

    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      debugShowCheckedModeBanner: false,
      title: 'GETREADYJOB V1.1',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Trebuchet MS',
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF123A63),
          primary: const Color(0xFF123A63),
          secondary: const Color(0xFF1E6A74),
          surface: const Color(0xFFF7FAFD),
          onSurface: const Color(0xFF0F172A),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.03,
            color: Color(0xFF0F172A),
          ),
          headlineMedium: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            height: 1.16,
            letterSpacing: -0.02,
            color: Color(0xFF0F172A),
          ),
          titleMedium: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          bodyLarge: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.58,
            color: Color(0xFF334155),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.58,
            color: Color(0xFF516175),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7FAFD),
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.35,
          ),
          iconTheme: IconThemeData(color: Color(0xFF334155)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFDCE6F2), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          showCheckmark: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FBFF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD7E3F1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD7E3F1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF123A63), width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF123A63),
            foregroundColor: Colors.white,
            elevation: 1,
            shadowColor: const Color(0xFF123A63),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF123A63),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF123A63),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF123A63),
            side: const BorderSide(color: Color(0xFFD0DCEC)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: const Color(0xFFFDFEFF),
          ),
        ),
      ),
      routes: routeTable,
      onGenerateInitialRoutes: (String initialRouteName) {
        // Avoid Navigator.defaultGenerateInitialRoutes' behavior of always
        // constructing the '/' (Home) route first in the background for any
        // deep-linked initial route: that silently mounts HomePageV11 (running
        // its side effects, including its own document.title update) even
        // when the user never sees it, racing with the real target page's SEO
        // metadata. Build only the actually-requested route instead.
        final normalized = initialRouteName.isEmpty ? '/' : initialRouteName;
        final builder = routeTable[normalized];
        return <Route<dynamic>>[
          MaterialPageRoute<void>(
            builder: builder ?? routeTable['/']!,
            settings: RouteSettings(name: builder != null ? normalized : '/'),
          ),
        ];
      },
      onUnknownRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const HomePageV11(),
      ),
    );
  }
}

/// Tracks the Navigator's actual current route NAME (not the browser's
/// address-bar string, which - per the boot-time Router race documented on
/// _JobReadyV11AppState.initState() - can settle back to the correct value
/// even when the wrong page widget is what's actually mounted). Used as the
/// source of truth for the one-time post-boot correction.
class _BootRouteObserver extends NavigatorObserver {
  String? currentRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = route.settings.name;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRouteName = newRoute?.settings.name ?? currentRouteName;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = previousRoute?.settings.name ?? currentRouteName;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRouteName = previousRoute?.settings.name ?? currentRouteName;
  }
}
