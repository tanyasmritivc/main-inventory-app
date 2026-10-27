import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/pip_extract_loader.dart';

void main() {
  Future<PipExtractLoaderHandle> open(
    WidgetTester tester, {
    bool reduced = false,
    double scale = 1,
    VoidCallback? onStop,
  }) async {
    late PipExtractLoaderHandle handle;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  handle = showPipExtractLoader(context, onStop: onStop),
              child: const Text('Photo'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return handle;
  }

  testWidgets('captions stop, no fictional counts, barrier cannot dismiss', (
    tester,
  ) async {
    final handle = await open(tester);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Preparing your photo...'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await tester.binding.handlePopRoute();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1500));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Preparing your photo...'), findsOneWidget);
    expect(find.textContaining('s elapsed'), findsOneWidget);
    handle.update('Reading details for 3 objects...');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Reading details for 3 objects...'), findsOneWidget);
    expect(find.textContaining('found'), findsNothing);
    handle.dismiss();
    handle.dismiss();
    await tester.pumpAndSettle();
    expect(find.byType(PipExtractLoader), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Stop during success cancels the hold without completing twice', (
    tester,
  ) async {
    var stops = 0;
    final handle = await open(tester, onStop: () => stops++);
    unawaited(handle.succeed(2));
    await tester.pump();
    await tester.tap(find.text('Stop extraction'));
    await tester.pumpAndSettle();
    handle.stop();
    expect(stops, 1);
    expect(find.byType(PipExtractLoader), findsNothing);
  });

  for (final count in [0, 1, 8]) {
    testWidgets('success uses real $count count and holds before dismissal', (
      tester,
    ) async {
      final handle = await open(tester);
      var finished = false;
      unawaited(handle.succeed(count).then((_) => finished = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.text('Found $count ${count == 1 ? 'item' : 'items'}'),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<SvgPicture>(find.byType(SvgPicture))
            .every(
              (svg) => (svg.bytesLoader as SvgAssetLoader).assetName.endsWith(
                'pip-found-it.svg',
              ),
            ),
        isTrue,
      );
      expect(finished, isFalse);
      await tester.pump(const Duration(milliseconds: 249));
      expect(finished, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(find.byType(PipExtractLoader), findsNothing);
    });
  }

  testWidgets(
    'Reduce Motion has no animated frames or seeds, including success',
    (tester) async {
      final handle = await open(tester, reduced: true);
      await tester.pump(const Duration(seconds: 8));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.byType(BackdropFilter), findsOneWidget);
      unawaited(handle.succeed(2));
      await tester.pump();
      expect(find.text('Found 2 items'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      handle.dismiss();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('iOS Reduce Motion stops an already running loader', (
    tester,
  ) async {
    final handle = await open(tester);
    await tester.pump(const Duration(milliseconds: 1600));
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isFalse);
    unawaited(handle.succeed(1));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('Found 1 item'), findsOneWidget);
    handle.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('early disposal resolves a success wait and releases timers', (
    tester,
  ) async {
    final handle = await open(tester);
    var finished = false;
    unawaited(handle.succeed(4).then((_) => finished = true));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('large text fits a small display', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final handle = await open(tester, reduced: true, scale: 3.2);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 1500));
      expect(tester.takeException(), isNull);
    }
    handle.update('Checking confidence and trimming item photos...');
    await tester.pump();
    expect(find.text('Checking confidence and trimming item photos...'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dismiss();
    await tester.pumpAndSettle();
  });
}
