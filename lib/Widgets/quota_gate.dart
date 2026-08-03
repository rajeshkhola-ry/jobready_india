import 'package:flutter/material.dart';

import '../Services/usage_quota_service.dart';
import '../Services/public_brand_config.dart';
import '../Services/free_trial_service.dart';
import '../Services/user_account_service.dart';
import '../Services/user_auth_service.dart';
import 'user_auth_dialog.dart';

/// Call this before starting any tool action.
/// Returns true if usage is within the free-tier limit.
/// Returns false and shows an upgrade prompt if the daily limit is reached.
Future<bool> checkQuotaAndProceed({
  required BuildContext context,
  required String actionBucket,
}) async {
  final summary = UsageQuotaService.getTodaySummary();

  bool overLimit = false;
  int used = 0;
  int limit = 0;

  switch (actionBucket) {
    case 'compress':
      used = summary.compressions;
      limit = summary.compressionLimit;
      overLimit = used >= limit;
      break;
    case 'convert':
      used = summary.conversions;
      limit = summary.conversionLimit;
      overLimit = used >= limit;
      break;
    case 'merge':
      used = summary.merges;
      limit = summary.mergeLimit;
      overLimit = used >= limit;
      break;
    case 'split':
      used = summary.splits;
      limit = summary.splitLimit;
      overLimit = used >= limit;
      break;
    default:
      return true;
  }

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
            'You have used $used of $limit free $actionBucket actions today.',
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
            backgroundColor: const Color(0xFF1F4E79),
            foregroundColor: Colors.white,
          ),
          child: const Text('View Plans'),
        ),
      ],
    ),
  );

  return false;
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
            Icon(Icons.lock_outline_rounded, color: Color(0xFF1F4E79)),
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
              backgroundColor: const Color(0xFF1F4E79),
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
            backgroundColor: const Color(0xFF1F4E79),
            foregroundColor: Colors.white,
          ),
          child: const Text('View Plans'),
        ),
      ],
    ),
  );

  return false;
}
