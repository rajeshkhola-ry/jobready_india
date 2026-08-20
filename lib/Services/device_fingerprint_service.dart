import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:universal_html/html.dart' as html;

import '../Utils/web_safe_browser.dart';
import 'owner_admin_access_service.dart';
import 'plan_catalog_service.dart';
import 'user_account_service.dart';

/// Enforces the "3 lifetime free files, no login required" device policy,
/// replacing the old desktop+mobile device-slot binding, the old daily free
/// quota, and the old one-time-per-account free trial. A "device" is
/// identified by a lightweight browser fingerprint (screen metrics, hardware
/// concurrency, canvas + WebGL renderer signature) hashed with the count
/// stored in localStorage under an obfuscated key.
///
/// Honesty/disclosure (same tier as every other quota in this app - voice,
/// OCR, daily usage, the old device binding - none of them are tamper-proof):
/// this is SOFT, client-side-only enforcement. A technically determined user
/// can always inspect/clear their own browser storage. Real, unbypassable
/// enforcement can only ever live server-side against a real account. Two
/// specific, disclosed limits of the fingerprint approach:
///  - It CANNOT survive a genuine incognito/private window: private
///    browsing uses an isolated storage partition by browser design, wiped
///    when the session ends - no client-only technique can defeat that.
///  - It DOES survive hard refreshes/reloads and normal repeat visits in the
///    SAME browser profile, and raises the bar (vs. a plain counter) against
///    a casual user directly editing the raw localStorage value, since the
///    stored blob only decodes correctly when re-derived from this same
///    device's fingerprint.
class DeviceFingerprintService {
  static const int lifetimeFreeFileLimit = 3;
  static const String _storageKey = 'jobready_device_ff_v1';
  static const String _appSalt = 'GETREADYJOB-DEVICE-FP-2026';

  static bool get _isAdmin => OwnerAdminAccessService.isUnlocked;

  static bool get _isPaidPlan {
    final profile = UserAccountService.getProfile();
    final plan = profile.activePlan.trim().isEmpty ? 'Free' : profile.activePlan.trim();
    return PlanCatalogConfig.isPaidPlan(plan);
  }

  /// Combines several weak, individually-spoofable browser signals into one
  /// signature. Every signal is read defensively (each wrapped in its own
  /// try/catch) so a browser missing/blocking any single API (e.g. WebGL
  /// debug info, increasingly masked by privacy-hardened browsers) still
  /// yields a usable, if slightly less unique, fingerprint rather than
  /// failing outright.
  static String computeFingerprint() {
    final buffer = StringBuffer();
    try {
      final screen = html.window.screen;
      buffer.write('${screen?.width ?? 0}x${screen?.height ?? 0}x${screen?.pixelDepth ?? 0}');
    } catch (_) {
      // Ignore: screen metrics unavailable in this environment.
    }
    try {
      buffer.write('|dpr:${html.window.devicePixelRatio}');
    } catch (_) {
      // Ignore: devicePixelRatio unavailable in this environment.
    }
    try {
      buffer.write('|hc:${html.window.navigator.hardwareConcurrency ?? 0}');
    } catch (_) {
      // Ignore: hardwareConcurrency unavailable in this environment.
    }
    try {
      buffer.write('|tz:${DateTime.now().timeZoneOffset.inMinutes}');
    } catch (_) {
      // Ignore: timezone read failed.
    }
    try {
      buffer.write('|canvas:${_canvasSignature()}');
    } catch (_) {
      // Ignore: canvas fingerprinting unavailable/blocked in this browser.
    }
    try {
      buffer.write('|webgl:${_webglRendererSignature()}');
    } catch (_) {
      // Ignore: WebGL unavailable/masked in this browser.
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  static String _canvasSignature() {
    final canvas = html.CanvasElement(width: 220, height: 40);
    final ctx = canvas.context2D;
    ctx.textBaseline = 'top';
    ctx.font = '14px Arial';
    ctx.fillStyle = '#f60';
    ctx.fillRect(0, 0, 60, 20);
    ctx.fillStyle = '#069';
    ctx.fillText('JobReady-fp', 2, 2);
    ctx.fillStyle = 'rgba(102, 204, 0, 0.7)';
    ctx.fillText('JobReady-fp', 4, 4);
    final dataUrl = canvas.toDataUrl();
    return dataUrl.length > 96 ? dataUrl.substring(dataUrl.length - 96) : dataUrl;
  }

  static String _webglRendererSignature() {
    final canvas = html.CanvasElement(width: 1, height: 1);
    final dynamic gl = canvas.getContext('webgl') ?? canvas.getContext('experimental-webgl');
    if (gl == null) {
      return '';
    }
    const unmaskedRendererWebgl = 0x9246;
    const glRenderer = 0x1F01;
    final dynamic debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
    final dynamic renderer = gl.getParameter(debugInfo != null ? unmaskedRendererWebgl : glRenderer);
    return renderer?.toString() ?? '';
  }

  static List<int> _keyStreamFor(String fingerprint) {
    return sha256.convert(utf8.encode('$fingerprint::$_appSalt')).bytes;
  }

  static String _encode(Map<String, dynamic> record, String fingerprint) {
    final plain = utf8.encode(jsonEncode(record));
    final key = _keyStreamFor(fingerprint);
    final xored = List<int>.generate(plain.length, (i) => plain[i] ^ key[i % key.length]);
    return base64Url.encode(xored);
  }

  static Map<String, dynamic>? _decode(String encoded, String fingerprint) {
    try {
      final xored = base64Url.decode(encoded);
      final key = _keyStreamFor(fingerprint);
      final plain = List<int>.generate(xored.length, (i) => xored[i] ^ key[i % key.length]);
      final decoded = jsonDecode(utf8.decode(plain));
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Malformed/foreign blob (edited by hand, or a genuinely different
      // device's fingerprint) - fail open to a fresh record, same as every
      // other soft quota store in this app.
    }
    return null;
  }

  static int _readFilesUsed() {
    final raw = WebSafeBrowser.readLocalStorage(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return 0;
    }
    final record = _decode(raw, computeFingerprint());
    if (record == null) {
      return 0;
    }
    return (record['used'] as num?)?.toInt() ?? 0;
  }

  static void _writeFilesUsed(int used) {
    final fingerprint = computeFingerprint();
    WebSafeBrowser.writeLocalStorage(_storageKey, _encode({'used': used, 'v': 1}, fingerprint));
  }

  /// Number of lifetime free files already consumed on this device. Always 0
  /// for admin/paid sessions (they never draw from this pool).
  static int get filesUsed {
    if (_isAdmin || _isPaidPlan) {
      return 0;
    }
    return _readFilesUsed();
  }

  static int get filesRemaining {
    final remaining = lifetimeFreeFileLimit - filesUsed;
    return remaining < 0 ? 0 : remaining;
  }

  static bool get hasFreeFilesRemaining {
    if (_isAdmin || _isPaidPlan) {
      return true;
    }
    return filesRemaining > 0;
  }

  /// Call this ONLY after a successful download/export - never at gate-check
  /// time - so a failed conversion never costs the user one of their 3
  /// credits. Safe to call unconditionally from any download path: it is a
  /// no-op for admin/paid sessions, which never draw from this pool.
  static void recordFileConsumed() {
    if (_isAdmin || _isPaidPlan) {
      return;
    }
    _writeFilesUsed(_readFilesUsed() + 1);
  }
}
