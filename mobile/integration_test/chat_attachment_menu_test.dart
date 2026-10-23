// Native menu rendering and callbacks with synthetic state only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/world/world_composer.dart';
import 'package:mobile/features/chat/native_chat_menu_button.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final brightness in Brightness.values) {
    testWidgets('compact attachment menu ${brightness.name}', (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      final selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          home: Scaffold(
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
                    controller: controller,
                    focusNode: focus,
                    onChanged: (_) {},
                    onAttach: () {},
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
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(NativeChatMenuButton)),
        const Size(48, 48),
      );
      // Native menu interaction is checked separately in the simulator preview.
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
    });
  }
}
