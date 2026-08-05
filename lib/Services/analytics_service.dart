import 'dart:js' as js;

import 'package:flutter/foundation.dart';

/// Privacy-safe, cookie-less analytics helper.
/// Fires anonymous tool open/action events via window.grjTrackTool — no PII, no user data.
/// Silently no-ops on non-web or when the tracker JS is unavailable.
class AnalyticsService {
  const AnalyticsService._();

  /// Call in initState() when a tool page is first shown.
  static void trackToolOpen(String toolId) => _send(toolId, null);

  /// Call when a user completes a meaningful action (export, download, pack, etc.).
  static void trackToolAction(String toolId, String action) => _send(toolId, action);

  static void _send(String toolId, String? action) {
    if (!kIsWeb) return;
    try {
      final fn = js.context['grjTrackTool'];
      if (fn == null) return;
      if (action != null) {
        js.context.callMethod('grjTrackTool', [toolId, action]);
      } else {
        js.context.callMethod('grjTrackTool', [toolId]);
      }
    } catch (_) {
      // Silently skip if JS bridge is unavailable (test/non-web builds).
    }
  }
}
