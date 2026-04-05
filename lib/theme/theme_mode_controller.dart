import 'package:flutter/material.dart';

import '../utils/session_manager.dart';

class AppThemeController {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static Future<void> load() async {
    final savedMode = await SessionManager.getThemeMode();
    themeMode.value = savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setMode(ThemeMode mode) async {
    themeMode.value = mode;
    await SessionManager.saveThemeMode(
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  static bool get isDarkMode => themeMode.value == ThemeMode.dark;
}
