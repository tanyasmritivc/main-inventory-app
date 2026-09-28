import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/chat_history_page.dart';

class _HistoryApi extends ApiClient {
  _HistoryApi() : super(baseUrl: 'https://invalid.test');

  bool fail = false;
  bool deleted = false;

  @override
  Future<List<ConversationSummary>> listConversations() async {
    if (fail) throw StateError('offline');
    return [
      ConversationSummary(
        id: 'conversation-one',
        title: 'Where is the clamp?',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      ),
    ];
  }

  @override
  Future<void> deleteConversation(String id) async {
    deleted = true;
  }
}

void main() {
  testWidgets('history opens a real conversation and confirms deletion', (
    tester,
  ) async {
    final api = _HistoryApi();
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => ChatHistoryPage(api: api)),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Where is the clamp?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete conversation?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.deleted, isFalse);
    await tester.tap(find.text('Where is the clamp?'));
    await tester.pumpAndSettle();
    expect(selected, 'conversation-one');
  });

  testWidgets('history read failure offers retry', (tester) async {
    final api = _HistoryApi()..fail = true;
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: ChatHistoryPage(api: api)),
    );
    await tester.pumpAndSettle();
    expect(find.text('History could not load.'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Where is the clamp?'), findsOneWidget);
  });
}
