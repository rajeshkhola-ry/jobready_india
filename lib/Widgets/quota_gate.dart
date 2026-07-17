import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../Services/usage_quota_service.dart';
import '../Services/public_brand_config.dart';

/// Call this before starting any tool action.
/// Returns true if usage is within the free-tier limit.
/// Returns false and shows an upgrade prompt if the daily limit is reached.
Future<bool> checkQuotaAndProceed({
  required BuildContext context,
  required String actionBucket,
}) async {
  if (!kIsWeb) {
    // Mobile runs should not fail due web-local quota storage constraints.
    return true;
  }

  UsageQuotaSummary summary;
  try {
    summary = UsageQuotaService.getTodaySummary();
  } catch (_) {
    // If quota storage is unavailable, allow tool execution instead of blocking all actions.
    return true;
  }

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
