import 'dart:async';
import 'package:flutter/services.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/chat_source_menu.dart';
import 'package:mobile/features/chat/native_chat_menu_button.dart';

void main() {
  testWidgets(
    'search, nested back and attachment selection keep distinct actions',
    (tester) async {
      final anchor = GlobalKey();
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Align(
                alignment: Alignment.bottomLeft,
                child: IconButton(
                  key: anchor,
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    selected = await showChatSourceMenu(context, anchor);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'context');
      await tester.pump();
      expect(find.text('Auto Extract'), findsNothing);
      await tester.tap(find.text('Add context'));
      await tester.pumpAndSettle();
      expect(find.text('Search context…'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'absent');
      await tester.pump();
      expect(find.text('No matching options'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to attachment options'));
      await tester.pumpAndSettle();
      expect(find.text('Auto Extract'), findsOneWidget);
      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photo library'));
      await tester.pumpAndSettle();
      expect(selected, 'library');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native Attach keeps its anchor mounted until a real source is selected',
    (tester) async {
      final anchor = GlobalKey();
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Align(
                alignment: Alignment.bottomLeft,
                child: IconButton(
                  key: anchor,
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    selected = await showChatSourceMenu(
                      context,
                      anchor,
                      nativeAttach: true,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();
      // A Flutter tap must not dismiss the row beneath the native menu.
      expect(selected, isNull);
      expect(find.text('Auto Extract'), findsOneWidget);
      expect(find.text('Photo library'), findsNothing);
      tester
          .widget<NativeChatMenuButton>(find.byType(NativeChatMenuButton))
          .onSelected('library');
      await tester.pumpAndSettle();
      expect(selected, 'library');
      expect(find.text('Auto Extract'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  group('native source sheet', () {
    late Completer<Object?> completion;
    late Map<dynamic, dynamic> model;
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    setUp(() {
      debugNativePresentationOverride = true;
      completion = Completer<Object?>();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativePresentation.channel,
        (call) async {
          if (call.method == 'present') {
            completion = Completer<Object?>();
            model = call.arguments as Map;
            return completion.future;
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
    Future<BuildContext> mount(WidgetTester tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold(body: Text('Chat'));
            },
          ),
        ),
      );
      return context;
    }

    List<String> leaves(Map<dynamic, dynamic> page) => [
      for (final section in page['sections'] as List)
        for (final row in section['rows'] as List)
          if (row['children'] is Map)
            ...leaves(row['children'] as Map)
          else
            row['id'] as String,
    ];
    const actions = [
      'auto_extract',
      'library',
      'camera',
      'file',
      'spreadsheet',
      'barcode',
      'space',
      'item',
      'project',
      'document',
      'connections',
    ];
    for (final action in actions) {
      testWidgets('returns $action only after native dismissal', (
        tester,
      ) async {
        final context = await mount(tester);
        String? selected;
        final pending = showChatSourceMenu(
          context,
          GlobalKey(),
        ).then((v) => selected = v);
        await tester.pumpAndSettle();
        void expectNoSearch(Map page) {
          expect(page['search'], isFalse);
          expect(page['searchPlaceholder'], isNull);
          for (final section in page['sections'] as List) {
            for (final row in section['rows'] as List) {
              if (row['children'] is Map) expectNoSearch(row['children']);
            }
          }
        }

        expectNoSearch(model);
        expect(leaves(model), unorderedEquals(actions));
        expect(model['sections'][0]['footer'], contains('Overly crowded'));
        expect(find.text('Auto Extract'), findsNothing); // UIKit owns the menu.
        expect(selected, isNull);
        completion.complete({'action': action});
        await tester.pumpAndSettle();
        await pending;
        expect(selected, action);
        expect(find.text('Chat'), findsOneWidget);
      });
    }
    for (final result in [
      null,
      {'action': 'auto_extract'},
      {'action': 'space'},
    ]) {
      testWidgets('Space attachment sheet rejects extraction/context $result', (
        tester,
      ) async {
        final context = await mount(tester);
        final pending = showChatSourceMenu(
          context,
          GlobalKey(),
          questionsOnly: true,
        );
        await tester.pumpAndSettle();
        expect(model['title'], 'Attach');
        expect(model['search'], isFalse);
        expect(leaves(model), ['library', 'camera', 'file']);
        expect(model['sections'][0]['footer'], isNull);
        completion.complete(result);
        await tester.pumpAndSettle();
        expect(await pending, isNull);
      });
    }
    testWidgets(
      'native presentation failure is visible and leaves chat usable',
      (tester) async {
        final context = await mount(tester);
        final pending = showChatSourceMenu(context, GlobalKey());
        await tester.pumpAndSettle();
        completion.completeError(PlatformException(code: 'presentation_busy'));
        await tester.pumpAndSettle();
        expect(await pending, isNull);
        expect(
          find.text('Could not open this control. Please try again.'),
          findsOneWidget,
        );
      },
    );
  });
}
