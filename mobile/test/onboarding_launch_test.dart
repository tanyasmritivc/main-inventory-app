import 'dart:async';
import 'dart:convert';

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
import 'package:mobile/features/sharing/invitation_host.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:mobile/main.dart';

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'https://api.test');
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
    for (var step = 0; step < 4; step++) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
    }
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(api.reads, 0);
    expect(await OnboardingPrefs.isCompleted(), isTrue);
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

  testWidgets('returning authenticated users keep their session and Home', (
    tester,
  ) async {
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'test@example.test',
      password: 'test-password',
    );
    await tester.pumpWidget(_gate(_Api()));
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
    expect(find.byType(AuthPage), findsNothing);
    expect(
      Supabase.instance.client.auth.currentUser?.id,
      'onboarding-test-account',
    );
    await tester.pumpWidget(const SizedBox());
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
