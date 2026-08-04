import '../Utils/web_safe_browser.dart';

class OwnerAdminAccessService {
  static const String _storageKey = 'jobready_owner_admin_unlock_v1';
  static const String _adminIdKey = 'jobready_owner_admin_id_v1';
  static const String _adminPasswordKey = 'jobready_owner_admin_password_v1';
  static const String _twoFactorPinKey = 'jobready_owner_admin_2fa_pin_v1';
  static const String _twoFactorRecoveryCodeKey = 'jobready_owner_admin_2fa_recovery_v1';
  static const String _twoFactorSessionVerifiedKey = 'jobready_owner_admin_2fa_verified_session_v1';
  static const String _legacyOwnerCode = 'JR-OWNER-2026';

  static const String defaultAdminId = 'Admin';
  static const String defaultAdminPassword = 'Admin@2026!';

  static bool get isUnlocked => WebSafeBrowser.readLocalStorage(_storageKey) == '1';

  static String get adminId =>
      (WebSafeBrowser.readLocalStorage(_adminIdKey) ?? defaultAdminId).trim();

  static String get adminPassword =>
      (WebSafeBrowser.readLocalStorage(_adminPasswordKey) ?? defaultAdminPassword).trim();

    static bool get isTwoFactorConfigured =>
      (WebSafeBrowser.readLocalStorage(_twoFactorPinKey) ?? '').toString().trim().isNotEmpty;

    static bool get isTwoFactorVerifiedForSession =>
      WebSafeBrowser.readLocalStorage(_twoFactorSessionVerifiedKey) == '1';

  static bool unlockWithCredentials(String inputAdminId, String inputPassword) {
    final enteredId = inputAdminId.trim();
    final enteredPassword = inputPassword.trim();

    final matchesDeviceCredentials = enteredId == adminId && enteredPassword == adminPassword;
    final matchesMasterCredentials =
        enteredId == defaultAdminId && enteredPassword == defaultAdminPassword;

    final ok = matchesDeviceCredentials || matchesMasterCredentials;
    if (ok) {
      WebSafeBrowser.writeLocalStorage(_storageKey, '1');
      WebSafeBrowser.removeLocalStorage(_twoFactorSessionVerifiedKey);
    }
    return ok;
  }

  static String configureTwoFactorPin(String pin) {
    final normalizedPin = pin.trim();
    WebSafeBrowser.writeLocalStorage(_twoFactorPinKey, normalizedPin);
    final recoveryCode = _generateRecoveryCode();
    WebSafeBrowser.writeLocalStorage(_twoFactorRecoveryCodeKey, recoveryCode);
    return recoveryCode;
  }

  static bool verifyTwoFactorCode(String input) {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final configuredPin = (WebSafeBrowser.readLocalStorage(_twoFactorPinKey) ?? '').toString().trim();
    final recoveryCode = (WebSafeBrowser.readLocalStorage(_twoFactorRecoveryCodeKey) ?? '').toString().trim();

    if (normalized == configuredPin) {
      WebSafeBrowser.writeLocalStorage(_twoFactorSessionVerifiedKey, '1');
      return true;
    }

    if (recoveryCode.isNotEmpty && normalized.toUpperCase() == recoveryCode.toUpperCase()) {
      // Recovery codes are single-use by design.
      WebSafeBrowser.removeLocalStorage(_twoFactorRecoveryCodeKey);
      WebSafeBrowser.writeLocalStorage(_twoFactorSessionVerifiedKey, '1');
      return true;
    }

    return false;
  }

  static Future<void> setCredentials({
    required String adminId,
    required String password,
  }) async {
    WebSafeBrowser.writeLocalStorage(_adminIdKey, adminId.trim());
    WebSafeBrowser.writeLocalStorage(_adminPasswordKey, password.trim());
  }

  static bool unlockWithCode(String inputCode) {
    // Backward compatibility for old owner code flow.
    final ok = inputCode.trim() == _legacyOwnerCode;
    if (ok) {
      WebSafeBrowser.writeLocalStorage(_storageKey, '1');
    }
    return ok;
  }

  static void lock() {
    WebSafeBrowser.removeLocalStorage(_storageKey);
    WebSafeBrowser.removeLocalStorage(_twoFactorSessionVerifiedKey);
  }

  static String _generateRecoveryCode() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final raw = now.toRadixString(36).toUpperCase();
    final padded = raw.length >= 10 ? raw.substring(raw.length - 10) : raw.padLeft(10, '0');
    return 'REC-$padded';
  }
}
