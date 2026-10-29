import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/chat_source.dart';
import 'package:mobile/core/chat_item_action.dart';
import 'package:mobile/core/ask_answer.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_typography.dart';
import 'package:mobile/core/inventory_cache.dart';
import 'package:mobile/features/chat/chat_page.dart';
import 'package:mobile/features/shell/home_navigation.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> Function(String)? releaseAuditCapture;

class _FocusApi extends ApiClient {
  _FocusApi({
    this.pending,
    this.fail = false,
    this.answer = 'Your drill is in Workshop.',
  }) : super(baseUrl: 'https://api.test');
  final StreamController<AiStreamEvent>? pending;
  final bool fail;
  final String answer;
  final requests = <String>[];
  final conversationIds = <String?>[];

  @override
  Stream<AiStreamEvent> aiCommandStream({
    required String message,
    String? conversationId,
    String? requestId,
    List<ChatSource> sources = const [],
  }) async* {
    requests.add(message);
    conversationIds.add(conversationId);
    if (pending != null && requests.length == 1) {
      yield* pending!.stream;
      return;
    }
    if (fail) throw const AskRequestException('Please try again.');
    yield AiStreamEvent(type: 'delta', delta: answer);
    yield AiStreamEvent(type: 'done', conversationId: 'focus-conversation');
  }

  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(items: const [], parsed: const {});
  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => [];
  @override
  Future<List<dynamic>> getMyShares() async => [];
  @override
  Future<List<dynamic>> getJoinedShares() async => [];
  @override
  Future<ReviewQueueResult> getReviewItems({int limit = 100}) async =>
      const ReviewQueueResult(items: [], pendingCount: 0);
  @override
  Future<List<Map<String, dynamic>>> getActiveCheckouts() async => [];
  @override
  Future<Map<String, dynamic>> getNotifications() async => {'unread_count': 0};
  @override
  Future<Map<String, dynamic>> getMyProfile() async => {};
  @override
  Future<Map<String, dynamic>> getMyLimits() async => {'pilot_mode': true};
}

class _ActionFocusApi extends _FocusApi {
  _ActionFocusApi(StreamController<AiStreamEvent> stream)
    : super(pending: stream);
  int confirmations = 0;
  final reply = List.generate(90, (i) => 'receipt$i').join(' ');
  @override
  Future<ChatItemActionResult> decideChatItemAction({
    required ChatItemAction action,
    required String decision,
    CancelToken? cancelToken,
  }) async {
    confirmations++;
    return ChatItemActionResult(
      action: ChatItemAction(
        id: action.id,
        inventoryId: action.inventoryId,
        operation: 'add',
        status: 'confirmed',
        items: action.items,
      ),
      assistantMessage: reply,
      replyId: 'confirmed-reply',
    );
  }
}

Future<void> _tab(WidgetTester tester, int index) async {
  await tester.tap(find.byType(NavigationDestination).at(index));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _mount(
  WidgetTester tester,
  _FocusApi api, {
  Brightness brightness = Brightness.light,
  double scale = 1,
  bool reduceMotion = false,
}) async {
  final theme = AppTheme.create(brightness);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: const bool.fromEnvironment('FINDEZ_VISUAL_QA')
          ? theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'FindEZQA'),
              primaryTextTheme: theme.primaryTextTheme.apply(
                fontFamily: 'FindEZQA',
              ),
              textButtonTheme: TextButtonThemeData(
                style: theme.textButtonTheme.style?.copyWith(
                  textStyle: WidgetStatePropertyAll(
                    (theme.textButtonTheme.style?.textStyle?.resolve({}) ??
                            const TextStyle())
                        .copyWith(fontFamily: 'FindEZQA'),
                  ),
                ),
              ),
            )
          : theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
        ),
        child: AppTypography(child: SafeArea(child: child!)),
      ),
      home: RepaintBoundary(
        key: const Key('chat-focus-qa'),
        child: MainShell(api: api),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _tab(tester, 2);
  if (find.text('New chat').evaluate().isNotEmpty) {
    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
  }
}

Future<void> _send(WidgetTester tester, String question) async {
  await tester.enterText(find.byType(TextField), question);
  await tester.pump();
  await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      await (FontLoader('FindEZQA')..addFont(
            File(
              '/System/Library/Fonts/SFNS.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() {
    InventoryCache.clear();
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugin.csdcorp.com/speech_to_text'),
      (_) async => false,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.findez.app/push'),
      (_) async => null,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} reviewed Chat action keeps focus and fades the confirmed model reply',
      (tester) async {
        final stream = StreamController<AiStreamEvent>();
        final api = _ActionFocusApi(stream);
        await _mount(tester, api, brightness: brightness);
        await _send(tester, 'Add 3 bolts in Garage');
        stream.add(
          AiStreamEvent(
            type: 'delta',
            delta: 'Review the new items before confirming.',
          ),
        );
        stream.add(
          AiStreamEvent(
            type: 'done',
            conversationId: 'action-conversation',
            answerContext: AskAnswerContext.fromJson({
              'pending_actions': [
                {
                  'id': '22222222-2222-4222-8222-222222222222',
                  'inventory_id': '11111111-1111-4111-8111-111111111111',
                  'operation': 'add',
                  'status': 'pending',
                  'items': [
                    {'name': 'Bolt', 'quantity': 3, 'location': 'Garage'},
                  ],
                },
              ],
            }),
          ),
        );
        await stream.close();
        await tester.pumpAndSettle();
        expect(api.confirmations, 0);
        await tester.ensureVisible(find.text('Confirm additions'));
        await tester.tap(find.text('Confirm additions'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 36));
        expect(api.confirmations, 1);
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(HomeNavigation), findsNothing);
        expect(find.byTooltip('Back'), findsOneWidget);
        expect(find.textContaining('receipt89'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.textContaining(api.reply), findsOneWidget);
        tester
            .widget<ListView>(find.byType(ListView).first)
            .controller!
            .jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.text('Items added'), findsOneWidget);
        expect(find.text('Confirm additions'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets('${brightness.name} focus keeps stream and draft across Back', (
      tester,
    ) async {
      if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      final pending = StreamController<AiStreamEvent>();
      final api = _FocusApi(pending: pending);
      await _mount(tester, api, brightness: brightness);
      final chatState = tester.state(find.byType(ChatPage));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(HomeNavigation), findsOneWidget);
      await _send(tester, 'Where is my drill?');
      expect(find.byType(HomeNavigation), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Where is my drill?'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'And my screwdriver?');
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(HomeNavigation), findsOneWidget);
      expect(
        tester
            .widget<HomeNavigation>(find.byType(HomeNavigation))
            .selectedIndex,
        0,
      );
      pending.add(
        AiStreamEvent(type: 'delta', delta: 'Your drill is on shelf 2.'),
      );
      pending.add(
        AiStreamEvent(type: 'done', conversationId: 'kept-conversation'),
      );
      await pending.close();
      await tester.pumpAndSettle();
      await _tab(tester, 2);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ChatPage)), same(chatState));
      expect(find.byType(HomeNavigation), findsNothing);
      expect(find.textContaining('Your drill is on shelf 2.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'And my screwdriver?',
      );
      if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('chat-focus-qa')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/private/tmp/findez-chat-focus-${brightness.name}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await _send(tester, 'And my screwdriver?');
      await tester.pumpAndSettle();
      expect(api.requests, ['Where is my drill?', 'And my screwdriver?']);
      expect(api.conversationIds, [null, 'kept-conversation']);
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeNavigation), findsOneWidget);
      expect(find.text('What would you like to know?'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.state(find.byType(ChatPage)), same(chatState));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} received chunks appear before completion without artificial pacing',
      (tester) async {
        final answer = List.generate(90, (index) => 'part$index').join(' ');
        final stream = StreamController<AiStreamEvent>();
        await _mount(
          tester,
          _FocusApi(pending: stream),
          brightness: brightness,
        );
        await _send(tester, 'Show my parts');
        await tester.pump(const Duration(milliseconds: 300));
        stream.add(AiStreamEvent(type: 'delta', delta: answer));
        await tester.pump();
        await tester.pump();
        final received = tester
            .widgetList<RichText>(find.byType(RichText))
            .map((text) => text.text.toPlainText())
            .join(' ');
        expect(received, contains('part0'));
        expect(received, contains('part89'));
        stream.add(AiStreamEvent(type: 'reset'));
        await tester.pump();
        expect(find.textContaining(answer), findsNothing);
        stream.add(
          AiStreamEvent(type: 'delta', delta: 'Corrected inventory answer.'),
        );
        await tester.pump();
        await tester.pump();
        expect(
          find.textContaining('Corrected inventory answer.'),
          findsOneWidget,
        );
        stream.add(
          AiStreamEvent(type: 'done', conversationId: 'streaming-parts'),
        );
        await stream.close();
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Corrected inventory answer.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} Back returns to Find and remains reachable with large text and keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetViewInsets);
        await _mount(
          tester,
          _FocusApi(fail: true),
          brightness: brightness,
          scale: 2.6,
          reduceMotion: true,
        );
        await _tab(tester, 3);
        await _tab(tester, 2);
        await _send(tester, 'Where is my drill?');
        await tester.pumpAndSettle();
        expect(find.byType(HomeNavigation), findsNothing);
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Back').hitTestable(), findsOneWidget);
        expect(find.byType(TextField).hitTestable(), findsOneWidget);
        expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 1);
        expect(
          tester
              .getSize(
                find.descendant(
                  of: find.byType(ChatPage),
                  matching: find.byType(ListView),
                ),
              )
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(find.byTooltip('New chat').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await releaseAuditCapture?.call(
          'chat-${brightness.name}-large-text-keyboard',
        );
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<HomeNavigation>(find.byType(HomeNavigation))
              .selectedIndex,
          3,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('Back stays pinned while a long reply scrolls', (tester) async {
    await _mount(
      tester,
      _FocusApi(
        answer: List.filled(
          30,
          'Your saved items are in Workshop.',
        ).join('\n\n'),
      ),
    );
    await _send(tester, 'Tell me about my things');
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byType(ChatPage),
      matching: find.byType(ListView),
    );
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
    final scrollable = find.descendant(
      of: list,
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable.first).position.pixels,
      greaterThan(0),
    );
    expect(find.byTooltip('Back').hitTestable(), findsOneWidget);
    expect(find.text('New chat').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
