import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/main.dart';
import 'package:mobile/core/appearance_controller.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/profile/appearance_settings.dart';
import 'package:mobile/features/shell/home_navigation.dart';

class _Storage implements AppearanceStorage {
  final values = <String, String>{};
  bool succeeds = true;
  Completer<bool>? pending;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<bool> write(String key, String value) async {
    final result = pending == null ? succeeds : await pending!.future;
    if (result) values[key] = value;
    return result;
  }
}

class _Probe extends StatelessWidget {
  const _Probe({required this.form});
  final TextEditingController form;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      children: [
        const AppearanceSettings(),
        TextField(key: const Key('appearance-draft'), controller: form),
        Text(
          'Theme probe',
          key: const Key('theme-probe'),
          style: TextStyle(color: AppTheme.textPrimary(context)),
        ),
      ],
    ),
    bottomNavigationBar: HomeNavigation(selectedIndex: 4, onSelected: (_) {}),
  );
}

Future<void> _open(
  WidgetTester tester,
  AppearanceController controller,
  TextEditingController form,
) async {
  await controller.load();
  await tester.pumpWidget(MyApp(appearance: controller));
  await tester.pump();
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  unawaited(
    navigator.push(MaterialPageRoute<void>(builder: (_) => _Probe(form: form))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-key',
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.findez.app/push'),
          (_) async => null,
        );
  });

  testWidgets(
    'real app switches modes in-place without losing the route or draft',
    (tester) async {
      final controller = AppearanceController(storage: _Storage());
      final form = TextEditingController(text: 'Unsaved inventory notes');
      addTearDown(controller.dispose);
      addTearDown(form.dispose);
      await _open(tester, controller, form);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.light]) {
        await tester.tap(
          find.widgetWithText(
            ChoiceChip,
            mode == ThemeMode.light ? 'Light' : 'Dark',
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byKey(const Key('theme-probe')));
        expect(
          Theme.of(context).brightness,
          mode == ThemeMode.light ? Brightness.light : Brightness.dark,
        );
        expect(
          tester.state<NavigatorState>(find.byType(Navigator).first),
          same(nav),
        );
        expect(form.text, 'Unsaved inventory notes');
        final overlay = tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
            )
            .value;
        expect(
          overlay.statusBarBrightness,
          mode == ThemeMode.light ? Brightness.light : Brightness.dark,
        );
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .labelBehavior,
          NavigationDestinationLabelBehavior.alwaysHide,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'System tracks live device changes while explicit modes ignore them',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final controller = AppearanceController(storage: _Storage());
      final form = TextEditingController();
      addTearDown(controller.dispose);
      addTearDown(form.dispose);
      await controller.setThemeMode(ThemeMode.system);
      await _open(tester, controller, form);
      Brightness brightness() =>
          Theme.of(tester.element(find.byType(_Probe))).brightness;
      expect(brightness(), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      await controller.setThemeMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await controller.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'root honors device text scaling and Bold Text after changing size',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.7;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(boldText: true);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final controller = AppearanceController(storage: _Storage());
      final form = TextEditingController();
      addTearDown(controller.dispose);
      addTearDown(form.dispose);
      await _open(tester, controller, form);
      MediaQueryData media() =>
          MediaQuery.of(tester.element(find.byType(_Probe)));
      expect(media().textScaler.scale(15), closeTo(25.5, .001));
      expect(media().boldText, isTrue);
      await controller.setTextSize(AppTextSize.larger);
      await tester.pumpAndSettle();
      expect(media().textScaler.scale(15), closeTo(33.15, .001));
      expect(media().boldText, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed save is visible and pending saves disable duplicate choices',
    (tester) async {
      final storage = _Storage()..succeeds = false;
      final controller = AppearanceController(storage: storage);
      final form = TextEditingController();
      addTearDown(controller.dispose);
      addTearDown(form.dispose);
      await _open(tester, controller, form);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Light'));
      await tester.pumpAndSettle();
      expect(controller.themeMode, ThemeMode.dark);
      expect(
        find.textContaining('Could not save appearance settings'),
        findsOneWidget,
      );
      storage.pending = Completer<bool>();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Light'));
      await tester.pump();
      expect(
        tester
            .widgetList<ChoiceChip>(find.byType(ChoiceChip))
            .every((chip) => chip.onSelected == null),
        isTrue,
      );
      storage.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(controller.themeMode, ThemeMode.light);
      expect(
        find.textContaining('Could not save appearance settings'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('${mode.name} settings wrap safely at 320pt and 2.6x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = AppearanceController(storage: _Storage());
      final form = TextEditingController();
      addTearDown(controller.dispose);
      addTearDown(form.dispose);
      await controller.setThemeMode(mode);
      await controller.setTextSize(AppTextSize.larger);
      await _open(tester, controller, form);
      await tester.scrollUntilVisible(find.text('Preview'), 200);
      expect(find.text('The right item, in the right place.'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).height,
        56,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
