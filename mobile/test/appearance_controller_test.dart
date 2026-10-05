import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/appearance_controller.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_colors.dart';

class _Storage implements AppearanceStorage {
  final values = <String, String>{};
  bool failRead = false, failWrite = false, confirms = true;
  int reads = 0, writes = 0;
  Completer<bool>? pending;
  @override
  Future<String?> read(String key) async {
    reads++;
    if (failRead) throw StateError('SECRET disk exception');
    return values[key];
  }

  @override
  Future<bool> write(String key, String value) async {
    writes++;
    if (failWrite) throw StateError('SECRET disk exception');
    final saved = pending == null ? confirms : await pending!.future;
    if (saved) values[key] = value;
    return saved;
  }
}

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();
  @override
  double scale(double size) => size < 20 ? size * 2 : size * 1.5;
  @override
  double get textScaleFactor => 2;
}

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  test(
    'first launch preserves dark appearance and system text scaling',
    () async {
      final storage = _Storage();
      final controller = AppearanceController(storage: storage);
      addTearDown(controller.dispose);
      await Future.wait([controller.load(), controller.load()]);
      expect(storage.reads, 2);
      expect(controller.loaded, isTrue);
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.textSize, AppTextSize.standard);
      const system = _NonlinearScaler();
      expect(identical(controller.textScaler(system), system), isTrue);
    },
  );

  for (final mode in ThemeMode.values) {
    for (final size in AppTextSize.values) {
      test(
        '${mode.name}/${size.name} persists into a fresh controller',
        () async {
          final storage = _Storage();
          final first = AppearanceController(storage: storage);
          await first.load();
          expect(await first.setThemeMode(mode), isTrue);
          expect(await first.setTextSize(size), isTrue);
          first.dispose();
          final second = AppearanceController(storage: storage);
          addTearDown(second.dispose);
          await second.load();
          expect(second.themeMode, mode);
          expect(second.textSize, size);
          expect(
            second.textScaler(const TextScaler.linear(2)).scale(15),
            closeTo(30 * size.factor, .001),
          );
        },
      );
    }
  }

  test(
    'real SharedPreferences handles invalid types and unrelated data',
    () async {
      SharedPreferences.setMockInitialValues({
        AppearanceController.themeKey: 7,
        AppearanceController.textSizeKey: 'unknown',
        'inventory-draft': 'preserved',
      });
      final controller = AppearanceController();
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.textSize, AppTextSize.standard);
      await controller.setThemeMode(ThemeMode.light);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppearanceController.themeKey), 'light');
      expect(prefs.getString('inventory-draft'), 'preserved');
    },
  );

  test(
    'read failures use safe defaults and still allow a later save',
    () async {
      final storage = _Storage()..failRead = true;
      final controller = AppearanceController(storage: storage);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.loaded, isTrue);
      expect(controller.error, contains('Could not load'));
      expect(controller.error, isNot(contains('SECRET')));
      expect(await controller.setThemeMode(ThemeMode.light), isTrue);
      expect(controller.error, isNull);
    },
  );

  test(
    'failed writes retain previous settings and expose a retryable error',
    () async {
      final storage = _Storage()..failWrite = true;
      final controller = AppearanceController(storage: storage);
      addTearDown(controller.dispose);
      expect(await controller.setThemeMode(ThemeMode.light), isFalse);
      expect(controller.themeMode, ThemeMode.dark);
      expect(
        controller.error,
        'Could not save appearance settings. Please try again.',
      );
      storage
        ..failWrite = false
        ..confirms = false;
      expect(await controller.setTextSize(AppTextSize.larger), isFalse);
      expect(controller.textSize, AppTextSize.standard);
      storage.confirms = true;
      expect(await controller.setTextSize(AppTextSize.larger), isTrue);
      expect(controller.error, isNull);
    },
  );

  test('pending writes cannot publish early or race a second change', () async {
    final storage = _Storage()..pending = Completer<bool>();
    final controller = AppearanceController(storage: storage);
    addTearDown(controller.dispose);
    await controller.load();
    final save = controller.setThemeMode(ThemeMode.light);
    await Future<void>.delayed(Duration.zero);
    expect(controller.saving, isTrue);
    expect(controller.themeMode, ThemeMode.dark);
    expect(await controller.setTextSize(AppTextSize.large), isFalse);
    expect(storage.writes, 1);
    storage.pending!.complete(true);
    expect(await save, isTrue);
    expect(controller.saving, isFalse);
    expect(controller.themeMode, ThemeMode.light);
  });

  test(
    'late writes after disposal never notify a disposed controller',
    () async {
      final storage = _Storage()..pending = Completer<bool>();
      final controller = AppearanceController(storage: storage);
      await controller.load();
      final save = controller.setThemeMode(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      storage.pending!.complete(true);
      expect(await save, isFalse);
    },
  );

  test(
    'custom text size composes with nonlinear accessibility scaling',
    () async {
      final controller = AppearanceController(storage: _Storage());
      addTearDown(controller.dispose);
      await controller.setTextSize(AppTextSize.larger);
      final scaler = controller.textScaler(const _NonlinearScaler());
      expect(scaler.scale(14), closeTo(36.4, .001));
      expect(scaler.scale(24), closeTo(46.8, .001));
      expect(scaler, const AppTextScaler(_NonlinearScaler(), 1.3));
    },
  );

  test(
    'light UI text and semantic status colors meet normal-text contrast',
    () {
      for (final background in [
        AppTheme.lightSurface,
        AppTheme.lightBg,
        AppTheme.lightSurface2,
      ]) {
        for (final foreground in [
          AppTheme.lightTextPrimary,
          AppTheme.lightTextSecondary,
          AppTheme.lightTextMuted,
          AppTheme.lightHint,
          AppTheme.resolve(Brightness.light, AppColors.warning),
          AppTheme.resolve(Brightness.light, AppColors.success),
          AppTheme.resolve(Brightness.light, AppColors.danger),
          AppTheme.resolve(Brightness.light, AppColors.accent),
        ]) {
          expect(
            _contrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '$foreground on $background',
          );
        }
      }
      expect(
        _contrast(
          Colors.white,
          AppTheme.resolve(Brightness.light, AppColors.accent),
        ),
        greaterThanOrEqualTo(4.5),
      );
      final theme = AppTheme.create(Brightness.light);
      expect(theme.brightness, Brightness.light);
      expect(theme.bottomSheetTheme.backgroundColor, AppTheme.lightSurface);
      expect(
        theme.dialogTheme.titleTextStyle!.color,
        AppTheme.lightTextPrimary,
      );
    },
  );

  test('adaptive palette never changes approved dark colors', () {
    for (final color in [
      Colors.white,
      Colors.black,
      AppColors.surface,
      AppColors.accent,
      AppColors.danger,
      const Color(0x4DFFFFFF),
    ]) {
      expect(AppTheme.resolve(Brightness.dark, color), color);
    }
    expect(
      AppTheme.create(Brightness.dark).scaffoldBackgroundColor,
      Colors.black,
    );
  });
}
