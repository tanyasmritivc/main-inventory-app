import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class MotionPreferences {
  const MotionPreferences({
    this.reduceMotion = false,
    this.preferCrossFade = false,
  });
  final bool reduceMotion, preferCrossFade;
}

/// Reads UIKit's real preferences, including live changes and app resume.
class NativeMotionPreferences extends ValueNotifier<MotionPreferences>
    with WidgetsBindingObserver {
  NativeMotionPreferences() : super(const MotionPreferences());
  static final instance = NativeMotionPreferences();
  static const channel = MethodChannel('com.findez.app/motion');
  bool _started = false;

  Future<void> initialize() async {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed' && call.arguments is Map) {
        _apply(call.arguments as Map);
      }
    });
    await refresh();
  }

  void _apply(Map values) {
    final next = MotionPreferences(
      reduceMotion: values['reduceMotion'] == true,
      preferCrossFade: values['preferCrossFade'] == true,
    );
    if (next.reduceMotion != value.reduceMotion ||
        next.preferCrossFade != value.preferCrossFade) {
      value = next;
    }
  }

  Future<void> refresh() async {
    try {
      final values = await channel.invokeMapMethod<String, dynamic>(
        'preferences',
      );
      if (values != null) _apply(values);
    } on MissingPluginException {
      // Older hosts still honor Flutter's Reduce Motion signal.
    } on PlatformException {
      // Keep the last native preference and Flutter's accessibility fallback.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_started && state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      channel.setMethodCallHandler(null);
    }
    super.dispose();
  }
}

/// A short stationary dissolve, with no scale/translation or blank frame.
/// The outgoing scene stays almost opaque underneath the incoming scene, so
/// their composited contribution never creates a dip through black/white.
abstract final class NavigationMotion {
  static const duration = Duration(milliseconds: 160);
  static const incomingCurve = Interval(.10, 1, curve: Curves.easeInOut);
  static const outgoingCurve = Interval(0, .35, curve: Curves.easeInOut);
  static double incoming(double progress) => incomingCurve.transform(progress);
  static double outgoing(double progress) =>
      1 - .06 * outgoingCurve.transform(progress);

  static bool enabled(BuildContext context, MotionPreferences preferences) {
    // Prefer Cross-Fade is nested under Reduce Motion on iOS. Its explicit
    // selection enables a non-spatial dissolve instead of disabling it.
    if (preferences.preferCrossFade) return true;
    return !preferences.reduceMotion &&
        !MediaQuery.disableAnimationsOf(context);
  }
}
