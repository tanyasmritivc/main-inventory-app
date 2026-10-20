import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/ui/member_avatar.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/workspaces/hierarchy_page.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:mobile/features/workspaces/invitation_page.dart';
import 'package:mobile/features/workspaces/inventory_context_host.dart';
import 'package:mobile/core/invitation.dart';
import 'package:mobile/features/sharing/invitation_host.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  String organizationRole = 'owner', workspaceRole = 'owner';
  var orgNames = <String>['Acme'];
  final opens = <String>[];
  Map<String, dynamic> organization(String name, int index) => {
    'organization_id': 'org-$index',
    'name': name,
    'owner_user_id': organizationRole == 'owner' ? 'actor-a' : 'other',
    'role': organizationRole,
  };
  Map<String, dynamic> workspace() => {
    'workspace_id': 'workspace-a',
    'team_id': 'workspace-a',
    'name': 'Client project',
    'organization_id': 'org-0',
    'owner_user_id': workspaceRole == 'owner' ? 'actor-a' : 'other',
    'role': workspaceRole,
  };
  setUp(() {
    fixture.requests.clear();
    fixture.status = 200;
    organizationRole = 'owner';
    workspaceRole = 'owner';
    orgNames = ['Acme'];
    opens.clear();
    fixture.respond = (request) {
      final path = request.path;
      if (path == '/organizations') {
        return {
          'organizations': [
            for (var i = 0; i < orgNames.length; i++)
              organization(orgNames[i], i),
          ],
        };
      }
      if (path == '/inventory-workspaces') {
        return {
          'workspaces': [
            {
              'workspace_id': 'personal',
              'kind': 'personal',
              'name': 'Personal',
            },
            {...workspace(), 'kind': 'team'},
          ],
        };
      }
      if (path == '/sharing/joined') return [];
      if (path == '/organizations/org-0') {
        return {
          'organization': organization(orgNames[0], 0),
          'workspaces': [
            {'team_id': 'workspace-a', 'name': 'Client project'},
          ],
          'members': [
            {
              'user_id': 'actor-a',
              'display_name': 'Tanya',
              'avatar_url': 'https://api.test/saved-profile.png',
              'role': organizationRole,
            },
          ],
          'attachable': [],
        };
      }
      if (path.endsWith('/overview')) {
        return {
          'workspace': workspace(),
          'members': [
            {
              'user_id': 'actor-a',
              'display_name': 'Tanya',
              'avatar_url': 'https://api.test/saved-profile.png',
              'role': workspaceRole,
            },
          ],
          'candidates': [],
          'locations': [
            {'location_id': 'room', 'name': 'Workshop', 'parent_id': null},
            {'location_id': 'bin', 'name': 'Bin 4', 'parent_id': 'room'},
          ],
        };
      }
      if (path.endsWith('/audit')) return {'activity': []};
      if (path.endsWith('/access-requests')) return {'requests': []};
      if (path == '/access-invitations') return {'invitations': []};
      if (path.endsWith('/directory')) {
        return {
          'workspace': workspace(),
          'inventories': [
            {
              'inventory_id': 'fasteners',
              'workspace_id': 'workspace-a',
              'name': 'Fasteners',
              'can_open': true,
              'can_edit': true,
              'can_rename': true,
              'role': 'editor',
              'item_count': 42,
            },
            {
              'inventory_id': 'electrical',
              'workspace_id': 'workspace-a',
              'name': 'Electrical',
              'can_open': false,
              'description': 'Restricted inventory',
            },
          ],
          'next_offset': null,
        };
      }
      throw StateError('Unexpected fixture route $path');
    };
  });
  Future<void> pump(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.create(Brightness.light), home: page),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('organization and workspace People use the saved profile photo', (
    tester,
  ) async {
    for (final level in [
      HierarchyLevel.organization,
      HierarchyLevel.workspace,
    ]) {
      await pump(
        tester,
        HierarchyPage(
          api: fixture.api,
          level: level,
          id: level == HierarchyLevel.organization ? 'org-0' : 'workspace-a',
          panel: HierarchyPanel.people,
          onOpenInventory: (id, workspace, organization) async {},
        ),
      );
      if (level == HierarchyLevel.organization) {
        await tester.tap(
          find.descendant(
            of: find.byWidgetPredicate(
              (widget) => widget is SegmentedButton<bool>,
            ),
            matching: find.text('People'),
          ),
        );
        await tester.pumpAndSettle();
      }
      final savedAvatar = find.byWidgetPredicate(
        (widget) =>
            widget is MemberAvatar &&
            widget.photoUrl == 'https://api.test/saved-profile.png',
      );
      expect(savedAvatar, findsOneWidget);
      expect(
        tester.widget<MemberAvatar>(savedAvatar).photoUrl,
        'https://api.test/saved-profile.png',
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  Future<void> open(String id, String workspace, String? org) async {
    opens.add('$org/$workspace/$id');
  }

  HierarchyPage page({
    HierarchyLevel level = HierarchyLevel.organizations,
    String? id,
  }) => HierarchyPage(
    api: ApiClient.forAccount(fixture.api, 'actor-a'),
    onOpenInventory: open,
    level: level,
    id: id,
  );

  testWidgets(
    'one and multiple organizations show Personal and assigned workspaces',
    (tester) async {
      await pump(tester, page());
      expect(find.text('Acme'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Client project'), findsOneWidget);
      orgNames = ['Acme', 'Robotics'];
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Robotics'), findsOneWidget);
      expect(fixture.requests.last.path, '/sharing/joined');
      expect(
        fixture.requests.every(
          (r) => r.headers['Authorization'].toString().startsWith('Bearer '),
        ),
        true,
      );
    },
  );

  testWidgets('organization members cannot see management actions', (
    tester,
  ) async {
    organizationRole = 'member';
    await pump(tester, page(level: HierarchyLevel.organization, id: 'org-0'));
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();
    expect(find.text('Tanya'), findsOneWidget);
    expect(find.text('Member'), findsOneWidget);
    expect(find.text('New workspace'), findsNothing);
    expect(find.text('Invite organization member'), findsNothing);
    await tester.tap(find.byTooltip('Actions'));
    await tester.pumpAndSettle();
    expect(find.text('Leave organization'), findsOneWidget);
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Delete organization'), findsNothing);
  });

  testWidgets(
    'directory distinguishes visible restricted inventories from accessible contents',
    (tester) async {
      workspaceRole = 'viewer';
      await pump(
        tester,
        page(level: HierarchyLevel.workspace, id: 'workspace-a'),
      );
      expect(find.text('42 items · Editor'), findsOneWidget);
      expect(find.text('Access restricted'), findsOneWidget);
      expect(find.text('New inventory'), findsNothing);
      await tester.tap(find.text('Fasteners'));
      await tester.pumpAndSettle();
      expect(opens, ['org-0/workspace-a/fasteners']);
      expect(
        fixture.requests.any((r) => r.path.contains('search_items')),
        false,
      );
    },
  );

  testWidgets('foreign-parent directory is rejected instead of displayed', (
    tester,
  ) async {
    final original = fixture.respond;
    fixture.respond = (r) => r.path.endsWith('/directory')
        ? {
            'inventories': [
              {
                'inventory_id': 'foreign',
                'workspace_id': 'workspace-b',
                'name': 'Private item',
              },
            ],
            'next_offset': null,
          }
        : original(r);
    await pump(
      tester,
      page(level: HierarchyLevel.workspace, id: 'workspace-a'),
    );
    expect(find.text('Private item'), findsNothing);
    expect(find.textContaining('directory changed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('failure and retry refresh actual server directory metadata', (
    tester,
  ) async {
    final original = fixture.respond;
    fixture.respond = (r) => throw dio.DioException(
      requestOptions: r,
      type: dio.DioExceptionType.connectionError,
    );
    await pump(tester, page());
    expect(find.text('Acme'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    fixture.respond = original;
    orgNames = ['Renamed on web'];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Renamed on web'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
    'loading and disposed late requests never render stale directories',
    (tester) async {
      final complete = Completer<Map<String, dynamic>>();
      fixture.respond = (_) => complete.future;
      await tester.pumpWidget(MaterialApp(home: page()));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(home: Text('Different organization')),
      );
      complete.complete({
        'organizations': [
          {'name': 'Old organization'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('Old organization'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'physical location picker preserves full parent path and sends explicit parent ID',
    (tester) async {
      final original = fixture.respond;
      fixture.respond = (r) =>
          r.method == 'POST' && r.path.endsWith('/locations')
          ? {
              'location': {'location_id': 'drawer', 'name': 'Drawer'},
            }
          : original(r);
      await pump(
        tester,
        page(level: HierarchyLevel.workspace, id: 'workspace-a'),
      );
      await tester.scrollUntilVisible(
        find.text('New physical location'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New physical location'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Drawer');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Workshop / Bin 4'), findsWidgets);
      await tester.tap(find.text('Workshop / Bin 4').last);
      await tester.pumpAndSettle();
      final request = fixture.requests.where((r) => r.method == 'POST').single;
      expect(request.path, '/inventory-workspaces/workspace-a/locations');
      expect(request.data, {'name': 'Drawer', 'parent_id': 'bin'});
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'invitation preview grants nothing until explicit recipient acceptance',
    (tester) async {
      fixture.respond = (r) => {
        'invitation': {
          'invitation_id': 'invite-a',
          'resource_id': 'org-a',
          'name': 'Acme',
          'scope': 'organization',
          'role': 'member',
          'status': r.path.endsWith('/decision') ? 'accepted' : 'pending',
        },
      };
      await pump(
        tester,
        AccessInvitationPage(api: fixture.api, code: 'ABCDEFGH2345'),
      );
      expect(fixture.requests.single.path, '/access-invitations/preview');
      expect(fixture.requests.single.data, {'code': 'ABCDEFGH2345'});
      expect(find.text('Accept invitation'), findsOneWidget);
      await tester.tap(find.text('Accept invitation'));
      await tester.pumpAndSettle();
      expect(fixture.requests.last.data, {'action': 'accept'});
      expect(
        fixture.requests.last.path,
        '/access-invitations/invite-a/decision',
      );
      expect(find.text('Status: accepted'), findsOneWidget);
    },
  );

  testWidgets(
    'wrong recipient or revoked invitation displays server denial with retry',
    (tester) async {
      fixture.status = 403;
      fixture.respond = (_) => {
        'detail': 'Use the invited account with a confirmed email.',
      };
      await pump(
        tester,
        AccessInvitationPage(api: fixture.api, invitationId: 'invite-a'),
      );
      expect(
        find.text('Use the invited account with a confirmed email.'),
        findsOneWidget,
      );
      expect(find.text('Accept invitation'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'phone layout handles long names and large text without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      orgNames = ['An organization with a very long project name for testing'];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: page(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'access invitation links and stored handoffs preserve legacy code formats',
    () {
      final access = Invitation.fromUri(
        Uri.parse('https://www.findez.ai/join/access?code=abcdefgh2345'),
      );
      expect(access?.kind, 'access');
      expect(access?.code, 'ABCDEFGH2345');
      expect(Invitation.fromData(access!.toData())?.url, access.url);
      expect(
        Invitation.fromUri(
          Uri.parse('https://other.test/join/access?code=ABCDEFGH2345'),
        ),
        isNull,
      );
      expect(
        Invitation.fromUri(
          Uri.parse('https://findez.ai/join/access?code=ABC123'),
        ),
        isNull,
      );
      expect(
        Invitation.fromUri(
          Uri.parse('https://findez.ai/join/team/ABC123'),
        )?.kind,
        'team',
      );
    },
  );

  testWidgets(
    'restricted access requests and cancellation grant no content access',
    (tester) async {
      Map<String, dynamic>? request;
      fixture.respond = (r) {
        if (r.method == 'POST') {
          request = {
            'request_id': 'request-a',
            'status': r.path.endsWith('/decision') ? 'cancelled' : 'pending',
          };
          return {'request': request};
        }
        return {
          'inventory': {'name': 'Electrical', 'can_open': false},
          'workspace': workspace(),
          'request': request?['status'] == 'pending' ? request : null,
        };
      };
      await pump(
        tester,
        RestrictedInventoryPage(
          api: fixture.api,
          id: 'electrical',
          workspaceId: 'workspace-a',
          onOpenInventory: open,
        ),
      );
      await tester.tap(find.text('Request viewer access'));
      await tester.pumpAndSettle();
      expect(find.text('Your request is pending.'), findsOneWidget);
      expect(opens, isEmpty);
      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();
      expect(fixture.requests.where((r) => r.method == 'POST').last.data, {
        'action': 'cancel',
      });
      expect(find.text('Open inventory'), findsNothing);
    },
  );

  testWidgets(
    'creation uses the selected workspace and refreshes the directory',
    (tester) async {
      final original = fixture.respond;
      var created = false;
      fixture.respond = (r) {
        if (r.method == 'POST' && r.path.endsWith('/inventories')) {
          created = true;
          return {
            'inventory': {'inventory_id': 'new', 'name': 'Materials'},
          };
        }
        final result = original(r);
        if (created && r.path.endsWith('/directory')) {
          return {
            'workspace': workspace(),
            'inventories': [
              {
                'inventory_id': 'new',
                'workspace_id': 'workspace-a',
                'name': 'Materials',
                'can_open': true,
                'item_count': 0,
              },
            ],
            'next_offset': null,
          };
        }
        return result;
      };
      await pump(
        tester,
        page(level: HierarchyLevel.workspace, id: 'workspace-a'),
      );
      await tester.tap(find.text('New inventory'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Materials');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inherited workspace access'));
      await tester.pumpAndSettle();
      expect(fixture.requests.where((r) => r.method == 'POST').single.data, {
        'name': 'Materials',
        'access_mode': 'workspace',
      });
      expect(
        fixture.requests.where((r) => r.method == 'POST').single.path,
        '/inventory-workspaces/workspace-a/inventories',
      );
      expect(find.text('Materials'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'share import picker returns a validated scoped client without opening a default inventory',
    (tester) async {
      final original = fixture.respond;
      fixture.respond = (r) => r.path == '/inventories/fasteners'
          ? {'inventory': inventory('fasteners', organization: 'org-0')}
          : original(r);
      ApiClient? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Choose destination'),
                onPressed: () async {
                  selected = await Navigator.of(context).push<ApiClient>(
                    MaterialPageRoute(
                      builder: (_) => InventoryContextHost(
                        api: fixture.api,
                        pickOnly: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose destination'));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      await tester.tap(find.text('Client project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fasteners'));
      await tester.pumpAndSettle();
      expect(selected?.inventoryContext?.inventoryId, 'fasteners');
      expect(
        selected?.inventoryPath('/inventory/import_spreadsheet'),
        '/inventories/fasteners/inventory/import_spreadsheet',
      );
      expect(find.text('Choose destination'), findsOneWidget);
    },
  );

  testWidgets('phone hierarchy visual acceptance', (tester) async {
    if (!const bool.fromEnvironment('FINDEZ_VISUAL_QA')) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    await (FontLoader(
      'Roboto',
    )..addFont(rootBundle.load('assets/fonts/Geist-Regular.ttf'))).load();
    await (FontLoader('PlaceGeist')
          ..addFont(rootBundle.load('assets/fonts/Geist-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Geist-Medium.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Geist-SemiBold.ttf')))
        .load();
    await (FontLoader(
      'PlaceGeistMono',
    )..addFont(rootBundle.load('assets/fonts/GeistMono-Medium.ttf'))).load();
    await tester.runAsync(() async {
      final bytes = await File('/System/Library/Fonts/SFNS.ttf').readAsBytes();
      for (final family in ['FindEZ-QA']) {
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
    });
    for (final brightness in Brightness.values) {
      for (final level in [
        HierarchyLevel.organizations,
        HierarchyLevel.workspace,
      ]) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness).copyWith(
              textTheme: AppTheme.create(
                brightness,
              ).textTheme.apply(fontFamily: 'FindEZ-QA'),
              primaryTextTheme: AppTheme.create(
                brightness,
              ).primaryTextTheme.apply(fontFamily: 'FindEZ-QA'),
              listTileTheme: AppTheme.create(brightness).listTileTheme.copyWith(
                titleTextStyle: AppTheme.create(brightness)
                    .listTileTheme
                    .titleTextStyle
                    ?.copyWith(fontFamily: 'FindEZ-QA'),
                subtitleTextStyle: AppTheme.create(brightness)
                    .listTileTheme
                    .subtitleTextStyle
                    ?.copyWith(fontFamily: 'FindEZ-QA'),
              ),
              appBarTheme: AppTheme.create(brightness).appBarTheme.copyWith(
                titleTextStyle: AppTheme.create(
                  brightness,
                ).appBarTheme.titleTextStyle?.copyWith(fontFamily: 'FindEZ-QA'),
              ),
            ),
            home: RepaintBoundary(
              key: key,
              child: page(
                level: level,
                id: level == HierarchyLevel.workspace ? 'workspace-a' : null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final snapshot = await boundary.toImage(pixelRatio: 2);
          final bytes = await snapshot.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            '/private/tmp/findez-hierarchy-${brightness.name}-${level.name}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          snapshot.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets(
    'access email link waits for sign-in and never grants membership on open',
    (tester) async {
      await tester.runAsync(
        () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
      );
      final links = StreamController<Uri>.broadcast();
      addTearDown(links.close);
      final navigator = GlobalKey<NavigatorState>();
      fixture.respond = (_) => {
        'invitation': {
          'invitation_id': 'invite-a',
          'resource_id': 'org-a',
          'name': 'Acme',
          'scope': 'organization',
          'role': 'member',
          'status': 'pending',
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => InvitationHost(
            api: fixture.api,
            navigatorKey: navigator,
            ready: true,
            incomingLinks: links.stream,
            initialLink: () async =>
                Uri.parse('https://findez.ai/join/access?code=ABCDEFGH2345'),
            child: child!,
          ),
          home: const Scaffold(body: Text('Sign in first')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AccessInvitationPage), findsNothing);
      expect(fixture.requests, isEmpty);
      await tester.runAsync(() => fixture.signIn('actor-a'));
      await tester.pumpAndSettle();
      expect(find.byType(AccessInvitationPage), findsOneWidget);
      expect(fixture.requests.single.path, '/access-invitations/preview');
      expect(find.text('Accept invitation'), findsOneWidget);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'inventory shell keeps context readable at large text and replaces Teams navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      fixture.respond = (r) => r.path.endsWith('/conversations')
          ? []
          : {
              'items': [],
              'parsed': {},
              'spaces': [],
              'reviews': [],
              'pending_count': 0,
              'checkouts': [],
              'active': [],
              'unread_count': 0,
              'notifications': [],
              'display_name': 'Tanya',
            };
      final selected = InventoryContext.fromJson(
        inventory('fasteners', role: 'viewer'),
        accountId: 'actor-a',
        expectedInventory: 'fasteners',
      );
      final api = ApiClient.forInventory(
        fixture.api,
        selected,
        isCurrent: () => true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2.6)),
            child: child!,
          ),
          home: MainShell(
            api: api,
            onSwitchContext: () async {},
            onManageContext: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('fasteners'), findsOneWidget);
      expect(find.byTooltip('Inventory settings'), findsOneWidget);
      expect(find.text('Teams'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'viewer can open Find results while item editing and swipes stay disabled',
    (tester) async {
      fixture.respond = (r) => {
        'items': [
          {
            'item_id': 'bolt-a',
            'name': 'Bolt',
            'category': 'Parts',
            'quantity': 2,
            'location': 'Drawer',
            'created_at': '2026-10-01T00:00:00Z',
          },
        ],
        'spaces': [],
        'photos': [],
        'documents': [],
        'checkouts': [],
        'active': [],
        'parsed': {},
      };
      final selected = InventoryContext.fromJson(
        inventory('fasteners', role: 'viewer'),
        accountId: 'actor-a',
        expectedInventory: 'fasteners',
      );
      final api = ApiClient.forInventory(
        fixture.api,
        selected,
        isCurrent: () => true,
      );
      await pump(
        tester,
        InventoryPage(api: api, initialQuery: 'Bolt', refreshToken: 0),
      );
      final swipes = tester.widgetList<Dismissible>(find.byType(Dismissible));
      expect(swipes, isNotEmpty);
      expect(
        swipes.every((row) => row.direction == DismissDirection.none),
        true,
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(Dismissible),
              matching: find.text('Bolt'),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('item-detail-scroll')), findsOneWidget);
      expect(find.text('Edit item'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(
        fixture.requests.any(
          (r) => r.method == 'PATCH' || r.method == 'DELETE',
        ),
        false,
      );
      expect(find.text('Bolt'), findsWidgets);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'inventory administrator can review requests without workspace admin rights',
    (tester) async {
      workspaceRole = 'member';
      final original = fixture.respond;
      var approved = false;
      fixture.respond = (r) {
        if (r.path.endsWith('/access-requests')) {
          return {
            'requests': approved
                ? []
                : [
                    {
                      'request_id': 'request-a',
                      'inventory_name': 'Fasteners',
                      'requester_name': 'Student',
                    },
                  ],
          };
        }
        if (r.path == '/inventory-access-requests/request-a/decision') {
          approved = true;
          return {
            'request': {'request_id': 'request-a', 'status': 'approved'},
          };
        }
        return original(r);
      };
      await pump(
        tester,
        HierarchyPage(
          api: ApiClient.forAccount(fixture.api, 'actor-a'),
          onOpenInventory: open,
          level: HierarchyLevel.workspace,
          id: 'workspace-a',
          panel: HierarchyPanel.people,
        ),
      );
      expect(find.text('New inventory'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Student'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve viewer access'));
      await tester.pumpAndSettle();
      expect(fixture.requests.where((r) => r.method == 'POST').single.data, {
        'action': 'approve',
      });
      expect(approved, true);
    },
  );
}
