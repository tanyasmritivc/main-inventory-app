// Debug-only launch of the real app with the dedicated App Review account.
// Credentials come from a private defines file; never use this as a release target.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/config.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';
import 'package:mobile/main.dart' as app;

Future<void> main() async {
  if (!kDebugMode) throw StateError('Review harness requires debug mode');
  const email = String.fromEnvironment('QA_REVIEW_EMAIL');
  const password = String.fromEnvironment('QA_REVIEW_PASSWORD');
  if (!email.toLowerCase().contains('review') || password.isEmpty) {
    throw StateError('A dedicated review account is required');
  }
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  await Supabase.instance.client.auth.signInWithPassword(
    email: email,
    password: password,
  );
  await OnboardingPrefs.setCompleted(true);
  await app.main();
}
