import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/chat_source.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/features/chat/chat_page.dart';
import 'package:mobile/features/chat/inventory_chat_button.dart';

InventoryContext scope(String id) => InventoryContext(
  accountId: 'fixture',
  inventoryId: id,
  name: id,
  workspaceId: 'personal',
  workspaceName: 'Personal',
  role: 'viewer',
  canEdit: false,
  canManage: false,
  canRename: false,
);

class ChatApi extends ApiClient {
  ChatApi(String? id)
    : super(
        baseUrl: 'https://fixture.invalid',
        inventoryContext: id == null ? null : scope(id),
      );
  final stream = StreamController<AiStreamEvent>.broadcast();
  final conversations = <String?>[];
  @override
  void assertCurrentContext() {}
  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(items: [], parsed: {});
  @override
  Stream<AiStreamEvent> aiCommandStream({
    required String message,
    String? conversationId,
    String? requestId,
    List<ChatSource> sources = const [],
  }) {
    conversations.add(conversationId);
    return stream.stream;
  }
}

void main({Future<void> Function(WidgetTester, String)? capture}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://fixture.invalid',
      publishableKey: 'fixture',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugin.csdcorp.com/speech_to_text'),
          (_) async => false,
        );
  });
  Widget host(
    ChatApi api, {
    Brightness brightness = Brightness.light,
    double scale = 1,
    double keyboard = 0,
  }) => MaterialApp(
    theme: AppTheme.create(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        padding: EdgeInsets.only(top: 24, bottom: keyboard > 0 ? 0 : 20),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 20),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: const Text('Inventory page'),
      floatingActionButton: InventoryChatButton(api: api),
    ),
  );
  testWidgets('no contextual chat can open without an inventory boundary', (
    tester,
  ) async {
    final api = ChatApi(null);
    await tester.pumpWidget(host(api));
    expect(find.text('Ask FindEZ'), findsNothing);
    await api.stream.close();
  });
  testWidgets('interruption retains the answer prefix with an incomplete notice', (tester) async {
    final api = ChatApi('Hardware');
    await tester.pumpWidget(host(api));
    await tester.tap(find.text('Ask FindEZ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Where is my drill?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    api.stream.add(AiStreamEvent(type: 'delta', delta: 'The drill is on shelf 2.'));
    await tester.pump();
    expect(find.textContaining('The drill is on shelf 2.'), findsOneWidget);
    api.stream.addError(StateError('interrupted'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The drill is on shelf 2.'), findsOneWidget);
    expect(find.textContaining('This response was interrupted.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await api.stream.close();
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} scoped sheet has close, original client, immediate stream, and cancels on dismissal',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = ChatApi('Hardware');
        await tester.pumpWidget(host(api, brightness: brightness));
        await tester.tap(find.text('Ask FindEZ'));
        await tester.pumpAndSettle();
        expect(find.text('Only in Hardware'), findsOneWidget);
        expect(tester.widget<ChatPage>(find.byType(ChatPage)).api, same(api));
        await tester.enterText(find.byType(TextField), 'Where is my drill?');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pump();
        api.stream.add(
          AiStreamEvent(type: 'delta', delta: 'In Hardware, on shelf 2.'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.textContaining('In Hardware, on shelf 2.'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
        await capture?.call(tester, brightness.name);
        expect(api.conversations, [null]);
        await tester.tap(find.byTooltip('Close contextual chat'));
        await tester.pumpAndSettle();
        api.stream.add(
          AiStreamEvent(type: 'delta', delta: 'Late text must not reappear.'),
        );
        await tester.pump();
        expect(find.byType(ChatPage), findsNothing);
        expect(find.textContaining('Late text'), findsNothing);
        await api.stream.close();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'switching inventory creates a fresh chat, not a shared account conversation',
    (tester) async {
      final a = ChatApi('Hardware'), b = ChatApi('Bathroom');
      await tester.pumpWidget(host(a));
      await tester.tap(find.text('Ask FindEZ'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Private hardware question',
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      a.stream.add(
        AiStreamEvent(type: 'delta', delta: 'Hardware-only answer.'),
      );
      a.stream.add(
        AiStreamEvent(type: 'done', conversationId: 'hardware-conversation'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close contextual chat'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(b));
      await tester.tap(find.text('Ask FindEZ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hardware-only answer'), findsNothing);
      expect(find.textContaining('Private hardware'), findsNothing);
      expect(find.text('Only in Bathroom'), findsOneWidget);
      await tester.tap(find.byTooltip('Close contextual chat'));
      await tester.pumpAndSettle();
      await a.stream.close();
      await b.stream.close();
    },
  );
  testWidgets('narrow sheet and large text keep the close action reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ChatApi('Hardware');
    await tester.pumpWidget(host(api, scale: 2));
    await tester.tap(find.text('Ask FindEZ'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close contextual chat'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(host(api, scale: 2, keyboard: 220));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byTooltip('Close contextual chat').hitTestable(),
      findsOneWidget,
    );
    await capture?.call(tester, 'narrow-keyboard');
    await tester.tap(find.byTooltip('Close contextual chat'));
    await tester.pumpAndSettle();
    await api.stream.close();
  });
}
