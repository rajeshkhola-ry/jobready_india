import 'package:universal_html/html.dart' as html;

class OwnerAdminAccessService {
  static const String _storageKey = 'jobready_owner_admin_unlock_v1';
  static const String ownerCode = 'JR-OWNER-2026';

  static bool get isUnlocked => html.window.localStorage[_storageKey] == '1';

  static bool unlockWithCode(String inputCode) {
    final ok = inputCode.trim() == ownerCode;
    if (ok) {
      html.window.localStorage[_storageKey] = '1';
    }
    return ok;
  }

  static void lock() {
    html.window.localStorage.remove(_storageKey);
  }
}
