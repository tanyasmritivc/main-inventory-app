import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Compatibility names for existing screens while they adopt AppTokens.of.
/// Reads the platform appearance so legacy widgets adapt with the theme.
class AppColors {
  static AppTokens get _t =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark
      ? AppTokens.dark
      : AppTokens.light;

  static Color get background => _t.bg;
  static Color get surface => _t.card;
  static Color get surface2 => _t.raised;
  static Color get surfaceRaised => _t.raised;
  static Color get chip => _t.raised;
  static Color get swipe => _t.line;
  static Color get border => _t.line;
  static Color get borderStrong => _t.lineStrong;
  static const accent = AppTokens.darkAccent;
  static const onAccent = AppTokens.darkOnAccent;
  static Color get primaryText => _t.ink;
  static Color get muted => _t.text2;
  static Color get hint => _t.text3;
  static Color get success => _t.ok;
  static Color get warning => _t.warn;
  static Color get danger => _t.danger;
  static Color get info => _t.info;
  static const ai = accent;
  static const scan = accent;
  static const blue = accent;
  static const indigo = accent;
  static const purple = accent;
  static Color get orange => warning;
  static Color get pink => danger;
  static Color get brandSlate => muted;
  static Color get brandIce => primaryText;
  static Color get brandIndigo => surfaceRaised;
  static const brandLavender = accent;
  static Color get brandPeriwinkle => primaryText;
  static Color get brandViolet => surfaceRaised;
  static Color get brandMist => muted;
}
