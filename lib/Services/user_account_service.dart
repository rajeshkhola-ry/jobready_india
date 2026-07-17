import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static String? _memoryRaw;

  static String? _getStorage(String key) {
    if (!kIsWeb) {
      return _memoryRaw;
    }

    try {
      return html.window.localStorage[key];
    } catch (_) {
      return _memoryRaw;
    }
  }

  static void _setStorage(String key, String value) {
    _memoryRaw = value;
    if (!kIsWeb) {
      return;
    }

    try {
      html.window.localStorage[key] = value;
    } catch (_) {
      // Keep memory fallback.
    }
  }

  static UserAccountProfile getProfile() {
    final raw = _getStorage(_storageKey);
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
    _setStorage(_storageKey, jsonEncode(profile.toMap()));
  }
}
