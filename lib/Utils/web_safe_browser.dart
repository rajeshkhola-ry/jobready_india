import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class WebSafeBrowser {
  static bool get isAvailable => kIsWeb;

  static String? readLocalStorage(String key) {
    if (!isAvailable) {
      return null;
    }

    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  static void writeLocalStorage(String key, String value) {
    if (!isAvailable) {
      return;
    }

    try {
      html.window.localStorage[key] = value;
    } catch (_) {
      // Ignore browser storage failures in non-web or test environments.
    }
  }

  static void removeLocalStorage(String key) {
    if (!isAvailable) {
      return;
    }

    try {
      html.window.localStorage.remove(key);
    } catch (_) {
      // Ignore browser storage failures in non-web or test environments.
    }
  }

  static String get navigatorLanguage {
    if (!isAvailable) {
      return '';
    }

    try {
      return html.window.navigator.language ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get navigatorPlatform {
    if (!isAvailable) {
      return '';
    }

    try {
      return html.window.navigator.platform ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get navigatorUserAgent {
    if (!isAvailable) {
      return '';
    }

    try {
      return html.window.navigator.userAgent ?? '';
    } catch (_) {
      return '';
    }
  }

  static (int width, int height) get screenSize {
    if (!isAvailable) {
      return (0, 0);
    }

    try {
      final screen = html.window.screen;
      return ((screen?.width ?? 0), (screen?.height ?? 0));
    } catch (_) {
      return (0, 0);
    }
  }

  static void openWindow(String url, {String target = '_blank'}) {
    if (!isAvailable) {
      return;
    }

    try {
      html.window.open(url, target);
    } catch (_) {
      // Ignore browser window failures in non-web or test environments.
    }
  }
}
