import 'package:flutter/foundation.dart';

class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static void validate({bool release = kReleaseMode}) {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
      if (release && apiBaseUrl == 'http://10.0.2.2:8000') 'API_BASE_URL',
    ];
    if (missing.isNotEmpty) {
      throw StateError(
        'Missing build configuration: ${missing.join(', ')}. '
        'Run Flutter with --dart-define-from-file=.env.',
      );
    }
    final authUri = Uri.tryParse(supabaseUrl);
    final apiUri = Uri.tryParse(apiBaseUrl);
    if (release &&
        (authUri?.scheme != 'https' ||
            authUri?.host.isEmpty != false ||
            apiUri?.scheme != 'https' ||
            apiUri?.host.isEmpty != false)) {
      throw StateError('Release endpoints must use HTTPS.');
    }
  }
}
