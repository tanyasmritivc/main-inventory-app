import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTextSize {
  small('Small', 0.9),
  standard('Default', 1),
  large('Large', 1.15),
  larger('Larger', 1.3);

  const AppTextSize(this.label, this.factor);
  final String label;
  final double factor;
}

abstract interface class AppearanceStorage {
  Future<String?> read(String key);
  Future<bool> write(String key, String value);
}

class DeviceAppearanceStorage implements AppearanceStorage {
  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(key);
    return value is String ? value : null;
  }

  @override
  Future<bool> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}

/// Device-local accessibility preferences, not inventory/account data.
class AppearanceController extends ChangeNotifier {
  AppearanceController({AppearanceStorage? storage})
    : _storage = storage ?? DeviceAppearanceStorage();

  static const themeKey = 'findez.appearance.theme.v1';
  static const textSizeKey = 'findez.appearance.text-size.v1';
  final AppearanceStorage _storage;
  ThemeMode _themeMode =
      ThemeMode.dark; // Preserve the approved existing default.
  AppTextSize _textSize = AppTextSize.standard;
  bool _loaded = false;
  bool _saving = false;
  bool _disposed = false;
  String? _error;
  Future<void>? _loadFuture;

  ThemeMode get themeMode => _themeMode;
  AppTextSize get textSize => _textSize;
  bool get loaded => _loaded;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final theme = await _storage.read(themeKey);
      final size = await _storage.read(textSizeKey);
      if (_disposed) return;
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == theme,
        orElse: () => ThemeMode.dark,
      );
      _textSize = AppTextSize.values.firstWhere(
        (value) => value.name == size,
        orElse: () => AppTextSize.standard,
      );
    } catch (_) {
      if (_disposed) return;
      _error =
          'Could not load appearance settings. Default settings are in use.';
    }
    if (_disposed) return;
    _loaded = true;
    notifyListeners();
  }

  Future<bool> setThemeMode(ThemeMode mode) =>
      _save(themeKey, mode.name, () => _themeMode = mode);

  Future<bool> setTextSize(AppTextSize size) =>
      _save(textSizeKey, size.name, () => _textSize = size);

  Future<bool> _save(String key, String value, VoidCallback publish) async {
    await load();
    if (_disposed || _saving) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      if (!await _storage.write(key, value)) {
        throw StateError('Preference write was not confirmed');
      }
      if (_disposed) return false;
      publish();
      return true;
    } catch (_) {
      if (!_disposed) {
        _error = 'Could not save appearance settings. Please try again.';
      }
      return false;
    } finally {
      if (!_disposed) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  /// Compose with iOS/Android's scaler, including nonlinear accessibility sizes.
  TextScaler textScaler(TextScaler system) => _textSize == AppTextSize.standard
      ? system
      : AppTextScaler(system, _textSize.factor);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppTextScaler extends TextScaler {
  const AppTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;

  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is AppTextScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppearanceController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}
