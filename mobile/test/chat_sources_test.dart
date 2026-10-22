import 'dart:async';
import 'package:mobile/features/chat/native_chat_menu_button.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/chat_source.dart';
import 'package:mobile/features/chat/chat_page.dart';
import 'package:mobile/features/chat/chat_context_picker.dart';
import 'package:mobile/features/chat/assistant_connections_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> Function(String)? sourceAuditCapture;

class _Api extends ApiClient {
  _Api() : super(worldKey: 'personal', baseUrl: 'https://api.test');
  final sent = <List<ChatSource>>[];
  final reads = <String>[];
  bool fail = false;
  Completer<ChatSource>? pendingFile;
  Completer<Map<String, dynamic>>? pendingSearch;
  @override
  void assertCurrentContext() {}
  @override
  Future<Map<String, dynamic>> collaboration(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async => {
    'inventories': [
      {'inventory_id': 'inv', 'name': 'Workshop', 'workspace_name': 'Home'},
    ],
  };
  @override
  Future<Map<String, dynamic>> chatSourceChoices({
    required String inventoryId,
    required String kind,
    String query = '',
    int offset = 0,
  }) async {
    if (query == 'old' && pendingSearch != null) return pendingSearch!.future;
    return {
      'sources': [
        {
          'kind': kind,
          'name': query.isEmpty ? 'Tool shelf' : query,
          'inventory_id': 'inv',
          'resource_id': query.isEmpty ? 'shelf' : query,
          'inventory_name': 'Workshop',
        },
      ],
    };
  }

  @override
  Future<ChatSource> readChatFile(List<int> bytes, String filename) async {
    reads.add(filename);
    return pendingFile?.future ??
        ChatSource(
          kind: 'file',
          name: filename,
          text: 'Shelf A contains batteries.',
        );
  }

  @override
  Stream<AiStreamEvent> aiCommandStream({
    required String message,
    String? conversationId,
    List<ChatSource> sources = const [],
  }) async* {
    sent.add(List.of(sources));
    if (fail) throw const AskRequestException('Please try again.');
    yield AiStreamEvent(
      type: 'done',
      assistantMessage: 'The batteries are on shelf A.',
      conversationId: 'chat',
    );
  }
}

class _Picker extends FilePicker {
  FilePickerResult? result;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}

Widget frame(
  Widget child, {
  Brightness brightness = Brightness.dark,
  double scale = 1,
  double keyboard = 0,
}) => RepaintBoundary(
  key: const ValueKey('sources-audit-frame'),
  child: MaterialApp(
    theme: AppTheme.create(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboard),
      ),
      child: child!,
    ),
    home: child,
  ),
);
Widget _chat(_Api api, {ValueChanged<VoidCallback>? reset}) => Scaffold(
  body: ChatPage(
    api: api,
    inPageView: true,
    worldHeading: 'Find your things.',
    onRegisterReset: reset,
  ),
);
Future<void> menu(WidgetTester tester, String action, {String? parent}) async {
  if (usesNativeChatMenu) {
    final value = {'Spaces': 'space', 'Choose files': 'file'}[action]!;
    tester
        .widget<NativeChatMenuButton>(find.byType(NativeChatMenuButton))
        .onSelected(value);
    await tester.pumpAndSettle();
    return;
  }
  await tester.tap(find.byTooltip('Capture or attach'));
  await tester.pumpAndSettle();
  if (parent != null) {
    await tester.tap(find.text(parent));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
  });
  testWidgets(
    'selected reference sends IDs, can be removed, and resets with chat',
    (tester) async {
      final api = _Api();
      late VoidCallback reset;
      await tester.pumpWidget(
        frame(_chat(api, reset: (value) => reset = value)),
      );
      await tester.pumpAndSettle();
      await menu(tester, 'Spaces', parent: 'Add context');
      await tester.tap(find.text('Tool shelf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done (1)'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove Tool shelf'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'What is here?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(api.sent.single.single.toJson(), {
        'kind': 'space',
        'inventory_id': 'inv',
        'resource_id': 'shelf',
      });
      await tester.tap(find.byTooltip('Remove Tool shelf'));
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
      await menu(tester, 'Spaces', parent: 'Add context');
      await tester.tap(find.text('Tool shelf'));
      await tester.pump();
      await tester.tap(find.text('Done (1)'));
      await tester.pumpAndSettle();
      reset();
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsNothing);
    },
  );
  testWidgets(
    'file cancellation keeps prompt and failed send keeps attachment for retry',
    (tester) async {
      final picker = _Picker();
      FilePicker.platform = picker;
      final api = _Api()..fail = true;
      await tester.pumpWidget(frame(_chat(api)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Where are the batteries?',
      );
      await menu(tester, 'Choose files', parent: 'Attach');
      expect(find.text('Where are the batteries?'), findsOneWidget);
      expect(api.reads, isEmpty);
      picker.result = FilePickerResult([
        PlatformFile(
          name: 'manual.txt',
          size: 3,
          bytes: Uint8List.fromList([65, 66, 67]),
        ),
      ]);
      await menu(tester, 'Choose files', parent: 'Attach');
      expect(find.byTooltip('Remove manual.txt'), findsOneWidget);
      await sourceAuditCapture?.call('file-chip');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(api.sent.single.single.text, 'Shelf A contains batteries.');
      expect(find.byTooltip('Remove manual.txt'), findsOneWidget);
      api.fail = false;
      await tester.enterText(find.byType(TextField).first, 'Try again');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(api.sent, hasLength(2));
      expect(api.sent.last.single.name, 'manual.txt');
    },
  );
  testWidgets('late file response cannot repopulate a fresh chat', (
    tester,
  ) async {
    final picker = _Picker()
      ..result = FilePickerResult([
        PlatformFile(
          name: 'manual.txt',
          size: 3,
          bytes: Uint8List.fromList([65, 66, 67]),
        ),
      ]);
    FilePicker.platform = picker;
    final api = _Api()..pendingFile = Completer();
    late VoidCallback reset;
    await tester.pumpWidget(frame(_chat(api, reset: (value) => reset = value)));
    await tester.pumpAndSettle();
    if (usesNativeChatMenu) {
      tester
          .widget<NativeChatMenuButton>(find.byType(NativeChatMenuButton))
          .onSelected('file');
    } else {
      await tester.tap(find.byTooltip('Capture or attach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose files'));
    }
    await tester.pump();
    reset();
    await tester.pump();
    api.pendingFile!.complete(
      const ChatSource(kind: 'file', name: 'manual.txt', text: 'old'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
  });
  testWidgets('late search response cannot replace current context results', (
    tester,
  ) async {
    final api = _Api()..pendingSearch = Completer();
    await tester.pumpWidget(
      frame(ChatContextPicker(api: api, kind: 'space', selected: const [])),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    api.pendingSearch!.complete({
      'sources': [
        {
          'kind': 'space',
          'name': 'stale',
          'inventory_id': 'inv',
          'resource_id': 'old',
        },
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text('stale'), findsNothing);
    expect(find.text('new'), findsWidgets);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} menu fits small screen with keyboard and large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          frame(_chat(_Api()), brightness: brightness, scale: 2, keyboard: 220),
        );
        await tester.pumpAndSettle();
        if (usesNativeChatMenu) {
          expect(find.byType(NativeChatMenuButton), findsOneWidget);
          expect(
            tester.getSize(find.byType(NativeChatMenuButton)),
            const Size(48, 48),
          );
          expect(tester.takeException(), isNull);
          return; // Native row layout is inspected separately through iOS UI.
        }
        await tester.tap(find.byTooltip('Capture or attach'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await sourceAuditCapture?.call('${brightness.name}-menu');
        await tester.tapAt(const Offset(310, 40));
        await tester.pumpAndSettle();
        expect(find.text('Auto Extract'), findsNothing);
      },
    );
  }
  testWidgets('connections shows real setup paths without connected claims', (
    tester,
  ) async {
    await tester.pumpWidget(frame(const AssistantConnectionsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Claude Desktop'), findsOneWidget);
    expect(find.text('ChatGPT'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    await sourceAuditCapture?.call('connections');
    await tester.enterText(find.byType(TextField), 'chatgpt');
    await tester.pumpAndSettle();
    expect(find.text('Claude Desktop'), findsNothing);
    expect(find.text('ChatGPT'), findsOneWidget);
  });
}
