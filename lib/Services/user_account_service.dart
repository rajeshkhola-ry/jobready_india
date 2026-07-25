import 'dart:convert';

import 'package:universal_html/html.dart' as html;

class UserAccountProfile {
  final String displayName;
  final String email;
  final String country;
  final bool historyEnabled;
  final bool googleLoginPreferred;

  const UserAccountProfile({
    required this.displayName,
    required this.email,
    required this.country,
    required this.historyEnabled,
    required this.googleLoginPreferred,
  });

  factory UserAccountProfile.initial() {
    return const UserAccountProfile(
      displayName: '',
      email: '',
      country: 'India',
      historyEnabled: true,
      googleLoginPreferred: false,
    );
  }

  UserAccountProfile copyWith({
    String? displayName,
    String? email,
    String? country,
    bool? historyEnabled,
    bool? googleLoginPreferred,
  }) {
    return UserAccountProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      country: country ?? this.country,
      historyEnabled: historyEnabled ?? this.historyEnabled,
      googleLoginPreferred: googleLoginPreferred ?? this.googleLoginPreferred,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'display_name': displayName,
      'email': email,
      'country': country,
      'history_enabled': historyEnabled,
      'google_login_preferred': googleLoginPreferred,
    };
  }

  factory UserAccountProfile.fromMap(Map<String, dynamic> map) {
    return UserAccountProfile(
      displayName: map['display_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      country: map['country']?.toString().trim().isNotEmpty == true
          ? map['country'].toString()
          : 'India',
      historyEnabled: map['history_enabled'] == true,
      googleLoginPreferred: map['google_login_preferred'] == true,
    );
  }
}

class UserAccountService {
  static const String _storageKey = 'jobready_user_account_profile_v2';

  static UserAccountProfile getProfile() {
    final raw = html.window.localStorage[_storageKey];
    if (raw == null || raw.trim().isEmpty) {
      return UserAccountProfile.initial();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return UserAccountProfile.initial();
      }
      return UserAccountProfile.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return UserAccountProfile.initial();
    }
  }

  static Future<void> saveProfile(UserAccountProfile profile) async {
    html.window.localStorage[_storageKey] = jsonEncode(profile.toMap());
  }
}
