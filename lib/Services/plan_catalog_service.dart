import 'dart:convert';

import '../Utils/web_safe_browser.dart';
import 'app_tools_registry.dart';

class PlanCatalogConfig {
  static const String resumeBuilderToolName = AppToolsRegistry.resumeBuilder;
  static const String legacyResumeBuilderToolName = AppToolsRegistry.legacyResumeBuilder;
  static const int freeTierMaxFileSizeMb = 25;
  static const int paidTierMaxFileSizeMb = 250;
  static const int freeTierDailyConversionLimit = 7;
  static const int unlimitedConversions = -1;

  static const Set<String> _paidPlans = <String>{
    '7Days',
    'Monthly',
    'Yearly',
    'Lifetime',
  };

  static const List<String> registeredToolNames = AppToolsRegistry.allTools;

  static bool isPaidPlan(String plan) => _paidPlans.contains(plan);

  static int maxFileSizeMbForPlan(String plan) {
    return isPaidPlan(plan) ? paidTierMaxFileSizeMb : freeTierMaxFileSizeMb;
  }

  static int dailyConversionLimitForPlan(String plan) {
    return isPaidPlan(plan) ? unlimitedConversions : freeTierDailyConversionLimit;
  }

  final Map<String, double> inrPrices;
  final Map<String, double> usdPrices;
  final Map<String, List<String>> enabledToolsByPlan;
  final Map<String, String> userQuotasByPlan;
  final Map<String, String> voiceQuotasByPlan;
  final Map<String, String> ocrQuotasByPlan;

  const PlanCatalogConfig({
    required this.inrPrices,
    required this.usdPrices,
    required this.enabledToolsByPlan,
    this.userQuotasByPlan = const <String, String>{},
    this.voiceQuotasByPlan = const <String, String>{},
    this.ocrQuotasByPlan = const <String, String>{},
  });

  factory PlanCatalogConfig.defaults() {
    return const PlanCatalogConfig(
      inrPrices: {
        'Free': 0,
        '7Days': 199,
        'Monthly': 499,
        'Yearly': 2499,
        'Lifetime': 19999,
      },
      usdPrices: {
        'Free': 0,
        '7Days': 4.99,
        'Monthly': 9.99,
        'Yearly': 29.99,
        'Lifetime': 199.99,
      },
      enabledToolsByPlan: {
        'Free': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'CSV to Excel',
          'AI Voice Command',
          AppToolsRegistry.govtVerifier,
          'PDF Compress (Single File) - set exact KB or MB target',
          'HD Photo Studio',
          resumeBuilderToolName,
          AppToolsRegistry.qrLocationGenerator,
        ],
        '7Days': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'Edit PDF',
          'OCR',
          'CSV to Excel',
          'AI Voice Command',
          AppToolsRegistry.govtVerifier,
          'PDF Compress (Single File) - set exact KB or MB target',
          'HD Photo Studio',
          resumeBuilderToolName,
          AppToolsRegistry.qrLocationGenerator,
          AppToolsRegistry.visionOcr,
        ],
        'Monthly': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'Edit PDF',
          'OCR',
          'CSV to Excel',
          'AI Voice Command',
          AppToolsRegistry.govtVerifier,
          'PDF Compress (Single File) - set exact KB or MB target',
          'Batch Compress (Multiple Files) - process many files',
          'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
          'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
          'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
          'PDF OCR & Extract (Extract and search text from PDF pages)',
          'Edit PDF (Edit PDF, then save and download)',
          'HD Photo Studio',
          resumeBuilderToolName,
          AppToolsRegistry.qrLocationGenerator,
          AppToolsRegistry.visionOcr,
        ],
        'Yearly': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'Edit PDF',
          'OCR',
          'History',
          'CSV to Excel',
          'AI Voice Command',
          AppToolsRegistry.govtVerifier,
          'PDF Compress (Single File) - set exact KB or MB target',
          'Batch Compress (Multiple Files) - process many files',
          'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
          'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
          'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
          'PDF OCR & Extract (Extract and search text from PDF pages)',
          'Edit PDF (Edit PDF, then save and download)',
          'HD Photo Studio',
          resumeBuilderToolName,
          AppToolsRegistry.qrLocationGenerator,
          AppToolsRegistry.visionOcr,
        ],
        'Lifetime': [
          'Compress',
          'Convert',
          'Merge',
          'Split',
          'Extract',
          'Edit PDF',
          'OCR',
          'History',
          'CSV to Excel',
          'AI Voice Command',
          AppToolsRegistry.govtVerifier,
          'PDF Compress (Single File) - set exact KB or MB target',
          'Batch Compress (Multiple Files) - process many files',
          'Micro-Canva (Background remover, passport resize, upscale, PNG to SVG)',
          'Resume Canvas (Template canvas for resumes, cover letters, SOP drafts)',
          'Poster Studio (Canvas-based poster, banner, flyer, and local print)',
          'PDF OCR & Extract (Extract and search text from PDF pages)',
          'Edit PDF (Edit PDF, then save and download)',
          'HD Photo Studio',
          resumeBuilderToolName,
          AppToolsRegistry.qrLocationGenerator,
          AppToolsRegistry.visionOcr,
        ],
      },
      userQuotasByPlan: {
        'Free': '7',
        '7Days': '50',
        'Monthly': '1200',
        'Yearly': '2000',
        'Lifetime': '10000',
      },
      voiceQuotasByPlan: {
        'Free': '0',
        '7Days': '25',
        'Monthly': '150',
        'Yearly': '1500',
        'Lifetime': '5000',
      },
      ocrQuotasByPlan: {
        'Free': '0',
        '7Days': '50',
        'Monthly': '200',
        'Yearly': '300',
        'Lifetime': '300',
      },
    );
  }

  static Set<String> get _v11AllowedTools => registeredToolNames.toSet();

  static String _canonicalToolName(String tool) {
    final canonical = AppToolsRegistry.canonicalName(tool);
    return canonical;
  }

  static List<String> _sanitizeTools(List<String> tools) {
    final sanitized = <String>{};
    for (final tool in tools) {
      final canonical = _canonicalToolName(tool);
      if (_v11AllowedTools.contains(canonical)) {
        sanitized.add(canonical);
      }
    }
    return sanitized.toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'inr_prices': inrPrices,
      'usd_prices': usdPrices,
      'enabled_tools_by_plan': enabledToolsByPlan,
      'user_quotas_by_plan': userQuotasByPlan,
      'voice_quotas_by_plan': voiceQuotasByPlan,
      'ocr_quotas_by_plan': ocrQuotasByPlan,
    };
  }

  factory PlanCatalogConfig.fromMap(Map<String, dynamic> map) {
    final defaults = PlanCatalogConfig.defaults();

    Map<String, double> readPriceMap(dynamic raw, Map<String, double> fallback) {
      if (raw is! Map) {
        return fallback;
      }
      final merged = <String, double>{...fallback};
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = double.tryParse(entry.value.toString());
        if (value != null) {
          merged[key] = value;
        }
      }
      return merged;
    }

    Map<String, List<String>> readToolsMap(dynamic raw, Map<String, List<String>> fallback) {
      if (raw is! Map) {
        return fallback;
      }
      final merged = <String, List<String>>{};
      for (final fallbackEntry in fallback.entries) {
        merged[fallbackEntry.key] = _sanitizeTools(List<String>.from(fallbackEntry.value));
      }

      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          final fallbackTools = merged[key] ?? const <String>[];
          final rawTools = value.map((item) => item.toString()).toList();
          merged[key] = _sanitizeTools(<String>[...fallbackTools, ...rawTools]);
        }
      }
      return merged;
    }

    Map<String, String> readQuotaMap(dynamic raw, Map<String, String> fallback) {
      if (raw is! Map) {
        return fallback;
      }
      final merged = <String, String>{...fallback};
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final rawValue = entry.value;
        // Explicit existence check (not a truthy check) - a legitimate "0"
        // quota must be preserved, only a genuinely missing/blank value
        // should fall back to the previous entry.
        if (rawValue != null && rawValue.toString().trim().isNotEmpty) {
          merged[key] = rawValue.toString().trim();
        }
      }
      return merged;
    }

    return PlanCatalogConfig(
      inrPrices: readPriceMap(map['inr_prices'], defaults.inrPrices),
      usdPrices: readPriceMap(map['usd_prices'], defaults.usdPrices),
      enabledToolsByPlan: readToolsMap(map['enabled_tools_by_plan'], defaults.enabledToolsByPlan),
      userQuotasByPlan: readQuotaMap(map['user_quotas_by_plan'], defaults.userQuotasByPlan),
      voiceQuotasByPlan: readQuotaMap(map['voice_quotas_by_plan'], defaults.voiceQuotasByPlan),
      ocrQuotasByPlan: readQuotaMap(map['ocr_quotas_by_plan'], defaults.ocrQuotasByPlan),
    );
  }
}

class PlanCatalogService {
  static const String _storageKey = 'jobready_plan_catalog_config_v1_1';

  static String formatPlanPriceLine(String plan, {required String currencyCode, String suffix = ''}) {
    final config = load();
    final inrAmount = config.inrPrices[plan] ?? 0.0;
    final usdAmount = config.usdPrices[plan] ?? 0.0;

    if (plan == 'Free') {
      return currencyCode == 'INR' ? '₹0$suffix' : '\$0$suffix';
    }

    if (currencyCode == 'INR') {
      return '₹${inrAmount.toStringAsFixed(inrAmount.truncateToDouble() == inrAmount ? 0 : 2)}$suffix';
    }

    return '\$${usdAmount.toStringAsFixed(usdAmount.truncateToDouble() == usdAmount ? 0 : 2)}$suffix';
  }

  static PlanCatalogConfig load() {
    final raw = WebSafeBrowser.readLocalStorage(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return PlanCatalogConfig.defaults();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return PlanCatalogConfig.defaults();
      }
      return PlanCatalogConfig.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return PlanCatalogConfig.defaults();
    }
  }

  static Future<void> save(PlanCatalogConfig config) async {
    WebSafeBrowser.writeLocalStorage(_storageKey, jsonEncode(config.toMap()));
  }

  static Future<void> reset() async {
    WebSafeBrowser.removeLocalStorage(_storageKey);
  }
}
