import 'dart:convert';

import '../Utils/web_safe_browser.dart';
import 'user_auth_service.dart';

/// Tracks the one-time free trial for premium tools (AI Resume Builder,
/// HD Photo Studio) that Free-plan accounts get exactly once per account.
/// Yearly/Lifetime plan users are never capped by this service.
class FreeTrialService {
  static const String _storageKey = 'jobready_free_trial_v1';

  static const String resumeBuilderTool = 'resume_builder';
  static const String hdPhotoTool = 'hd_photo';

  static Map<String, dynamic> _loadStore() {
    final raw = WebSafeBrowser.readLocalStorage(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Ignore malformed local data and reset.
    }

    return <String, dynamic>{};
  }

  static Future<void> _saveStore(Map<String, dynamic> store) async {
    WebSafeBrowser.writeLocalStorage(_storageKey, jsonEncode(store));
  }

  // Free trial usage is keyed per signed-in account (uid, falling back to email).
  static String? _currentAccountKey() {
    final session = UserAuthService.getSession();
    if (session == null) {
      return null;
    }
    if (session.uid.trim().isNotEmpty) {
      return session.uid.trim();
    }
    if (session.email.trim().isNotEmpty) {
      return session.email.trim().toLowerCase();
    }
    return null;
  }

  /// True if the signed-in account has already used its one-time free trial for [tool].
  static bool hasUsedFreeTrial(String tool) {
    final key = _currentAccountKey();
    if (key == null) {
      return false;
    }
    final store = _loadStore();
    final account = Map<String, dynamic>.from(store[key] as Map? ?? const <String, dynamic>{});
    return account[tool] == true;
  }

  static Future<void> markFreeTrialUsed(String tool) async {
    final key = _currentAccountKey();
    if (key == null) {
      return;
    }
    final store = _loadStore();
    final account = Map<String, dynamic>.from(store[key] as Map? ?? const <String, dynamic>{});
    account[tool] = true;
    store[key] = account;
    await _saveStore(store);
  }
}
