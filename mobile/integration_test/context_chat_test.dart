import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/app_theme.dart';
import 'dart:ui' as ui;
import 'package:mobile/features/chat/chat_page.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/inventory_chat_test.dart' as contextual;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Resolve bundled font loading before native test frames mount paragraphs.
    AppTheme.create(Brightness.light);
    AppTheme.create(Brightness.dark);
    await GoogleFonts.pendingFonts();
  });
  var count = 0;
  contextual.main(
    capture: const bool.fromEnvironment('CONTEXT_CHAT_EVIDENCE')
        ? (tester, name) async {
            await tester.pump(const Duration(milliseconds: 200));
            final boundary = tester
                .element(find.byType(ChatPage))
                .findAncestorRenderObjectOfType<RenderRepaintBoundary>()!;
            final frame = await boundary.toImage(pixelRatio: 2);
            final bytes = (await frame.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List();
            final file = File(
              '${Directory.systemTemp.path}/context-chat-${count++}-$name.png',
            );
            await file.writeAsBytes(bytes);
            debugPrint('CONTEXT_CHAT_IMAGE ${file.path}');
            frame.dispose();
          }
        : null,
  );
}
