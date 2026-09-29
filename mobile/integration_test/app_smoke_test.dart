import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SmokeApi extends ApiClient {
  _SmokeApi() : super(baseUrl: 'https://invalid.test');

  @override
  Future<List<Map<String, dynamic>>> listWorkspaces() async =>
      throw StateError('Legacy schema');

  @override
  Future<SearchItemsResult> searchItems({required String query}) async {
    final item = InventoryItem.fromJson({
      'item_id': 'screw-1',
      'name': 'M4 screw',
      'category': 'Supplies',
      'quantity': 12,
      'location': 'Workshop',
      'created_at': '2026-09-27T12:00:00Z',
    });
    return SearchItemsResult(
      items:
          query.isEmpty || item.name.toLowerCase().contains(query.toLowerCase())
          ? [item]
          : const [],
      parsed: const {},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => [
    {'id': 'workshop', 'name': 'Workshop'},
  ];

  @override
  Future<List<Map<String, dynamic>>> getActiveCheckouts() async => const [];

  @override
  Future<List<ProjectKitSummary>> getProjectKits({
    String? location,
    String? shareId,
  }) async => const [];

  @override
  Future<Map<String, dynamic>> getNotifications() async => {
    'unread_count': 0,
    'notifications': <Map<String, dynamic>>[],
  };

  @override
  Future<Map<String, dynamic>> getMyProfile() async => {
    'display_name': 'Test user',
    'email': 'test@example.invalid',
  };

  @override
  Future<List<dynamic>> getMyShares() async => const [];

  @override
  Future<List<dynamic>> getJoinedShares() async => const [];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('Home, Places search, More, and Ask stay navigable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainShell(api: _SmokeApi(), enablePushNotifications: false),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(find.text('Recent photos'), findsNothing);
    expect(find.text('Workshop'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Places'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Search objects'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search objects'),
      'M4',
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('M4 screw'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'More'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Inventory'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Ask'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Find objects, places, or project supplies.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
