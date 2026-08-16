import 'dart:convert';

import '../Utils/web_safe_browser.dart';
import 'owner_admin_access_service.dart';
import 'plan_catalog_service.dart';
import 'user_account_service.dart';

/// Tracks voice-command usage against a single running balance
/// (`UserAccountProfile.voiceCommandsBalance`) that both the plan's allocated
/// quota and purchased top-up packs contribute to. Admin sessions
/// (`OwnerAdminAccessService.isUnlocked`) always bypass this entirely.
class VoiceQuotaService {
  static const String _topUpHistoryKey = 'jobready_voice_topup_history_v1';

  /// Site-owner/admin sessions get unlimited voice commands.
  static bool get isAdmin => OwnerAdminAccessService.isUnlocked;

  static String _rawQuotaForPlan(String plan) {
    final config = PlanCatalogService.load();
    return config.voiceQuotasByPlan[plan] ?? PlanCatalogConfig.defaults().voiceQuotasByPlan[plan] ?? '5';
  }

  /// True when the current plan's admin-configured voice quota is the literal
  /// 'Unlimited' value (not tied to the numeric balance at all).
  static bool get isUnlimitedForCurrentPlan {
    final profile = UserAccountService.getProfile();
    return _rawQuotaForPlan(profile.activePlan).trim().toLowerCase() == 'unlimited';
  }

  /// Whether a voice command may be started right now.
  static bool canUseVoiceCommand() {
    if (isAdmin || isUnlimitedForCurrentPlan) {
      return true;
    }
    return UserAccountService.getProfile().voiceCommandsBalance > 0;
  }

  /// Friendly, user-facing reason why voice commands are blocked right now
  /// (empty string if they are currently allowed). Distinguishes a plan
  /// configured with a "0" voice quota from a balance simply run out, so the
  /// prompt always points the user toward a top-up or plan upgrade.
  static String blockedReasonMessage() {
    if (canUseVoiceCommand()) {
      return '';
    }
    final profile = UserAccountService.getProfile();
    final planQuotaIsZero = _rawQuotaForPlan(profile.activePlan).trim() == '0';
    if (planQuotaIsZero && profile.voiceCommandsBalance <= 0) {
      return 'Voice commands are not included in your current plan. Please purchase a top-up pack or upgrade your plan to use AI voice commands.';
    }
    return 'Voice quota exhausted for your plan. Please upgrade or top up to continue using AI voice commands.';
  }

  /// User-facing label for the account/profile UI - "Unlimited" for admin or
  /// an unlimited plan, otherwise "XX / Total".
  static String remainingLabel() {
    if (isAdmin || isUnlimitedForCurrentPlan) {
      return 'Unlimited';
    }
    final profile = UserAccountService.getProfile();
    final balance = profile.voiceCommandsBalance < 0 ? 0 : profile.voiceCommandsBalance;
    return '$balance / ${profile.voiceCommandsTotal}';
  }

  /// Deducts 1 voice command from the balance after a successful classification.
  /// No-op for admin sessions or plans with an Unlimited voice quota.
  static Future<void> recordUsage() async {
    if (isAdmin || isUnlimitedForCurrentPlan) {
      return;
    }
    final profile = UserAccountService.getProfile();
    final nextBalance = profile.voiceCommandsBalance > 0 ? profile.voiceCommandsBalance - 1 : 0;
    await UserAccountService.saveProfile(profile.copyWith(voiceCommandsBalance: nextBalance));
  }

  /// Applies the admin-configured voice quota for [plan] as the account's
  /// starting balance/total - called when a plan is purchased/activated.
  static Future<void> applyPlanQuotaAllocation(String plan) async {
    final raw = _rawQuotaForPlan(plan).trim();
    if (raw.toLowerCase() == 'unlimited') {
      return;
    }
    final quota = int.tryParse(raw) ?? 0;
    final profile = UserAccountService.getProfile();
    await UserAccountService.saveProfile(profile.copyWith(
      voiceCommandsBalance: quota,
      voiceCommandsTotal: quota,
    ));
  }

  /// Credits a purchased top-up pack onto the existing balance (never resets
  /// or expires) and records it in the local Top-Up History list.
  static Future<void> addTopUp({
    required int credits,
    required String packName,
    required double amountPaid,
    required String currency,
    String? invoiceUrl,
    String? transactionId,
  }) async {
    final profile = UserAccountService.getProfile();
    await UserAccountService.saveProfile(profile.copyWith(
      voiceCommandsBalance: profile.voiceCommandsBalance + credits,
      voiceCommandsTotal: profile.voiceCommandsTotal + credits,
    ));

    final history = getTopUpHistory();
    history.insert(0, {
      'date': DateTime.now().toIso8601String(),
      'packName': packName,
      'creditsAdded': credits,
      'amountPaid': amountPaid,
      'currency': currency,
      'invoiceUrl': invoiceUrl ?? '',
      'transactionId': transactionId ?? '',
    });
    WebSafeBrowser.writeLocalStorage(_topUpHistoryKey, jsonEncode(history));
  }

  static List<Map<String, dynamic>> getTopUpHistory() {
    final raw = WebSafeBrowser.readLocalStorage(_topUpHistoryKey);
    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }
      return decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
