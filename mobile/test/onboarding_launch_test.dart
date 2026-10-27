import 'dart:async';
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
import 'package:mobile/core/invitation.dart';
import 'package:mobile/features/auth/auth_page.dart';
import 'package:mobile/features/world/world_shell.dart';
import 'package:mobile/features/world/native_bottom_tabs.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';
import 'package:mobile/features/onboarding/pending_world.dart';
import 'package:mobile/features/sharing/invitation_host.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:mobile/features/inventory/space_directory.dart';
import 'package:mobile/main.dart';
import 'package:mobile/features/workspaces/inventory_context_host.dart';
import 'package:mobile/features/workspaces/workspace_home.dart';

class _LaunchAdapter implements dio.HttpClientAdapter {
  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    final Object result = path == '/inventories/personal-inventory'
        ? {
            'inventory': {
              'inventory_id': 'personal-inventory',
              'name': 'My inventory',
              'team_id': null,
              'role': 'owner',
              'can_edit': true,
              'can_manage': true,
              'can_rename': true,
              'workspace': {
                'workspace_id': 'personal',
                'name': 'Personal',
                'role': 'owner',
              },
            },
          }
        : path == '/inventory-workspaces/personal/directory'
        ? {
            'inventories': [
              {
                'inventory_id': 'personal-inventory',
                'workspace_id': 'personal',
                'name': 'My inventory',
                'role': 'owner',
                'can_open': true,
                'can_edit': true,
                'item_count': 0,
              },
            ],
            'next_offset': null,
          }
        : path.endsWith('/conversations') || path == '/sharing/joined'
        ? []
        : {
            'organizations': [],
            'workspaces': [
              {
                'workspace_id': 'personal',
                'name': 'Personal',
                'kind': 'personal',
                'role': 'owner',
              },
            ],
            'items': [],
            'spaces': [],
            'checkouts': [],
            'pending_count': 0,
            'notifications': [],
            'unread_count': 0,
            'display_name': 'Test',
          };
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

class _Api extends ApiClient {
  _Api()
    : super(
        baseUrl: 'https://api.test',
        httpClient: dio.Dio(dio.BaseOptions(baseUrl: 'https://api.test'))
          ..httpClientAdapter = _LaunchAdapter(),
      );
  int reads = 0;
  @override
  Future<SearchItemsResult> searchItems({required String query}) async {
    reads++;
    return SearchItemsResult(items: [], parsed: const {});
  }

  @override
  Future<ReviewQueueResult> getReviewItems({int limit = 100}) async =>
      const ReviewQueueResult(items: [], pendingCount: 0);
  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => [];
  @override
  Future<List<Map<String, dynamic>>> getActiveCheckouts() async => [];
  @override
  Future<Map<String, dynamic>> getNotifications() async => {'unread_count': 0};
  @override
  Future<Map<String, dynamic>> getMyProfile() async => {'display_name': 'Test'};
  @override
  Future<Map<String, dynamic>> getMyLimits() async => {'tier': 'free'};
}

Widget _gate(_Api api, {Key? key}) => MaterialApp(
  theme: AppTheme.create(Brightness.light),
  home: LaunchAuthGate(key: key, api: api),
);

void main() {
  Future<void> settleHome(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
    }
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://auth.test',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((request) async {
        final user = {
          'id': 'onboarding-test-account',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'test@example.test',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
        };
        String encode(Object data) =>
            base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
        final jwt =
            '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': user['id'], 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.signature';
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/token')
                ? {
                    'access_token': jwt,
                    'refresh_token': 'test-refresh',
                    'expires_in': 3600,
                    'token_type': 'bearer',
                    'user': user,
                  }
                : request.url.path.endsWith('/user')
                ? user
                : {},
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  setUp(() async {
    await Supabase.instance.client.auth.signOut();
    SharedPreferences.setMockInitialValues({});
    OnboardingPrefs.justSignedUp = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.findez.app/push'),
          (_) async => null,
        );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets('fresh launch offers Personal or Team before authentication', (
    tester,
  ) async {
    final api = _Api();
    await tester.pumpWidget(_gate(api));
    await settleHome(tester);
    expect(find.text('Just you, or a team?'), findsOneWidget);
    expect(find.byType(AuthPage), findsNothing);
    expect(find.byType(MainShell), findsNothing);
    expect(api.reads, 0);
    expect(find.text('Memory for physical things.'), findsOneWidget);
    await tester.tap(
      find.text('Already have an account? Sign in', findRichText: true),
    );
    await settleHome(tester);
    expect(find.text('Just you, or a team?'), findsNothing);
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(api.reads, 0);
    expect(await OnboardingPrefs.isCompleted(), isFalse);
    expect(await WorldSetupStore.draft(), isNull);
    expect(await OnboardingPrefs.getPendingFirstSpaceName(), isNull);
  });

  testWidgets(
    'Existing-account shortcut opens auth and signed-out restart offers the choice',
    (tester) async {
      final api = _Api();
      await tester.pumpWidget(_gate(api));
      await settleHome(tester);
      await tester.tap(
        find.text('Already have an account? Sign in', findRichText: true),
      );
      await settleHome(tester);
      expect(find.byType(AuthPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_gate(api, key: const Key('restart')));
      await settleHome(tester);
      expect(find.text('Just you, or a team?'), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
      expect(api.reads, 0);
    },
  );

  testWidgets(
    'signed-out installs see the choice despite the old completed flag',
    (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      await tester.pumpWidget(_gate(_Api()));
      await settleHome(tester);
      expect(find.byType(AuthPage), findsNothing);
      expect(find.text('Just you, or a team?'), findsOneWidget);
    },
  );

  testWidgets('returning authenticated users keep their session and open Ask', (
    tester,
  ) async {
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'test@example.test',
      password: 'test-password',
    );
    await tester.pumpWidget(_gate(_Api()));
    await settleHome(tester);
    expect(find.byType(InventoryContextHost), findsOneWidget);
    expect(find.byType(WorldShell), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(find.text('Just you, or a team?'), findsNothing);
    expect(find.byType(AuthPage), findsNothing);
    expect(
      Supabase.instance.client.auth.currentUser?.id,
      'onboarding-test-account',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'fresh-install inventory entry stays in Spaces across interrupted restart',
    (tester) async {
      addTearDown(Supabase.instance.client.auth.stopAutoRefresh);
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: false);
      await OnboardingPrefs.setCompleted(true);
      await Supabase.instance.client.auth.signInWithPassword(
        email: 'test@example.test',
        password: 'test-password',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'findez.active-inventory:onboarding-test-account',
        'personal-inventory',
      );
      await tester.pumpWidget(_gate(_Api()));
      await settleHome(tester);
      if (usesNativeBottomTabs) {
        tester
            .widget<NativeBottomTabs>(find.byType(NativeBottomTabs))
            .onSelected(2);
      } else {
        await tester.tap(find.byTooltip('More'));
      }
      await settleHome(tester);
      await tester.tap(find.text('Workspaces and team tools'));
      await settleHome(tester);
      expect(find.byType(WorkspaceHome), findsOneWidget);
      await tester.tap(find.text('My inventory'));
      await settleHome(tester);
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(InventorySpacesPage), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      expect(find.byKey(const Key('tutorial-card')), findsNothing);
      expect(find.text('Start at Home'), findsNothing);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settleHome(tester);
      expect(find.byKey(const Key('tutorial-card')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await settleHome(tester);
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: true);
      OnboardingPrefs.justSignedUp = true;
      await OnboardingPrefs.setPostSignupPending(true);
      await tester.pumpWidget(_gate(_Api(), key: const Key('reopened')));
      await settleHome(tester);
      expect(find.byType(WorldShell), findsOneWidget);
      if (usesNativeBottomTabs) {
        tester
            .widget<NativeBottomTabs>(find.byType(NativeBottomTabs))
            .onSelected(2);
      } else {
        await tester.tap(find.byTooltip('More'));
      }
      await settleHome(tester);
      await tester.tap(find.text('Workspaces and team tools'));
      await settleHome(tester);
      expect(find.byType(WorkspaceHome), findsOneWidget);
      await tester.tap(find.text('My inventory'));
      await settleHome(tester);
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(MainShell), findsNothing);
      expect(find.byType(InventorySpacesPage), findsOneWidget);
      expect(find.byKey(const Key('tutorial-card')), findsNothing);
      OnboardingPrefs.justSignedUp = false;
      await tester.pumpWidget(const SizedBox());
      Supabase.instance.client.auth.stopAutoRefresh();
      await tester.pump();
    },
  );

  testWidgets('offline refresh keeps saved sign-in and offers retry', (
    tester,
  ) async {
    final auth = Supabase.instance.client.auth;
    await auth.signInWithPassword(
      email: 'test@example.test',
      password: 'test-only',
    );
    auth.stopAutoRefresh();
    final saved = auth.currentSession!.toJson();
    String encode(Object data) =>
        base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    saved['access_token'] =
        '${encode({'alg': 'HS256'})}.${encode({'sub': auth.currentUser!.id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600})}.signature';
    await auth.setInitialSession(jsonEncode(saved));
    await tester.pumpWidget(_gate(_Api()));
    await tester.pump();
    // Inject the SDK stream error without a real network outage.
    // ignore: invalid_use_of_internal_member
    auth.notifyException(
      AuthRetryableFetchException(message: 'Temporary connection failure'),
    );
    await tester.pump();
    expect(find.text('Reconnect to continue'), findsOneWidget);
    expect(find.byType(AuthPage), findsNothing);
    expect(auth.currentSession, isNotNull);
    await tester.tap(find.text('Retry'));
    await settleHome(tester);
    expect(auth.currentSession!.isExpired, isFalse);
    expect(find.text('Reconnect to continue'), findsNothing);
    expect(find.byType(AuthPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
    auth.stopAutoRefresh();
  });

  for (final kind in ['space', 'team']) {
    testWidgets('$kind invitation survives pre-auth onboarding and restart', (
      tester,
    ) async {
      final api = _Api();
      final navigator = GlobalKey<NavigatorState>();
      final links = StreamController<Uri>.broadcast();
      addTearDown(links.close);
      final inbox = InvitationInbox();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.create(Brightness.light),
          builder: (_, child) => InvitationHost(
            api: api,
            navigatorKey: navigator,
            ready: true,
            inbox: inbox,
            incomingLinks: links.stream,
            initialLink: () async => null,
            child: child!,
          ),
          home: LaunchAuthGate(api: api),
        ),
      );
      await settleHome(tester);
      links.add(
        Uri.parse(
          'https://www.findez.ai/join/${kind == 'team' ? 'team/' : ''}ZZZZZZ',
        ),
      );
      await settleHome(tester);
      expect(inbox.pending?.kind, kind);
      expect(find.text('Just you, or a team?'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(
        find.text('Already have an account? Sign in', findRichText: true),
      );
      await settleHome(tester);
      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
      final restored = InvitationInbox();
      await restored.restore();
      expect(restored.pending?.kind, kind);
      expect(restored.pending?.code, 'ZZZZZZ');
      expect(restored.ownerId, isNull);
      expect(api.reads, 0);
      await tester.pumpWidget(_gate(api));
      await settleHome(tester);
      expect(find.text('Just you, or a team?'), findsOneWidget);
    });
  }
}
