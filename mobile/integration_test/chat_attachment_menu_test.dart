// Render the actual UIKit menu. Action contracts are in chat_source_menu_test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/chat_source_menu.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final brightness in Brightness.values) {
    for (final page in ['root', 'attach', 'inventory', 'context']) {
      testWidgets('native source menu ${brightness.name} $page', (
        tester,
      ) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            home: Builder(
              builder: (c) {
                context = c;
                return const Scaffold(body: Text('Chat'));
              },
            ),
          ),
        );
        if (!context.mounted) return;
        final navigator = Navigator.of(context, rootNavigator: true);
        final pending = showChatSourceMenu(
          context,
          GlobalKey(),
          initialPage: page,
        );
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(seconds: 2));
        debugPrint('NATIVE_CAPTURE_READY source-${brightness.name}-$page');
        await Future<void>.delayed(const Duration(seconds: 2));
        // Pop the owning Flutter route; its disposal dismisses UIKit as well.
        navigator.pop();
        await tester.pumpAndSettle();
        expect(await pending, isNull);
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(find.text('Chat'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
