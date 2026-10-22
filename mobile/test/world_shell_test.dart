import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/place_session.dart';
import 'package:mobile/features/world/world_shell.dart';
import 'package:mobile/features/world/world_action_card.dart';
import 'package:mobile/features/world/world_composer.dart';
import 'package:mobile/features/workspaces/organization_pill.dart';
import 'support/hierarchy_fixture.dart';

Future<void> Function(String)? worldAuditCapture;

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    fixture.status = 200;
    fixture.requests.clear();
    fixture.respond = (request) {
      if (request.path.endsWith('/profile/me')) {
        return {'user_id': 'actor-a', 'display_name': 'Alex'};
      }
      if (request.path.endsWith('/directory')) {
        return {'has_items': false, 'inventories': []};
      }
      if (request.path.endsWith('/spaces')) return {'inventories': []};
      return <String, dynamic>{};
    };
  });
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboard = 0,
    Brightness brightness = Brightness.light,
    bool bold = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = PlaceSession(fixture.api, 'actor-a')
      ..loading = false
      ..navigationReady = true;
    addTearDown(session.dispose);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('world-audit-frame'),
        child: MaterialApp(
          theme: AppTheme.create(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 44, bottom: 34),
              viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
              textScaler: TextScaler.linear(scale),
              boldText: bold,
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
          home: WorldShell(
            session: session,
            onOpenInventory: (_, _, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('Avatar exposes preferences directly $brightness', (
      tester,
    ) async {
      await mount(tester, brightness: brightness);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Theme'), findsNothing);
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(find.text('Theme').hitTestable(), findsOneWidget);
      expect(find.text('Text size').hitTestable(), findsOneWidget);
      expect(find.text('Notifications').hitTestable(), findsOneWidget);
      expect(find.text('Account and settings'), findsNothing);
      await worldAuditCapture?.call('avatar-${brightness.name}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('Ask retains light text with OS Bold Text $brightness', (
      tester,
    ) async {
      await mount(tester, brightness: brightness, bold: true);
      final heading = tester.widget<RichText>(
        find.descendant(
          of: find.text('Create your inventory world.'),
          matching: find.byType(RichText),
        ),
      );
      expect(heading.text.style?.fontWeight, FontWeight.w500);
      final hint = tester.widget<RichText>(
        find.descendant(
          of: find.text('Describe your inventory…'),
          matching: find.byType(RichText),
        ),
      );
      expect(hint.text.style?.fontWeight, FontWeight.w400);
      await tester.enterText(find.byType(TextField).first, 'My tools');
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .style
            .fontWeight,
        FontWeight.w400,
      );
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byType(WorldComposer)),
        ).scale(17),
        17,
      );
      expect(tester.takeException(), isNull);
      await worldAuditCapture?.call('typography-${brightness.name}');
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final brightness in Brightness.values) {
    for (final profile in [
      (const Size(390, 844), 1.0, 0.0),
      (const Size(320, 568), 1.0, 0.0),
      (const Size(390, 844), 2.0, 0.0),
      (const Size(390, 844), 1.0, 340.0),
      (const Size(1024, 768), 1.0, 0.0),
    ]) {
      testWidgets('Ask layout $brightness $profile', (tester) async {
        await mount(
          tester,
          size: profile.$1,
          scale: profile.$2,
          keyboard: profile.$3,
          brightness: brightness,
        );
        expect(find.text('Create your inventory world.'), findsOneWidget);
        expect(find.byType(WorldComposer), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.text('Dashboard'), findsNothing);
        if (profile.$1 == const Size(390, 844) &&
            profile.$2 == 1 &&
            profile.$3 == 0) {
          await worldAuditCapture?.call('ask-${brightness.name}');
        }
        await tester.ensureVisible(find.byTooltip('Capture or attach'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Capture or attach'));
        await tester.pumpAndSettle();
        for (final label in [
          'Auto Extract',
          'Take photo',
          'Choose photos',
          'Scan barcode',
          'Import spreadsheet',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.byType(BottomSheet), findsNothing);
        if (profile.$1 == const Size(390, 844) &&
            profile.$2 == 1 &&
            profile.$3 == 0) {
          await worldAuditCapture?.call('attachments-${brightness.name}');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Spaces is reachable and does not replace Ask with a dashboard', (
    tester,
  ) async {
    final fallback = fixture.respond;
    fixture.respond = (request) {
      if (request.path.endsWith('/spaces')) {
        return {
          'inventories': [
            {
              'name': 'Workshop tools',
              'workspace_name': 'Personal',
              'spaces': [
                {'name': 'Workbench', 'space_id': 'space-a'},
                {'name': 'Parts drawers', 'space_id': 'space-b'},
              ],
            },
          ],
        };
      }
      return fallback(request);
    };
    await mount(tester);
    await tester.tap(find.byTooltip('Spaces'));
    await tester.pumpAndSettle();
    expect(find.text('Search Spaces'), findsOneWidget);
    expect(find.text('Workbench'), findsOneWidget);
    expect(find.byType(OrganizationPill), findsNothing);
    expect(tester.getTopLeft(find.text('Spaces')).dy, lessThan(110));
    await worldAuditCapture?.call('spaces');
    await tester.enterText(find.byType(TextField).last, 'drawers');
    await tester.pumpAndSettle();
    expect(find.text('Workbench'), findsNothing);
    expect(find.text('Parts drawers'), findsOneWidget);
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Workspaces and team tools'), findsOneWidget);
    expect(find.byType(OrganizationPill), findsNothing);
    expect(tester.getTopLeft(find.text('More')).dy, lessThan(110));
    await worldAuditCapture?.call('more');
    await tester.tap(find.byTooltip('Ask'));
    await tester.pumpAndSettle();
    expect(find.text('Create your inventory world.'), findsOneWidget);
  });
  testWidgets('History search filters titles and opens the selected chat', (
    tester,
  ) async {
    final fallback = fixture.respond;
    fixture.respond = (request) {
      if (request.path.endsWith('/conversations')) {
        return [
          {'id': 'chat-tools', 'title': 'Workshop tools'},
          {'id': 'chat-books', 'title': 'Classroom books'},
        ];
      }
      if (request.path.endsWith('/conversations/chat-books')) {
        return {
          'conversation': {'id': 'chat-books', 'title': 'Classroom books'},
          'messages': [
            {'id': 'q1', 'role': 'user', 'content': 'Where are the books?'},
            {
              'id': 'a1',
              'role': 'assistant',
              'content': 'On the classroom shelf.',
            },
          ],
        };
      }
      return fallback(request);
    };
    await mount(tester, brightness: Brightness.dark);
    await tester.tap(find.byTooltip('Chat history'));
    await tester.pumpAndSettle();
    expect(find.text('Workshop tools'), findsOneWidget);
    await worldAuditCapture?.call('history-dark');
    await tester.tap(find.byTooltip('Search chats'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'BOOKS');
    await tester.pumpAndSettle();
    expect(find.text('Workshop tools'), findsNothing);
    expect(find.text('Classroom books'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matching chats'), findsOneWidget);
    await tester.tap(find.byTooltip('Search chats'));
    await tester.pumpAndSettle();
    expect(find.text('Workshop tools'), findsOneWidget);
    await tester.tap(find.text('Classroom books'));
    await tester.pumpAndSettle();
    expect(find.textContaining('On the classroom shelf.'), findsWidgets);
    expect(find.byTooltip('More'), findsNothing);
    expect(
      fixture.requests.map((r) => r.path),
      contains('/worlds/personal/conversations/chat-books'),
    );
    await worldAuditCapture?.call('conversation-dark');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Glass navigation and history fit narrow screens at large text', (
    tester,
  ) async {
    final fallback = fixture.respond;
    fixture.respond = (request) =>
        request.path.endsWith('/conversations') ? [] : fallback(request);
    await mount(tester, size: const Size(320, 568), scale: 2);
    for (final label in ['Spaces', 'More', 'Ask']) {
      await tester.tap(find.byTooltip(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Chat history'));
    await tester.pumpAndSettle();
    expect(find.text('Start your first chat'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Search chats'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Ask focuses chat and retains the draft on Back', (tester) async {
    final requests = <http.Request>[];
    final haptics = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await http.runWithClient(
      () async {
        await mount(tester);
        await tester.enterText(
          find.byType(TextField).first,
          'Where is my drill?',
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Send message'));
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)),
          );
        }
        expect(requests.single.url.path, '/worlds/personal/ai_command');
        expect(
          haptics,
          containsAllInOrder([
            'HapticFeedbackType.lightImpact',
            'HapticFeedbackType.selectionClick',
            'HapticFeedbackType.lightImpact',
          ]),
        );
        expect(find.byTooltip('More'), findsNothing);
        expect(find.byTooltip('Account'), findsNothing);
        expect(find.textContaining('Your drill is on Shelf 2.'), findsWidgets);
        final list = find.byType(ListView).first;
        expect(
          tester.getTopLeft(list).dy,
          lessThan(tester.getBottomLeft(find.byTooltip('Back')).dy),
        );
        await tester.drag(list, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(list).dy,
          lessThan(tester.getBottomLeft(find.byTooltip('Back')).dy),
        );
        expect(find.text('Ask FindEZ…'), findsOneWidget);
        expect(find.byTooltip('Send message'), findsNothing);
        await worldAuditCapture?.call('conversation-clearance');
        await tester.enterText(
          find.byType(TextField).first,
          'What about the charger?',
        );
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('More'), findsOneWidget);
        expect(find.text('What about the charger?'), findsOneWidget);
        expect(find.text('Create your inventory world.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
      () => MockClient((request) async {
        requests.add(request);
        final delta = jsonEncode({
          'type': 'delta',
          'delta': 'Your drill is on Shelf 2.',
        });
        final done = jsonEncode({
          'type': 'done',
          'conversation_id': '10000000-0000-4000-8000-000000000001',
          'assistant_message': 'Your drill is on Shelf 2.',
          'answer_context': {},
        });
        return http.Response(
          'data: $delta\n\ndata: $done\n\ndata: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );
  });
  test(
    'world API routes history and refuses stale organization clients',
    () async {
      var current = true;
      final api = ApiClient.forWorld(
        fixture.api,
        'org-a',
        isCurrent: () => current,
      );
      expect(api.inventoryPath('/ai_command'), '/worlds/org-a/ai_command');
      fixture.respond = (_) => [];
      await api.listConversations();
      expect(fixture.requests.last.path, '/worlds/org-a/conversations');
      current = false;
      expect(
        () => api.inventoryPath('/ai_command'),
        throwsA(isA<AskRequestException>()),
      );
    },
  );
  testWidgets(
    'structure card shows exact destination and waits for durable confirmation',
    (tester) async {
      final action = {
        'id': 'review',
        'status': 'pending',
        'workspace_label': 'Workshop',
        'plan': {
          'inventories': [
            {
              'name': 'Hardware',
              'spaces': ['Bolts'],
            },
          ],
        },
      };
      final api = ApiClient.forWorld(
        fixture.api,
        'org-a',
        isCurrent: () => true,
      );
      var changes = 0;
      fixture.respond = (_) => {
        'action': {...action, 'status': 'confirmed'},
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldActionCard(
              api: api,
              action: action,
              onSaved: () => changes++,
            ),
          ),
        ),
      );
      expect(find.text('Workspace: Workshop'), findsOneWidget);
      expect(changes, 0);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(find.text('Saved to your world'), findsOneWidget);
      expect(
        fixture.requests.single.path,
        '/worlds/org-a/structure-actions/review',
      );
    },
  );
}
