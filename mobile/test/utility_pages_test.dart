import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/chat_context_picker.dart';
import 'package:mobile/features/chat/assistant_connections_page.dart';
import 'package:mobile/features/notifications/notifications_page.dart';
import 'package:mobile/features/profile/memory_page.dart';
import 'package:mobile/features/scan/connector_destination_page.dart';
import 'memory_controller_test.dart' show MemoryApi;

class UtilityApi extends ApiClient {
  UtilityApi() : super(worldKey: 'personal', baseUrl: 'https://api.test');
  @override
  String get accountId => 'fixture';
  @override
  void assertCurrentContext() {}
  @override
  Future<Map<String, dynamic>> collaboration(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async => path == '/inventory-workspaces'
      ? {
          'workspaces': [
            {'workspace_id': 'personal', 'name': 'Personal'},
          ],
        }
      : {
          'inventories': [
            for (final name in [
              'My Items',
              'My Personal Inventory',
              'Garage',
              'Workshop',
            ])
              {
                'inventory_id': name,
                'name': name,
                'workspace_name': 'Personal',
                'can_edit': true,
              },
          ],
        };
  @override
  Future<Map<String, dynamic>> chatSourceChoices({
    required String inventoryId,
    required String kind,
    String query = '',
    int offset = 0,
  }) async => {
    'sources': kind == 'document' || kind == 'project'
        ? []
        : [
            for (final name
                in kind == 'space'
                    ? ['Workshop']
                    : ['Hex keys', 'M3 screws', 'Nuts', 'Washers'])
              if (name.toLowerCase().contains(query.toLowerCase()))
                {
                  'kind': kind,
                  'name': name,
                  'inventory_id': inventoryId,
                  'inventory_name': 'Garage',
                  'resource_id': name,
                },
          ],
  };
  @override
  Future<Map<String, dynamic>> getNotifications() async => {
    'unread_count': 1,
    'notifications': [
      {
        'display_text': 'You created the task: download FindEZ version 1.1.1',
        'action': 'task_created',
        'team_name': 'FTC Season 2026-2027 Workspace',
        'is_read': false,
      },
      {
        'display_text': 'A teammate completed the stock check',
        'action': 'task_completed',
        'team_name': 'Workshop',
        'is_read': true,
      },
      {
        'display_text':
            'You uploaded Fastener and Mechanical Parts Database.xlsx',
        'action': 'file_uploaded',
        'team_name': 'FTC Season 2026-2027 Workspace',
        'is_read': true,
      },
    ],
  };
}

void main() {
  const visual = bool.fromEnvironment('FINDEZ_VISUAL_QA');
  setUpAll(() async {
    if (!visual) return;
    await (FontLoader(
      'PlusJakartaSans',
    )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });

  Widget frame(
    Widget page,
    Brightness brightness,
    double scale,
    GlobalKey key,
  ) => MaterialApp(
    theme: AppTheme.create(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: RepaintBoundary(key: key, child: page),
  );
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0, 3.2]) {
      testWidgets(
        '${brightness.name} utility pages remain reachable at $scale text',
        (tester) async {
          tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final pages = <String, Widget>{
            'notifications': NotificationsPage(api: UtilityApi()),
            'inventories': ConnectorDestinationPage(api: UtilityApi()),
            'connections': AssistantConnectionsPage(api: UtilityApi()),
            'items': ChatContextPicker(
              api: UtilityApi(),
              kind: 'item',
              selected: const [],
            ),
            'spaces': ChatContextPicker(
              api: UtilityApi(),
              kind: 'space',
              selected: const [],
            ),
            'documents': ChatContextPicker(
              api: UtilityApi(),
              kind: 'document',
              selected: const [],
            ),
            'projects': ChatContextPicker(
              api: UtilityApi(),
              kind: 'project',
              selected: const [],
            ),
            'memory': MemoryPage(api: MemoryApi()..record['enabled'] = true),
          };
          for (final entry in pages.entries) {
            final key = GlobalKey();
            await tester.pumpWidget(frame(entry.value, brightness, scale, key));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: entry.key);
            if (visual && scale == 1) {
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 2);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '/private/tmp/findez-utility-${brightness.name}-${entry.key}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            if (entry.key == 'items') {
              await tester.scrollUntilVisible(
                find.text('Washers'),
                180,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.tap(find.text('Washers'));
              await tester.pumpAndSettle();
              expect(
                find.text(scale > 1.5 ? 'Done' : 'Done (1)'),
                findsOneWidget,
              );
              await tester.scrollUntilVisible(
                find.byType(TextField),
                -180,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.enterText(find.byType(TextField), 'zzzz');
              await tester.pumpAndSettle(const Duration(milliseconds: 300));
              expect(find.text('No matches'), findsOneWidget);
              expect(
                find.text(scale > 1.5 ? 'Done' : 'Done (1)'),
                findsOneWidget,
              );
            }
            if (entry.key == 'memory') {
              await tester.scrollUntilVisible(
                find.text('Export memory'),
                180,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('Export memory'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Export memory'));
              await tester.pumpAndSettle();
              expect(find.text('Copy JSON'), findsOneWidget);
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key} after interaction',
            );
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );
    }
  }
}
