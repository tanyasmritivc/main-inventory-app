import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/main.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('renders the FindEZ splash screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('FindEZ AI'), findsOneWidget);
    expect(find.text('Organize everything instantly'), findsOneWidget);
  });
}
