import 'dart:convert';

import '../Utils/lifetime_device_limit_utils.dart';
import '../Utils/web_safe_browser.dart';
import 'shared_user_auth_service.dart';
import 'user_account_service.dart';

class UserAuthSession {
  final String uid;
  final String displayName;
  final String email;
  final String country;
  final String countryCode;
  final String mobileNumber;
  final String authMethod;
  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  const UserAuthSession({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.country,
    required this.countryCode,
    required this.mobileNumber,
    required this.authMethod,
    required this.isEmailVerified,
    required this.createdAt,
    required this.lastLoginAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'display_name': displayName,
      'email': email,
      'country': country,
      'country_code': countryCode,
      'mobile_number': mobileNumber,
      'auth_method': authMethod,
      'is_email_verified': isEmailVerified,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt.toIso8601String(),
    };
  }

  factory UserAuthSession.fromMap(Map<String, dynamic> map) {
    return UserAuthSession(
      uid: map['uid']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      country: map['country']?.toString() ?? 'India',
      countryCode: map['country_code']?.toString() ?? '+91',
      mobileNumber: map['mobile_number']?.toString() ?? '',
      authMethod: map['auth_method']?.toString() ?? 'email',
      isEmailVerified: map['is_email_verified'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      lastLoginAt: DateTime.tryParse(map['last_login_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class AuthRestrictionException implements Exception {
  final String message;

  const AuthRestrictionException(this.message);

  @override
  String toString() => message;
}

class UserAuthService {
  static const String _sessionStorageKey = 'jobready_auth_session_v2';
  static const String _accountsStorageKey = 'jobready_auth_accounts_v2';
  static const String _passwordResetStorageKey = 'jobready_auth_password_resets_v2';
  static const String _lifetimeDeviceRegistryStorageKey = 'jobready_lifetime_device_registry_v2';
  static const String _deviceSessionTokenStorageKey = 'jobready_device_session_token_v2';
  static const String _authRoleStorageKey = 'jobready_auth_role_v1';
  static const String _authTokenStorageKey = 'jobready_auth_token_v1';

  static bool get isSignedIn {
    if (getSession() != null) {
      return true;
    }

    final role = WebSafeBrowser.readLocalStorage(_authRoleStorageKey)?.trim().toLowerCase();
    if (role == 'user' || role == 'admin') {
      return true;
    }

    final token = WebSafeBrowser.readLocalStorage(_authTokenStorageKey)?.trim();
    return token != null && token.isNotEmpty;
  }

  static UserAuthSession? getSession() {
    final raw = WebSafeBrowser.readLocalStorage(_sessionStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return UserAuthSession.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static Future<UserAuthSession?> signInWithEmailPassword(String email, String password, {String? selectedPlan}) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty || password.trim().isEmpty) {
      return null;
    }

    final accounts = _readAccounts();
    final rawAccount = accounts[normalizedEmail];
    if (rawAccount is! Map) {
      return null;
    }

    final storedHash = rawAccount['password_hash']?.toString();
    if (!_passwordMatches(password, storedHash)) {
      return null;
    }

    final effectivePlan = _normalizePlan(selectedPlan ?? rawAccount['active_plan']?.toString());
    if (effectivePlan == 'Lifetime') {
      await _enforceLifetimeDeviceLimit(email: normalizedEmail, selectedPlan: effectivePlan);
    }

    final session = UserAuthSession(
      uid: rawAccount['uid']?.toString() ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
      displayName: rawAccount['display_name']?.toString() ?? 'User',
      email: normalizedEmail,
      country: rawAccount['country']?.toString() ?? 'India',
      countryCode: rawAccount['country_code']?.toString() ?? '+91',
      mobileNumber: rawAccount['mobile_number']?.toString() ?? '',
      authMethod: rawAccount['auth_method']?.toString() ?? 'email',
      isEmailVerified: true,
      createdAt: DateTime.tryParse(rawAccount['created_at']?.toString() ?? '') ?? DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    await _persistSession(session);
    await _updateProfileFromSession(session, activePlan: effectivePlan);
    return session;
  }

  static Future<UserAuthSession?> signUpWithEmailPassword({
    required String displayName,
    required String email,
    required String password,
    required String country,
    required String countryCode,
    required String mobileNumber,
    String? selectedPlan,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty || displayName.trim().isEmpty || password.trim().isEmpty) {
      return null;
    }

    final accounts = _readAccounts();
    if (accounts.containsKey(normalizedEmail)) {
      return signInWithEmailPassword(normalizedEmail, password);
    }

    final effectivePlan = _normalizePlan(selectedPlan);
    if (effectivePlan == 'Lifetime') {
      await _enforceLifetimeDeviceLimit(email: normalizedEmail, selectedPlan: effectivePlan);
    }

    final session = UserAuthSession(
      uid: 'local-${DateTime.now().microsecondsSinceEpoch}',
      displayName: displayName.trim(),
      email: normalizedEmail,
      country: country.trim().isNotEmpty ? country : 'India',
      countryCode: countryCode.trim().isNotEmpty ? countryCode : '+91',
      mobileNumber: mobileNumber.trim(),
      authMethod: 'email',
      isEmailVerified: true,
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    final accountEntry = {
      'uid': session.uid,
      'display_name': session.displayName,
      'email': normalizedEmail,
      'active_plan': effectivePlan,
      'country': session.country,
      'country_code': session.countryCode,
      'mobile_number': session.mobileNumber,
      'auth_method': 'email',
      'password_hash': _hashPassword(password),
      'created_at': session.createdAt.toIso8601String(),
      'last_login_at': session.lastLoginAt.toIso8601String(),
    };

    accounts[normalizedEmail] = accountEntry;
    await _saveAccounts(accounts);
    await _persistSession(session);
    await _updateProfileFromSession(session, activePlan: effectivePlan);
    return session;
  }

  static Future<UserAuthSession?> signInWithGoogle({
    required String email,
    String? displayName,
    String? country,
    String? countryCode,
    String? mobileNumber,
    String? selectedPlan,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      return null;
    }

    final accounts = _readAccounts();
    final existing = accounts[normalizedEmail];
    final effectivePlan = _normalizePlan(selectedPlan ?? (existing is Map ? existing['active_plan']?.toString() : null));
    if (effectivePlan == 'Lifetime') {
      await _enforceLifetimeDeviceLimit(email: normalizedEmail, selectedPlan: effectivePlan);
    }

    final existingDisplayName = existing is Map ? existing['display_name']?.toString().trim() ?? '' : '';
    final existingCountry = existing is Map ? existing['country']?.toString().trim() ?? '' : '';
    final existingCountryCode = existing is Map ? existing['country_code']?.toString().trim() ?? '' : '';
    final existingMobile = existing is Map ? existing['mobile_number']?.toString().trim() ?? '' : '';

    final session = UserAuthSession(
      uid: existing is Map ? existing['uid']?.toString() ?? 'local-${DateTime.now().microsecondsSinceEpoch}' : 'local-${DateTime.now().microsecondsSinceEpoch}',
      displayName: displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : (existingDisplayName.isNotEmpty ? existingDisplayName : 'Google User'),
      email: normalizedEmail,
      country: country?.trim().isNotEmpty == true
        ? country!
        : (existingCountry.isNotEmpty ? existingCountry : 'India'),
      countryCode: countryCode?.trim().isNotEmpty == true
        ? countryCode!
        : (existingCountryCode.isNotEmpty ? existingCountryCode : '+91'),
      mobileNumber: mobileNumber?.trim().isNotEmpty == true
        ? mobileNumber!.trim()
        : existingMobile,
      authMethod: 'google',
      isEmailVerified: true,
      createdAt: existing is Map ? DateTime.tryParse(existing['created_at']?.toString() ?? '') ?? DateTime.now() : DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    final accountEntry = {
      'uid': session.uid,
      'display_name': session.displayName,
      'email': normalizedEmail,
      'active_plan': effectivePlan,
      'country': session.country,
      'country_code': session.countryCode,
      'mobile_number': session.mobileNumber,
      'auth_method': 'google',
      'password_hash': null,
      'created_at': session.createdAt.toIso8601String(),
      'last_login_at': session.lastLoginAt.toIso8601String(),
    };

    accounts[normalizedEmail] = accountEntry;
    await _saveAccounts(accounts);
    await _persistSession(session);
    await _updateProfileFromSession(session, activePlan: effectivePlan);
    return session;
  }

  static Future<UserAuthSession?> signInWithGoogleAuto({
    String? selectedPlan,
  }) async {
    // Try to reuse browser/local account context before asking user for manual fields.
    final profile = UserAccountService.getProfile();
    final accounts = _readAccounts();

    final profileEmail = _normalizeEmail(profile.email);
    if (profileEmail.isNotEmpty) {
      final account = accounts[profileEmail];
      if (account is Map && account['auth_method']?.toString() == 'google') {
        return signInWithGoogle(
          email: profileEmail,
          displayName: profile.displayName,
          country: profile.country,
          countryCode: profile.countryCode,
          mobileNumber: profile.mobileNumber,
          selectedPlan: selectedPlan,
        );
      }
    }

    for (final entry in accounts.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      if (value['auth_method']?.toString() != 'google') {
        continue;
      }

      return signInWithGoogle(
        email: entry.key,
        displayName: value['display_name']?.toString(),
        country: value['country']?.toString(),
        countryCode: value['country_code']?.toString(),
        mobileNumber: value['mobile_number']?.toString(),
        selectedPlan: selectedPlan,
      );
    }

    return null;
  }

  static Future<bool> requestPasswordReset(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      return false;
    }

    final accounts = _readAccounts();
    if (!accounts.containsKey(normalizedEmail)) {
      return false;
    }

    WebSafeBrowser.writeLocalStorage(
      _passwordResetStorageKey,
      jsonEncode({
        'email': normalizedEmail,
        'requested_at': DateTime.now().toIso8601String(),
      }),
    );
    return true;
  }

  static Future<bool> updatePassword(String currentPassword, String newPassword) async {
    final session = getSession();
    if (session == null) {
      return false;
    }

    final normalizedEmail = _normalizeEmail(session.email);
    if (normalizedEmail.isEmpty || newPassword.trim().isEmpty) {
      return false;
    }

    final accounts = _readAccounts();
    final rawAccount = accounts[normalizedEmail];
    if (rawAccount is! Map) {
      return false;
    }

    if (rawAccount['auth_method']?.toString() == 'google') {
      return false;
    }

    if (!_passwordMatches(currentPassword, rawAccount['password_hash']?.toString())) {
      return false;
    }

    rawAccount['password_hash'] = _hashPassword(newPassword);
    accounts[normalizedEmail] = rawAccount;
    await _saveAccounts(accounts);
    return true;
  }

  static Future<void> signOut() async {
    await SharedUserAuthService.logout();
    WebSafeBrowser.removeLocalStorage(_sessionStorageKey);
    WebSafeBrowser.removeLocalStorage(_authRoleStorageKey);
    WebSafeBrowser.removeLocalStorage(_authTokenStorageKey);
  }

  static Future<void> reset() async {
    WebSafeBrowser.removeLocalStorage(_sessionStorageKey);
    WebSafeBrowser.removeLocalStorage(_accountsStorageKey);
    WebSafeBrowser.removeLocalStorage(_passwordResetStorageKey);
    WebSafeBrowser.removeLocalStorage(_authRoleStorageKey);
    WebSafeBrowser.removeLocalStorage(_authTokenStorageKey);
  }

  static Future<void> _persistSession(UserAuthSession session) async {
    WebSafeBrowser.writeLocalStorage(_sessionStorageKey, jsonEncode(session.toMap()));
  }

  static Future<void> _saveAccounts(Map<String, dynamic> accounts) async {
    WebSafeBrowser.writeLocalStorage(_accountsStorageKey, jsonEncode(accounts));
  }

  static Map<String, dynamic> _readAccounts() {
    final raw = WebSafeBrowser.readLocalStorage(_accountsStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _updateProfileFromSession(UserAuthSession session, {String? activePlan}) async {
    final profile = UserAccountService.getProfile();
    await UserAccountService.saveProfile(
      profile.copyWith(
        displayName: session.displayName,
        email: session.email,
        country: session.country,
        countryCode: session.countryCode,
        mobileNumber: session.mobileNumber,
        googleLoginPreferred: session.authMethod == 'google',
        activePlan: activePlan ?? profile.activePlan,
      ),
    );
  }

  static String _normalizePlan(String? plan) {
    final normalized = (plan ?? '').trim();
    if (normalized.isEmpty) {
      return 'Free';
    }
    return normalized.toLowerCase().contains('lifetime') ? 'Lifetime' : normalized;
  }

  static Future<void> _enforceLifetimeDeviceLimit({required String email, required String selectedPlan}) async {
    if (selectedPlan != 'Lifetime') {
      return;
    }

    final normalizedEmail = _normalizeEmail(email);
    final deviceId = _buildDeviceFingerprint();
    final deviceToken = _getOrCreateSessionToken();
    final deviceType = _detectDeviceType();
    final registry = _readLifetimeDeviceRegistry();
    final accountEntry = (registry[normalizedEmail] is Map)
        ? Map<String, dynamic>.from(registry[normalizedEmail] as Map)
        : <String, dynamic>{};
    final devices = <Map<String, dynamic>>[];
    if (accountEntry['devices'] is List) {
      for (final item in accountEntry['devices'] as List) {
        if (item is Map) {
          devices.add(Map<String, dynamic>.from(item));
        }
      }
    }

    final existingDeviceIndex = devices.indexWhere((device) {
      final deviceIdValue = device['device_id']?.toString() ?? '';
      final tokenValue = device['session_token']?.toString() ?? '';
      return deviceIdValue == deviceId || tokenValue == deviceToken;
    });

    if (existingDeviceIndex >= 0) {
      devices[existingDeviceIndex]['last_seen_at'] = DateTime.now().toIso8601String();
      accountEntry['devices'] = devices;
      registry[normalizedEmail] = accountEntry;
      await _persistLifetimeDeviceRegistry(registry);
      return;
    }

    final existingDesktopCount = devices.where((device) => device['device_type'] == 'desktop').length;
    final existingMobileCount = devices.where((device) => device['device_type'] == 'mobile').length;
    final isDesktopDevice = deviceType == 'desktop';
    final isMobileDevice = deviceType == 'mobile';

    if (shouldBlockLifetimeDeviceLogin(
      existingDesktopCount: existingDesktopCount,
      existingMobileCount: existingMobileCount,
      deviceType: deviceType,
    )) {
      throw AuthRestrictionException(buildLifetimeDeviceLimitNotice());
    }

    devices.add({
      'device_id': deviceId,
      'session_token': deviceToken,
      'device_type': deviceType,
      'label': isDesktopDevice ? 'Desktop / Laptop' : (isMobileDevice ? 'Mobile' : 'Other device'),
      'created_at': DateTime.now().toIso8601String(),
      'last_seen_at': DateTime.now().toIso8601String(),
    });
    accountEntry['devices'] = devices;
    registry[normalizedEmail] = accountEntry;
    await _persistLifetimeDeviceRegistry(registry);
  }

  static String _buildDeviceFingerprint() {
    final platform = WebSafeBrowser.navigatorPlatform;
    final language = WebSafeBrowser.navigatorLanguage;
    final (screenWidth, screenHeight) = WebSafeBrowser.screenSize;
    final userAgent = WebSafeBrowser.navigatorUserAgent;
    final payload = '$platform|$language|${screenWidth}x${screenHeight}|$userAgent';
    return base64Encode(utf8.encode(payload));
  }

  static String _detectDeviceType() {
    final platform = WebSafeBrowser.navigatorPlatform.toLowerCase();
    final userAgent = WebSafeBrowser.navigatorUserAgent.toLowerCase();
    final isMobile = userAgent.contains('android') ||
        userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('mobile') ||
        platform.contains('iphone') ||
        platform.contains('android');
    if (isMobile) {
      return 'mobile';
    }
    return 'desktop';
  }

  static String _getOrCreateSessionToken() {
    final existing = WebSafeBrowser.readLocalStorage(_deviceSessionTokenStorageKey) ?? '';
    if (existing.trim().isNotEmpty) {
      return existing;
    }
    final token = _buildDeviceFingerprint();
    WebSafeBrowser.writeLocalStorage(_deviceSessionTokenStorageKey, token);
    return token;
  }

  static Map<String, dynamic> _readLifetimeDeviceRegistry() {
    final raw = WebSafeBrowser.readLocalStorage(_lifetimeDeviceRegistryStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> _persistLifetimeDeviceRegistry(Map<String, dynamic> registry) async {
    WebSafeBrowser.writeLocalStorage(_lifetimeDeviceRegistryStorageKey, jsonEncode(registry));
  }

  static String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  static String _hashPassword(String password) {
    return base64Encode(utf8.encode(password));
  }

  static bool _passwordMatches(String password, String? storedHash) {
    if (storedHash == null || storedHash.trim().isEmpty) {
      return false;
    }
    return _hashPassword(password) == storedHash;
  }
}
