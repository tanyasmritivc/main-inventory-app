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
}
