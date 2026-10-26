// Simulator-only visual review. No production credentials or server writes.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/onboarding/chat_onboarding_page.dart';

Future<void> main() async {
  if (!kDebugMode) throw StateError('Visual review requires a debug build');
  WidgetsFlutterBinding.ensureInitialized();
  // Isolate the preview from installation preferences and saved accounts.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://onboarding.invalid',
    publishableKey: 'visual-review-only',
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatOnboardingPage(
        api: ApiClient(baseUrl: 'https://onboarding.invalid'),
      ),
    ),
  );
}
