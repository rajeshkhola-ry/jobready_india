import 'dart:convert';
import 'dart:math';

import '../Utils/web_safe_browser.dart';
import 'owner_admin_access_service.dart';
import 'user_account_service.dart';

/// Soft, client-side enforcement of the Free plan's "1 desktop + 1 mobile
/// device" rule. Like every other quota in this app (voice/OCR/daily usage),
/// this is a per-browser localStorage check, NOT a hardened server-side
/// account-to-hardware binding - a different browser/profile/incognito
/// window looks like a "new device", and clearing storage resets it. Paid
/// plans and admin sessions are never gated by this.
class DeviceBindingService {
  static const String _deviceIdKey = 'jobready_device_id_v1';
  static const String _slotsKey = 'jobready_free_device_slots_v1';

  static bool get _isAdmin => OwnerAdminAccessService.isUnlocked;

  static String get _deviceId {
    var id = WebSafeBrowser.readLocalStorage(_deviceIdKey);
    if (id == null || id.trim().isEmpty) {
      id = _generateId();
      WebSafeBrowser.writeLocalStorage(_deviceIdKey, id);
    }
    return id;
  }

  static String _generateId() {
    final random = Random();
    final buffer = StringBuffer();
    for (var i = 0; i < 24; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-$buffer';
  }

  /// 'desktop' or 'mobile', inferred from the browser's own user agent -
  /// mirrors the existing heuristic already used in user_auth_service.dart.
  static String get _deviceType {
    final userAgent = WebSafeBrowser.navigatorUserAgent.toLowerCase();
    final isMobile = userAgent.contains('android') ||
        userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('mobile');
    return isMobile ? 'mobile' : 'desktop';
  }

  static Map<String, dynamic> _loadSlots() {
    final raw = WebSafeBrowser.readLocalStorage(_slotsKey);
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

  static void _saveSlots(Map<String, dynamic> slots) {
    WebSafeBrowser.writeLocalStorage(_slotsKey, jsonEncode(slots));
  }

  /// Binds this device to its type's slot ('desktop'/'mobile') if that slot
  /// is empty; returns false only when the slot is already taken by a
  /// DIFFERENT device. Only applies to the Free plan - paid plans and admin
  /// sessions always return true.
  static bool checkAndBindForFreePlan() {
    if (_isAdmin) {
      return true;
    }
    final profile = UserAccountService.getProfile();
    if (profile.activePlan.trim().isNotEmpty && profile.activePlan.trim() != 'Free') {
      return true;
    }

    final slots = _loadSlots();
    final type = _deviceType;
    final boundId = slots[type]?.toString();
    final thisId = _deviceId;

    if (boundId == null || boundId.isEmpty) {
      slots[type] = thisId;
      _saveSlots(slots);
      return true;
    }
    return boundId == thisId;
  }

  static const String blockedMessage =
      'Free plan is limited to 1 desktop device and 1 mobile device. This looks like an additional device - upgrade your plan to use more devices.';
}
