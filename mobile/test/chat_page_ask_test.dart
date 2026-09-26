import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/chat/ask_client.dart';
import 'package:mobile/features/chat/ask_event.dart';
import 'package:mobile/features/chat/chat_page.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('typed questions use ASK events and preserve navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final gateway = _ConversationGateway();
    var inventoryRefreshes = 0;
    VoidCallback? reset;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ChatPage(
          api: _FakeApiClient(),
          askGateway: gateway,
          inPageView: true,
          onInventoryMutated: () => inventoryRefreshes += 1,
          onRegisterReset: (callback) => reset = callback,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Where is the bearing?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await gateway.completeLatest(const [
      AskEvent.conversation('conversation-1'),
      AskEvent.delta('Cabinet A'),
      AskEvent.navigation({'type': 'space', 'name': 'Cabinet A'}),
      AskEvent.done(),
    ]);
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    for (
      var i = 0;
      i < 10 && find.byIcon(Icons.stop_rounded).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(gateway.conversationIds, [null]);
    expect(find.text('Where is the bearing?'), findsOneWidget);
    expect(_renderedMarkdown(tester), contains('Cabinet A'));
    expect(find.text('Open Cabinet A'), findsOneWidget);
    expect(inventoryRefreshes, 1);

    reset?.call();
    await tester.pump();
  });
}

List<String> _renderedMarkdown(WidgetTester tester) {
  return tester
      .widgetList<MarkdownBody>(find.byType(MarkdownBody))
      .map((widget) => widget.data)
      .toList();
}

class _ConversationGateway implements AskGateway {
  final List<String?> conversationIds = [];
  final List<StreamController<AskEvent>> _streams = [];

  Future<void> completeLatest(List<AskEvent> events) async {
    final stream = _streams.last;
    for (final event in events) {
      stream.add(event);
    }
    await stream.close();
  }

  @override
  Future<AskRequest> streamText({
    required String message,
    String? conversationId,
  }) async {
    conversationIds.add(conversationId);
    final stream = StreamController<AskEvent>();
    _streams.add(stream);
    return AskRequest(events: stream.stream, cancel: () async {});
  }

  @override
  Future<AskRequest> streamFile({
    required String filename,
    required List<int> bytes,
    required String mimeType,
    String? conversationId,
  }) {
    throw UnimplementedError();
  }
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.invalid');

  @override
  Future<SearchItemsResult> searchItems({required String query}) async {
    return SearchItemsResult(items: const [], parsed: const {});
  }
}
