import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/main.dart';
import 'package:mobile/features/chat/chat_page.dart';
import 'package:mobile/features/world/world_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/auth/auth_page.dart';
import 'package:mobile/features/onboarding/chat_onboarding_draft.dart';
import 'package:mobile/features/onboarding/chat_onboarding_page.dart';
import 'package:mobile/features/onboarding/chat_onboarding_save.dart';
import 'package:mobile/features/onboarding/chat_onboarding_gate.dart';
import 'package:mobile/features/onboarding/sample_scan.dart';
import 'package:mobile/core/first_camera_hint.dart';

class TrialTransport implements dio.HttpClientAdapter {
  final requests = <String>[];
  final writes = <Map<String, dynamic>>[];
  final saved = <String, Map<String, dynamic>>{};
  bool loseResponse = false;
  bool partial = false;
  bool failSave = false;
  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options.path);
    Object response;
    if (options.path == '/inventory-workspaces/personal/inventories') {
      response = {
        'inventories': [
          {'inventory_id': 'default', 'is_default': true},
        ],
        'next_offset': null,
      };
    } else if (options.path == '/inventories/default') {
      response = {
        'inventory': {
          'inventory_id': 'default',
          'name': 'Personal inventory',
          'team_id': null,
          'role': 'owner',
          'can_edit': true,
          'can_manage': true,
          'can_rename': true,
          'workspace': {'workspace_id': 'personal', 'name': 'Personal'},
        },
      };
    } else if (options.path == '/inventories/default/spaces') {
      response = {
        'space': {'id': 'space-id', 'name': options.data['name']},
      };
    } else if (options.path == '/inventories/default/inventory/bulk_create') {
      if (failSave) {
        throw dio.DioException(
          requestOptions: options,
          type: dio.DioExceptionType.connectionError,
        );
      }
      final items = (options.data['items'] as List)
          .cast<Map<String, dynamic>>();
      writes.addAll(items);
      final accepted = <int>[];
      for (var i = 0; i < items.length; i++) {
        // Match the real capture-save required-field contract.
        if ([
          'name',
          'category',
          'location',
        ].any((field) => (items[i][field] as String? ?? '').trim().isEmpty)) {
          throw StateError('Name, category and location are required.');
        }
        if (partial && i > 0) continue;
        saved.putIfAbsent(
          items[i]['client_request_id'],
          () => {'item_id': 'item-$i', ...items[i]},
        );
        accepted.add(i);
      }
      if (loseResponse) {
        loseResponse = false;
        throw dio.DioException(
          requestOptions: options,
          type: dio.DioExceptionType.receiveTimeout,
        );
      }
      response = {
        'inserted': accepted
            .map((i) => saved[items[i]['client_request_id']])
            .toList(),
        'accepted_indices': accepted,
        'failures': partial
            ? [
                {'index': 1, 'reason': 'Retry'},
              ]
            : [],
      };
    } else if (options.path == '/inventory-workspaces') {
      response = {
        'workspaces': [
          {'workspace_id': 'personal', 'name': 'Personal', 'role': 'owner'},
        ],
      };
    } else if (options.path == '/organizations') {
      response = {'organizations': []};
    } else if (options.path.endsWith('/conversations') ||
        options.path == '/sharing/joined') {
      response = [];
    } else if (options.method == 'GET') {
      response = {
        'items': [],
        'parsed': {},
        'spaces': [],
        'inventories': [],
        'checkouts': [],
        'pending_count': 0,
        'notifications': [],
        'unread_count': 0,
        'display_name': 'Test',
        'tier': 'free',
        'shares': [],
      };
    } else {
      throw StateError('Unexpected API ${options.path}');
    }
    return dio.ResponseBody.fromString(
      jsonEncode(response),
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
  late TrialTransport transport;
  late ApiClient api;
  String actor = 'trial-user';
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://auth.test',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((request) async {
        final user = {
          'id': actor,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'trial@example.test',
          'email_confirmed_at': '2026-01-01T00:00:00Z',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
          'is_anonymous': false,
        };
        String encode(Object data) =>
            base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
        final jwt =
            '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': actor, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.signature';
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
    actor = 'trial-user';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.findez.app/push'),
          (_) async => null,
        );
    transport = TrialTransport();
    api = ApiClient(
      baseUrl: 'https://api.test',
      httpClient: dio.Dio(dio.BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = transport,
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  Future<void> pump(WidgetTester tester, [int milliseconds = 1000]) async {
    for (var elapsed = 0; elapsed < milliseconds; elapsed += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
    }
  }

  Future<void> launch(
    WidgetTester tester, {
    ChatOnboardingDraft? draft,
    bool reduce = false,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: reduce),
          child: ChatOnboardingPage(
            api: api,
            initialDraft: draft,
            showWorld: false,
          ),
        ),
      ),
    );
    await pump(tester);
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text, findRichText: true).last;
    await tester.ensureVisible(target);
    final rect = tester.getRect(target);
    final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(
      Offset(
        rect.left.clamp(16, viewport.width - 32).toDouble() + 8,
        rect.center.dy,
      ),
    );
    await pump(tester);
  }

  Future<void> login() => Supabase.instance.client.auth.signInWithPassword(
    email: 'trial@example.test',
    password: 'test-password',
  );

  test('prototype templates and spots are local and deterministic', () async {
    final templates = await TrialTemplates.load();
    for (final space in [
      'Garage',
      'Workshop',
      'Kitchen',
      'Lab',
      'Closet',
      'Craft room',
      'Dorm room',
      'Home',
    ]) {
      final draft = ChatOnboardingDraft();
      templates.describe(draft, space);
      expect(draft.items.length, 12);
      expect(draft.space, space);
      expect(draft.items.every((i) => i.spot.isNotEmpty), isTrue);
    }
    final draft = ChatOnboardingDraft();
    templates.describe(draft, 'my dorm room');
    expect(draft.space, 'Dorm room');
    expect(draft.items.first.item.name, 'Laptop charger');
    templates.describe(draft, 'Garage');
    expect(draft.items[1].spot, 'Bin B');
    expect(transport.writes, isEmpty);
  });
  test(
    'list parser handles leading phrases, numbers, words and separators without dropping long lists',
    () {
      final items = TrialTemplates.parseList(
        'I have 20 M3 screws, four batteries; a drill and 2 multimeters\nDuct tape',
      );
      expect(items.map((i) => i.quantity), [20, 4, 1, 2, 1]);
      expect(items.map((i) => i.name), [
        'M3 screws',
        'Batteries',
        'Drill',
        'Multimeters',
        'Duct tape',
      ]);
      expect(
        TrialTemplates.parseList(
          List.generate(20, (i) => '1 item $i').join(','),
        ).length,
        20,
      );
    },
  );
  test(
    'durable snapshots retain edits and receipt IDs across restart',
    () async {
      final draft = ChatOnboardingDraft()..option = 'list';
      (await TrialTemplates.load()).list(draft, '3 hammers');
      final first = ChatOnboardingStore.save(draft);
      draft.items.first.item.quantity = 7;
      final second = ChatOnboardingStore.save(draft);
      await Future.wait([first, second]);
      final restored = (await ChatOnboardingStore.read())!;
      expect(restored.id, draft.id);
      expect(restored.items.first.item.quantity, 7);
    },
  );
  for (final partial in [false, true]) {
    test(
      'save survives ${partial ? 'partial receipt' : 'lost response'} and restart without duplicates',
      () async {
        await login();
        final draft = ChatOnboardingDraft()
          ..method = 'email'
          ..keep = true;
        (await TrialTemplates.load()).list(draft, '3 hammers, a drill');
        transport.loseResponse = !partial;
        transport.partial = partial;
        await expectLater(
          ChatOnboardingSaver(api).save(draft),
          throwsA(anything),
        );
        final restored = (await ChatOnboardingStore.read())!;
        expect(restored.saving, isTrue);
        expect(restored.complete, isFalse);
        transport.partial = false;
        await ChatOnboardingSaver(api).save(restored);
        expect(transport.saved.length, 2);
        expect(
          transport.writes.map((i) => i['client_request_id']).toSet().length,
          2,
        );
        expect(
          transport.writes.every((i) => i['location'] == 'Workshop'),
          isTrue,
        );
        expect((await ChatOnboardingStore.read())!.complete, isTrue);
      },
    );
  }
  test(
    'legacy startup draft supplies category without changing retry IDs',
    () async {
      await login();
      final draft = ChatOnboardingDraft(id: 'legacy')
        ..method = 'email'
        ..option = 'list'
        ..keep = true
        ..saving = true
        ..items = [
          TrialItem(
            ExtractedInventoryItem(name: 'Hammer', category: '', quantity: 2),
            'Shelf',
          ),
          TrialItem(
            ExtractedInventoryItem(
              name: 'Drill',
              category: 'Tools',
              quantity: 1,
            ),
            'Shelf',
          ),
        ];
      await ChatOnboardingStore.save(draft);
      final restored = (await ChatOnboardingStore.read())!;
      await ChatOnboardingSaver(api).save(restored);
      expect(transport.writes.map((item) => item['category']), [
        'Other',
        'Tools',
      ]);
      expect(transport.writes.map((item) => item['client_request_id']), [
        'onboarding-legacy-0',
        'onboarding-legacy-1',
      ]);
      expect(restored.complete, isTrue);
      expect(transport.saved.length, 2);
    },
  );

  testWidgets(
    'startup failed save can continue without losing or repeating draft',
    (tester) async {
      await login();
      final draft = ChatOnboardingDraft()
        ..method = 'email'
        ..option = 'list'
        ..keep = true;
      (await TrialTemplates.load()).list(draft, '2 hammers');
      await ChatOnboardingStore.save(draft);
      transport.failSave = true;
      await tester.pumpWidget(MaterialApp(home: ChatOnboardingGate(api: api)));
      await pump(tester);
      expect(find.text('Continue to app'), findsOneWidget);
      expect(
        find.textContaining('Your setup draft is still on this device'),
        findsOneWidget,
      );
      final attempts = transport.requests
          .where((p) => p.endsWith('/bulk_create'))
          .length;
      expect(attempts, 1);
      await tester.tap(find.text('Continue to app'));
      await pump(tester);
      expect(find.byType(WorldShell), findsOneWidget);
      expect((await ChatOnboardingStore.read())!.id, draft.id);
      expect((await ChatOnboardingStore.read())!.complete, isFalse);
      expect(
        transport.requests.where((p) => p.endsWith('/bulk_create')).length,
        attempts,
      );
      // A new launch can complete the same draft after the connection returns.
      await tester.pumpWidget(const SizedBox());
      transport.failSave = false;
      await tester.pumpWidget(MaterialApp(home: ChatOnboardingGate(api: api)));
      await pump(tester);
      expect(find.byType(WorldShell), findsOneWidget);
      expect(transport.saved.length, 1);
      expect(await ChatOnboardingStore.read(), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'startup unreadable draft is preserved and does not trap app entry',
    (tester) async {
      await login();
      final prefs = await SharedPreferences.getInstance();
      const raw = '{legacy-unreadable-draft';
      await prefs.setString(ChatOnboardingStore.key, raw);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(3.2)),
            child: child!,
          ),
          home: ChatOnboardingGate(api: api),
        ),
      );
      await pump(tester);
      expect(
        find.text('We could not open your saved setup draft.'),
        findsOneWidget,
      );
      expect(find.textContaining('Check your connection'), findsNothing);
      await tester.ensureVisible(find.text('Continue to app'));
      await tester.tap(find.text('Continue to app'));
      await pump(tester);
      expect(find.byType(WorldShell), findsOneWidget);
      expect(prefs.getString(ChatOnboardingStore.key), raw);
      expect(transport.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('another account cannot retry a claimed draft', () async {
    await login();
    final draft = ChatOnboardingDraft()
      ..owner = 'other'
      ..items = [
        TrialItem(
          ExtractedInventoryItem(name: 'Drill', category: '', quantity: 1),
          'Shelf',
        ),
      ];
    await expectLater(ChatOnboardingSaver(api).save(draft), throwsStateError);
    expect(transport.writes, isEmpty);
  });
  testWidgets(
    'auth saves retained trial to Personal and opens Ask with its Space selected',
    (tester) async {
      final draft = ChatOnboardingDraft()
        ..option = 'list'
        ..answered = true
        ..keep = true;
      (await TrialTemplates.load()).list(draft, '3 hammers, a drill');
      await ChatOnboardingStore.save(draft);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      draft.method = 'email';
      await ChatOnboardingStore.save(draft);
      await tester.pumpWidget(MaterialApp(home: LaunchAuthGate(api: api)));
      await pump(tester);
      await tester.tap(
        find.text('Already have an account? Sign in', findRichText: true),
      );
      await pump(tester);
      await tester.tap(find.byKey(const Key('auth-more-options')));
      await pump(tester);
      await tester.tap(find.byKey(const Key('auth-email-option')));
      await pump(tester);
      expect(find.byType(AuthPage), findsOneWidget);
      for (final entry in {
        'Email': 'trial@example.test',
        'Password': 'test-password',
      }.entries) {
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == entry.key,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      final button = find.widgetWithText(FilledButton, 'Sign in');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await pump(tester, 2500);
      expect(find.byType(AuthPage), findsNothing);
      expect(find.byType(WorldShell), findsOneWidget);
      expect(find.byType(ChatPage), findsOneWidget);
      expect(
        tester.widget<ChatPage>(find.byType(ChatPage)).initialSource?.name,
        'Workshop',
      );
      expect(transport.saved.length, 2);
      expect(await ChatOnboardingStore.read(), isNull);
      expect(find.text('Saved 2 items to Workshop'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      Supabase.instance.client.auth.stopAutoRefresh();
    },
  );

  testWidgets(
    'Describe reaches an answer before Keep; no network or continue step',
    (tester) async {
      await launch(tester);
      await tap(tester, 'Describe a space');
      await tester.enterText(find.byType(TextField), 'Garage');
      await tester.tap(find.byTooltip('Send'));
      await pump(tester);
      expect(find.text('Keep these 12 items'), findsNothing);
      expect(transport.writes, isEmpty);
      await tap(tester, 'Where is the cordless drill?');
      expect(find.text('Garage · Shelf 1'), findsOneWidget);
      expect(find.text('Keep these 12 items'), findsNothing);
      await pump(tester, 2000);
      expect(find.text('Keep these 12 items'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Type accepts edits, typed questions and no-match suggestions', (
    tester,
  ) async {
    await launch(tester, reduce: true);
    await tap(tester, 'Type a list');
    await tester.enterText(find.byType(TextField), '3 hammers, duct tape');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byTooltip('Send'));
    await tester.tap(find.byTooltip('Send'));
    await pump(tester);
    final quantity = find.bySemanticsLabel('Hammers quantity 3. Edit quantity');
    await tester.ensureVisible(quantity);
    await tester.tap(quantity);
    await pump(tester, 50);
    await tester.tap(find.byTooltip('Increase Hammers'));
    await pump(tester, 50);
    expect((await ChatOnboardingStore.read())!.items.first.item.quantity, 4);
    await tester.tap(find.byType(TextField));
    await pump(tester, 500);
    await tester.enterText(find.byType(TextField), 'where is the elephant?');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byTooltip('Send'));
    await tester.tap(find.byTooltip('Send'));
    await pump(tester);
    expect(
      find.text('That is not on this list yet. Try one of these:'),
      findsOneWidget,
    );
    expect(find.text('Keep these 2 items'), findsNothing);
    await tester.tap(find.byType(TextField));
    await pump(tester, 500);
    await tester.enterText(find.byType(TextField), 'how many hammers?');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byTooltip('Send'));
    await tester.tap(find.byTooltip('Send'));
    await pump(tester);
    expect(find.text('4 hammers in Home.', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('sign-in shortcut keeps existing auth entry', (tester) async {
    await launch(tester);
    await tap(tester, 'Already have an account? Sign in');
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to your inventory.'), findsOneWidget);
    expect(transport.writes, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'sample demo runs offline, answers model, and only opens Keep once',
    (tester) async {
      await launch(tester);
      await tap(tester, 'Scan it');
      expect(find.text('Scanning the sample photo...'), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
      await pump(tester, 2000);
      expect(find.text('Battery charger'), findsOneWidget);
      expect(find.text('Makita · DC18RC'), findsOneWidget);
      expect((await ChatOnboardingStore.read())!.items.length, 7);
      await tap(tester, 'What model is the charger?');
      expect(
        find.text(
          'The battery charger is a Makita DC18RC, read from its label.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('Now try it on real stuff'), findsNothing);
      await pump(tester, 2000);
      expect(find.text('Now try it on real stuff'), findsOneWidget);
      await tap(tester, 'Ask another question');
      expect(find.text('Now try it on real stuff'), findsNothing);
      await tap(tester, 'Where is the battery pack, 18v?');
      await pump(tester, 3500);
      expect(find.text('Now try it on real stuff'), findsNothing);
      expect(transport.writes, isEmpty);
      expect(Supabase.instance.client.auth.currentSession, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'sample reduced motion shows boxes and quantities without a sweep',
    (tester) async {
      await launch(tester, reduce: true);
      await tap(tester, 'Scan it');
      expect(find.text('Scanning the sample photo...'), findsNothing);
      expect(find.text('charger'), findsOneWidget);
      await tap(tester, 'How many screws?');
      expect(
        find.text('14 socket head screws in Workbench.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Workbench · Front bin'), findsOneWidget);
      expect(transport.writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('native Reduce Motion changes are respected during onboarding', (
    tester,
  ) async {
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await launch(tester);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    await tester.pump();
    await tap(tester, 'Scan it');
    expect(find.text('Scanning the sample photo...'), findsNothing);
    expect(find.text('charger'), findsOneWidget);
    expect(transport.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'sample save and retry never write demo items, hint is account-bound',
    () async {
      await login();
      final sample = await TrialSample.load();
      final draft = ChatOnboardingDraft()
        ..option = 'sample'
        ..space = sample.space
        ..items = sample.newItems()
        ..method = 'email'
        ..keep = true;
      await ChatOnboardingSaver(api).save(draft);
      expect(draft.complete, isTrue);
      expect(transport.writes, isEmpty);
      expect(transport.requests, isEmpty);
      expect(await FirstCameraHint.pending(actor), isTrue);
      expect(await FirstCameraHint.pending('other-user'), isFalse);
      await FirstCameraHint.consume(actor);
      await ChatOnboardingSaver(api).save((await ChatOnboardingStore.read())!);
      expect(transport.writes, isEmpty);
      expect(await FirstCameraHint.pending(actor), isFalse);
    },
  );
  testWidgets(
    'sample auth lands in empty Ask with camera hint and no demo items',
    (tester) async {
      final sample = await TrialSample.load();
      final draft = ChatOnboardingDraft()
        ..option = 'sample'
        ..space = sample.space
        ..items = sample.newItems()
        ..method = 'email'
        ..answered = true
        ..keep = true;
      await ChatOnboardingStore.save(draft);
      await login();
      await tester.pumpWidget(MaterialApp(home: LaunchAuthGate(api: api)));
      await pump(tester, 2500);
      expect(find.byType(ChatPage), findsOneWidget);
      expect(
        tester.widget<ChatPage>(find.byType(ChatPage)).initialSource,
        isNull,
      );
      expect(find.byTooltip('Snap a shelf'), findsOneWidget);
      expect(find.text('Snap a shelf to add your first items'), findsOneWidget);
      expect(transport.writes, isEmpty);
      expect(await ChatOnboardingStore.read(), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      Supabase.instance.client.auth.stopAutoRefresh();
    },
  );
  testWidgets(
    'old camera draft restarts safely without extraction or anonymous sign-in',
    (tester) async {
      final draft = ChatOnboardingDraft()
        ..option = 'snap'
        ..photoPending = true
        ..photoPath = '/old-photo.jpg';
      await launch(tester, draft: draft);
      expect(find.text('Scan it'), findsOneWidget);
      expect(Supabase.instance.client.auth.currentSession, isNull);
      expect(transport.writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'restart cancels sample callbacks and does not restore old rows',
    (tester) async {
      await launch(tester);
      await tap(tester, 'Scan it');
      await tester.tap(find.byTooltip('Start over'));
      await pump(tester, 2500);
      expect(find.text('Scan it'), findsOneWidget);
      expect(find.text('Battery charger'), findsNothing);
      expect((await ChatOnboardingStore.read())!.items, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final example in {
    'my dorm room': 'Laptop charger',
    'a university room': 'Laptop charger',
    'my home': 'Flashlight',
    'science lab': 'Safety goggles',
    'workshop': 'Cordless drill',
  }.entries) {
    test('local starter fits ${example.key}', () async {
      final draft = ChatOnboardingDraft();
      (await TrialTemplates.load()).describe(draft, example.key);
      expect(draft.items.first.item.name, example.value);
      expect(transport.requests, isEmpty);
    });
  }
  testWidgets(
    'first real camera tap consumes the hint even when photo is cancelled',
    (tester) async {
      await login();
      await FirstCameraHint.arm(actor);
      final worldApi = ApiClient.forWorld(
        api,
        'personal',
        isCurrent: () => true,
      );
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPage(
              api: worldApi,
              worldHeading: 'Your physical world, remembered.',
              photoPicker: (camera) async {
                expect(camera, isTrue);
                opened++;
                return null;
              },
            ),
          ),
        ),
      );
      await pump(tester);
      await tester.tap(find.byTooltip('Snap a shelf'));
      await pump(tester);
      expect(opened, 1);
      expect(await FirstCameraHint.pending(actor), isFalse);
      expect(find.byTooltip('Snap a shelf'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      Supabase.instance.client.auth.stopAutoRefresh();
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets('intro and list fit $size with reduced motion', (tester) async {
      await launch(tester, size: size, reduce: true);
      expect(tester.takeException(), isNull);
      await tap(tester, 'Type a list');
      await tap(tester, '2 phone chargers, 3 notebooks and spare keys');
      expect(find.text('Phone chargers'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
