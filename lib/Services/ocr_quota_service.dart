import 'dart:convert';

import '../Utils/web_safe_browser.dart';
import 'owner_admin_access_service.dart';
import 'plan_catalog_service.dart';
import 'user_account_service.dart';

/// Tracks the SHARED (combined) AI OCR page quota used by BOTH the scanned
/// PDF -> Word path and the Scanned PDF -> Searchable PDF tool. Unlike
/// [VoiceQuotaService] (a running balance allocated once per plan purchase),
/// this pool resets automatically every calendar month regardless of plan,
/// matching the product spec ("resets monthly on the 1st"). This is a
/// client-side/soft limit only - the server additionally enforces its own
/// authoritative global monthly cap shared across all users (990 pages).
class OcrQuotaService {
  static const String _storageKey = 'jobready_ocr_quota_v1';

  // Last-resort fallback only - the real, admin-editable source of truth is
  // PlanCatalogConfig.ocrQuotasByPlan (see monthlyLimitForCurrentPlan below).
  static const Map<String, int> _monthlyPageLimitByPlan = {
    'free': 0,
    '7days': 50,
    'monthly': 200,
    'yearly': 300,
    'lifetime': 300,
  };

  static bool get isAdmin => OwnerAdminAccessService.isUnlocked;

  static String _normalizedPlan(String plan) {
    final normalized = plan.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (normalized.contains('lifetime')) return 'lifetime';
    if (normalized.contains('year')) return 'yearly';
    if (normalized.contains('month')) return 'monthly';
    if (normalized.contains('7day') || normalized.contains('weekly') || normalized.contains('week')) {
      return '7days';
    }
    return 'free';
  }

  static const Map<String, String> _canonicalPlanKeyByNormalized = {
    'free': 'Free',
    '7days': '7Days',
    'monthly': 'Monthly',
    'yearly': 'Yearly',
    'lifetime': 'Lifetime',
  };

  /// Total combined OCR pages allowed per month for the current plan.
  /// Reads the admin-editable value first (PlanCatalogConfig.ocrQuotasByPlan,
  /// synced from the server-backed pricing config), falling back to shipped
  /// defaults and finally the hardcoded map above if all else is missing.
  static int get monthlyLimitForCurrentPlan {
    final profile = UserAccountService.getProfile();
    final normalized = _normalizedPlan(profile.activePlan);
    final canonicalKey = _canonicalPlanKeyByNormalized[normalized] ?? 'Free';
    final config = PlanCatalogService.load();
    final raw = config.ocrQuotasByPlan[canonicalKey] ?? PlanCatalogConfig.defaults().ocrQuotasByPlan[canonicalKey];
    final parsed = raw != null ? int.tryParse(raw.trim()) : null;
    return parsed ?? _monthlyPageLimitByPlan[normalized] ?? 0;
  }

  static bool get isFreePlan => _normalizedPlan(UserAccountService.getProfile().activePlan) == 'free';

  static String _monthKey() {
    final now = DateTime.now().toLocal();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

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

  static void _saveStore(Map<String, dynamic> store) {
    WebSafeBrowser.writeLocalStorage(_storageKey, jsonEncode(store));
  }

  /// Pages already used this calendar month (0 if the stored month has
  /// rolled over - the pool resets automatically on the 1st).
  static int get pagesUsedThisMonth {
    final store = _loadStore();
    if (store['monthKey'] != _monthKey()) {
      return 0;
    }
    return int.tryParse(store['pagesUsed']?.toString() ?? '0') ?? 0;
  }

  static int get remainingPages {
    if (isAdmin) return monthlyLimitForCurrentPlan;
    final remaining = monthlyLimitForCurrentPlan - pagesUsedThisMonth;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether [pageCount] more OCR pages may be processed right now.
  static bool canUseOcr(int pageCount) {
    if (isAdmin) return true;
    if (monthlyLimitForCurrentPlan <= 0) return false;
    return pagesUsedThisMonth + pageCount <= monthlyLimitForCurrentPlan;
  }

  /// Friendly, user-facing reason OCR is blocked right now (empty string if
  /// [pageCount] pages may proceed).
  static String blockedReasonMessage(int pageCount) {
    if (canUseOcr(pageCount)) {
      return '';
    }
    if (isFreePlan) {
      return 'AI OCR is available on 7-Day, Monthly, and Lifetime plans.';
    }
    return 'AI OCR quota exhausted for this month ($pagesUsedThisMonth/$monthlyLimitForCurrentPlan pages used). Resets on the 1st of next month, or upgrade your plan for a higher limit.';
  }

  /// User-facing label, e.g. "AI OCR Quota: 128 pages remaining".
  static String remainingLabel() {
    if (isAdmin) {
      return 'AI OCR Quota: Unlimited (admin)';
    }
    if (monthlyLimitForCurrentPlan <= 0) {
      return 'AI OCR Quota: not included in your plan';
    }
    return 'AI OCR Quota: $remainingPages of $monthlyLimitForCurrentPlan pages remaining';
  }

  /// Deducts [pageCount] pages from this month's combined pool after a
  /// successful OCR conversion (no-op for admin sessions).
  static Future<void> recordUsage(int pageCount) async {
    if (isAdmin || pageCount <= 0) {
      return;
    }
    final monthKey = _monthKey();
    final store = _loadStore();
    final currentUsed = store['monthKey'] == monthKey ? (int.tryParse(store['pagesUsed']?.toString() ?? '0') ?? 0) : 0;
    _saveStore({
      'monthKey': monthKey,
      'pagesUsed': currentUsed + pageCount,
    });
  }
}
