import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/api_config.dart';
import '../Services/usage_quota_service.dart';
import '../Services/public_brand_config.dart';
import '../Services/free_trial_service.dart';
import '../Services/device_binding_service.dart';
import '../Services/plan_catalog_service.dart';
import '../Services/user_account_service.dart';
import '../Services/user_auth_service.dart';
import '../Services/owner_admin_access_service.dart';
import 'user_auth_dialog.dart';

bool _isAdminBypassActive() {
  return OwnerAdminAccessService.isUnlocked;
}

/// Fire-and-forget: decrements the signed-in customer's purchased quota balance on the
/// backend and refreshes the local cached profile so the Dashboard reflects it immediately,
/// without blocking or slowing down the tool action itself.
void _syncPaidQuotaConsumption() {
  if (!UserAuthService.isSignedIn) {
    return;
  }
  final profile = UserAccountService.getProfile();
  final email = profile.email.trim();
  if (email.isEmpty || profile.activePlan.trim().isEmpty || profile.activePlan == 'Free') {
    return;
  }

  Future<void>(() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/user/quota/consume');
      final request = await html.HttpRequest.request(
        uri.toString(),
        method: 'POST',
        requestHeaders: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
        sendData: jsonEncode({'email': email}),
      );
      final raw = request.responseText ?? '';
      if (raw.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['success'] != true) {
        return;
      }
      final isUnlimited = decoded['quotaIsUnlimited'] == true || decoded['quotaTotal']?.toString() == 'unlimited';
      final remaining = isUnlimited ? -1 : int.tryParse(decoded['quotaRemaining']?.toString() ?? '');
      if (remaining == null) {
        return;
      }
      await UserAccountService.saveProfile(profile.copyWith(remainingCredits: remaining));
    } catch (_) {
      // Non-critical: the Dashboard will pick up the correct balance on its next server sync.
    }
  });
}

/// Call this before starting any tool action.
/// Returns true if usage is within the free-tier limit.
/// Returns false and shows an upgrade prompt if the daily limit is reached.
Future<bool> checkQuotaAndProceed({
  required BuildContext context,
  required String actionBucket,
}) async {
  if (_isAdminBypassActive()) {
    return true;
  }

  if (!DeviceBindingService.checkAndBindForFreePlan()) {
    if (!context.mounted) {
      return false;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.devices_other_rounded, color: Color(0xFFB45309)),
            SizedBox(width: 8),
            Text(
              'Device Limit Reached',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              DeviceBindingService.blockedMessage,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'Contact: ${PublicBrandConfig.supportEmail}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
    return false;
  }

  // Paid plans (7Days/Monthly/Yearly/Lifetime) have no daily action cap -
  // matches PlanCatalogConfig.dailyConversionLimitForPlan()'s existing
  // "unlimited for any paid plan" intent, which nothing previously enforced.
  final profile = UserAccountService.getProfile();
  final plan = profile.activePlan.trim().isEmpty ? 'Free' : profile.activePlan.trim();
  if (PlanCatalogConfig.isPaidPlan(plan)) {
    _syncPaidQuotaConsumption();
    return true;
  }

  // Free plan: ONE combined daily pool across compress/convert/merge/split
  // (not 4 separate high buckets) - the real enforcement number now comes
  // from the SAME admin-editable "Daily Usage Quota" shown in the Pricing
  // Modal/Comparison Table, so an admin change actually takes effect here.
  final summary = UsageQuotaService.getTodaySummary();
  final combinedUsed = summary.compressions + summary.conversions + summary.merges + summary.splits;
  final combinedLimit = _freeDailyCombinedLimit();
  final overLimit = combinedLimit >= 0 && combinedUsed >= combinedLimit;

  if (!overLimit) {
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          SizedBox(width: 8),
          Text(
            'Daily Limit Reached',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have used $combinedUsed of $combinedLimit free actions today.',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            'Upgrade to Pro or AI Premium for higher daily limits.',
            style: TextStyle(fontSize: 13, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 10),
          Text(
            'Contact: ${PublicBrandConfig.supportEmail}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
          ),
          child: const Text('View Plans'),
        ),
      ],
    ),
  );

  return false;
}

/// Free plan's combined daily action limit - reads the SAME admin-editable
/// "Daily Usage Quota" value used by the Pricing Modal/Comparison Table
/// (PlanCatalogConfig.userQuotasByPlan['Free']), 'Unlimited' aware. Falls
/// back to PlanCatalogConfig.freeTierDailyConversionLimit if unset/unparsable.
int _freeDailyCombinedLimit() {
  final config = PlanCatalogService.load();
  final raw = (config.userQuotasByPlan['Free'] ??
          PlanCatalogConfig.defaults().userQuotasByPlan['Free'] ??
          PlanCatalogConfig.freeTierDailyConversionLimit.toString())
      .trim();
  if (raw.toLowerCase() == 'unlimited') {
    return -1;
  }
  return int.tryParse(raw) ?? PlanCatalogConfig.freeTierDailyConversionLimit;
}

/// Call this before entering a one-time-free premium tool (AI Resume Builder,
/// HD Photo Studio). Yearly/Lifetime accounts get unlimited access. Free
/// accounts must sign in and get exactly one free use per account; visitors
/// without an account are asked to sign up first.
/// Returns true if the user may proceed.
Future<bool> checkOneTimeToolAccessAndProceed({
  required BuildContext context,
  required String toolKey,
  required String toolLabel,
}) async {
  if (_isAdminBypassActive()) {
    return true;
  }

  if (!UserAuthService.isSignedIn) {
    // Reuse any existing Google-authenticated local account before showing login UI again.
    await UserAuthService.signInWithGoogleAuto();
  }

  if (!UserAuthService.isSignedIn) {
    if (!context.mounted) {
      return false;
    }

    var wantsToSignIn = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Color(0xFF0F172A)),
            SizedBox(width: 8),
            Text('Create a Free Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'New users get 1 free use of $toolLabel. Create a free account or sign in to continue — it only takes a minute.',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              wantsToSignIn = true;
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Up / Sign In'),
          ),
        ],
      ),
    );

    if (!wantsToSignIn) {
      return false;
    }

    if (!context.mounted) {
      return false;
    }

    // onAuthenticated is a no-op so the dialog just closes here instead of
    // hard-navigating to /dashboard, keeping the user on the tool page they
    // were trying to open.
    await showDialog<void>(
      context: context,
      builder: (authContext) => UserAuthDialog(
        stayOnHomeAfterAuth: true,
        onAuthenticated: (_, __) {},
      ),
    );

    if (!UserAuthService.isSignedIn) {
      return false;
    }
  }

  final activePlan = UserAccountService.getProfile().activePlan.trim().toLowerCase();
  final isPaidPlan = activePlan.contains('year') || activePlan.contains('lifetime');
  if (isPaidPlan) {
    return true;
  }

  if (!FreeTrialService.hasUsedFreeTrial(toolKey)) {
    await FreeTrialService.markFreeTrialUsed(toolKey);
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: Color(0xFFB45309)),
          SizedBox(width: 8),
          Text('Free Trial Already Used', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
      content: Text(
        'You already used your 1 free try of $toolLabel on this account. Upgrade to a 1-Year or Lifetime plan for unlimited access.',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
          ),
          child: const Text('View Plans'),
        ),
      ],
    ),
  );

  return false;
}
