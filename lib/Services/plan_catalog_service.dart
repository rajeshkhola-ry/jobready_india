import 'dart:convert';

import '../Utils/web_safe_browser.dart';

class PlanCatalogConfig {
  static const String resumeBuilderToolName = 'AI Resume Builder';
  static const String legacyResumeBuilderToolName = 'Resume Builder';

  static const List<String> registeredToolNames = <String>[
    'Compress',
    'Convert',
    'Merge',
    'Split',
    'Extract',
    'Edit PDF',
    'OCR',
    'History',
    'HD Photo Studio',
    resumeBuilderToolName,
  ];

  final Map<String, double> inrPrices;
  final Map<String, double> usdPrices;
  final Map<String, List<String>> enabledToolsByPlan;
  final Map<String, String> userQuotasByPlan;

  const PlanCatalogConfig({
    required this.inrPrices,
    required this.usdPrices,
    required this.enabledToolsByPlan,
    this.userQuotasByPlan = const <String, String>{},
  });

  factory PlanCatalogConfig.defaults() {
    return const PlanCatalogConfig(
      inrPrices: {
        'Free': 0,
        '7Days': 49,
        'Monthly': 99,
        'Yearly': 799,
        'Lifetime': 1999,
      },
      usdPrices: {
        'Free': 0,
        '7Days': 0.99,
        'Monthly': 1.99,
        'Yearly': 14.99,
        'Lifetime': 39,
      },
      enabledToolsByPlan: {
        'Free': ['Compress', 'Convert', 'Merge', 'Split', 'Extract'],
        '7Days': ['Compress', 'Convert', 'Merge', 'Split', 'Extract', 'Edit PDF', 'OCR'],
        'Monthly': ['Compress', 'Convert', 'Merge', 'Split', 'Extract', 'Edit PDF', 'OCR'],
        'Yearly': ['Compress', 'Convert', 'Merge', 'Split', 'Extract', 'Edit PDF', 'OCR', 'History', 'HD Photo Studio', 'AI Resume Builder'],
        'Lifetime': ['Compress', 'Convert', 'Merge', 'Split', 'Extract', 'Edit PDF', 'OCR', 'History', 'HD Photo Studio', 'AI Resume Builder'],
      },
      userQuotasByPlan: {
        'Free': '2',
        '7Days': '50',
        'Monthly': '200',
        'Yearly': '1000',
        'Lifetime': 'Unlimited',
      },
    );
  }

  static Set<String> get _v11AllowedTools => registeredToolNames.toSet();

  static String _canonicalToolName(String tool) {
    final trimmed = tool.trim();
    if (trimmed == legacyResumeBuilderToolName) {
      return resumeBuilderToolName;
    }
    return trimmed;
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
          merged[key] = _sanitizeTools(value.map((item) => item.toString()).toList());
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
        final value = entry.value?.toString() ?? '';
        if (value.trim().isNotEmpty) {
          merged[key] = value;
        }
      }
      return merged;
    }

    return PlanCatalogConfig(
      inrPrices: readPriceMap(map['inr_prices'], defaults.inrPrices),
      usdPrices: readPriceMap(map['usd_prices'], defaults.usdPrices),
      enabledToolsByPlan: readToolsMap(map['enabled_tools_by_plan'], defaults.enabledToolsByPlan),
      userQuotasByPlan: readQuotaMap(map['user_quotas_by_plan'], defaults.userQuotasByPlan),
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
      return '₹0 / \$0$suffix';
    }

    if (currencyCode == 'INR') {
      return '₹${inrAmount.toStringAsFixed(inrAmount.truncateToDouble() == inrAmount ? 0 : 2)}$suffix';
    }

    return '₹${inrAmount.toStringAsFixed(inrAmount.truncateToDouble() == inrAmount ? 0 : 2)} / \$${usdAmount.toStringAsFixed(usdAmount.truncateToDouble() == usdAmount ? 0 : 2)}$suffix';
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
