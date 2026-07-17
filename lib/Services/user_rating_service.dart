import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class UserRatingSummary {
  final int totalCount;
  final int todayCount;
  final double average;
  final bool publicVisible;

  const UserRatingSummary({
    required this.totalCount,
    required this.todayCount,
    required this.average,
    required this.publicVisible,
  });
}

class UserRatingService {
  static const String _ratingsKey = 'jobready_user_ratings_v1';
  static const String _visibilityKey = 'jobready_user_ratings_public_visible_v1';
  static const int _maxEntries = 2000;
  static final Map<String, String> _memoryStore = <String, String>{};

  static String? _getStorage(String key) {
    if (!kIsWeb) {
      return _memoryStore[key];
    }

    try {
      return html.window.localStorage[key];
    } catch (_) {
      return _memoryStore[key];
    }
  }

  static void _setStorage(String key, String value) {
    _memoryStore[key] = value;
    if (!kIsWeb) {
      return;
    }

    try {
      html.window.localStorage[key] = value;
    } catch (_) {
      // Keep memory fallback.
    }
  }

  static Future<void> submitRating(int stars) async {
    final normalized = stars.clamp(1, 5);
    final entries = _loadRatings().toList(growable: true);
    entries.add({
      'stars': normalized,
      'ts': DateTime.now().toIso8601String(),
    });

    final trimmed = entries.length > _maxEntries
        ? entries.sublist(entries.length - _maxEntries)
        : entries;

    _setStorage(_ratingsKey, jsonEncode(trimmed));
  }

  static UserRatingSummary getSummary() {
    final entries = _loadRatings();
    final today = DateTime.now().toLocal();

    var todayCount = 0;
    for (final entry in entries) {
      final tsRaw = entry['ts']?.toString();
      final ts = tsRaw == null ? null : DateTime.tryParse(tsRaw)?.toLocal();
      if (ts != null &&
          ts.year == today.year &&
          ts.month == today.month &&
          ts.day == today.day) {
        todayCount += 1;
      }
    }

    if (entries.isEmpty) {
      return UserRatingSummary(
        totalCount: 0,
        todayCount: 0,
        average: 0,
        publicVisible: isPublicVisible(),
      );
    }

    var total = 0;
    for (final entry in entries) {
      total += int.tryParse(entry['stars']?.toString() ?? '0') ?? 0;
    }

    return UserRatingSummary(
      totalCount: entries.length,
      todayCount: todayCount,
      average: total / entries.length,
      publicVisible: isPublicVisible(),
    );
  }

  static bool isPublicVisible() {
    final raw = _getStorage(_visibilityKey);
    if (raw == null || raw.trim().isEmpty) {
      return true;
    }
    return raw.toLowerCase() == 'true';
  }

  static Future<void> setPublicVisible(bool visible) async {
    _setStorage(_visibilityKey, visible.toString());
  }

  static List<Map<String, dynamic>> _loadRatings() {
    final raw = _getStorage(_ratingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Map<String, dynamic>>[];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
}
