// Network-free native QA entry point. Never imported by production main.dart.
// Uses the real picker, photo flow and Confirm Items, with a delayed API fixture.
import 'package:flutter/material.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import '../test/support/hierarchy_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  await fixture.initialize(mockPreferences: false);
  fixture.respond = (request) async {
    if (request.path.endsWith('/extract_from_image')) {
      await Future<void>.delayed(const Duration(seconds: 30));
      return {
        'items': [
          {'name': 'QA fixture charger', 'category': 'Tools', 'quantity': 1},
          {'name': 'QA fixture battery', 'category': 'Tools', 'quantity': 1},
        ],
        'summary': {
          'total_detected': 2,
          'categories': {'Tools': 2},
        },
      };
    }
    return {'unread_count': 0, 'notifications': <Object>[]};
  };
  final api = ApiClient.forInventory(
    fixture.api,
    InventoryContext.fromJson(
      inventory('pip-qa'),
      accountId: 'actor-a',
      expectedInventory: 'pip-qa',
    ),
    isCurrent: () => true,
  );
  runApp(
    MaterialApp(
      theme: AppTheme.create(Brightness.light),
      darkTheme: AppTheme.create(Brightness.dark),
      home: LocationItemsPage(
        api: api,
        location: 'Pip QA • fixture response',
        spaceId: 'pip-space',
        items: const [],
        thresholds: const {},
        allItems: const [],
      ),
    ),
  );
}
