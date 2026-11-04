// Opt-in, disposable-account verification. No credentials or customer data here.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
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
import 'package:mobile/features/chat/auto_extract/extract_widgets.dart';
import 'package:mobile/features/chat/chat_capture_card.dart';
import '../test/support/extract_photo_fixture.dart';

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
      find.byKey(const Key('live-scan-frame')),
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final path = '${Directory.systemTemp.path}/$name.png';
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    debugPrint('PHOTO_SCAN_IMAGE $path');
  }

  for (final scenario in [
    'portrait',
    'landscape',
    'one-item',
    'many-items',
    'single-bearing',
  ]) {
    testWidgets(
      'live production scan $scenario retains an unsaved review draft',
      (t) async {
        final bench = (await rootBundle.load(
          'assets/onboarding/sample_workbench.jpg',
        )).buffer.asUint8List();
        Uint8List photo;
        if (scenario == 'portrait') {
          photo = Uint8List.fromList(
            img.encodeJpg(
              img.copyRotate(img.decodeJpg(extractPhotoFixture)!, angle: 90),
            ),
          );
        } else if (scenario == 'one-item') {
          photo = Uint8List.fromList(
            img.encodeJpg(
              img.copyCrop(
                img.decodeJpg(bench)!,
                x: 470,
                y: 0,
                width: 460,
                height: 240,
              ),
            ),
          );
        } else if (scenario == 'single-bearing') {
          photo = Uint8List.fromList(
            img.encodeJpg(
              img.copyResize(
                img.copyCrop(
                  img.decodeJpg(bench)!,
                  x: 125,
                  y: 427,
                  width: 72,
                  height: 62,
                ),
                width: 576,
              ),
            ),
          );
        } else {
          photo = scenario == 'many-items' ? bench : extractPhotoFixture;
        }
        Map<String, dynamic>? draft;
        String? conversation;
        String status = 'Preparing your photo…';
        bool finished = false;
        Object? failure;
        late StateSetter render;
        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(Brightness.dark),
            home: RepaintBoundary(
              key: const Key('live-scan-frame'),
              child: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(15),
                    child: StatefulBuilder(
                      builder: (_, set) {
                        render = set;
                        return draft != null && finished
                            ? ChatCaptureCard(
                                api: api,
                                conversationId: conversation!,
                                draft: draft!,
                                photoBytes: photo,
                                scanPreview: true,
                                onChanged: (v) => render(() => draft = v),
                              )
                            : ExtractScanning(photo: photo, message: status);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final subscription = api
            .aiPhotoQuestionStream(
              message: '',
              photo: AskPhoto(bytes: photo, autoExtract: true),
              previewOnly: true,
            )
            .listen(
              (event) {
                render(() {
                  conversation = event.conversationId ?? conversation;
                  if (event.type == 'status') status = event.message ?? status;
                  draft = event.answerContext?.chatCapture ?? draft;
                  if (event.type == 'done') finished = true;
                });
              },
              onError: (Object e) {
                failure = e;
                finished = true;
              },
              onDone: () {
                render(() => finished = true);
              },
            );
        await t.pump(const Duration(milliseconds: 600));
        await screenshot(t, 'live-$scenario-scanning');
        final deadline = DateTime.now().add(const Duration(minutes: 4));
        while (!finished && DateTime.now().isBefore(deadline)) {
          await t.pump(const Duration(milliseconds: 500));
        }
        await subscription.cancel();
        expect(failure, isNull);
        expect(finished, isTrue);
        expect(draft, isNotNull);
        expect(conversation, isNotNull);
        expect(draft!['status'], 'draft');
        final rows = (draft!['items'] as List).cast<Map>();
        expect(rows, isNotEmpty);
        await t.pumpAndSettle();
        final review = find.textContaining('Review ').last;
        await t.ensureVisible(review);
        await t.pumpAndSettle();
        await screenshot(t, 'live-$scenario-done');
        debugPrint(
          'LIVE_SCAN_RESULT ${jsonEncode({'scenario': scenario, 'items': rows.length, 'crop_urls': rows.where((r) => r['item']['image_url'] != null).length, 'draft_status': draft!['status']})}',
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}
