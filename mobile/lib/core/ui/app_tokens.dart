import 'package:flutter/material.dart';

/// Shared layout and interaction values for the FindEZ mobile product.
///
/// Color remains owned by AppColors. These tokens keep spacing, shape,
/// motion, and touch targets consistent as product destinations evolve.
abstract final class AppTokens {
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;
  static const double radiusPill = 999;

  static const double minimumTouchTarget = 44;
  static const double primaryNavigationHeight = 72;
  static const EdgeInsets pagePadding = EdgeInsets.all(space16);

  static const Duration motionFast = Duration(milliseconds: 140);
  static const Duration motionStandard = Duration(milliseconds: 180);
}
