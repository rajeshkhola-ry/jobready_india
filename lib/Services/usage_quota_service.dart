import 'dart:convert';

import 'package:universal_html/html.dart' as html;

import 'api_config.dart';

class UsageQuotaSummary {
  final int conversions;
  final int compressions;
  final int merges;
  final int splits;

  const UsageQuotaSummary({
    required this.conversions,
    required this.compressions,
    required this.merges,
    required this.splits,
  });

  int get conversionLimit => ApiConfig.maxConversionPerDay;
  int get compressionLimit => ApiConfig.maxCompressionPerDay;
  int get mergeLimit => ApiConfig.maxMergePerDay;
  int get splitLimit => ApiConfig.maxSplitPerDay;
}

class UsageQuotaService {
  static const String _storageKey = 'jobready_usage_quota_v2';
  static Map<String, dynamic> _memoryStore = <String, dynamic>{};

  static String _todayKey() {
    final now = DateTime.now().toLocal();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Map<String, dynamic> _loadStore() {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null || raw.trim().isEmpty) {
        return Map<String, dynamic>.from(_memoryStore);
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // localStorage may be blocked in privacy mode or restricted browser context.
      // Fall back to in-memory store so tool actions continue to work.
      return Map<String, dynamic>.from(_memoryStore);
    }

    return Map<String, dynamic>.from(_memoryStore);
  }

  static Future<void> _saveStore(Map<String, dynamic> store) async {
    _memoryStore = Map<String, dynamic>.from(store);
    try {
      html.window.localStorage[_storageKey] = jsonEncode(store);
    } catch (_) {
      // Ignore storage write failures; in-memory fallback remains active.
    }
  }

  static UsageQuotaSummary getTodaySummary() {
    final store = _loadStore();
    final day = Map<String, dynamic>.from(store[_todayKey()] as Map? ?? const <String, dynamic>{});

    int value(String key) => int.tryParse(day[key]?.toString() ?? '0') ?? 0;

    return UsageQuotaSummary(
      conversions: value('conversions'),
      compressions: value('compressions'),
      merges: value('merges'),
      splits: value('splits'),
    );
  }

  static Future<void> recordAction(String action) async {
    final normalized = action.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }

    final store = _loadStore();
    final key = _todayKey();
    final day = Map<String, dynamic>.from(store[key] as Map? ?? const <String, dynamic>{});

    String? bucket;
    if (normalized.contains('compress')) {
      bucket = 'compressions';
    } else if (normalized.contains('merge')) {
      bucket = 'merges';
    } else if (normalized.contains('split')) {
      bucket = 'splits';
    } else if (normalized.contains('convert') ||
        normalized.contains('word') ||
        normalized.contains('pdf') ||
        normalized.contains('image') ||
        normalized.contains('edited')) {
      bucket = 'conversions';
    }

    if (bucket == null) {
      return;
    }

    final current = int.tryParse(day[bucket]?.toString() ?? '0') ?? 0;
    day[bucket] = current + 1;
    store[key] = day;

    await _saveStore(store);
  }

  static Future<void> clearToday() async {
    final store = _loadStore();
    store.remove(_todayKey());
    await _saveStore(store);
  }
}
