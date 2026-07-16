import 'dart:convert';

import 'package:universal_html/html.dart' as html;

class UserAccountProfile {
  final String displayName;
  final String email;
  final bool historyEnabled;

  const UserAccountProfile({
    required this.displayName,
    required this.email,
    required this.historyEnabled,
  });

  factory UserAccountProfile.initial() {
    return const UserAccountProfile(
      displayName: '',
      email: '',
      historyEnabled: true,
    );
  }

  UserAccountProfile copyWith({
    String? displayName,
    String? email,
    bool? historyEnabled,
  }) {
    return UserAccountProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      historyEnabled: historyEnabled ?? this.historyEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'display_name': displayName,
      'email': email,
      'history_enabled': historyEnabled,
    };
  }

  factory UserAccountProfile.fromMap(Map<String, dynamic> map) {
    return UserAccountProfile(
      displayName: map['display_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      historyEnabled: map['history_enabled'] == true,
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
