import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreference {
  ThemePreference._();

  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static const _key = 'interior_theme_mode';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = switch (prefs.getString(_key)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static Future<void> set(ThemeMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
    mode.value = value;
  }
}
