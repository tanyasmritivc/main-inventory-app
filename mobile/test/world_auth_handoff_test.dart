import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/auth/auth_page.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';
import 'package:mobile/features/onboarding/pending_world.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:mobile/features/world/world_shell.dart';
import 'package:mobile/features/workspaces/workspace_home.dart';
import 'package:mobile/main.dart';

const actor = '10000000-0000-4000-8000-000000000001';
const orgId = '20000000-0000-4000-8000-000000000001';
const workspaceId = '30000000-0000-4000-8000-000000000001';
const inventoryId = '40000000-0000-4000-8000-000000000001';

/// Real ApiClient transport and real AuthPage handlers, with synthetic HTTP peers.
class SetupTransport implements dio.HttpClientAdapter {
  final posts = <dio.RequestOptions>[];
  String? organization;
  String purpose = 'Workshop', inventory = 'Tools';
  bool workspaceCreated = false, inventoryCreated = false;
  bool hasExistingWorkspace = false;
  Map<String, dynamic> get workspace => {
    'workspace_id': workspaceId,
    'team_id': workspaceId,
    'name': purpose,
    'owner_user_id': actor,
    'role': 'owner',
    'organization_id': organization,
    'organization_name': organization == null ? null : 'Kestrel Labs',
  };
  Map<String, dynamic> get item => {
    'inventory_id': inventoryId,
    'name': inventory,
    'team_id': workspaceId,
    'owner_user_id': actor,
    'created_by_user_id': actor,
    'role': 'owner',
    'can_edit': true,
    'can_manage': true,
    'can_rename': true,
    'workspace': workspace,
  };
  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    Object result;
    if (options.method == 'POST' &&
        [
          '/organizations',
          '/organizations/$orgId/workspaces',
          '/teams',
          '/inventory-workspaces/$workspaceId/inventories',
        ].contains(path)) {
      expect(Supabase.instance.client.auth.currentSession, isNotNull);
      expect(options.headers['Authorization'], startsWith('Bearer '));
      posts.add(options);
      final data = Map<String, dynamic>.from(options.data as Map);
      if (path == '/organizations') {
        organization = orgId;
        result = {
          'organization': {
            'organization_id': orgId,
            'name': data['name'],
            'owner_user_id': actor,
          },
        };
      } else if (path.endsWith('/inventories')) {
        inventory = data['name'] as String;
        inventoryCreated = true;
        result = {'inventory': item};
      } else {
        purpose = data['name'] as String;
        workspaceCreated = true;
        // Existing organization create returns team_id, standalone returns team.
        result = {
          path == '/teams' ? 'team' : 'workspace': {
            'team_id': workspaceId,
            'name': purpose,
            'organization_id': organization,
          },
        };
      }
    } else if (path == '/organizations') {
      result = {
        'organizations': organization == null
            ? []
            : [
                {
                  'organization_id': orgId,
                  'name': 'Kestrel Labs',
                  'owner_user_id': actor,
                  'role': 'owner',
                },
              ],
      };
    } else if (path == '/inventory-workspaces') {
      result = {
        'workspaces': [
          {'workspace_id': 'personal', 'name': 'Personal', 'role': 'owner'},
          if (hasExistingWorkspace)
            {
              'workspace_id': '50000000-0000-4000-8000-000000000001',
              'name': 'Existing workspace',
              'owner_user_id': actor,
              'role': 'owner',
            },
          if (workspaceCreated) workspace,
        ],
      };
    } else if (path == '/organizations/$orgId') {
      result = {
        'organization': {
          'organization_id': orgId,
          'name': 'Kestrel Labs',
          'owner_user_id': actor,
        },
        'workspaces': workspaceCreated ? [workspace] : [],
      };
    } else if (path == '/inventory-workspaces/$workspaceId/overview') {
      result = {
        'workspace': workspace,
        'members': [
          {'user_id': actor, 'role': 'owner'},
        ],
      };
    } else if (path == '/inventory-workspaces/$workspaceId/inventories' ||
        path == '/inventory-workspaces/$workspaceId/directory') {
      result = {
        'workspace': workspace,
        'inventories': inventoryCreated
            ? [
                {
                  ...item,
                  'workspace_id': workspaceId,
                  'can_open': true,
                  'item_count': 0,
                },
              ]
            : [],
        'next_offset': null,
      };
    } else if (path == '/inventories/$inventoryId') {
      result = {'inventory': item};
    } else if (path.endsWith('/conversations') || path == '/sharing/joined') {
      result = [];
    } else {
      result = {
        'items': [],
        'parsed': {},
        'spaces': [],
        'checkouts': [],
        'pending_count': 0,
        'notifications': [],
        'unread_count': 0,
        'display_name': 'Test',
        'tier': 'free',
        'shares': [],
      };
    }
    return dio.ResponseBody.fromString(
      jsonEncode(result),
      200,
      headers: {
        dio.Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var confirmationRequired = false;
  final authRequests = <String>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://auth.test',
      publishableKey: 'synthetic-only',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        authRequests.add(path);
        final user = {
          'id': actor,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'test@example.test',
          'email_confirmed_at': '2026-01-01T00:00:00Z',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
        };
        String encode(Object value) => base64Url
            .encode(utf8.encode(jsonEncode(value)))
            .replaceAll('=', '');
        final token =
            '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': actor, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.signature';
        final Object response = path.endsWith('/signup') && confirmationRequired
            ? user
            : path.endsWith('/token') || path.endsWith('/signup')
            ? {
                'access_token': token,
                'refresh_token': 'synthetic-refresh',
                'expires_in': 3600,
                'token_type': 'bearer',
                'user': user,
              }
            : path.endsWith('/user')
            ? user
            : path.contains('/rest/v1/')
            ? []
            : {};
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  setUp(() async {
    await Supabase.instance.client.auth.signOut();
    Supabase.instance.client.auth.stopAutoRefresh();
    SharedPreferences.setMockInitialValues({});
    confirmationRequired = false;
    authRequests.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.findez.app/push'),
          (_) async => null,
        );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
  }

  Future<SetupTransport> launch(
    WidgetTester tester, {
    bool team = true,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = SetupTransport();
    final client = dio.Dio(dio.BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = transport;
    final api = ApiClient(baseUrl: 'https://api.test', httpClient: client);
    await WorldSetupStore.saveDraft(
      PendingWorld(
        path: team ? 'team' : 'personal',
        orgName: team ? 'Kestrel Labs' : '',
        workspacePurpose: team ? 'R&D' : 'Workshop',
        inventoryName: team ? 'Hardware' : 'Tools',
        step: WorldStep.auth,
      ),
    );
    await OnboardingPrefs.setCompleted(true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(brightness),
        home: LaunchAuthGate(api: api),
      ),
    );
    await settle(tester);
    expect(transport.posts, isEmpty);
    expect(find.text('Your dashboard is ready'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('auth-more-options')));
    await tester.tap(find.byKey(const Key('auth-more-options')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('auth-email-option')));
    await tester.tap(find.byKey(const Key('auth-email-option')));
    await tester.pumpAndSettle();
    return transport;
  }

  Future<void> enter(WidgetTester tester, String label, String value) async {
    final field = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
  }

  for (final signup in [false, true]) {
    testWidgets(
      '${signup ? 'signup' : 'sign-in'} preserves prepared setup through existing HTTP routes and opens Ask',
      (tester) async {
        final transport = await launch(
          tester,
          team: !signup,
          brightness: signup ? Brightness.dark : Brightness.light,
        );
        if (signup) {
          await tester.ensureVisible(find.text('New here? Create account'));
          await tester.tap(find.text('New here? Create account'));
          await tester.pumpAndSettle();
          await enter(tester, 'First name', 'Test');
          await enter(tester, 'Last name', 'Person');
          await tester.ensureVisible(find.byType(CheckboxListTile));
          await tester.tap(find.byType(CheckboxListTile));
        }
        await enter(tester, 'Email', 'test@example.test');
        await enter(tester, 'Password', 'safe-test-password');
        await submit(tester, signup ? 'Create account' : 'Sign in');
        expect(
          transport.posts.map((request) => request.path),
          signup
              ? ['/teams', '/inventory-workspaces/$workspaceId/inventories']
              : [
                  '/organizations',
                  '/organizations/$orgId/workspaces',
                  '/inventory-workspaces/$workspaceId/inventories',
                ],
        );
        expect(find.byType(MainShell), findsNothing);
        expect(find.byType(WorldShell), findsOneWidget);
        expect(find.byType(WorkspaceHome), findsNothing);
        expect(find.byType(AuthPage), findsNothing);
        expect(await WorldSetupStore.draft(), isNull);
        expect(
          (await SharedPreferences.getInstance()).getString(
            'findez.active-inventory:$actor',
          ),
          isNull,
        );
        tester.platformDispatcher.textScaleFactorTestValue = 3.2;
        await tester.pump();
        expect(tester.takeException(), isNull);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pump();
        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Workspaces and team tools'));
        await settle(tester);
        expect(find.byType(WorkspaceHome), findsOneWidget);
        await tester.tap(find.text(signup ? 'Tools' : 'Hardware'));
        await settle(tester);
        expect(find.byType(MainShell), findsOneWidget);
        // Switching from the actual dashboard retires its nested inventory
        // navigator and leaves the new organization boundary selected.
        await tester.tap(
          find.bySemanticsLabel(
            'Switch organization. Current: ${signup ? 'Personal' : 'Kestrel Labs'}',
          ),
        );
        await settle(tester);
        await tester.tap(find.text('Personal').last);
        await settle(tester);
        expect(find.byType(MainShell), findsNothing);
        expect(find.byType(WorldShell), findsOneWidget);
        expect(
          find.bySemanticsLabel('Switch organization. Current: Personal'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        Supabase.instance.client.auth.stopAutoRefresh();
      },
    );
  }
  for (final add in [true, false]) {
    testWidgets(
      'existing account explicitly ${add ? 'adds' : 'skips'} prepared setup before any writes',
      (tester) async {
        final transport = await launch(tester);
        transport.hasExistingWorkspace = true;
        await enter(tester, 'Email', 'test@example.test');
        await enter(tester, 'Password', 'safe-test-password');
        await submit(tester, 'Sign in');
        expect(find.text('Add Kestrel Labs to your account?'), findsOneWidget);
        expect(transport.posts, isEmpty);
        final choice = find.text(add ? 'Add it' : 'Skip');
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await settle(tester);
        expect(transport.posts.length, add ? 3 : 0);
        expect(find.byType(MainShell), findsNothing);
        expect(find.byType(WorldShell), findsOneWidget);
        expect(await WorldSetupStore.draft(), isNull);
        expect(
          (await SharedPreferences.getInstance()).containsKey(
            WorldSetupStore.accountKey(actor),
          ),
          isFalse,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        Supabase.instance.client.auth.stopAutoRefresh();
      },
    );
  }
  testWidgets(
    'verification-required signup keeps setup and resend/reset until a real session exists',
    (tester) async {
      confirmationRequired = true;
      final transport = await launch(tester);
      await tester.ensureVisible(find.text('New here? Create account'));
      await tester.tap(find.text('New here? Create account'));
      await tester.pumpAndSettle();
      await enter(tester, 'First name', 'Test');
      await enter(tester, 'Last name', 'Person');
      await enter(tester, 'Email', 'test@example.test');
      await enter(tester, 'Password', 'safe-test-password');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await submit(tester, 'Create account');
      expect(
        find.text('Check your email to confirm your account.'),
        findsOneWidget,
      );
      expect(transport.posts, isEmpty);
      expect((await WorldSetupStore.draft())!.ready, isTrue);
      await tester.ensureVisible(find.text('Resend verification email'));
      await tester.tap(find.text('Resend verification email'));
      await settle(tester);
      expect(authRequests.any((path) => path.endsWith('/resend')), isTrue);
      await tester.ensureVisible(find.text('Already have an account? Sign in'));
      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await settle(tester);
      expect(authRequests.any((path) => path.endsWith('/recover')), isTrue);
      expect(transport.posts, isEmpty);
      await submit(tester, 'Sign in');
      expect(transport.posts.length, 3);
      expect(find.byType(WorldShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      Supabase.instance.client.auth.stopAutoRefresh();
    },
  );
}
