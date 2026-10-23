// Native rendering of synthetic connector data, without inventory or provider I/O.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/assistant_connections_page.dart';
import 'package:mobile/features/scan/connector_review_page.dart';
import '../test/connector_review_test.dart' as fixture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final brightness in Brightness.values) {
    for (final name in ['connections', 'review']) {
      testWidgets('$name ${brightness.name}', (tester) async {
        final api = ApiClient(baseUrl: 'https://api.test');
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            home: RepaintBoundary(
              key: const ValueKey('frame'),
              child: name == 'connections'
                  ? AssistantConnectionsPage(api: api)
                  : ConnectorReviewPage(api: api, source: fixture.source()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Google'), findsNothing);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('frame')),
        );
        final frame = await boundary.toImage(pixelRatio: 2);
        final bytes = (await frame.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        final file = File(
          '${Directory.systemTemp.path}/findez-$name-${brightness.name}.png',
        );
        await file.writeAsBytes(bytes);
        debugPrint('CONNECTOR_VISUAL ${file.path}');
        frame.dispose();
      });
    }
  }
}
