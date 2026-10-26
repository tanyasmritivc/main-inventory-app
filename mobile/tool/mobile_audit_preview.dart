// Network-free UI inspection. Never imported by the production application.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/appearance_controller.dart';
import 'package:mobile/features/review/review_queue_page.dart';
import 'package:mobile/features/notifications/notifications_page.dart';
import 'package:mobile/features/profile/memory_page.dart';
import 'package:mobile/features/chat/chat_context_picker.dart';
import 'package:mobile/features/chat/assistant_connections_page.dart';
import '../test/utility_pages_test.dart' show UtilityApi;
import '../test/memory_controller_test.dart' show MemoryApi;
import '../test/support/hierarchy_fixture.dart';

Future<void> main() async {
  if (kReleaseMode) throw UnsupportedError('Debug audit only');
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  await fixture.initialize();
  fixture.respond = (request) {
    if (request.path.endsWith('/profile/me')) {
      return {'display_name': 'Alex Example'};
    }
    if (request.path.endsWith('/review-items')) {
      return {
        'pending_count': 1,
        'items': [
          {
            'review_id': 'capture',
            'name': 'Sample item',
            'category': 'Tools',
            'location': 'Workshop',
            'quantity': 2,
            'status': 'pending',
          },
        ],
      };
    }
    return {'notifications': [], 'unread_count': 0};
  };
  final appearance = AppearanceController();
  await appearance.load();
  runApp(
    AnimatedBuilder(
      animation: appearance,
      builder: (_, _) => AppearanceScope(
        controller: appearance,
        child: MaterialApp(
          theme: AppTheme.create(Brightness.light),
          darkTheme: AppTheme.create(Brightness.dark),
          themeMode: appearance.themeMode,
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Synthetic mobile audit')),
              body: ListView(
                children: [
                  TextButton(
                    onPressed: () => appearance.setThemeMode(
                      appearance.themeMode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark,
                    ),
                    child: const Text('Toggle light / dark'),
                  ),
                  for (final entry in <String, Widget Function()>{
                    'Review': () =>
                        ReviewQueuePage(api: fixture.api, location: 'Workshop'),
                    'Notifications': () => NotificationsPage(api: UtilityApi()),
                    'Connections': () =>
                        AssistantConnectionsPage(api: UtilityApi()),
                    'Memory': () => MemoryPage(api: MemoryApi()),
                    for (final kind in ['item', 'space', 'document', 'project'])
                      kind: () => ChatContextPicker(
                        api: UtilityApi(),
                        kind: kind,
                        selected: const [],
                      ),
                  }.entries)
                    ListTile(
                      title: Text(entry.key),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => entry.value())),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
