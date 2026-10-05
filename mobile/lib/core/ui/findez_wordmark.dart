import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_theme.dart';
import 'brand_colors.dart';

/// Original outlined artwork, not a font approximation or whole-image tint.
class FindEZWordmark extends StatelessWidget {
  const FindEZWordmark({super.key, this.width = 208});

  final double width;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/brand/findez-wordmark.svg',
    width: width,
    semanticsLabel: 'FindEZ',
    colorMapper: AppTheme.isDark(context) ? const _ReverseInk() : null,
  );
}

class _ReverseInk extends ColorMapper {
  const _ReverseInk();

  @override
  Color substitute(String? id, String element, String attribute, Color color) =>
      color == BrandColors.ink ? BrandColors.paper : color;
}
