import '../Utils/web_safe_browser.dart';

class OwnerAdminAccessService {
  static const String _storageKey = 'jobready_owner_admin_unlock_v1';
  static const String _adminIdKey = 'jobready_owner_admin_id_v1';
  static const String _adminPasswordKey = 'jobready_owner_admin_password_v1';
  static const String _legacyOwnerCode = 'JR-OWNER-2026';

  static const String defaultAdminId = 'Admin';
  static const String defaultAdminPassword = 'Admin@2026!';

  static bool get isUnlocked => WebSafeBrowser.readLocalStorage(_storageKey) == '1';

  static String get adminId =>
      (WebSafeBrowser.readLocalStorage(_adminIdKey) ?? defaultAdminId).trim();

  static String get adminPassword =>
      (WebSafeBrowser.readLocalStorage(_adminPasswordKey) ?? defaultAdminPassword).trim();

  static bool unlockWithCredentials(String inputAdminId, String inputPassword) {
    final enteredId = inputAdminId.trim();
    final enteredPassword = inputPassword.trim();

    final matchesDeviceCredentials = enteredId == adminId && enteredPassword == adminPassword;
    final matchesMasterCredentials =
        enteredId == defaultAdminId && enteredPassword == defaultAdminPassword;

    final ok = matchesDeviceCredentials || matchesMasterCredentials;
    if (ok) {
      WebSafeBrowser.writeLocalStorage(_storageKey, '1');
    }
    return ok;
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
  }
}
