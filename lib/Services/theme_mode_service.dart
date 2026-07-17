import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeService {
  static const String _themeModeKey = 'jobready_theme_mode';

  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDarkMode => themeMode.value == ThemeMode.dark;

  static Future<void> loadSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeModeKey);

    if (savedMode == 'dark') {
      themeMode.value = ThemeMode.dark;
      return;
    }

    themeMode.value = ThemeMode.light;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeModeKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  static void toggle() {
    final nextMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(nextMode);
  }
}
