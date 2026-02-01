import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPrefs {
  static const _kCompleted = 'onboarding_completed';
  static const _kPersona = 'onboarding_persona';

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCompleted) ?? false;
  }

  static Future<void> setCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCompleted, value);
  }

  static Future<String?> getPersona() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPersona);
  }

  static Future<void> setPersona(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_kPersona);
      return;
    }
    await prefs.setString(_kPersona, value.trim());
  }
}
