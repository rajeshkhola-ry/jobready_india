import 'package:flutter/foundation.dart';

/// Central place to turn ANY raw error (server exception, transport
/// failure, parse error, raw JSON, etc.) into one clean, user-facing
/// message. The original technical detail is always still logged via
/// [debugPrint] (visible in DevTools/browser console) so issues remain
/// fully diagnosable server/client-side - only the ON-SCREEN text changes.
class ErrorMessageService {
  ErrorMessageService._();

  static const String genericMessage =
      'Conversion could not be completed. Please ensure the file is not password-protected or corrupted, then try again.';

  // Markers that indicate a message is a raw/technical error rather than an
  // already-friendly, human-authored one (most messages in this codebase
  // already are friendly - only these get rewritten).
  static const List<String> _rawMarkers = <String>[
    'exception:',
    'server error (',
    'http ',
    '{"success"',
    'stacktrace',
    'formatexception',
    'null check operator',
    'errno',
  ];

  static bool _looksRaw(String text) {
    final lower = text.toLowerCase();
    return _rawMarkers.any((marker) => lower.contains(marker));
  }

  /// Returns a clean, user-facing message for [error]. [context] is only
  /// used to prefix the debug log line (e.g. "PDF to Word conversion").
  static String friendly(Object? error, {String context = 'Operation'}) {
    if (error == null) {
      return 'Something went wrong. Please try again.';
    }

    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    debugPrint('[$context] Raw error: $raw');

    if (raw.isEmpty) {
      return genericMessage;
    }

    final lower = raw.toLowerCase();

    if (lower.contains('password') || lower.contains('encrypted')) {
      return 'This file appears to be password-protected. Please remove the password and try again.';
    }
    if (lower.contains('too many images') || lower.contains('too many pages')) {
      return 'This document is large and is now being processed in smaller batches automatically. Please try again.';
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return 'This is taking longer than expected for a large or complex file. Please try again in a moment.';
    }
    if (lower.contains('cors') || lower.contains('failed host lookup') || lower.contains('socketexception')) {
      return 'We could not reach the server. Please check your internet connection and try again.';
    }
    if (lower.contains('quota') || lower.contains('limit reached') || lower.contains('billing')) {
      // These are already specific, actionable, human-authored messages
      // from the quota services - pass through unchanged.
      return raw;
    }
    if (!_looksRaw(raw)) {
      // Already a short, human-authored message - don't re-wrap it.
      return raw;
    }

    return genericMessage;
  }
}
