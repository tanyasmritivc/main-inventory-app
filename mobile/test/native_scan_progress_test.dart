import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/native_scan_progress.dart';
import 'package:mobile/features/chat/scan_region.dart';
import 'package:mobile/core/ui/photo_scan_hint.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native scan retains events, all regions, Stop and disposal', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final messenger = binding.defaultBinaryMessenger;
    MethodChannel? channel;
    final models = <Map>[];
    final photos = <Object?>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        expect(args['viewType'], 'com.findez.app/scan-progress');
        models.add(
          args['params'] == null
              ? {}
              : const StandardMessageCodec().decodeMessage(
                      ByteData.sublistView(args['params'] as Uint8List),
                    )
                    as Map,
        );
        channel = MethodChannel('com.findez.app/scan-progress/${args['id']}');
        messenger.setMockMethodCallHandler(channel!, (call) async {
          if (call.method == 'configure') models.add(call.arguments as Map);
          if (call.method == 'photo') photos.add(call.arguments);
          return null;
        });
      }
      return null;
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      if (channel != null) messenger.setMockMethodCallHandler(channel!, null);
    });
    var message = 'Finding objects';
    var regions = <ScanRegion>[];
    var dark = false;
    var reduced = false;
    var stops = 0;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: reduced,
                textScaler: TextScaler.linear(2),
              ),
              child: SizedBox(
                width: 320,
                height: 300,
                child: NativeScanProgress(
                  image: const AssetImage(
                    'assets/onboarding/sample_workbench.jpg',
                  ),
                  message: message,
                  regions: regions,
                  onStop: () => stops++,
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(channel, isNotNull);
    expect(models.last['progress'], .25);
    expect(models.last['textScale'], 2);
    expect(models.last['tips'], scanTips);
    update(() {
      message = 'Checked 30 of 30';
      regions = List.generate(
        30,
        (i) => ScanRegion(
          i,
          const Rect.fromLTRB(.1, .2, .3, .4),
          ScanRegionPhase.checked,
        ),
      );
    });
    await tester.pump();
    expect(models.last['progress'], .75);
    expect(models.last['regions'], hasLength(30));
    expect((models.last['regions'] as List).last, {
      'id': 29,
      'box': [.1, .2, .3, .4],
      'phase': 'checked',
      'status': 'Checked',
    });
    update(() {
      message = 'Finding objects';
      dark = true;
      reduced = true;
    });
    await tester.pumpAndSettle();
    expect(
      models.last['progress'],
      .75,
      reason: 'Late events never rewind progress',
    );
    expect(models.last['dark'], true);
    expect(models.last['reduceMotion'], true);
    expect(models.last['steps'], [
      'Finding objects',
      'Checked 30 of 30',
      'Finding objects',
    ]);
    for (var i = 0; i < 35; i++) {
      update(() => message = 'Step $i');
      await tester.pump();
    }
    expect(models.last['steps'], hasLength(30));
    expect((models.last['steps'] as List).last, 'Step 34');
    Future<void> event(String method) async {
      final done = Completer<void>();
      await messenger.handlePlatformMessage(
        channel!.name,
        const StandardMethodCodec().encodeMethodCall(MethodCall(method)),
        (_) => done.complete(),
      );
      await done.future;
    }

    await event('unknown');
    expect(stops, 0);
    await event('stop');
    await event('stop');
    expect(stops, 1);
    await tester.pumpWidget(const SizedBox());
    await event('stop');
    expect(stops, 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
