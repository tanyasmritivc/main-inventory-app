import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/chat/message_actions.dart';

class FeedbackApi extends ApiClient {
  FeedbackApi() : super(baseUrl: 'https://api.test');
  final calls = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>> pending = Completer();
  @override
  void assertCurrentContext() {}
  @override
  Future<Map<String, dynamic>> collaboration(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) {
    calls.add({'path': path, ...?data});
    return pending.future;
  }
}

void main() {
  test(
    'verified completion is emitted once; late errors never replace it',
    () async {
      final events = await decodeAiCommandEvents(
        Stream.value(
          utf8.encode(
            'data: {"type":"done","message_id":"exact","assistant_message":"Saved","created_at":"2026-10-25T12:00:00Z"}\n\ndata: [DONE]\n\ndata: {"type":"error"}\n\n',
          ),
        ),
      ).toList();
      expect(events, hasLength(1));
      expect(events.single.messageId, 'exact');
      expect(events.single.createdAt, isNotNull);
    },
  );
  test('transport marker without completion receipt is not success', () async {
    await expectLater(
      decodeAiCommandEvents(Stream.value(utf8.encode('data: [DONE]\n\n'))),
      emitsError(isA<AskRequestException>()),
    );
  });
  testWidgets(
    'rating waits for receipt, repeated taps lock, saved state restores',
    (tester) async {
      final api = FeedbackApi();
      Map<String, dynamic>? rating;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MessageActions(
                api: api,
                content: 'Answer',
                timestamp: 1000,
                isUser: false,
                messageId: 'exact',
                rating: rating,
                onRating: (value) => setState(() => rating = value),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Good response'));
      await tester.pump();
      await tester.tap(find.byTooltip('Good response'));
      await tester.pump();
      expect(api.calls, hasLength(1));
      expect(rating, isNull);
      expect(api.calls.single['path'], '/response-feedback/exact');
      api.pending.complete({'message_id': 'exact', 'rating': 1, 'revision': 1});
      await tester.pumpAndSettle();
      expect(rating?['rating'], 1);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Good response',
              ),
            )
            .isSelected,
        isTrue,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageActions(
              api: api,
              content: 'Answer',
              timestamp: 1000,
              isUser: false,
              messageId: 'exact',
              rating: rating,
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Good response',
              ),
            )
            .isSelected,
        isTrue,
      );
    },
  );
  testWidgets('network error never selects rating and permits retry', (
    tester,
  ) async {
    final api = FeedbackApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageActions(
            api: api,
            content: 'Answer',
            timestamp: 1000,
            isUser: false,
            messageId: 'exact',
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Good response'));
    api.pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(
      find.text("Feedback wasn't saved. Please try again."),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Good response',
            ),
          )
          .isSelected,
      isFalse,
    );
    api.pending = Completer();
    await tester.tap(find.byTooltip('Good response'));
    expect(api.calls, hasLength(2));
    api.pending.complete({'message_id': 'exact', 'rating': 1, 'revision': 1});
    await tester.pumpAndSettle();
  });
  testWidgets('prompt actions remain compact at large text in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.6)),
              child: MessageActions(
                api: FeedbackApi(),
                content: 'Prompt',
                timestamp: 1000,
                isUser: true,
                onRetry: () {},
                onEdit: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Good response'), findsNothing);
      expect(find.byTooltip('Edit prompt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
