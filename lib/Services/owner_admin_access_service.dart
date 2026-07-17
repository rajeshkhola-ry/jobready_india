import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class OwnerAdminAccessService {
  static const String _storageKey = 'jobready_owner_admin_unlock_v1';
  static const String ownerCode = 'JR-OWNER-2026';
  static bool _memoryUnlocked = false;

  static String? _getStorage(String key) {
    if (!kIsWeb) {
      return _memoryUnlocked ? '1' : null;
    }

    try {
      return html.window.localStorage[key];
    } catch (_) {
      return _memoryUnlocked ? '1' : null;
    }
  }

  static void _setStorage(String key, String value) {
    _memoryUnlocked = value == '1';
    if (!kIsWeb) {
      return;
    }

    try {
      html.window.localStorage[key] = value;
    } catch (_) {
      // Keep memory fallback.
    }
  }

  static void _removeStorage(String key) {
    _memoryUnlocked = false;
    if (!kIsWeb) {
      return;
    }

    try {
      html.window.localStorage.remove(key);
    } catch (_) {
      // Keep memory fallback.
    }
  }

  static bool get isUnlocked => _getStorage(_storageKey) == '1';

  static bool unlockWithCode(String inputCode) {
    final ok = inputCode.trim() == ownerCode;
    if (ok) {
      _setStorage(_storageKey, '1');
    }
    return ok;
  }

  static void lock() {
    _removeStorage(_storageKey);
  }
}
