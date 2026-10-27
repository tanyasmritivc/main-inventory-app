// Native menu rendering and callbacks with synthetic state only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/world/world_composer.dart';
import 'package:mobile/features/chat/native_chat_menu_button.dart';
import 'package:mobile/features/chat/chat_source_menu.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final brightness in Brightness.values) {
    testWidgets('compact attachment menu ${brightness.name}', (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      final selected = <String>[];
      final anchor = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Ask')),
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Ask about a photo, or use Auto Extract to review items.',
                        ),
                      ),
                    ),
                    WorldComposer(
                      attachmentKey: anchor,
                      controller: controller,
                      focusNode: focus,
                      onChanged: (_) {},
                      onAttach: () async {
                        final value = await showChatSourceMenu(
                          context,
                          anchor,
                          nativeAttach: true,
                        );
                        if (value != null) selected.add(value);
                      },
                      onSourceSelected: selected.add,
                      onVoice: () {},
                      onSend: () {},
                      busy: false,
                      listening: false,
                      compact: true,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NativeChatMenuButton), findsNothing);
      await tester.tap(find.byTooltip('Capture or attach'));
      await tester.pumpAndSettle();
      for (final label in [
        'Auto Extract',
        'Attach',
        'Inventory tools',
        'Add context',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(NativeChatMenuButton), findsOneWidget);
      expect(
        tester.getSize(find.byType(NativeChatMenuButton)).width,
        greaterThan(150),
      );
      tester
          .widget<NativeChatMenuButton>(find.byType(NativeChatMenuButton))
          .onSelected('library');
      await tester.pumpAndSettle();
      expect(selected, ['library']);
      expect(find.text('Auto Extract'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
    });
  }
}
