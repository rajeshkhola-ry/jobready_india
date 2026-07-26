import 'dart:convert';

import 'package:universal_html/html.dart' as html;

class PlanCatalogConfig {
  final Map<String, double> inrPrices;
  final Map<String, double> usdPrices;
  final Map<String, List<String>> enabledToolsByPlan;

  const PlanCatalogConfig({
    required this.inrPrices,
    required this.usdPrices,
    required this.enabledToolsByPlan,
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
        'Monthly': ['Compress', 'Convert', 'Merge', 'Split', 'Extract', 'Edit PDF', 'OCR', 'Resume'],
        'Yearly': ['Compress', 'Convert', 'Merge', 'Split', 'Extract', 'Edit PDF', 'OCR', 'Resume', 'History'],
        'Lifetime': ['Compress', 'Convert', 'Merge', 'Split', 'Extract', 'Edit PDF', 'OCR', 'Resume', 'History'],
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inr_prices': inrPrices,
      'usd_prices': usdPrices,
      'enabled_tools_by_plan': enabledToolsByPlan,
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
        merged[fallbackEntry.key] = List<String>.from(fallbackEntry.value);
      }

      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          merged[key] = value.map((item) => item.toString()).toList();
        }
      }
      return merged;
    }

    return PlanCatalogConfig(
      inrPrices: readPriceMap(map['inr_prices'], defaults.inrPrices),
      usdPrices: readPriceMap(map['usd_prices'], defaults.usdPrices),
      enabledToolsByPlan: readToolsMap(map['enabled_tools_by_plan'], defaults.enabledToolsByPlan),
    );
  }
}

class PlanCatalogService {
  static const String _storageKey = 'jobready_plan_catalog_config_v1_1';

  static PlanCatalogConfig load() {
    final raw = html.window.localStorage[_storageKey];
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
    html.window.localStorage[_storageKey] = jsonEncode(config.toMap());
  }

  static Future<void> reset() async {
    html.window.localStorage.remove(_storageKey);
  }
}
