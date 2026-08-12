import 'dart:convert';

import '../Utils/web_safe_browser.dart';

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
  final String planId;
  final String planName;
  final String? activatedAtIso;
  final String? expiresAtIso;
  final bool toolsUnlimited;

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
    this.planId = 'free',
    this.planName = 'Free / Trial',
    this.activatedAtIso,
    this.expiresAtIso,
    this.toolsUnlimited = false,
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
      remainingCredits: 5,
      convertedFilesCount: 0,
      planCurrency: 'INR',
      planPrice: 0.0,
      planSummary: 'Free / Trial access',
      planId: 'free',
      planName: 'Free / Trial',
      toolsUnlimited: false,
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
    String? planId,
    String? planName,
    String? activatedAtIso,
    String? expiresAtIso,
    bool? toolsUnlimited,
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
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      activatedAtIso: activatedAtIso ?? this.activatedAtIso,
      expiresAtIso: expiresAtIso ?? this.expiresAtIso,
      toolsUnlimited: toolsUnlimited ?? this.toolsUnlimited,
    );
  }

  Map<String, dynamic> toMap() {
    final normalizedPlanId = planId.isNotEmpty ? planId : 'free';
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
      'plan_id': normalizedPlanId,
      'plan_name': planName,
      'activated_at': activatedAtIso,
      'expires_at': expiresAtIso,
      'tools_unlimited': toolsUnlimited,
      'plan': {
        'plan_id': normalizedPlanId,
        'plan_name': planName,
        'status': planStatus,
        'activated_at': activatedAtIso,
        'expires_at': expiresAtIso,
      },
      'credits': {
        'voice_minutes_remaining': remainingCredits,
        'tools_unlimited': toolsUnlimited,
      },
    };
  }

  factory UserAccountProfile.fromMap(Map<String, dynamic> map) {
    final planMap = map['plan'] is Map ? Map<String, dynamic>.from(map['plan'] as Map) : <String, dynamic>{};
    final creditsMap = map['credits'] is Map ? Map<String, dynamic>.from(map['credits'] as Map) : <String, dynamic>{};
    final legacyPlanId = map['plan_id']?.toString() ?? map['active_plan']?.toString() ?? 'free';
    final planId = (planMap['plan_id'] ?? legacyPlanId).toString();
    final displayPlanName = (planMap['plan_name'] ?? map['plan_name'] ?? map['active_plan'] ?? 'Free / Trial').toString();
    final activePlan = map['active_plan']?.toString() ?? displayPlanName;
    final remaining = int.tryParse(creditsMap['voice_minutes_remaining']?.toString() ?? map['remaining_credits']?.toString() ?? '') ??
        int.tryParse(map['voice_minutes_remaining']?.toString() ?? '') ?? 5;
    final toolsUnlimited = (creditsMap['tools_unlimited'] ?? map['tools_unlimited'] ?? false) == true;
    final expiresAt = (planMap['expires_at'] ?? map['expires_at'])?.toString();

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
      activePlan: activePlan,
      planStatus: (planMap['status'] ?? map['plan_status'] ?? 'active').toString(),
      remainingCredits: remaining,
      convertedFilesCount: int.tryParse(map['converted_files_count']?.toString() ?? '') ?? 0,
      planCurrency: map['plan_currency']?.toString() ?? 'INR',
      planPrice: double.tryParse(map['plan_price']?.toString() ?? '') ?? 0.0,
      planSummary: map['plan_summary']?.toString() ?? 'Free / Trial access',
      planId: planId,
      planName: displayPlanName,
      activatedAtIso: (planMap['activated_at'] ?? map['activated_at'])?.toString(),
      expiresAtIso: expiresAt,
      toolsUnlimited: toolsUnlimited,
    );
  }
}

class UserAccountService {
  static const String _storageKey = 'jobready_user_account_profile_v2';

  static UserAccountProfile getProfile() {
    final raw = WebSafeBrowser.readLocalStorage(_storageKey);
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
    WebSafeBrowser.writeLocalStorage(_storageKey, jsonEncode(profile.toMap()));
  }
}
