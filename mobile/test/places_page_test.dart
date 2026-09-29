import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/inventory/inventory_page.dart';

class _PlacesApi extends ApiClient {
  _PlacesApi() : super(baseUrl: 'https://invalid.test');

  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(
        items: [
          InventoryItem(
            itemId: 'owned-one',
            name: 'Cordless drill',
            category: 'Tools',
            quantity: 1,
            location: 'Workshop',
            spaceId: 'workshop',
            createdAt: DateTime(2026),
          ),
          InventoryItem(
            itemId: 'owned-two',
            name: 'Hex bolts',
            category: 'Hardware',
            quantity: 20,
            location: 'Garage',
            spaceId: 'garage',
            createdAt: DateTime(2026),
          ),
        ],
        parsed: const {},
      );

  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => const [
    {'id': 'garage', 'name': 'Garage'},
    {'id': 'workshop', 'name': 'Workshop'},
  ];

  @override
  Future<List<dynamic>> getMyShares() async => const [
    {'share_id': 'owned-share', 'share_name': 'Workshop'},
  ];

  @override
  Future<List<dynamic>> getJoinedShares() async => const [
    {
      'share_id': 'joined-share',
      'team_shares': {
        'share_id': 'joined-share',
        'share_name': 'Robotics room',
        'permission': 'view',
      },
    },
  ];

  @override
  Future<List<dynamic>> getShareInventory(String shareId) async => const [
    {
      'item_id': 'joined-one',
      'name': 'Shared motor',
      'category': 'Robot Parts',
      'quantity': 2,
      'location': 'Robotics room',
    },
  ];
}

void main() {
  testWidgets('Places combines owned, shared, and joined inventories', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: InventoryPage(
          api: _PlacesApi(),
          refreshToken: 0,
          workspaceName: 'My inventory',
          showAppBar: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Places'), findsOneWidget);
    expect(find.text('3 places / 3 objects'), findsOneWidget);
    expect(find.text('My inventory'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('Shared by you'), findsOneWidget);
    expect(find.text('Shared by you, 1 kind'), findsNothing);
    expect(find.text('Shared with you'), findsOneWidget);
    expect(find.text('Robotics room'), findsOneWidget);
    expect(find.text('Join a shared place'), findsOneWidget);
    expect(find.text('Find'), findsNothing);
  });
}
