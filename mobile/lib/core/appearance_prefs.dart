import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearancePrefs {
  static const _key = 'appearance_mode';
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = switch (prefs.getString(_key)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  static Future<void> setMode(ThemeMode value) async {
    mode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark',
    });
  }
}
