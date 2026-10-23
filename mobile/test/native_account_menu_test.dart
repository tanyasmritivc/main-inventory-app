import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/appearance_controller.dart';
import 'package:mobile/core/profile_store.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/profile/native_account_menu.dart';
import 'support/hierarchy_fixture.dart';

class Storage implements AppearanceStorage {
  bool fail = false;
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<bool> write(String key, String value) async {
    if (fail) return false;
    values[key] = value;
    return true;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(() async {
    await fixture.initialize();
    fixture.respond = (_) => {'user_id': 'actor-a', 'display_name': 'Alex'};
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets(
    'native settings persist confirmed preferences and retain prior selection on failure',
    (tester) async {
      final storage = Storage();
      final appearance = AppearanceController(storage: storage);
      await appearance.load();
      final profile = ProfileStore(api: fixture.api);
      addTearDown(appearance.dispose);
      addTearDown(profile.dispose);
      late Completer<Object?> completion;
      late Map model;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativePresentation.channel,
        (call) async {
          if (call.method == 'present') {
            model = call.arguments as Map;
            completion = Completer<Object?>();
            return completion.future;
          }
          return null;
        },
      );
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          NativePresentation.channel,
          null,
        ),
      );
      late BuildContext context;
      await tester.pumpWidget(
        AppearanceScope(
          controller: appearance,
          child: MaterialApp(
            home: Builder(
              builder: (c) {
                context = c;
                return const Scaffold();
              },
            ),
          ),
        ),
      );
      final pending = showNativeAccountMenu(
        context,
        api: fixture.api,
        profile: profile,
      );
      await tester.pumpAndSettle();
      const codec = StandardMethodCodec();
      Future<Map> action(String id, [bool? value]) async {
        final result = Completer<Map>();
        await binding.defaultBinaryMessenger.handlePlatformMessage(
          NativePresentation.channel.name,
          codec.encodeMethodCall(
            MethodCall('action', {
              'token': model['token'],
              'id': id,
              'value': value,
            }),
          ),
          (bytes) => result.complete(codec.decodeEnvelope(bytes!) as Map),
        );
        return result.future;
      }

      final changed = await action('theme:dark');
      expect(changed['dark'], true);
      expect(appearance.themeMode, ThemeMode.dark);
      expect(storage.values[AppearanceController.themeKey], 'dark');
      storage.fail = true;
      final failed = await action('theme:light');
      expect(failed['error'], isNotNull);
      expect(failed['dark'], true);
      await action('scan', true);
      expect(
        (await SharedPreferences.getInstance()).getBool('confirm_before_save'),
        true,
      );
      final accountRows =
          ((model['sections'] as List).last as Map)['rows'] as List;
      expect(accountRows.last['confirmation']['destructive'], true);
      expect(
        accountRows.last['confirmation']['message'],
        contains('cannot be undone'),
      );
      completion.complete(null);
      await tester.pumpAndSettle();
      await pending;
      expect(tester.takeException(), isNull);
    },
  );
}
