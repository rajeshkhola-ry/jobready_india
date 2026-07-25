import 'package:universal_html/html.dart' as html;

class OwnerAdminAccessService {
  static const String _storageKey = 'jobready_owner_admin_unlock_v1';
  static const String _adminIdKey = 'jobready_owner_admin_id_v1';
  static const String _adminPasswordKey = 'jobready_owner_admin_password_v1';
  static const String _legacyOwnerCode = 'JR-OWNER-2026';

  static const String defaultAdminId = 'rajesh.khola';
  static const String defaultAdminPassword = 'Rajesh@2026';

  static bool get isUnlocked => html.window.localStorage[_storageKey] == '1';

  static String get adminId =>
      (html.window.localStorage[_adminIdKey] ?? defaultAdminId).trim();

  static String get adminPassword =>
      (html.window.localStorage[_adminPasswordKey] ?? defaultAdminPassword).trim();

  static bool unlockWithCredentials(String inputAdminId, String inputPassword) {
    final ok = inputAdminId.trim() == adminId && inputPassword.trim() == adminPassword;
    if (ok) {
      html.window.localStorage[_storageKey] = '1';
    }
    return ok;
  }

  static Future<void> setCredentials({
    required String adminId,
    required String password,
  }) async {
    html.window.localStorage[_adminIdKey] = adminId.trim();
    html.window.localStorage[_adminPasswordKey] = password.trim();
  }

  static bool unlockWithCode(String inputCode) {
    // Backward compatibility for old owner code flow.
    final ok = inputCode.trim() == _legacyOwnerCode;
    if (ok) {
      html.window.localStorage[_storageKey] = '1';
    }
    return ok;
  }

  static void lock() {
    html.window.localStorage.remove(_storageKey);
  }
}
