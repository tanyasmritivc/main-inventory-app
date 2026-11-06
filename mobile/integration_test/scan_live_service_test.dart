// Opt-in native checks using an isolated disposable account. No secrets here.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ask_answer.dart';
import 'package:mobile/features/chat/chat_page.dart';
import 'package:mobile/features/chat/chat_capture_card.dart';
import 'package:mobile/features/chat/extraction_progress_panel.dart';
import '../test/support/scan_live_photo_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('RUN_LIVE_SCAN')) return;
  late ApiClient api;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    await Supabase.instance.client.auth.setSession(
      const String.fromEnvironment('QA_REFRESH_TOKEN'),
    );
    expect(
      Supabase.instance.client.auth.currentUser!.id,
      const String.fromEnvironment('QA_ACCOUNT_ID'),
    );
    api = ApiClient.forWorld(
      ApiClient(baseUrl: const String.fromEnvironment('API_BASE_URL')),
      'personal',
      isCurrent: () => true,
    );
  });
  tearDownAll(() async {
    await Supabase.instance.client.auth.signOut();
    await Supabase.instance.dispose();
  });
  Future<void> screenshot(WidgetTester t, String name) async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('live-service-frame')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final path = '${Directory.systemTemp.path}/scan-service-$name.png';
    await File(path).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    debugPrint('SCAN_LIVE_IMAGE $path');
  }

  for (final scenario in ['mixed-workbench', 'parts-bin', 'obscured']) {
    testWidgets(
      'real photo through Ask: $scenario',
      (t) async {
        final bench = (await rootBundle.load(
          'assets/onboarding/sample_workbench.jpg',
        )).buffer.asUint8List();
        final Uint8List photo;
        if (scenario == 'mixed-workbench') {
          photo = extractPhotoFixture;
        } else {
          final source = img.decodeJpg(bench)!;
          // Real photo crops exercise dense parts and ambiguous partial objects.
          photo = Uint8List.fromList(
            img.encodeJpg(
              img.copyCrop(
                source,
                x: (source.width * (scenario == 'parts-bin' ? .05 : .46))
                    .round(),
                y: (source.height * (scenario == 'parts-bin' ? .5 : .13))
                    .round(),
                width: (source.width * .45).round(),
                height: (source.height * .45).round(),
              ),
            ),
          );
        }
        final brightness = scenario == 'parts-bin'
            ? Brightness.light
            : Brightness.dark;
        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            home: RepaintBoundary(
              key: const Key('live-service-frame'),
              child: Scaffold(
                body: ChatPage(
                  key: ValueKey(scenario),
                  api: api,
                  inPageView: true,
                  worldHeading: 'Find your things.',
                  photoPicker: (_) async => AskPhoto(bytes: photo),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Capture or attach'));
        await t.pumpAndSettle();
        await t.tap(find.text('Auto Extract'));
        await t.pumpAndSettle();
        await t.tap(find.text('Choose photo'));
        await t.pump(const Duration(seconds: 2));
        expect(find.byType(ScanPhotoFrame), findsOneWidget);
        await screenshot(t, '$scenario-scanning');
        final deadline = DateTime.now().add(const Duration(minutes: 5));
        while (DateTime.now().isBefore(deadline)) {
          await t.pump(const Duration(seconds: 1));
          if (find.byType(ScanPhotoFrame).evaluate().isEmpty &&
              find.byType(ChatCaptureCard).evaluate().isEmpty) {
            break;
          }
          if (find.byType(ChatCaptureCard).evaluate().isNotEmpty &&
              !t
                  .widget<ChatCaptureCard>(find.byType(ChatCaptureCard).first)
                  .disabled) {
            break;
          }
        }
        expect(find.byType(ChatCaptureCard), findsOneWidget);
        final card = t.widget<ChatCaptureCard>(find.byType(ChatCaptureCard));
        expect(card.disabled, false);
        final draft = card.draft;
        expect(draft['status'], 'draft');
        final original = jsonEncode(draft);
        final rows = (draft['items'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        final sorted = scanDisplayRows(rows);
        var unknownSeen = false;
        double? previous;
        for (final row in sorted) {
          final unknown = scanUnknown(row);
          if (unknown && !unknownSeen) {
            unknownSeen = true;
            previous = null;
          }
          expect(unknownSeen && !unknown, false);
          final confidence = scanConfidence(row);
          if (confidence != null && previous != null) {
            expect(confidence, lessThanOrEqualTo(previous));
          }
          previous = confidence;
        }
        expect(jsonEncode(draft), original);
        await t.pump(const Duration(seconds: 2));
        expect(t.takeException(), isNull);
        await screenshot(t, '$scenario-review');
        final fields =
            rows
                .expand((r) => (r['item'] as Map).keys.cast<String>())
                .toSet()
                .toList()
              ..sort();
        debugPrint(
          'LIVE_SCAN_RESULT ${jsonEncode({'scenario': scenario, 'items': rows.length, 'confidence_values': sorted.map(scanConfidence).toList(), 'unknowns': sorted.where(scanUnknown).length, 'returned_fields': fields, 'crop_count': rows.where((r) => (r['item'] as Map)['image_url'] != null).length, 'display_preserved_draft': jsonEncode(draft) == original, 'no_inventory_save_requested': true})}',
        );
        await t.tap(find.byTooltip('Keep draft in chat'));
        await t.pump(const Duration(seconds: 1));
        await t.pumpWidget(const SizedBox());
      },
      timeout: const Timeout(Duration(minutes: 7)),
    );
  }
}
