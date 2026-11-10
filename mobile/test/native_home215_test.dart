import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/workspaces/organization_pill.dart';
import 'package:mobile/features/workspaces/invitation_page.dart';
import 'package:mobile/features/announcements/announcement_controller.dart';
import 'package:mobile/features/announcements/announcement_host.dart';
import 'package:mobile/features/announcements/announcement_widgets.dart';
import 'support/announcement_fixture.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  late Map model;
  late Completer<Object?> completion;
  setUp(() {
    debugNativePresentationOverride = true;
    fixture.requests.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      NativePresentation.channel,
      (call) async {
        if (call.method == 'present') {
          model = call.arguments as Map;
          completion = Completer<Object?>();
          return completion.future;
        }
        return null;
      },
    );
  });
  tearDown(() {
    debugNativePresentationOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      NativePresentation.channel,
      null,
    );
  });
  Future<Map> action(String id) async {
    const codec = StandardMethodCodec();
    final response = Completer<Map>();
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      NativePresentation.channel.name,
      codec.encodeMethodCall(
        MethodCall('action', {'token': model['token'], 'id': id}),
      ),
      (bytes) => response.complete(codec.decodeEnvelope(bytes!) as Map),
    );
    return response.future;
  }

  test(
    'sign-in welcome uses verified access and rejects a switched account',
    () async {
      var current = true;
      final pending = Completer<Map<String, dynamic>>();
      fixture.respond = (_) => pending.future;
      final controller = AnnouncementController(
        api: fixture.api,
        accountId: 'actor-a',
        platform: 'ios',
        isCurrent: () => current,
        welcomeAfterSignIn: true,
      );
      final loading = controller.evaluate();
      current = false;
      pending.complete(announcementAccess);
      await loading;
      expect(controller.campaign, isNull);
      controller.dispose();
    },
  );
  test(
    'sign-in welcome cannot invent Founders Access for non-pilot accounts',
    () async {
      fixture.respond = (_) => {...announcementAccess, 'pilot': false};
      final controller = AnnouncementController(
        api: fixture.api,
        accountId: 'actor-a',
        platform: 'ios',
        isCurrent: () => true,
        welcomeAfterSignIn: true,
      );
      await controller.evaluate();
      expect(controller.campaign, isNull);
      expect(controller.access?['pilot'], false);
      controller.dispose();
    },
  );
  testWidgets(
    'native organization picker preserves choices and selected account scope',
    (tester) async {
      fixture.respond = (_) => {
        'organizations': [
          {'organization_id': 'b', 'name': 'Beta'},
          {'organization_id': 'a', 'name': 'Alpha'},
        ],
      };
      String? selected = 'unchanged';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizationPill(
              api: fixture.api,
              id: 'b',
              name: 'Beta',
              glass: true,
              onSelected: (id) async => selected = id,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(model['kind'], 'organization');
      final rows = (model['sections'] as List)
          .expand((section) => section['rows'] as List)
          .toList();
      expect(rows.map((row) => row['title']), [
        'Alpha',
        'Beta',
        'Personal',
        'New organization',
        'Review invitation',
      ]);
      expect(rows[1]['checked'], true);
      completion.complete({'action': 'personal'});
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(fixture.requests.every((r) => r.method == 'GET'), true);
    },
  );
  testWidgets(
    'native invitation previews without granting access and requires explicit acceptance',
    (tester) async {
      var accepted = false;
      fixture.respond = (r) {
        if (r.path.endsWith('/decision')) accepted = true;
        return {
          'invitation': {
            'invitation_id': 'inv',
            'scope': 'organization',
            'resource_id': 'org',
            'organization_id': 'org',
            'name': 'Design Studio',
            'role': 'admin',
            'status': accepted ? 'accepted' : 'pending',
            'expires_at': '2099-01-01T00:00:00Z',
            'invited_by_name': 'Alex',
          },
        };
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AccessInvitationPage(
                    api: fixture.api,
                    invitationId: 'inv',
                  ),
                ),
              ),
              child: const Text('Review'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();
      final preview = await tester.runAsync(() => action('load'));
      expect(accepted, false);
      expect(preview.toString(), contains('Design Studio'));
      expect(
        preview.toString(),
        contains(
          const DefaultMaterialLocalizations().formatFullDate(
            DateTime.parse('2099-01-01T00:00:00Z').toLocal(),
          ),
        ),
      );
      expect(preview.toString(), contains('Accept invitation'));
      final updated = await tester.runAsync(() => action('accept'));
      expect(accepted, true);
      expect(updated.toString(), contains('Open organization'));
      expect(
        fixture.requests.where((r) => r.path.endsWith('/decision')),
        hasLength(1),
      );
      completion.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Review'), findsOneWidget);
    },
  );
  testWidgets(
    'sign-in welcome ignores campaign suppression and stays until gesture dismissal',
    (tester) async {
      fixture.respond = (_) => announcementAccess;
      final controller = AnnouncementController(
        api: fixture.api,
        accountId: 'actor-a',
        platform: 'ios',
        isCurrent: () => true,
        welcomeAfterSignIn: true,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [announcementRoutes],
          home: AnnouncementScope(
            controller: controller,
            child: Scaffold(
              body: AnnouncementGate(
                isSafe: () => false,
                isWelcomeSafe: () => true,
                onCapture: () {},
                child: const Text('Home'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Founders Access'), findsOneWidget);
      expect(find.byTooltip('Close announcement'), findsNothing);
      expect(find.text('Got it'), findsNothing);
      await tester.pump(const Duration(minutes: 2));
      expect(find.byType(AnnouncementSheet), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      expect(find.byType(AnnouncementSheet), findsNothing);
      expect(fixture.requests.map((r) => r.path), ['/announcements/access']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
