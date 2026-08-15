import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:js_interop' as js_interop;

import '../Utils/ui_web_stub.dart' if (dart.library.html) 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

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

/// Captures the user's real, verified Google email in-page (no popup/new tab,
/// no full-page redirect) using Google Identity Services (GIS), then asks the
/// backend to verify the ID token and persist the account before trusting it.
class GoogleIdentityService {
  GoogleIdentityService._();
  static final GoogleIdentityService instance = GoogleIdentityService._();

  /// Public Google OAuth Web Client ID (not a secret). Supplied at build time via
  /// `--dart-define=GOOGLE_OAUTH_CLIENT_ID=...`. Must match the backend's
  /// GOOGLE_OAUTH_CLIENT_ID env var so token audience verification succeeds.
  static const String clientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue: '',
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
      window.postMessage({ source: 'jobready_google_signin', token: '$token', credential: null }, window.location.origin);
    };
    document.head.appendChild(script);
  }
  withGis(function () {
    try {
      window.google.accounts.id.initialize({
        client_id: '$clientId',
        auto_select: false,
        callback: function (response) {
          window.postMessage({ source: 'jobready_google_signin', token: '$token', credential: response.credential }, window.location.origin);
        }
      });
      window.google.accounts.id.prompt(function (notification) {
        if (notification.isNotDisplayed() || notification.isSkippedMoment() || notification.isDismissedMoment()) {
          window.postMessage({ source: 'jobready_google_signin', token: '$token', credential: null }, window.location.origin);
        }
      });
    } catch (error) {
      window.postMessage({ source: 'jobready_google_signin', token: '$token', credential: null }, window.location.origin);
    }
  });
})();
''';
    js.context.callMethod('eval', [script]);
  }

  /// Shows a small in-place dialog with Google's real button, used only when the
  /// seamless One Tap prompt above is suppressed (still no new tab/redirect).
  Future<String?> _showFallbackButtonDialog(BuildContext context) async {
    final token = _activeToken;
    final completer = Completer<String?>();
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
      completer.complete(data['credential']?.toString());
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

  /// Triggers real Google Sign-In in-place. Returns the server-verified profile,
  /// or null if the user cancels or the flow could not be verified.
  Future<GoogleSignInProfile?> signIn(BuildContext context) async {
    if (!isConfigured) {
      return null;
    }

    final token = 'gsi_${DateTime.now().microsecondsSinceEpoch}';
    _activeToken = token;
    _ensureButtonFactoryRegistered();

    final completer = Completer<String?>();
    final subscription = html.window.onMessage.listen((event) {
      final data = _decodeBridgeMessage(event.data);
      if (data == null) {
        return;
      }
      if (data['source'] != 'jobready_google_signin' || data['token'] != token) {
        return;
      }
      if (!completer.isCompleted) {
        completer.complete(data['credential']?.toString());
      }
    });

    _initializeAndPrompt(token);

    String? credential = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
    await subscription.cancel();

    if ((credential == null || credential.isEmpty) && context.mounted) {
      credential = await _showFallbackButtonDialog(context);
    }

    if (credential == null || credential.isEmpty) {
      return null;
    }

    return _verifyWithBackend(credential);
  }

  Future<GoogleSignInProfile?> _verifyWithBackend(String idToken) async {
    final claims = _decodeIdTokenClaims(idToken) ?? const <String, dynamic>{};
    try {
      final response = await html.HttpRequest.request(
        '/api/user/google-signin',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        sendData: jsonEncode({'id_token': idToken}),
      );
      final raw = response.responseText ?? '{}';
      final decoded = (jsonDecode(raw) as Map?) ?? const <String, dynamic>{};
      if (decoded['success'] != true) {
        return null;
      }
      final user = decoded['user'];
      final serverEmail = user is Map ? (user['email']?.toString() ?? '') : '';
      final email = serverEmail.isNotEmpty ? serverEmail : (claims['email']?.toString() ?? '');
      if (email.trim().isEmpty) {
        return null;
      }
      return GoogleSignInProfile(
        email: email.trim().toLowerCase(),
        emailVerified: decoded['emailVerified'] == true || claims['email_verified']?.toString() == 'true',
        displayName: (user is Map ? user['name']?.toString() : null) ?? claims['name']?.toString() ?? '',
        pictureUrl: (user is Map ? user['googlePicture']?.toString() : null) ?? claims['picture']?.toString() ?? '',
        googleSub: (user is Map ? user['googleSub']?.toString() : null) ?? claims['sub']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
