// Network-free native preview. This entry point is not used by lib/main.dart.
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import '../test/support/hierarchy_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  await fixture.initialize(mockPreferences: false);
  fixture.respond = (_) => {'unread_count': 0, 'notifications': <Object>[]};
  final api = ApiClient.forInventory(
    fixture.api,
    InventoryContext.fromJson(
      inventory('capture-preview'),
      accountId: 'actor-a',
      expectedInventory: 'capture-preview',
    ),
    isCurrent: () => true,
  );
  runApp(
    MaterialApp(
      theme: AppTheme.create(Brightness.light),
      home: LocationItemsPage(
        api: api,
        location: 'Garage',
        spaceId: 'garage-preview',
        items: const [],
        thresholds: const {},
        allItems: const [],
      ),
    ),
  );
}
