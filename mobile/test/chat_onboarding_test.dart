import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

class TrialTransport implements dio.HttpClientAdapter {
  final writes = <Map<String, dynamic>>[];
  final saved = <String, Map<String, dynamic>>{};
  bool loseResponse = false;
  bool partial = false;
  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
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
      final items = (options.data['items'] as List)
          .cast<Map<String, dynamic>>();
      writes.addAll(items);
      final accepted = <int>[];
      for (var i = 0; i < items.length; i++) {
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
    Future<MultiExtractResult> Function()? extract,
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
            photoExtractor: extract == null ? null : (_, _) => extract(),
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
    expect(draft.items.first.item.name, 'Flashlight');
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
      await tester.pumpWidget(MaterialApp(home: LaunchAuthGate(api: api)));
      await pump(tester);
      await tap(tester, 'Continue with email');
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
      await tap(tester, 'Describe a space.');
      await tap(tester, 'Garage');
      expect(find.text('Keep these 12 items'), findsNothing);
      expect(transport.writes, isEmpty);
      await tap(tester, 'Where is the cordless drill?');
      expect(find.text('Garage · Shelf 1'), findsOneWidget);
      expect(find.text('Keep these 12 items'), findsNothing);
      await pump(tester, 1600);
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
    await tap(tester, 'Type a list.');
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
      find.text('That is not in Home yet. Try one of these:'),
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
    'photo authentication rejection retains the photo and opens signup',
    (tester) async {
      final draft = ChatOnboardingDraft()
        ..option = 'snap'
        ..photoPath = '/nonexistent/trial.jpg'
        ..photoPending = true;
      await launch(
        tester,
        draft: draft,
        extract: () async => throw dio.DioException(
          requestOptions: dio.RequestOptions(path: '/extract'),
          response: dio.Response(
            requestOptions: dio.RequestOptions(path: '/extract'),
            statusCode: 401,
          ),
        ),
      );
      await tap(tester, 'Try again');
      expect(
        find.text('Make a free account to read this photo.'),
        findsWidgets,
      );
      expect((await ChatOnboardingStore.read())!.photoPending, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('photo result uses real quantity and unknown remains unknown', (
    tester,
  ) async {
    final photo = File(
      '${Directory.systemTemp.path}/findez-onboarding-test.png',
    );
    photo.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jP1kAAAAASUVORK5CYII=',
      ),
    );
    addTearDown(() => photo.deleteSync());
    final draft = ChatOnboardingDraft()
      ..option = 'snap'
      ..photoPath = photo.path
      ..photoPending = true;
    await launch(
      tester,
      draft: draft,
      extract: () async => MultiExtractResult.fromJson({
        'items': [
          {'name': 'Drill', 'category': 'Tools', 'quantity': 2},
          {
            'name': 'Screws',
            'category': 'Tools',
            'quantity': 1,
            'scan_evidence': {
              'quantity_basis': 'unknown',
              'needs_review': true,
            },
          },
        ],
      }),
    );
    await tap(tester, 'Try again');
    expect((await ChatOnboardingStore.read())!.items.first.item.quantity, 2);
    expect(find.text('?'), findsOneWidget);
    await tap(tester, 'Where is the drill?');
    expect(find.text('Workbench · Workbench'), findsOneWidget);
    await pump(tester, 1600);
    expect(find.text('Keep these 2 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'photo re-extraction retains explicit quantity edits after auth',
    (tester) async {
      await login();
      final draft = ChatOnboardingDraft()
        ..option = 'snap'
        ..photoPath = '/nonexistent/trial.jpg'
        ..photoPending = true
        ..answered = true
        ..items = [
          TrialItem(
            ExtractedInventoryItem.fromJson({
              'name': 'Drill',
              'category': 'Tools',
              'quantity': 7,
            }),
            'Workbench',
          )..quantityEdited = true,
        ];
      await launch(
        tester,
        draft: draft,
        extract: () async => MultiExtractResult.fromJson({
          'items': [
            {'name': 'Drill', 'category': 'Tools', 'quantity': 2},
          ],
        }),
      );
      final restored = (await ChatOnboardingStore.read())!;
      expect(restored.items.single.item.quantity, 7);
      expect(restored.items.single.quantityEdited, isTrue);
      expect(restored.photoPending, isFalse);
      expect(restored.answered, isTrue);
      expect(restored.keep, isTrue);
      expect(
        restored.extractedBy,
        Supabase.instance.client.auth.currentUser!.id,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('offline photo shows retry and Stop ignores late result', (
    tester,
  ) async {
    final pending = Completer<MultiExtractResult>();
    final draft = ChatOnboardingDraft()
      ..option = 'snap'
      ..photoPath = '/nonexistent/trial.jpg'
      ..photoPending = true;
    await launch(tester, draft: draft, extract: () => pending.future);
    await tap(tester, 'Try again');
    await tap(tester, 'Stop');
    pending.complete(
      MultiExtractResult.fromJson({
        'items': [
          {'name': 'Late drill', 'category': '', 'quantity': 1},
        ],
      }),
    );
    await pump(tester);
    expect(find.text('Late drill'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await launch(
      tester,
      draft: draft,
      extract: () async => throw const SocketException('offline'),
    );
    await tap(tester, 'Try again');
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.text('Type a list'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets('intro and list fit $size with reduced motion', (tester) async {
      await launch(tester, size: size, reduce: true);
      expect(tester.takeException(), isNull);
      await tap(tester, 'Type a list.');
      await tap(tester, '20 M3 screws, 4 batteries, a drill and 2 multimeters');
      expect(find.text('M3 screws'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
