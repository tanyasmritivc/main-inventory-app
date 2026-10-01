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
import 'package:mobile/core/ask_answer.dart';
import 'package:mobile/features/chat/ask_answer_view.dart';
import 'package:mobile/features/chat/chat_page.dart';
import 'package:mobile/features/shell/home_navigation.dart';

final _context = AskAnswerContext.fromJson({
  'sources': [
    {
      'kind': 'project',
      'label': 'Loft shelving',
      'detail': 'Project requirements checked',
    },
    {
      'kind': 'inventory',
      'label': 'Garage',
      'detail': 'Current available stock checked',
    },
  ],
  'rows': [
    {
      'id': 'a',
      'name': '6 mm masonry bit',
      'available_quantity': 0,
      'required_quantity': 1,
    },
    {
      'id': 'b',
      'name': 'Shelf pin',
      'available_quantity': 0,
      'required_quantity': 24,
    },
    {
      'id': 'c',
      'name': 'Hex bolt, M4 x 20',
      'available_quantity': 14,
      'required_quantity': 40,
    },
    {
      'id': 'd',
      'name': 'Steel L bracket',
      'available_quantity': 8,
      'required_quantity': 8,
    },
  ],
});

class _AskApi extends ApiClient {
  _AskApi({this.fail = false, this.pending})
    : super(baseUrl: 'https://api.test');
  final bool fail;
  final StreamController<AiStreamEvent>? pending;
  final List<String?> conversationIds = [];
  final List<AskPhoto> photos = [];
  final List<String> photoQuestions = [];
  @override
  Stream<AiStreamEvent> aiPhotoQuestionStream({
    required String message,
    required AskPhoto photo,
    String? conversationId,
  }) async* {
    photos.add(photo);
    photoQuestions.add(message);
    if (fail) {
      throw const AskRequestException(
        'Your photo could not be analyzed. Please try again.',
      );
    }
    yield AiStreamEvent(type: 'status', message: 'Reading your photo...');
    if (pending != null) {
      yield* pending!.stream;
      return;
    }
    yield AiStreamEvent(
      type: 'delta',
      delta: 'This appears to be a servo. No inventory item has been added.',
    );
    yield AiStreamEvent(type: 'done', conversationId: 'photo-conversation');
  }

  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(items: const [], parsed: const {});
  @override
  Stream<AiStreamEvent> aiCommandStream({
    required String message,
    String? conversationId,
  }) async* {
    conversationIds.add(conversationId);
    if (pending != null) {
      yield* pending!.stream;
      return;
    }
    if (fail) throw StateError('SECRET internal failure');
    yield AiStreamEvent(
      type: 'delta',
      delta: 'You have enough stock for 1 of the 4 required parts.',
    );
    yield AiStreamEvent(
      type: 'done',
      answerContext: _context,
      conversationId: 'conversation-1',
    );
  }
}

Widget _page(
  _AskApi api, {
  String? initialMessage,
  TextScaler scaler = TextScaler.noScaling,
  Future<AskPhoto?> Function(bool camera)? photoPicker,
}) => MaterialApp(
  theme: ThemeData.dark(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: scaler),
    child: child!,
  ),
  home: Scaffold(
    body: ChatPage(
      api: api,
      inPageView: true,
      initialMessage: initialMessage,
      photoPicker: photoPicker,
    ),
    bottomNavigationBar: HomeNavigation(selectedIndex: 2, onSelected: (_) {}),
  ),
);

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==',
  );
  Future<void> attach(WidgetTester tester, {bool camera = false}) async {
    await tester.tap(find.byTooltip('Attach photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(camera ? 'Take photo' : 'Choose photo'));
    await tester.pumpAndSettle();
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugin.csdcorp.com/speech_to_text'),
          (_) async => false,
        );
  });

  test(
    'structured rows derive badges from counts and reject invalid input',
    () {
      final data = AskAnswerContext.fromJson({
        'sources': [
          {'kind': 'internal_tool', 'label': 'SECRET'},
          {'kind': 'inventory', 'label': 'Inventory'},
        ],
        'rows': [
          {
            'name': 'Bolt',
            'available_quantity': 2,
            'required_quantity': 10,
            'status': 'have',
          },
          {'name': 'Invalid', 'available_quantity': -1},
          {'name': 'Fractional', 'available_quantity': 0.5},
          {'name': 'Broken', 'available_quantity': '1'},
        ],
      });
      expect(data.sources.single.kind, 'inventory');
      expect(data.rows.single.status, 'low');
    },
  );

  test('SSE decoder preserves fragmented UTF-8 and additive context', () async {
    final text =
        'data: {"content":"Drill - café"}\n\n'
        'data: ${jsonEncode({
          'type': 'done',
          'conversation_id': 'conversation-1',
          'answer_context': {'sources': [], 'rows': []},
        })}\n\n'
        'data: [DONE]\n\n';
    final bytes = utf8.encode(text);
    final events = await decodeAiCommandEvents(
      Stream.fromIterable(bytes.map((b) => [b])),
    ).toList();
    expect(events.first.delta, 'Drill - café');
    expect(events[1].conversationId, 'conversation-1');
    expect(events[1].answerContext, isNotNull);
  });

  test('SSE error never exposes internal server exception', () async {
    final events = decodeAiCommandEvents(
      Stream.value(utf8.encode('data: {"error":"SECRET provider stack"}\n\n')),
    );
    await expectLater(
      events.toList(),
      throwsA(predicate((e) => !e.toString().contains('SECRET'))),
    );
  });

  test('saved conversation restores its original source snapshot', () {
    final message = ConversationMessage.fromJson({
      'id': 'message-1',
      'role': 'assistant',
      'content': 'Answer',
      'created_at': '2026-09-30T12:00:00Z',
      'answer_context': {
        'sources': [
          {'kind': 'inventory', 'label': 'Garage'},
        ],
        'rows': [
          {'name': 'Bolt', 'available_quantity': 14, 'required_quantity': 40},
        ],
      },
    });
    expect(message.answerContext?.sources.single.label, 'Garage');
    expect(message.answerContext?.rows.single.status, 'low');
  });

  test('local conversation scope resets on account switch and sign-out', () {
    final scope = AskSessionScope();
    expect(scope.selectAccount('account-a'), isTrue);
    expect(scope.selectAccount('account-a'), isFalse);
    expect(scope.selectAccount('account-b'), isTrue);
    expect(scope.selectAccount(null), isTrue);
    expect(scope.selectAccount(null), isTrue);
    expect(scope.selectAccount('account-a'), isTrue);
  });

  testWidgets(
    'reference has question card, collapsed sources and grounded readiness rows',
    (tester) async {
      await tester.pumpWidget(
        _page(
          _AskApi(),
          initialMessage: 'What do I still need to finish the loft shelving?',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ask FindEZ'), findsOneWidget);
      expect(find.byType(AskQuestionCard), findsOneWidget);
      expect(find.text('What it read'), findsOneWidget);
      expect(find.byKey(const Key('ask-sources')), findsNothing);
      expect(find.text('14 of 40'), findsOneWidget);
      expect(find.text('missing'), findsNWidgets(2));
      expect(find.text('low'), findsOneWidget);
      expect(find.text('have'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
      await tester.ensureVisible(find.text('What it read'));
      await tester.tap(find.text('What it read'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ask-sources')), findsOneWidget);
      expect(find.text('Loft shelving'), findsOneWidget);
      await tester.tap(find.text('What it read'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ask-sources')), findsNothing);
    },
  );

  testWidgets(
    'missing context stays a plain answer without invented evidence or rows',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AskAnswerView(answer: 'Tell me which project you mean.'),
          ),
        ),
      );
      expect(find.text('What it read'), findsNothing);
      expect(find.text('missing'), findsNothing);
    },
  );

  testWidgets('stream failure is visible and never produces a success table', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(_AskApi(fail: true), initialMessage: 'Where is my drill?'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('SECRET'), findsNothing);
    expect(find.text('What it read'), findsNothing);
  });

  testWidgets('conversation ID survives follow-ups and new chat clears it', (
    tester,
  ) async {
    final api = _AskApi();
    await tester.pumpWidget(
      _page(api, initialMessage: 'What do I need for loft shelving?'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'And the bolts?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(api.conversationIds, [null, 'conversation-1']);
    await tester.scrollUntilVisible(
      find.text('New chat'),
      -250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    expect(find.byType(AskQuestionCard), findsNothing);
    await tester.enterText(find.byType(TextField), 'A fresh question');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(api.conversationIds.last, isNull);
  });

  testWidgets('new chat ignores late events from a reset request', (
    tester,
  ) async {
    final pending = StreamController<AiStreamEvent>();
    await tester.pumpWidget(
      _page(_AskApi(pending: pending), initialMessage: 'Question'),
    );
    await tester.pump();
    await tester.tap(find.text('New chat'));
    pending.add(AiStreamEvent(type: 'delta', delta: 'Stale answer'));
    await pending.close();
    await tester.pumpAndSettle();
    expect(find.textContaining('Stale answer'), findsNothing);
    expect(find.byType(AskQuestionCard), findsNothing);
  });

  testWidgets('narrow large-text result stays scrollable above pill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _page(
        _AskApi(),
        initialMessage: 'What do I still need to finish the loft shelving?',
        scaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Steel L bracket'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('generated answer images cannot load third-party content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AskAnswerView(
            answer: '![tracker](https://untrusted.test/track.png)',
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
  });

  test(
    'photo sources restore and previews reject arbitrary origins and owners',
    () {
      final path =
          '/storage/v1/object/public/item-images/account-a/ask-${'a' * 32}.jpg';
      final url = 'https://api.test$path';
      String? safe(String? value, {String? owner = 'account-a'}) =>
          trustedAskPhotoUrl(
            value,
            owner: owner,
            origins: ['https://api.test', ''],
          );
      expect(safe(url), url);
      expect(
        safe('${url.replaceFirst('/public/', '/sign/')}?token=valid'),
        isNotNull,
      );
      for (final value in [
        url.replaceFirst('api.test', 'evil.test'),
        url.replaceFirst('https:', 'http:'),
        url.replaceFirst('account-a', 'account-b'),
        url.replaceFirst('ask-', '../ask-'),
        url.replaceFirst('ask-', 'item-'),
        'https://api.test@evil.test$path',
        '$url#fragment',
      ]) {
        expect(safe(value), isNull);
      }
      expect(safe(url, owner: null), isNull);
      final context = AskAnswerContext.fromJson({
        'photo_url': url,
        'sources': [
          {'kind': 'photo', 'label': 'Attached photo'},
        ],
      });
      expect(context.photoUrl, url);
      expect(context.sources.single.kind, 'photo');
    },
  );

  test(
    'photo stream errors are safe, specific, and never expose raw details',
    () async {
      await expectLater(
        decodeAiCommandEvents(
          Stream.value(
            utf8.encode(
              'data: {"type":"error","code":"photo_timeout","message":"SECRET"}\n\n',
            ),
          ),
        ).toList(),
        throwsA(
          predicate(
            (e) =>
                e is AskRequestException &&
                e.message.contains('too long') &&
                !e.message.contains('SECRET'),
          ),
        ),
      );
      await expectLater(
        ApiClient(baseUrl: 'https://api.test')
            .aiPhotoQuestionStream(
              message: 'What is this?',
              photo: AskPhoto(bytes: Uint8List(AskPhoto.maxBytes + 1)),
            )
            .toList(),
        throwsA(isA<AskRequestException>()),
      );
    },
  );

  testWidgets('photo preview can be removed, replaced, and sent without text', (
    tester,
  ) async {
    final api = _AskApi();
    var picks = 0;
    await tester.pumpWidget(
      _page(
        api,
        photoPicker: (_) async {
          picks++;
          return AskPhoto(bytes: png);
        },
      ),
    );
    await attach(tester);
    expect(find.byKey(const Key('ask-photo-preview')), findsOneWidget);
    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ask-photo-preview')), findsNothing);
    await attach(tester);
    await tester.tap(find.bySemanticsLabel('Attached photo. Tap to replace.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(picks, 3);
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(api.photos, hasLength(1));
    expect(api.photoQuestions.single, contains('Do I already have it?'));
    expect(api.conversationIds, isEmpty);
    expect(find.byKey(const Key('ask-photo-preview')), findsNothing);
    expect(find.byType(AskQuestionCard), findsOneWidget);
    expect(
      tester.widget<AskQuestionCard>(find.byType(AskQuestionCard)).photoBytes,
      png,
    );
    expect(
      find.textContaining('No inventory item has been added'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera choice and typed question use the photo endpoint', (
    tester,
  ) async {
    final api = _AskApi();
    bool? camera;
    await tester.pumpWidget(
      _page(
        api,
        photoPicker: (value) async {
          camera = value;
          return AskPhoto(bytes: png);
        },
      ),
    );
    await attach(tester, camera: true);
    await tester.enterText(find.byType(TextField), 'What is this used for?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(camera, isTrue);
    expect(api.photoQuestions.single, 'What is this used for?');
    expect(api.conversationIds, isEmpty);
  });

  testWidgets('picker cancellation leaves composer unchanged', (tester) async {
    await tester.pumpWidget(_page(_AskApi(), photoPicker: (_) async => null));
    await tester.enterText(find.byType(TextField), 'Keep this question');
    await attach(tester);
    expect(find.byKey(const Key('ask-photo-preview')), findsNothing);
    expect(find.text('Keep this question'), findsOneWidget);
  });

  testWidgets('photo permission errors are visible without internal details', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(
        _AskApi(),
        photoPicker: (_) async => throw StateError('SECRET permission stack'),
      ),
    );
    await attach(tester);
    expect(find.textContaining('Check camera or photo access'), findsOneWidget);
    expect(find.textContaining('SECRET'), findsNothing);
    expect(find.byKey(const Key('ask-photo-preview')), findsNothing);
  });

  testWidgets('photo analysis failure is visible and keeps the sent photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _page(
        _AskApi(fail: true),
        photoPicker: (_) async => AskPhoto(bytes: png),
      ),
    );
    await attach(tester);
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be analyzed'), findsOneWidget);
    expect(
      tester.widget<AskQuestionCard>(find.byType(AskQuestionCard)).photoBytes,
      png,
    );
  });

  testWidgets('reset ignores late photo picker completion', (tester) async {
    final picker = Completer<AskPhoto?>();
    await tester.pumpWidget(
      _page(
        _AskApi(),
        initialMessage: 'Question',
        photoPicker: (_) => picker.future,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Attach photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose photo'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('New chat'));
    picker.complete(AskPhoto(bytes: png));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ask-photo-preview')), findsNothing);
  });

  testWidgets('narrow large-text photo composer stays above the pill', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _page(
        _AskApi(),
        scaler: const TextScaler.linear(2),
        photoPicker: (_) async => AskPhoto(bytes: png),
      ),
    );
    await attach(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('ask-photo-preview')), findsOneWidget);
  });
}
