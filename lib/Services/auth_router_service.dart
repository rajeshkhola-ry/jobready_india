import 'dart:convert';

import 'package:flutter/material.dart';

import '../Utils/web_safe_browser.dart';
import 'owner_admin_access_service.dart';
import 'user_auth_service.dart';

class AuthRouterService {
  static const String _roleStorageKey = 'jobready_auth_role_v1';
  static const String _authTokenStorageKey = 'jobready_auth_token_v1';

  static String getCurrentRole({String fallback = 'guest'}) {
    final storedRole = WebSafeBrowser.readLocalStorage(_roleStorageKey)?.toString().trim().toLowerCase();
    if (storedRole == 'admin') {
      return 'admin';
    }
    if (storedRole == 'user') {
      return 'user';
    }

    final token = WebSafeBrowser.readLocalStorage(_authTokenStorageKey)?.toString().trim() ?? '';
    if (token.isNotEmpty) {
      final decodedRole = _decodeTokenRole(token);
      if (decodedRole != null) {
        return decodedRole;
      }
    }

    if (OwnerAdminAccessService.isUnlocked && OwnerAdminAccessService.isTwoFactorVerifiedForSession) {
      return 'admin';
    }

    if (UserAuthService.isSignedIn) {
      return 'user';
    }

    return fallback;
  }

  static String resolveTargetRoute({String? role, String fallbackRoute = '/home'}) {
    final normalizedRole = role?.trim().toLowerCase();
    if (normalizedRole == 'admin') {
      return '/admin-dashboard';
    }
    if (normalizedRole == 'user') {
      return '/dashboard';
    }
    return fallbackRoute;
  }

  static Future<void> markAdminAuthenticated({String? authToken}) async {
    WebSafeBrowser.writeLocalStorage(_roleStorageKey, 'admin');
    if (authToken != null && authToken.trim().isNotEmpty) {
      WebSafeBrowser.writeLocalStorage(_authTokenStorageKey, authToken.trim());
    }
  }

  static Future<void> markUserAuthenticated({String? authToken}) async {
    WebSafeBrowser.writeLocalStorage(_roleStorageKey, 'user');
    if (authToken != null && authToken.trim().isNotEmpty) {
      WebSafeBrowser.writeLocalStorage(_authTokenStorageKey, authToken.trim());
    }
  }

  static Future<void> clearAuthentication() async {
    WebSafeBrowser.removeLocalStorage(_roleStorageKey);
    WebSafeBrowser.removeLocalStorage(_authTokenStorageKey);
  }

  static void redirectAfterLogin(BuildContext context, {String fallbackRoute = '/home'}) {
    final targetRoute = resolveTargetRoute(
      role: getCurrentRole(),
      fallbackRoute: fallbackRoute,
    );
    Navigator.of(context).pushNamedAndRemoveUntil(targetRoute, (route) => false);
  }

  static String? _decodeTokenRole(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final payload = parts[1];
      final normalizedPayload = payload + '=' * ((4 - payload.length % 4) % 4);
      final decodedBytes = base64Decode(normalizedPayload);
      final decoded = jsonDecode(utf8.decode(decodedBytes));
      if (decoded is! Map) {
        return null;
      }

      final role = decoded['role']?.toString().trim().toLowerCase();
      if (role == 'admin' || role == 'user') {
        return role;
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
