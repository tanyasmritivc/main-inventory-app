import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/world/native_bottom_tabs.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native tabs synchronize selection, theme and callback lifecycle',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger = binding.defaultBinaryMessenger;
      final configurations = <Map<Object?, Object?>>[];
      MethodChannel? channel;
      final platformCalls = <String>[];
      var ancestorTaps = 0;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        platformCalls.add(call.method);
        if (call.method == 'create') {
          final args = call.arguments as Map<Object?, Object?>;
          channel = MethodChannel('com.findez.app/native-tabs/${args['id']}');
          messenger.setMockMethodCallHandler(channel!, (call) async {
            if (call.method == 'configure') {
              configurations.add(call.arguments as Map<Object?, Object?>);
            }
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
      var selected = 0;
      var dark = false;
      var changes = 0;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MaterialApp(
              builder: (context, child) => GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: MediaQuery.viewInsetsOf(context).bottom > 0
                    ? () => ancestorTaps++
                    : null,
                child: child,
              ),
              theme: ThemeData(
                brightness: dark ? Brightness.dark : Brightness.light,
              ),
              home: Center(
                child: SizedBox(
                  width: 288,
                  child: NativeBottomTabs(
                    selected: selected,
                    onSelected: (index) => setState(() {
                      selected = index;
                      changes++;
                    }),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(configurations.last, {
        'selected': 0,
        'dark': false,
        'reduceMotion': false,
      });
      platformCalls.clear();
      await tester.tap(find.byType(UiKitView));
      await tester.pumpAndSettle();
      expect(platformCalls, contains('acceptGesture'));
      expect(ancestorTaps, 0);
      platformCalls.clear();
      await tester.drag(find.byType(UiKitView), const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(platformCalls, contains('acceptGesture'));
      expect(ancestorTaps, 0);
      Future<void> nativeEvent(
        Object? value, {
        String method = 'selected',
      }) async {
        final done = Completer<void>();
        await messenger.handlePlatformMessage(
          channel!.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, value),
          ),
          (_) => done.complete(),
        );
        await done.future;
        await tester.pumpAndSettle();
      }

      await nativeEvent(1);
      expect(selected, 1);
      expect(changes, 1);
      expect(configurations.last['selected'], 1);
      for (final invalid in [-1, 3, '2', null, 1]) {
        await nativeEvent(invalid);
      }
      await nativeEvent(2, method: 'unknown');
      expect(changes, 1);
      update(() {
        selected = 2;
        dark = true;
      });
      await tester.pumpAndSettle();
      expect(configurations.last, {
        'selected': 2,
        'dark': true,
        'reduceMotion': false,
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await nativeEvent(0);
      expect(changes, 1);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
