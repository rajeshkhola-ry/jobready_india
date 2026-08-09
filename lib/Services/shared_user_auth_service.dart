import 'dart:convert';

import 'package:universal_html/html.dart' as html;

class SharedUserProfile {
  final String fullName;
  final String email;
  final String mobile;
  final String country;
  final String role;
  final int walletBalancePaise;

  const SharedUserProfile({required this.fullName, required this.email, required this.mobile, required this.country, required this.role, required this.walletBalancePaise});

  factory SharedUserProfile.fromMap(Map<String, dynamic> map) => SharedUserProfile(
    fullName: map['fullName']?.toString() ?? 'User',
    email: map['email']?.toString() ?? '',
    mobile: map['mobile']?.toString() ?? '',
    country: map['country']?.toString() ?? 'India',
    role: map['role']?.toString() ?? 'user',
    walletBalancePaise: int.tryParse(map['walletBalancePaise']?.toString() ?? '') ?? 0,
  );
}

class SharedAuthResult {
  final SharedUserProfile? profile;
  final String? error;
  const SharedAuthResult({this.profile, this.error});
  bool get success => profile != null;
}

class SharedUserAuthService {
  static const _baseUrl = 'https://voice.getreadyjob.com';

  static Future<SharedAuthResult> login(String email, String password) => _post('/api/auth/login', {'email': email, 'password': password});

  static Future<SharedAuthResult> signup({required String fullName, required String email, required String mobile, required String country, required String password}) =>
      _post('/api/auth/signup', {'fullName': fullName, 'email': email, 'mobile': mobile, 'country': country, 'password': password});

  static Future<void> logout() async {
    try {
      await html.HttpRequest.request(
        '$_baseUrl/api/auth/logout',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: '{}',
        withCredentials: true,
      );
    } catch (_) {}
  }

  static Future<SharedAuthResult> _post(String path, Map<String, dynamic> payload) async {
    try {
      final response = await html.HttpRequest.request(
        '$_baseUrl$path',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: jsonEncode(payload),
        withCredentials: true,
      );
      final data = jsonDecode(response.responseText ?? '{}') as Map<String, dynamic>;
      if (response.status! < 200 || response.status! >= 300 || data['success'] != true) return SharedAuthResult(error: data['error']?.toString() ?? 'Shared authentication failed.');
      return SharedAuthResult(profile: SharedUserProfile.fromMap(Map<String, dynamic>.from(data['user'] as Map)));
    } catch (_) {
      return const SharedAuthResult(error: 'Unable to reach the shared account service.');
    }
  }
}
