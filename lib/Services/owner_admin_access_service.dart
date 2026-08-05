import 'dart:math';

import 'package:crypto/crypto.dart';

import '../Utils/web_safe_browser.dart';

class TwoFactorSetupData {
  final String secret;
  final String otpauthUri;
  final String recoveryCode;

  const TwoFactorSetupData({
    required this.secret,
    required this.otpauthUri,
    required this.recoveryCode,
  });
}

class OwnerAdminAccessService {
  static const String _storageKey = 'jobready_owner_admin_unlock_v1';
  static const String _adminIdKey = 'jobready_owner_admin_id_v1';
  static const String _adminPasswordKey = 'jobready_owner_admin_password_v1';
  static const String _twoFactorSecretKey = 'jobready_owner_admin_2fa_secret_v1';
  static const String _twoFactorPendingSecretKey = 'jobready_owner_admin_2fa_pending_secret_v1';
  static const String _twoFactorRecoveryCodeKey = 'jobready_owner_admin_2fa_recovery_v1';
  static const String _twoFactorPendingRecoveryCodeKey = 'jobready_owner_admin_2fa_pending_recovery_v1';
  static const String _twoFactorStatusKey = 'jobready_owner_admin_2fa_status_v1';
  static const String _twoFactorSessionVerifiedKey = 'jobready_owner_admin_2fa_verified_session_v1';
  static const String _legacyOwnerCode = 'JR-OWNER-2026';
  static const String _totpIssuer = 'GETREADYJOB';
  static const String _totpAccountName = 'Admin';

  static const String defaultAdminId = 'Admin';
  static const String defaultAdminPassword = 'Admin@2026!';

  static bool get isUnlocked => WebSafeBrowser.readLocalStorage(_storageKey) == '1';

  static String get adminId =>
      (WebSafeBrowser.readLocalStorage(_adminIdKey) ?? defaultAdminId).trim();

  static String get adminPassword =>
      (WebSafeBrowser.readLocalStorage(_adminPasswordKey) ?? defaultAdminPassword).trim();

  static bool get isTwoFactorConfigured => isTwoFactorEnabled;

  static bool get isTwoFactorEnabled {
    final status = (WebSafeBrowser.readLocalStorage(_twoFactorStatusKey) ?? '').toString().trim().toUpperCase();
    if (status == 'ACTIVE') {
      return true;
    }

    // Backward compatibility: older versions only stored the secret.
    if (twoFactorSecret.isNotEmpty) {
      WebSafeBrowser.writeLocalStorage(_twoFactorStatusKey, 'ACTIVE');
      return true;
    }

    return false;
  }

  static bool get isTwoFactorVerifiedForSession =>
      WebSafeBrowser.readLocalStorage(_twoFactorSessionVerifiedKey) == '1';

  static String get twoFactorSecret =>
      (WebSafeBrowser.readLocalStorage(_twoFactorSecretKey) ?? '').toString().trim();

    static String get _twoFactorPendingSecret =>
      (WebSafeBrowser.readLocalStorage(_twoFactorPendingSecretKey) ?? '').toString().trim();

  static String get twoFactorRecoveryCode =>
      (WebSafeBrowser.readLocalStorage(_twoFactorRecoveryCodeKey) ?? '').toString().trim();

    static String get _twoFactorPendingRecoveryCode =>
      (WebSafeBrowser.readLocalStorage(_twoFactorPendingRecoveryCodeKey) ?? '').toString().trim();

  static String get twoFactorOtpauthUri {
    final secret = twoFactorSecret;
    if (secret.isEmpty) {
      return '';
    }

    return _buildOtpAuthUri(secret);
  }

  static String _buildOtpAuthUri(String secret) {
    if (secret.isEmpty) {
      return '';
    }

    final label = Uri.encodeComponent('$_totpIssuer:$_totpAccountName');
    final issuer = Uri.encodeComponent(_totpIssuer);
    return 'otpauth://totp/$label?secret=$secret&issuer=$issuer&period=30&digits=6&algorithm=SHA1';
  }

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

  static TwoFactorSetupData initializeTwoFactorSetup() {
    if (isTwoFactorEnabled) {
      final activeSecret = twoFactorSecret;
      final activeRecovery = twoFactorRecoveryCode;
      return TwoFactorSetupData(
        secret: activeSecret,
        otpauthUri: _buildOtpAuthUri(activeSecret),
        recoveryCode: activeRecovery,
      );
    }

    final pendingSecret = _twoFactorPendingSecret.isNotEmpty ? _twoFactorPendingSecret : _generateSecret();
    WebSafeBrowser.writeLocalStorage(_twoFactorPendingSecretKey, pendingSecret);

    final pendingRecoveryCode = _twoFactorPendingRecoveryCode.isNotEmpty
        ? _twoFactorPendingRecoveryCode
        : _generateRecoveryCode();
    WebSafeBrowser.writeLocalStorage(_twoFactorPendingRecoveryCodeKey, pendingRecoveryCode);

    return TwoFactorSetupData(
      secret: pendingSecret,
      otpauthUri: _buildOtpAuthUri(pendingSecret),
      recoveryCode: pendingRecoveryCode,
    );
  }

  static bool verifyTwoFactorSetupCode(String input) {
    final normalized = input.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
      return false;
    }

    final secret = _twoFactorPendingSecret;
    if (secret.isEmpty) {
      return false;
    }

    final currentTimeSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final timeStep = currentTimeSeconds ~/ 30;
    for (var offset = -1; offset <= 1; offset++) {
      final expected = _generateTotpCode(secret, timeStep + offset);
      if (expected == normalized) {
        return true;
      }
    }

    return false;
  }

  static void completeTwoFactorSetup() {
    final pendingSecret = _twoFactorPendingSecret;
    if (pendingSecret.isEmpty) {
      return;
    }

    final pendingRecovery = _twoFactorPendingRecoveryCode.isNotEmpty
        ? _twoFactorPendingRecoveryCode
        : _generateRecoveryCode();

    WebSafeBrowser.writeLocalStorage(_twoFactorSecretKey, pendingSecret);
    WebSafeBrowser.writeLocalStorage(_twoFactorRecoveryCodeKey, pendingRecovery);
    WebSafeBrowser.writeLocalStorage(_twoFactorStatusKey, 'ACTIVE');
    WebSafeBrowser.writeLocalStorage(_twoFactorSessionVerifiedKey, '1');

    WebSafeBrowser.removeLocalStorage(_twoFactorPendingSecretKey);
    WebSafeBrowser.removeLocalStorage(_twoFactorPendingRecoveryCodeKey);
  }

  static bool verifyTwoFactorCode(String input) {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final recoveryCode = twoFactorRecoveryCode;

    if (recoveryCode.isNotEmpty && normalized.toUpperCase() == recoveryCode.toUpperCase()) {
      // Recovery codes are single-use by design.
      WebSafeBrowser.removeLocalStorage(_twoFactorRecoveryCodeKey);
      WebSafeBrowser.writeLocalStorage(_twoFactorSessionVerifiedKey, '1');
      return true;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
      return false;
    }

    final secret = twoFactorSecret;
    if (secret.isEmpty) {
      return false;
    }

    final currentTimeSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final timeStep = currentTimeSeconds ~/ 30;
    for (var offset = -1; offset <= 1; offset++) {
      final expected = _generateTotpCode(secret, timeStep + offset);
      if (expected == normalized) {
        WebSafeBrowser.writeLocalStorage(_twoFactorStatusKey, 'ACTIVE');
        WebSafeBrowser.writeLocalStorage(_twoFactorSessionVerifiedKey, '1');
        return true;
      }
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

  static String _generateSecret() {
    final rng = Random.secure();
    final bytes = List<int>.generate(20, (_) => rng.nextInt(256));
    return _base32Encode(bytes);
  }

  static String _generateTotpCode(String secret, int counter) {
    final keyBytes = _base32Decode(secret);
    final counterBytes = List<int>.filled(8, 0);
    var value = counter;
    for (var i = 7; i >= 0; i--) {
      counterBytes[i] = value & 0xff;
      value >>= 8;
    }

    final digest = Hmac(sha1, keyBytes).convert(counterBytes).bytes;
    final offset = digest.last & 0x0f;
    final binary = ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);
    final otp = binary % 1000000;
    return otp.toString().padLeft(6, '0');
  }

  static String _base32Encode(List<int> input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final output = StringBuffer();
    var buffer = 0;
    var bitsLeft = 0;

    for (final byte in input) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;
      while (bitsLeft >= 5) {
        final index = (buffer >> (bitsLeft - 5)) & 31;
        bitsLeft -= 5;
        output.write(alphabet[index]);
      }
    }

    if (bitsLeft > 0) {
      final index = (buffer << (5 - bitsLeft)) & 31;
      output.write(alphabet[index]);
    }

    return output.toString();
  }

  static List<int> _base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final normalized = input.replaceAll('=', '').replaceAll(' ', '').toUpperCase();
    var buffer = 0;
    var bitsLeft = 0;
    final output = <int>[];

    for (final rune in normalized.runes) {
      final char = String.fromCharCode(rune);
      final index = alphabet.indexOf(char);
      if (index < 0) {
        continue;
      }
      buffer = (buffer << 5) | index;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        output.add((buffer >> (bitsLeft - 8)) & 0xff);
        bitsLeft -= 8;
      }
    }

    return output;
  }

  static String _generateRecoveryCode() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final raw = now.toRadixString(36).toUpperCase();
    final padded = raw.length >= 10 ? raw.substring(raw.length - 10) : raw.padLeft(10, '0');
    return 'REC-$padded';
  }
}
