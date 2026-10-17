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
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';
import 'package:mobile/features/onboarding/pending_world.dart';
import 'package:mobile/features/sharing/invitation_host.dart';
import 'package:mobile/features/shell/main_shell.dart';
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
      anonKey: 'test',
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

  testWidgets('fresh launch completes onboarding BEFORE authentication', (
    tester,
  ) async {
    final api = _Api();
    await tester.pumpWidget(_gate(api));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.byType(AuthPage), findsNothing);
    expect(find.byType(MainShell), findsNothing);
    expect(api.reads, 0);
    final choices = [
      'world-path-personal',
      'world-chip-Home',
      'world-chip-Tools',
    ];
    for (final choice in choices) {
      await tester.ensureVisible(find.byKey(Key(choice)));
      await tester.tap(find.byKey(Key(choice)));
      await tester.pumpAndSettle();
    }
    expect(find.text('This is your world.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('onboarding-next')));
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(api.reads, 0);
    expect(await OnboardingPrefs.isCompleted(), isTrue);
    expect((await WorldSetupStore.draft())!.ready, isTrue);
    expect(find.text('Your dashboard is ready'), findsOneWidget);
    expect(await OnboardingPrefs.getPendingFirstSpaceName(), isNull);
  });

  testWidgets(
    'Skip opens auth and a restart does not replay the introduction',
    (tester) async {
      final api = _Api();
      await tester.pumpWidget(_gate(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_gate(api, key: const Key('restart')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(AuthPage), findsOneWidget);
      expect(api.reads, 0);
    },
  );

  testWidgets('legacy completed installs retain the authentication flow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await tester.pumpWidget(_gate(_Api()));
    await tester.pumpAndSettle();
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets(
    'returning authenticated users keep their session and open their place home',
    (tester) async {
      await Supabase.instance.client.auth.signInWithPassword(
        email: 'test@example.test',
        password: 'test-password',
      );
      await tester.pumpWidget(_gate(_Api()));
      await settleHome(tester);
      expect(find.byType(InventoryContextHost), findsOneWidget);
      expect(find.byType(WorkspaceHome), findsOneWidget);
      expect(find.byType(MainShell), findsNothing);
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(AuthPage), findsNothing);
      expect(
        Supabase.instance.client.auth.currentUser?.id,
        'onboarding-test-account',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'fresh-install Home tour is not replayed after interrupted restart',
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
      await tester.tap(find.text('My inventory'));
      await settleHome(tester);
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const Key('tutorial-card')), findsOneWidget);
      expect(find.text('Start at Home'), findsOneWidget);
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
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutorial-card')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: true);
      OnboardingPrefs.justSignedUp = true;
      await OnboardingPrefs.setPostSignupPending(true);
      await tester.pumpWidget(_gate(_Api(), key: const Key('reopened')));
      await settleHome(tester);
      expect(find.byType(WorkspaceHome), findsOneWidget);
      await tester.tap(find.text('My inventory'));
      await settleHome(tester);
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byKey(const Key('tutorial-card')), findsNothing);
      OnboardingPrefs.justSignedUp = false;
      await tester.pumpWidget(const SizedBox());
      Supabase.instance.client.auth.stopAutoRefresh();
      await tester.pump();
    },
  );

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
      await tester.pumpAndSettle();
      links.add(
        Uri.parse(
          'https://www.findez.ai/join/${kind == 'team' ? 'team/' : ''}ZZZZZZ',
        ),
      );
      await tester.pumpAndSettle();
      expect(inbox.pending?.kind, kind);
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
    });
  }
}
