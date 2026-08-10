import 'dart:convert';

import 'package:http/http.dart' as http;

import '../Utils/web_safe_browser.dart';
import 'api_config.dart';

class AdminRemoteLoginResult {
  final bool success;
  final String? error;
  final bool showQr;
  final String qrCodeUrl;
  final String authToken;

  const AdminRemoteLoginResult({
    required this.success,
    this.error,
    this.showQr = false,
    this.qrCodeUrl = '',
    this.authToken = '',
  });
}

class AdminRemoteAuthService {
  static const _challengeKey = 'jobready_admin_remote_challenge_v1';
  static const _showQrKey = 'jobready_admin_remote_show_qr_v1';
  static const _qrUrlKey = 'jobready_admin_remote_qr_url_v1';

  static bool get hasPendingChallenge => (WebSafeBrowser.readLocalStorage(_challengeKey) ?? '').isNotEmpty;
  static bool get showQr => WebSafeBrowser.readLocalStorage(_showQrKey) == '1';
  static String get qrCodeUrl => WebSafeBrowser.readLocalStorage(_qrUrlKey) ?? '';

  static Future<AdminRemoteLoginResult> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.renderCompressionApiUrl}/api/admin/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
        return AdminRemoteLoginResult(success: false, error: data['error']?.toString() ?? 'Admin login failed.');
      }

      final directToken = data['token']?.toString() ?? '';
      if (directToken.isNotEmpty) {
        clearPendingChallenge();
        return AdminRemoteLoginResult(success: true, authToken: directToken);
      }

      final challenge = data['challengeToken']?.toString() ?? '';
      if (challenge.isEmpty) return const AdminRemoteLoginResult(success: false, error: 'Admin challenge was not created.');
      final displayQr = data['showQR'] == true;
      final qrUrl = data['qrCodeUrl']?.toString() ?? '';
      WebSafeBrowser.writeLocalStorage(_challengeKey, challenge);
      WebSafeBrowser.writeLocalStorage(_showQrKey, displayQr ? '1' : '0');
      WebSafeBrowser.writeLocalStorage(_qrUrlKey, qrUrl);
      return AdminRemoteLoginResult(success: true, showQr: displayQr, qrCodeUrl: qrUrl);
    } catch (_) {
      return const AdminRemoteLoginResult(success: false, error: 'Unable to reach the production admin service.');
    }
  }

  static Future<String?> verify(String input) async {
    final challenge = WebSafeBrowser.readLocalStorage(_challengeKey) ?? '';
    if (challenge.isEmpty) return null;
    final normalized = input.trim();
    final body = <String, String>{'challengeToken': challenge};
    if (RegExp(r'^\d{6}$').hasMatch(normalized)) {
      body['code'] = normalized;
    } else {
      body['recoveryCode'] = normalized;
    }
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.renderCompressionApiUrl}/api/admin/2fa/verify'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) return null;
      final token = data['token']?.toString() ?? '';
      if (token.isEmpty) return null;
      clearPendingChallenge();
      return token;
    } catch (_) {
      return null;
    }
  }

  static void clearPendingChallenge() {
    WebSafeBrowser.removeLocalStorage(_challengeKey);
    WebSafeBrowser.removeLocalStorage(_showQrKey);
    WebSafeBrowser.removeLocalStorage(_qrUrlKey);
  }
}
