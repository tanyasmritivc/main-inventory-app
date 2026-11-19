// Synthetic accounts and responses only; no customer inventory writes.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/background_http.dart';
import 'context_chat_test.dart' as chat;
import '../test/space_chat_api_test.dart' as scope;
import '../test/chat_answer_format_test.dart' as formatting;

Future<void> resetClient() async {
  try {
    final client = Supabase.instance;
    if (client.isInitialized) await client.dispose();
  } on AssertionError {
    // No client was initialized by the previous suite.
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Organization Space routing', () {
    // Route iOS requests through the zone-scoped HTTP fixture in these tests.
    setUp(() => debugAssistantHttpClientFactory = http.Client.new);
    tearDown(() => debugAssistantHttpClientFactory = null);
    setUpAll(resetClient);
    tearDownAll(resetClient);
    scope.main();
  });
  group('Native contextual chat', () {
    setUpAll(resetClient);
    tearDownAll(resetClient);
    chat.main();
  });
  group('Native answer formatting', formatting.main);
}
