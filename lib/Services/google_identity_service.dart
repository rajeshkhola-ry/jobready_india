import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_interop' as js_interop;

import '../Utils/ui_web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

import 'api_config.dart';

/// Real, server-verified Google profile returned after a successful sign-in.
class GoogleSignInProfile {
  final String email;
  final bool emailVerified;
  final String displayName;
  final String pictureUrl;
  final String googleSub;

  const GoogleSignInProfile({
    required this.email,
    required this.emailVerified,
    required this.displayName,
    required this.pictureUrl,
    required this.googleSub,
  });
}

/// Why a Google sign-in attempt ended, so callers can route the user to the
/// email/password flow with an accurate message instead of a generic failure.
enum GoogleSignInStatus {
  success,

  /// User closed One Tap / the button dialog, or dismissed the consent screen.
  cancelled,

  /// Google Identity Services could not load or start (blocked script, offline,
  /// unsupported browser, missing client id).
  unavailable,

  /// A credential was returned but the backend refused it (unverified app,
  /// audience mismatch, expired or tampered token).
  verificationFailed,
}

class GoogleSignInResult {
  final GoogleSignInStatus status;
  final GoogleSignInProfile? profile;

  const GoogleSignInResult({required this.status, this.profile});

  bool get isSuccess => status == GoogleSignInStatus.success && profile != null;
}

/// Captures the user's real, verified Google email in-page (no popup/new tab,
/// no full-page redirect) using Google Identity Services (GIS), then asks the
/// backend to verify the ID token and persist the account before trusting it.
class GoogleIdentityService {
  GoogleIdentityService._();
  static final GoogleIdentityService instance = GoogleIdentityService._();

  /// Public Google OAuth Web Client ID (not a secret). Real production value is the default
  /// so it works even without a build flag; still overridable via
  /// `--dart-define=GOOGLE_OAUTH_CLIENT_ID=...`. Must match the backend's GOOGLE_OAUTH_CLIENT_ID
  /// env var so token audience verification succeeds.
  static const String clientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue: '365906972808-o92qicufhbn7r40hjrib3bln05vv52mk.apps.googleusercontent.com',
  );

  bool get isConfigured => clientId.trim().isNotEmpty;

  static const String _buttonViewType = 'jobready-google-signin-button';
  bool _buttonFactoryRegistered = false;
  String _activeToken = '';

  void _ensureButtonFactoryRegistered() {
    if (_buttonFactoryRegistered) {
      return;
    }
    _buttonFactoryRegistered = true;
    try {
      ui_web.platformViewRegistry.registerViewFactory(_buttonViewType, (int viewId) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center';
        _renderGoogleButton(container, _activeToken);
        return container;
      });
    } catch (_) {
      // Ignore registration failures on environments that do not support this path.
    }
  }

  void _renderGoogleButton(html.DivElement container, String token) {
    try {
      final googleId = js.context['google']?['accounts']?['id'];
      if (googleId == null) {
        return;
      }
      googleId.callMethod('renderButton', [
        container,
        js.JsObject.jsify({'theme': 'outline', 'size': 'large', 'width': 260, 'text': 'continue_with'}),
      ]);
    } catch (_) {
      // Ignore render failures; the caller still shows a manual cancel option.
    }
  }

  Map<String, dynamic>? _decodeBridgeMessage(dynamic data) {
    dynamic normalized = data;
    if (normalized is String) {
      final candidate = normalized.trim();
      if (candidate.isEmpty) {
        return null;
      }
      try {
        normalized = jsonDecode(candidate);
      } catch (_) {
        return null;
      }
    }
    if (normalized is Map) {
      return Map<String, dynamic>.from(normalized);
    }
    try {
      final dartified = (normalized as js_interop.JSAny?).dartify();
      if (dartified is Map) {
        return Map<String, dynamic>.from(dartified);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, dynamic>? _decodeIdTokenClaims(String idToken) {
    final parts = idToken.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64.decode(payload));
      final claims = jsonDecode(decoded);
      return claims is Map ? Map<String, dynamic>.from(claims) : null;
    } catch (_) {
      return null;
    }
  }

  void _initializeAndPrompt(String token) {
    final script =
        '''
(function() {
  function withGis(cb) {
    if (window.google && window.google.accounts && window.google.accounts.id) { cb(); return; }
    var existing = document.getElementById('jobready-gsi-script');
    if (existing) { existing.addEventListener('load', cb); setTimeout(cb, 400); return; }
    var script = document.createElement('script');
    script.id = 'jobready-gsi-script';
    script.src = 'https://accounts.google.com/gsi/client';
    script.async = true;
    script.onload = cb;
    script.onerror = function () {
      window.postMessage({ source: 'jobready_google_signin', token: '$token', credential: null, reason: 'script_error' }, window.location.origin);
    };
    document.head.appendChild(script);
  }
  withGis(function () {
    try {
      window.google.accounts.id.initialize({
        client_id: '$clientId',
        auto_select: false,
        callback: function (response) {
          window.postMessage({ source: 'jobready_google_signin', token: '$token', credential: response.credential, reason: '' }, window.location.origin);
        }
      });
      window.google.accounts.id.prompt(function (notification) {
        if (notification.isNotDisplayed() || notification.isSkippedMoment() || notification.isDismissedMoment()) {
          window.postMessage({ source: 'jobready_google_signin', token: '$token', credential: null, reason: 'prompt_suppressed' }, window.location.origin);
        }
      });
    } catch (error) {
      window.postMessage({ source: 'jobready_google_signin', token: '$token', credential: null, reason: 'init_error' }, window.location.origin);
    }
  });
})();
''';
    js.context.callMethod('eval', [script]);
  }

  /// Shows a small in-place dialog with Google's real button, used only when the
  /// seamless One Tap prompt above is suppressed (still no new tab/redirect).
  Future<Map<String, dynamic>?> _showFallbackButtonDialog(BuildContext context) async {
    final token = _activeToken;
    final completer = Completer<Map<String, dynamic>?>();
    BuildContext? capturedDialogContext;

    final subscription = html.window.onMessage.listen((event) {
      final data = _decodeBridgeMessage(event.data);
      if (data == null) {
        return;
      }
      if (data['source'] != 'jobready_google_signin' || data['token'] != token) {
        return;
      }
      if (completer.isCompleted) {
        return;
      }
      completer.complete(data);
      final dialogCtx = capturedDialogContext;
      if (dialogCtx != null && dialogCtx.mounted) {
        Navigator.of(dialogCtx).pop();
      }
    });

    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          capturedDialogContext = dialogContext;
          return AlertDialog(
            title: const Text('Continue with Google'),
            content: const SizedBox(
              width: 280,
              height: 60,
              child: HtmlElementView(viewType: _buttonViewType),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    }

    await subscription.cancel();
    if (!completer.isCompleted) {
      completer.complete(null);
    }
    return completer.future;
  }

  /// Triggers real Google Sign-In in-place. The returned status tells the caller
  /// whether to retry or to fall back to email/password sign-in.
  Future<GoogleSignInResult> signIn(BuildContext context) async {
    if (!isConfigured) {
      return const GoogleSignInResult(status: GoogleSignInStatus.unavailable);
    }

    final token = 'gsi_${DateTime.now().microsecondsSinceEpoch}';
    _activeToken = token;
    _ensureButtonFactoryRegistered();

    final completer = Completer<Map<String, dynamic>?>();
    final subscription = html.window.onMessage.listen((event) {
      final data = _decodeBridgeMessage(event.data);
      if (data == null) {
        return;
      }
      if (data['source'] != 'jobready_google_signin' || data['token'] != token) {
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(data);
      }
    });

    _initializeAndPrompt(token);

    final message = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
    await subscription.cancel();

    var credential = message?['credential']?.toString() ?? '';
    var reason = message?['reason']?.toString() ?? '';

    if (credential.isEmpty && (reason == 'script_error' || reason == 'init_error')) {
      return const GoogleSignInResult(status: GoogleSignInStatus.unavailable);
    }

    if (credential.isEmpty && context.mounted) {
      final fallback = await _showFallbackButtonDialog(context);
      credential = fallback?['credential']?.toString() ?? '';
      final fallbackReason = fallback?['reason']?.toString() ?? '';
      if (fallbackReason.isNotEmpty) {
        reason = fallbackReason;
      }
    }

    if (credential.isEmpty) {
      if (reason == 'script_error' || reason == 'init_error') {
        return const GoogleSignInResult(status: GoogleSignInStatus.unavailable);
      }
      return const GoogleSignInResult(status: GoogleSignInStatus.cancelled);
    }

    return _verifyWithBackend(credential);
  }

  Future<GoogleSignInResult> _verifyWithBackend(String idToken) async {
    final claims = _decodeIdTokenClaims(idToken) ?? const <String, dynamic>{};
    // Must be absolute: Firebase Hosting rewrites every unknown path to index.html,
    // so a relative /api call would return HTML instead of reaching the API server.
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    try {
      final response = await html.HttpRequest.request(
        '$base/api/user/google-signin',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        sendData: jsonEncode({'id_token': idToken}),
      );
      final raw = response.responseText ?? '{}';
      final decoded = (jsonDecode(raw) as Map?) ?? const <String, dynamic>{};
      if (decoded['success'] != true) {
        return const GoogleSignInResult(status: GoogleSignInStatus.verificationFailed);
      }
      final user = decoded['user'];
      final serverEmail = user is Map ? (user['email']?.toString() ?? '') : '';
      final email = serverEmail.isNotEmpty ? serverEmail : (claims['email']?.toString() ?? '');
      if (email.trim().isEmpty) {
        return const GoogleSignInResult(status: GoogleSignInStatus.verificationFailed);
      }
      return GoogleSignInResult(
        status: GoogleSignInStatus.success,
        profile: GoogleSignInProfile(
          email: email.trim().toLowerCase(),
          emailVerified: decoded['emailVerified'] == true || claims['email_verified']?.toString() == 'true',
          displayName: (user is Map ? user['name']?.toString() : null) ?? claims['name']?.toString() ?? '',
          pictureUrl: (user is Map ? user['googlePicture']?.toString() : null) ?? claims['picture']?.toString() ?? '',
          googleSub: (user is Map ? user['googleSub']?.toString() : null) ?? claims['sub']?.toString() ?? '',
        ),
      );
    } catch (_) {
      return const GoogleSignInResult(status: GoogleSignInStatus.unavailable);
    }
  }
}
