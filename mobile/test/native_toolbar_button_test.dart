import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ui/native_menu_button.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native toolbar accepts only current actions and detaches on dispose',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger = binding.defaultBinaryMessenger;
      MethodChannel? channel;
      final configurations = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          channel = MethodChannel(
            'com.findez.app/toolbar-control/${args['id']}',
          );
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
      final selected = <String>[];
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return MaterialApp(
              home: NativeToolbarButton(
                symbol: 'ellipsis',
                label: 'Options',
                items: const [AppMenuItem('rename', 'Rename', 'pencil')],
                onSelected: enabled ? selected.add : null,
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(configurations.last['enabled'], true);
      Future<void> event(Object? action) async {
        final done = Completer<void>();
        await messenger.handlePlatformMessage(
          channel!.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('selected', action),
          ),
          (_) => done.complete(),
        );
        await done.future;
        await tester.pumpAndSettle();
      }

      await event('unknown');
      await event('__press__');
      await event('rename');
      expect(selected, ['rename']);
      update(() => enabled = false);
      await tester.pumpAndSettle();
      expect(configurations.last['enabled'], false);
      await event('rename');
      expect(selected, ['rename']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await event('rename');
      expect(selected, ['rename']);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
