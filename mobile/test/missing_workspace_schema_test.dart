import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/home/home_dashboard.dart';
import 'package:mobile/features/inventory/item_detail_sheet.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LegacyApi extends ApiClient {
  _LegacyApi() : super(baseUrl: 'https://invalid.test');

  @override
  Future<List<Map<String, dynamic>>> listWorkspaces() async =>
      throw StateError('workspaces table does not exist');

  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(items: const [], parsed: const {});

  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => const [];

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
}

class _LegacyInventoryApi extends _LegacyApi {
  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(
        items: [
          InventoryItem.fromJson({
            'item_id': 'one',
            'name': 'Unknown item',
            'category': 'Tools',
            'quantity': 2,
            'location': 'Workshop',
            'created_at': '2026-09-27T12:00:00Z',
          }),
        ],
        parsed: const {},
      );
}

class _LegacyItemApi extends _LegacyApi {
  final item = InventoryItem.fromJson({
    'item_id': 'one',
    'name': 'Clamp',
    'category': 'Tools',
    'quantity': 2,
    'location': 'Workshop',
    'workspace_name': 'Your inventory',
    'space_name': 'Workshop',
  });

  @override
  Future<InventoryItem> itemDetail(String itemId) async =>
      throw StateError('item detail route does not exist');

  @override
  Future<List<Map<String, dynamic>>> itemHistory(String itemId) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> itemRelationships(String itemId) async =>
      throw StateError('item_relationships table does not exist');

  @override
  Future<List<DocumentEntry>> getDocuments({String? itemId}) async => const [];

  @override
  Future<List<Map<String, dynamic>>> getItemCheckouts({
    required String itemId,
  }) async => const [];
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  test('missing identity and reorder fields use honest fallbacks', () {
    final item = InventoryItem.fromJson({
      'item_id': 'one',
      'name': 'Unknown item',
      'category': 'Tools',
      'quantity': 2,
      'location': 'Workshop',
      'workspace_name': 'Your inventory',
      'space_name': 'Workshop',
    });

    expect(item.needsIdentifying, isTrue);
    expect(item.identityConfirmationAvailable, isFalse);
    expect(item.reorderPointAvailable, isFalse);
    expect(item.reorderPoint, isNull);
    expect(inventoryPath(item), 'Your inventory / Workshop');
  });

  testWidgets('missing workspaces still opens the five-tab interior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MainShell(api: _LegacyApi()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Workspace could not load'), findsNothing);
    expect(find.text('Your inventory'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Ask'), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Places'), findsOneWidget);
    expect(find.text('Find'), findsNothing);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Choose a workspace'), findsNothing);
  });

  testWidgets('Home uses derived review and omits unavailable low stock', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeDashboard(
            api: _LegacyInventoryApi(),
            workspaceName: 'Your inventory',
            workspaceAvailable: false,
            refreshToken: 0,
            onAsk: () {},
            onDecision: (_) {},
            onPlace: (_, _, _, _) {},
            onAllPlaces: () {},
            onWorkspace: () {},
            onCapture: () {},
            onImport: () {},
            onWorkspaces: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('need identifying'), findsOneWidget);
    expect(find.text('running low'), findsNothing);
    expect(find.text('Choose a workspace'), findsNothing);
  });

  testWidgets('object opens from list data when detail routes are missing', (
    tester,
  ) async {
    final api = _LegacyItemApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () =>
                  showItemDetailSheet(context, item: api.item, api: api),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Your inventory / Workshop'), findsOneWidget);
    expect(find.text('Clamp'), findsWidgets);
    expect(find.text('Could not load this object.'), findsNothing);
    expect(find.text('Connects to'), findsNothing);
    expect(find.text('Reorder at'), findsNothing);
  });
}
