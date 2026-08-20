import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import '../Services/api_config.dart';
import '../Services/device_fingerprint_service.dart';
import '../Services/public_brand_config.dart';
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

/// Shared free-tier gate (2026-08-20 policy): paid plans and admin sessions
/// bypass entirely and rely on their own backend quota; every other visitor
/// - signed in or not - is capped at DeviceFingerprintService's lifetime
/// free-file limit for THIS device, with no login required up to that
/// point. Replaces the old "1 desktop + 1 mobile device" binding, the old
/// daily combined free-action quota, and the old "1 free use then forced
/// account creation" one-time-tool gate - all three are now this one policy.
Future<bool> _checkFreeFileDeviceGateAndProceed(BuildContext context) async {
  if (_isAdminBypassActive()) {
    return true;
  }

  final profile = UserAccountService.getProfile();
  final plan = profile.activePlan.trim().isEmpty ? 'Free' : profile.activePlan.trim();
  if (PlanCatalogConfig.isPaidPlan(plan)) {
    _syncPaidQuotaConsumption();
    return true;
  }

  if (DeviceFingerprintService.hasFreeFilesRemaining) {
    return true;
  }

  if (!context.mounted) {
    return false;
  }

  return _showFreeFileLimitReachedDialog(context);
}

/// The exact paywall shown once a device's lifetime free files are used up.
Future<bool> _showFreeFileLimitReachedDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: Color(0xFFB45309)),
          SizedBox(width: 8),
          Expanded(
            child: Text('Upgrade to Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have used your ${DeviceFingerprintService.lifetimeFreeFileLimit} free document credits on this device. '
            'Upgrade to our affordable plan or 1-Click Micro Pass to continue unlimited document edits.',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
          child: const Text('Not Now'),
        ),
        OutlinedButton(
          onPressed: () {
            // No dedicated quick-pay/"Micro Pass" flow exists yet in this app -
            // routes to Pricing (the closest real entry point) until one does.
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pushNamed('/pricing');
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFF0F172A)),
          ),
          child: const Text('Quick UPI / Micro Pass'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            if (UserAuthService.isSignedIn) {
              if (!context.mounted) return;
              Navigator.of(context).pushNamed('/pricing');
              return;
            }
            if (!context.mounted) return;
            await showDialog<void>(
              context: context,
              builder: (authContext) => UserAuthDialog(
                stayOnHomeAfterAuth: true,
                onAuthenticated: (_, _) {},
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
          ),
          child: const Text('Login / View Plans'),
        ),
      ],
    ),
  );
  return false;
}

/// Call this before starting any tool action.
/// Returns true if usage is within the free-tier limit.
/// Returns false and shows an upgrade prompt if the daily limit is reached.
Future<bool> checkQuotaAndProceed({
  required BuildContext context,
  required String actionBucket,
}) {
  return _checkFreeFileDeviceGateAndProceed(context);
}

/// Call this before entering a one-time-free premium tool (AI Resume Builder,
/// HD Photo Studio). This is now the SAME shared device-based lifetime-free-
/// file policy as every other tool - no forced sign-up before the free
/// files are used up. Paid plans and admin sessions still get unlimited
/// access via the shared gate above.
/// Returns true if the user may proceed.
Future<bool> checkOneTimeToolAccessAndProceed({
  required BuildContext context,
  required String toolKey,
  required String toolLabel,
}) {
  return _checkFreeFileDeviceGateAndProceed(context);
}
