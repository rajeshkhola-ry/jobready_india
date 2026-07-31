import 'dart:convert';

import 'package:universal_html/html.dart' as html;

class UserAccountProfile {
  final String displayName;
  final String email;
  final String country;
  final String countryCode;
  final String mobileNumber;
  final bool historyEnabled;
  final bool googleLoginPreferred;
  final String activePlan;
  final String planStatus;
  final int remainingCredits;
  final int convertedFilesCount;
  final String planCurrency;
  final double planPrice;
  final String planSummary;

  const UserAccountProfile({
    required this.displayName,
    required this.email,
    required this.country,
    required this.countryCode,
    required this.mobileNumber,
    required this.historyEnabled,
    required this.googleLoginPreferred,
    required this.activePlan,
    required this.planStatus,
    required this.remainingCredits,
    required this.convertedFilesCount,
    required this.planCurrency,
    required this.planPrice,
    required this.planSummary,
  });

  factory UserAccountProfile.initial() {
    return const UserAccountProfile(
      displayName: '',
      email: '',
      country: 'India',
      countryCode: '+91',
      mobileNumber: '',
      historyEnabled: true,
      googleLoginPreferred: false,
      activePlan: 'Free',
      planStatus: 'Active',
      remainingCredits: 3,
      convertedFilesCount: 0,
      planCurrency: 'USD',
      planPrice: 0.0,
      planSummary: 'Free access to core tools',
    );
  }

  UserAccountProfile copyWith({
    String? displayName,
    String? email,
    String? country,
    String? countryCode,
    String? mobileNumber,
    bool? historyEnabled,
    bool? googleLoginPreferred,
    String? activePlan,
    String? planStatus,
    int? remainingCredits,
    int? convertedFilesCount,
    String? planCurrency,
    double? planPrice,
    String? planSummary,
  }) {
    return UserAccountProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      historyEnabled: historyEnabled ?? this.historyEnabled,
      googleLoginPreferred: googleLoginPreferred ?? this.googleLoginPreferred,
      activePlan: activePlan ?? this.activePlan,
      planStatus: planStatus ?? this.planStatus,
      remainingCredits: remainingCredits ?? this.remainingCredits,
      convertedFilesCount: convertedFilesCount ?? this.convertedFilesCount,
      planCurrency: planCurrency ?? this.planCurrency,
      planPrice: planPrice ?? this.planPrice,
      planSummary: planSummary ?? this.planSummary,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'display_name': displayName,
      'email': email,
      'country': country,
      'country_code': countryCode,
      'mobile_number': mobileNumber,
      'history_enabled': historyEnabled,
      'google_login_preferred': googleLoginPreferred,
      'active_plan': activePlan,
      'plan_status': planStatus,
      'remaining_credits': remainingCredits,
      'converted_files_count': convertedFilesCount,
      'plan_currency': planCurrency,
      'plan_price': planPrice,
      'plan_summary': planSummary,
    };
  }

  factory UserAccountProfile.fromMap(Map<String, dynamic> map) {
    return UserAccountProfile(
      displayName: map['display_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      country: map['country']?.toString().trim().isNotEmpty == true
          ? map['country'].toString()
          : 'India',
      countryCode: map['country_code']?.toString().trim().isNotEmpty == true
          ? map['country_code'].toString()
          : '+91',
      mobileNumber: map['mobile_number']?.toString() ?? '',
      historyEnabled: map['history_enabled'] == true,
      googleLoginPreferred: map['google_login_preferred'] == true,
      activePlan: map['active_plan']?.toString() ?? 'Free',
      planStatus: map['plan_status']?.toString() ?? 'Active',
      remainingCredits: int.tryParse(map['remaining_credits']?.toString() ?? '') ?? 3,
      convertedFilesCount: int.tryParse(map['converted_files_count']?.toString() ?? '') ?? 0,
      planCurrency: map['plan_currency']?.toString() ?? 'USD',
      planPrice: double.tryParse(map['plan_price']?.toString() ?? '') ?? 0.0,
      planSummary: map['plan_summary']?.toString() ?? 'Free access to core tools',
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
