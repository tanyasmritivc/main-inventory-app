import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/documents/documents_page.dart';
import 'package:mobile/features/documents/notes_editor_page.dart';

DocumentEntry _doc(String name, String mime, {String? label, String? url}) =>
    DocumentEntry(
      documentId: 'owner/$name',
      filename: name,
      mimeType: mime,
      displayName: label,
      url: url,
      createdAt: DateTime(2026, 10, 1),
    );

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'https://api.test');
  List<DocumentEntry> documents = [
    _doc('note-1.txt', 'text/plain', label: 'Workshop note'),
    _doc('manual.pdf', 'application/pdf'),
    _doc('image.png', 'image/png'),
    _doc('list.txt', 'text/plain'),
  ];
  bool failRead = false,
      failWrite = false,
      failOpen = false,
      failSearch = false;
  String? openUrl;
  int reads = 0, uploads = 0, deletes = 0, summaries = 0;
  Map<String, String>? renamed;
  Map<String, String?>? linked;
  Completer<List<DocumentEntry>>? pending;
  @override
  Future<List<DocumentEntry>> getDocuments({String? itemId}) async {
    reads++;
    if (failRead) throw StateError('SECRET database');
    return pending == null ? documents.toList() : pending!.future;
  }

  @override
  Future<String> openDocumentUrl({required String storagePath}) async {
    if (failOpen) throw StateError('SECRET signing');
    if (openUrl != null) return openUrl!;
    return 'https://api.test/storage/v1/object/sign/documents/$storagePath?token=test';
  }

  @override
  Future<void> renameDocument({
    required String storagePath,
    required String displayName,
  }) async {
    if (failWrite) throw StateError('SECRET rename');
    renamed = {'path': storagePath, 'name': displayName};
    documents = documents
        .map(
          (d) => d.documentId == storagePath
              ? _doc(d.filename, d.mimeType!, label: displayName)
              : d,
        )
        .toList();
  }

  @override
  Future<void> deleteDocument({required String storagePath}) async {
    deletes++;
    if (failWrite) throw StateError('SECRET deletion');
    documents.removeWhere((d) => d.documentId == storagePath);
  }

  @override
  Future<UploadDocumentResult> uploadDocument({
    required dio.MultipartFile file,
    String? itemId,
  }) async {
    uploads++;
    if (failWrite) throw StateError('SECRET upload');
    documents.add(_doc(file.filename!, file.contentType.toString()));
    return UploadDocumentResult(
      filename: file.filename!,
      activitySummary: 'Saved',
    );
  }

  @override
  Future<SearchItemsResult> searchItems({required String query}) async {
    if (failSearch) throw StateError('SECRET search');
    return SearchItemsResult(
      items: [
        InventoryItem(
          itemId: 'bolt',
          name: 'Bolt',
          category: 'Parts',
          quantity: 2,
          location: 'Shelf',
          createdAt: DateTime(2026),
        ),
      ],
      parsed: const {},
    );
  }

  @override
  Future<void> linkDocument({
    required String storagePath,
    String? itemId,
  }) async {
    if (failWrite) throw StateError('SECRET link');
    linked = {'path': storagePath, 'item': itemId};
  }

  @override
  Future<AiCommandResult> aiCommand({
    required String message,
    String? conversationId,
  }) async {
    summaries++;
    return AiCommandResult(
      tool: null,
      result: null,
      assistantMessage: 'A workshop document.',
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

Widget _page(_Api api, {String? Function()? owner, TextScaler? scaler}) =>
    RepaintBoundary(
      key: const ValueKey('documents-qa'),
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: const bool.fromEnvironment('FINDEZ_VISUAL_QA')
                ? 'FindEZQA'
                : null,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        ),
        home: DocumentsPage(
          api: api,
          ownerId: owner ?? () => 'owner',
          contentClient: MockClient(
            (_) async =>
                http.Response('The soldering iron is on the shelf.', 200),
          ),
        ),
      ),
    );
Future<void> _action(
  WidgetTester tester,
  String filename,
  String action,
) async {
  await tester.ensureVisible(find.byTooltip('Actions for $filename'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Actions for $filename'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action).last);
  // A summary keeps its busy indicator until the dialog is dismissed.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _add(WidgetTester tester, String action) async {
  await tester.tap(find.byTooltip('Add document'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      final font = FontLoader('FindEZQA')
        ..addFont(
          File(
            '/System/Library/Fonts/SFNS.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await font.load();
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'matte sections classify notes correctly and keep only essential actions',
    (tester) async {
      if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      await tester.pumpWidget(_page(_Api()));
      await tester.pumpAndSettle();
      expect(find.text('Notes'), findsOneWidget);
      if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('documents-qa')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/private/tmp/findez-documents-qa.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.text('PDFs'), findsOneWidget);
      await tester.ensureVisible(find.text('Files'));
      await tester.pumpAndSettle();
      expect(find.text('Files'), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byTooltip('Add document'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);
      expect(find.textContaining('image/png'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'search includes note contents and has an honest no-result state',
    (tester) async {
      await tester.pumpWidget(_page(_Api()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'soldering iron');
      await tester.pumpAndSettle();
      expect(find.text('Workshop note'), findsOneWidget);
      expect(find.text('manual.pdf'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'no such object');
      await tester.pumpAndSettle();
      expect(find.text('No matching documents or notes.'), findsOneWidget);
    },
  );
  testWidgets(
    'failed reads expose safe Retry and empty state still allows adding',
    (tester) async {
      final api = _Api()..failRead = true;
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      api.failRead = false;
      api.documents = [];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No documents yet'), findsOneWidget);
      await _add(tester, 'New note');
      expect(find.byType(NotesEditorPage), findsOneWidget);
    },
  );
  testWidgets(
    'rename preserves identity and failed writes restore server data',
    (tester) async {
      final api = _Api();
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      await _action(tester, 'manual.pdf', 'Rename');
      await tester.enterText(find.byType(TextField).last, 'Parts manual');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(api.renamed, {'path': 'owner/manual.pdf', 'name': 'Parts manual'});
      api.failWrite = true;
      await _action(tester, 'Parts manual', 'Rename');
      await tester.enterText(find.byType(TextField).last, 'Should not persist');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Parts manual'), findsOneWidget);
      expect(find.text('Should not persist'), findsNothing);
      expect(find.textContaining('SECRET'), findsNothing);
    },
  );
  testWidgets(
    'delete cancellation writes nothing and failure leaves the document',
    (tester) async {
      final api = _Api();
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      await _action(tester, 'manual.pdf', 'Delete');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.deletes, 0);
      api.failWrite = true;
      await _action(tester, 'manual.pdf', 'Delete');
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('manual.pdf'), findsWidgets);
      expect(find.textContaining('SECRET'), findsNothing);
    },
  );
  testWidgets('summary and item link remain functional', (tester) async {
    final api = _Api();
    await tester.pumpWidget(_page(api));
    await tester.pumpAndSettle();
    await _action(tester, 'manual.pdf', 'Summarize');
    expect(find.text('A workshop document.'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await _action(tester, 'manual.pdf', 'Link to item');
    await tester.tap(find.text('Bolt'));
    await tester.pumpAndSettle();
    expect(api.linked, {'path': 'owner/manual.pdf', 'item': 'bolt'});
    await _action(tester, 'manual.pdf', 'Remove link');
    expect(api.linked?['item'], isNull);
  });
  testWidgets('upload validates supported files and safe failures', (
    tester,
  ) async {
    final picker = _Picker();
    FilePicker.platform = picker;
    final api = _Api();
    await tester.pumpWidget(_page(api));
    await tester.pumpAndSettle();
    picker.result = FilePickerResult([
      PlatformFile(name: 'clip.mov', size: 1, bytes: Uint8List.fromList([1])),
    ]);
    await _add(tester, 'Upload file');
    expect(api.uploads, 0);
    picker.result = FilePickerResult([
      PlatformFile(name: 'new.pdf', size: 1, bytes: Uint8List.fromList([1])),
    ]);
    await _add(tester, 'Upload file');
    expect(api.uploads, 1);
    api.failWrite = true;
    await _add(tester, 'Upload file');
    expect(find.textContaining('SECRET'), findsNothing);
  });
  testWidgets('new note Save actually returns after confirmed write', (
    tester,
  ) async {
    final api = _Api();
    await tester.pumpWidget(_page(api));
    await tester.pumpAndSettle();
    await _add(tester, 'New note');
    await tester.enterText(find.byType(TextField).last, 'A remembered note.');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.uploads, 1);
    expect(find.byType(NotesEditorPage), findsNothing);
  });
  testWidgets(
    'failed note save retains the draft and does not report success',
    (tester) async {
      final api = _Api()..failWrite = true;
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      await _add(tester, 'New note');
      await tester.enterText(find.byType(TextField).last, 'Keep this draft');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(find.text('Failed to save note'), findsOneWidget);
      expect(find.text('Note saved successfully'), findsNothing);
    },
  );
  testWidgets('late reads from a previous account never become visible', (
    tester,
  ) async {
    String? owner = 'owner';
    final api = _Api()..pending = Completer();
    await tester.pumpWidget(_page(api, owner: () => owner));
    await tester.pump();
    owner = 'other';
    api.pending!.complete(api.documents);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Workshop note'), findsNothing);
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('note and image URLs reject external and foreign storage paths', (
    tester,
  ) async {
    final api = _Api()..openUrl = 'https://external.test/photo.png';
    await tester.pumpWidget(_page(api));
    await tester.pumpAndSettle();
    await _action(tester, 'Workshop note', 'Open');
    expect(find.byType(NotesEditorPage), findsNothing);
    api.openUrl =
        'https://api.test/storage/v1/object/sign/documents/other/photo.png';
    await _action(tester, 'image.png', 'Open');
    expect(find.byType(InteractiveViewer), findsNothing);
    api.openUrl =
        'https://api.test/storage/v1/object/sign/documents/owner/%2e%2e/other/photo.png';
    await _action(tester, 'image.png', 'Open');
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.textContaining('SECRET'), findsNothing);
  });
  testWidgets(
    'link read failure can retry and failed link writes stay visible',
    (tester) async {
      final api = _Api()..failSearch = true;
      await tester.pumpWidget(_page(api));
      await tester.pumpAndSettle();
      await _action(tester, 'manual.pdf', 'Link to item');
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No matches.'), findsNothing);
      api.failSearch = false;
      api.failWrite = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bolt'));
      await tester.pumpAndSettle();
      expect(api.linked, isNull);
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.textContaining('update link'), findsOneWidget);
    },
  );
  testWidgets('a note draft cannot be uploaded into a changed account', (
    tester,
  ) async {
    String? owner = 'owner';
    final api = _Api();
    await tester.pumpWidget(_page(api, owner: () => owner));
    await tester.pumpAndSettle();
    await _add(tester, 'New note');
    await tester.enterText(find.byType(TextField).last, 'Private draft');
    owner = 'other';
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.uploads, 0);
    expect(
      find.text('Your account changed. Reopen this note.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'narrow large-text documents remain scrollable and menu actions visible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _page(_Api(), scaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('list.txt'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _action(tester, 'list.txt', 'Rename');
      expect(find.text('Rename document'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
