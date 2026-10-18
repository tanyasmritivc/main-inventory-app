import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/invitation_destination.dart';
import 'package:mobile/core/last_place.dart';
import 'package:mobile/features/sharing/invitation_host.dart';
import 'package:mobile/features/sharing/review_invitation_page.dart';
import 'package:mobile/features/workspaces/inventory_context_host.dart';
import 'package:mobile/features/workspaces/invitation_page.dart';
import 'package:mobile/features/workspaces/organization_pill.dart';
import 'package:mobile/features/workspaces/workspace_home.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final f = HierarchyFixture();
  setUpAll(f.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  var scope = 'organization', decision = 'accepted', granted = false;
  var expired = false;
  Map<String, dynamic> row() => {
    'invitation_id': 'invite',
    'name': 'Invited Studio',
    'scope': scope,
    'resource_id': scope == 'organization'
        ? 'b'
        : scope == 'workspace'
        ? 'b-work'
        : 'inv-b',
    'organization_id': 'b',
    'team_id': scope == 'organization' ? null : 'b-work',
    'inventory_id': scope == 'inventory' ? 'inv-b' : null,
    'status': granted ? decision : 'pending',
    'role': 'editor',
    'expires_at': expired ? '2000-01-01T00:00:00Z' : '2099-01-01T00:00:00Z',
  };
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    InvitationNavigation.instance.take('actor-a');
    f.requests.clear();
    f.status = 200;
    scope = 'organization';
    decision = 'accepted';
    granted = false;
    expired = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.findez.app/push'),
          (_) async => null,
        );
    f.respond = (r) {
      if (r.path == '/access-invitations/preview') return {'invitation': row()};
      if (r.path.endsWith('/decision')) {
        granted = true;
        return {'invitation': row()};
      }
      if (r.path == '/organizations') {
        return {
          'organizations': [
            {'organization_id': 'a', 'name': 'Original Studio'},
            if (granted) {'organization_id': 'b', 'name': 'Invited Studio'},
          ],
        };
      }
      if (r.path.startsWith('/organizations/')) {
        final id = r.path.split('/').last;
        return {
          'organization': {
            'organization_id': id,
            'name': id == 'a' ? 'Original Studio' : 'Invited Studio',
            'role': 'member',
          },
          'workspaces': [
            if (id == 'a' || scope != 'organization')
              {
                'team_id': '$id-work',
                'name': 'Workshop',
                'organization_id': id,
              },
          ],
        };
      }
      if (r.path.endsWith('/overview')) {
        final ws = r.path.split('/')[2];
        return {
          'workspace': {
            'workspace_id': ws,
            'name': 'Workshop',
            'organization_id': ws.substring(0, 1),
            'organization_name': ws == 'a-work'
                ? 'Original Studio'
                : 'Invited Studio',
            'role': 'member',
          },
        };
      }
      if (r.path.endsWith('/directory')) {
        final ws = r.path.split('/')[2];
        return {
          'inventories': [
            {
              'inventory_id': ws == 'a-work' ? 'inv-a' : 'inv-b',
              'workspace_id': ws,
              'name': ws == 'a-work'
                  ? 'Original inventory'
                  : 'Invited inventory',
              'can_open': true,
            },
          ],
          'next_offset': null,
        };
      }
      if (r.path == '/inventories/inv-b') {
        return {
          'inventory': inventory(
            'inv-b',
            workspace: 'b-work',
            organization: 'b',
            name: 'Invited inventory',
          ),
        };
      }
      if (r.path.endsWith('/conversations') || r.path == '/sharing/joined') {
        return [];
      }
      return {
        'notifications': [],
        'unread_count': 0,
        'items': [],
        'spaces': [],
        'parsed': {},
        'checkouts': [],
        'pending_count': 0,
        'display_name': 'Test',
        'tier': 'free',
        'shares': [],
      };
    };
    await LastPlaceStore('actor-a').save(
      const LastPlace.workspace('a-work'),
      organizationId: 'a',
      isCurrent: () => true,
    );
  });
  Future<void> mount(
    WidgetTester tester,
    Brightness mode, {
    bool link = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(mode),
        navigatorKey: key,
        builder: (context, child) => InvitationHost(
          api: f.api,
          navigatorKey: key,
          ready: true,
          incomingLinks: const Stream.empty(),
          initialLink: () async => link
              ? Uri.parse('findez://access-invite?code=ABCDEFGH2345')
              : null,
          child: child!,
        ),
        home: InventoryContextHost(api: f.api),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final mode in Brightness.values) {
    for (final target in ['organization', 'workspace', 'inventory']) {
      testWidgets(
        '$mode $target accepted into exact scope without a second shell',
        (tester) async {
          scope = target;
          await mount(tester, mode);
          expect(
            f.requests.where((r) => r.path.endsWith('/decision')),
            isEmpty,
          );
          await tester.tap(find.text('Accept invitation'));
          await tester.pumpAndSettle();
          expect(find.text('Status: accepted'), findsOneWidget);
          await tester.tap(find.text('Open $target'));
          await tester.pumpAndSettle();
          expect(find.byType(InventoryContextHost), findsOneWidget);
          expect(find.byType(AccessInvitationPage), findsNothing);
          expect(
            tester.widget<OrganizationPill>(find.byType(OrganizationPill)).id,
            'b',
          );
          if (target == 'inventory') {
            expect(find.byType(MainShell), findsOneWidget);
            expect(f.requests.any((r) => r.path == '/inventories/inv-b'), true);
          } else {
            expect(find.byType(WorkspaceHome), findsOneWidget);
            expect(find.text('Original inventory'), findsNothing);
          }
          expect(await LastPlaceStore('actor-a').readOrganization(), 'b');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
    testWidgets('$mode manual code entry preserves consent and scope', (
      tester,
    ) async {
      await mount(tester, mode, link: false);
      await tester.tap(find.byType(OrganizationPill));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review invitation'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewInvitationPage), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'abcdefgh2345');
      await tester.tap(find.widgetWithText(FilledButton, 'Review invitation'));
      await tester.pumpAndSettle();
      expect(granted, false);
      await tester.tap(find.text('Accept invitation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open organization'));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewInvitationPage), findsNothing);
      expect(
        tester.widget<OrganizationPill>(find.byType(OrganizationPill)).id,
        'b',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
    testWidgets(
      '$mode expired link cannot accept and wrong-account review disappears',
      (tester) async {
        expired = true;
        await mount(tester, mode);
        expect(
          find.textContaining('This invitation has expired'),
          findsOneWidget,
        );
        expect(find.text('Accept invitation'), findsNothing);
        expect(f.requests.where((r) => r.path.endsWith('/decision')), isEmpty);
        await tester.runAsync(() => f.signIn('other'));
        await tester.pumpAndSettle();
        expect(find.byType(AccessInvitationPage), findsNothing);
        expect(find.text('Invited Studio'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.runAsync(() => f.signIn('actor-a'));
      },
    );
    testWidgets('$mode mismatched decision cannot navigate', (tester) async {
      decision = 'declined';
      await mount(tester, mode);
      await tester.tap(find.text('Accept invitation'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Decision could not be confirmed'),
        findsOneWidget,
      );
      expect(find.text('Open organization'), findsNothing);
      expect(
        tester.widget<OrganizationPill>(find.byType(OrganizationPill).first).id,
        'a',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  test(
    'only recipient root consumes pending destination; incomplete receipt rejected',
    () {
      final nav = InvitationNavigation();
      nav.open('recipient', const InvitationDestination(organizationId: 'org'));
      expect(nav.take('other'), isNull);
      expect(nav.take('recipient')!.organizationId, 'org');
      expect(nav.take('recipient'), isNull);
      expect(
        () => InvitationDestination.fromAccess({
          'scope': 'inventory',
          'resource_id': 'inv',
          'status': 'accepted',
        }),
        throwsFormatException,
      );
    },
  );
}
