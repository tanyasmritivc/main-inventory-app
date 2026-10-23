import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/chat/chat_history_sheet.dart';
import 'package:mobile/core/api_client.dart';

class HistoryApi extends ApiClient {
  HistoryApi() : super(baseUrl: 'https://test.invalid');
  bool fail = false, current = true;
  int deletes = 0;
  @override
  void assertCurrentContext() {
    if (!current) throw StateError('Scope changed');
  }

  @override
  Future<List<ConversationSummary>> listConversations() async => [
    ConversationSummary(
      id: 'a',
      title: 'Drill',
      updatedAt: DateTime(2026),
      createdAt: DateTime(2026),
    ),
  ];
  @override
  Future<void> deleteConversation(String id) async {
    assertCurrentContext();
    if (fail) throw StateError('Failed');
    deletes++;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();
  late Completer<Object?> completion;
  late Map<String, dynamic> presented;
  final dismissed = <String>[];
  setUp(() {
    completion = Completer<Object?>();
    dismissed.clear();
    debugNativePresentationOverride = true;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      NativePresentation.channel,
      (call) async {
        if (call.method == 'present') {
          completion = Completer<Object?>();
          presented = Map<String, dynamic>.from(call.arguments as Map);
          return completion.future;
        }
        if (call.method == 'dismiss') {
          dismissed.add((call.arguments as Map)['token'] as String);
        }
        return null;
      },
    );
  });
  tearDown(() {
    debugNativePresentationOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      NativePresentation.channel,
      null,
    );
  });
  Future<Object?> action(String id, {String? token, bool? value}) async {
    final result = Completer<Object?>();
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      NativePresentation.channel.name,
      codec.encodeMethodCall(
        MethodCall('action', {
          'token': token ?? presented['token'],
          'id': id,
          'value': value,
        }),
      ),
      (bytes) =>
          result.complete(bytes == null ? null : codec.decodeEnvelope(bytes)),
    );
    return result.future;
  }

  Future<BuildContext> mount(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: Text('Home'));
          },
        ),
      ),
    );
    return context;
  }

  testWidgets(
    'presentation returns cancellation and ignores foreign callbacks',
    (tester) async {
      final context = await mount(tester);
      var calls = 0;
      final pending = NativePresentation.show(
        context,
        model: {'title': 'Test'},
        onAction: (id, value) async {
          calls++;
          return {'title': 'Updated'};
        },
      );
      await tester.pumpAndSettle();
      expect(await action('load', token: 'foreign'), isNull);
      expect(calls, 0);
      expect(await action('load'), {'title': 'Updated'});
      completion.complete(null);
      await tester.pumpAndSettle();
      expect(await pending, isNull);
      expect(await action('load'), isNull);
      expect(dismissed, isEmpty);
      expect(find.text('Home'), findsOneWidget);
    },
  );
  testWidgets('disposing owning route dismisses native presentation', (
    tester,
  ) async {
    final context = await mount(tester);
    NativePresentation.show(context, model: {'title': 'Test'});
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(dismissed, [presented['token']]);
    completion.complete(null);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'native confirmation cancels safely and keeps destructive metadata',
    (tester) async {
      final context = await mount(tester);
      final pending = showAppConfirmation(
        context,
        title: 'Delete?',
        message: 'Keep exact scope.',
      );
      await tester.pumpAndSettle();
      expect(presented['destructive'], isTrue);
      expect(presented['message'], 'Keep exact scope.');
      completion.complete(null);
      await tester.pumpAndSettle();
      expect(await pending, isFalse);
    },
  );
  testWidgets(
    'history loads saved data, preserves failed deletions and rejects revoked scope',
    (tester) async {
      final context = await mount(tester);
      final api = HistoryApi();
      final deleted = <String>[];
      final pending = showChatHistory(
        context,
        api: api,
        onDeleted: deleted.add,
      );
      await tester.pumpAndSettle();
      expect(presented['load'], isTrue);
      var model = await action('load') as Map;
      List rows(Map m) =>
          ((m['sections'] as List).first as Map)['rows'] as List;
      expect(rows(model).single['title'], 'Drill');
      expect(
        rows(model).single['delete']['confirmation']['destructive'],
        isTrue,
      );
      api.fail = true;
      model = await action('delete:a') as Map;
      expect(model['error'], isNotNull);
      expect(rows(model).length, 1);
      expect(deleted, isEmpty);
      api.fail = false;
      api.current = false;
      model = await action('delete:a') as Map;
      expect(model['error'], isNotNull);
      expect(api.deletes, 0);
      api.current = true;
      model = await action('delete:a') as Map;
      expect(rows(model), isEmpty);
      expect(deleted, ['a']);
      await action('delete:a');
      expect(api.deletes, 1);
      completion.complete({'action': ChatHistorySheet.newChat});
      await tester.pumpAndSettle();
      expect(await pending, ChatHistorySheet.newChat);
    },
  );
}
