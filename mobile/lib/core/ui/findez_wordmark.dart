import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_theme.dart';

/// Supplied Petals wordmark, with the outlined name preserved in both themes.
class FindEZWordmark extends StatelessWidget {
  const FindEZWordmark({super.key, this.width = 208});

  final double width;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    AppTheme.isDark(context)
        ? 'assets/brand/findez-wordmark-white.svg'
        : 'assets/brand/findez-wordmark.svg',
    width: width,
    semanticsLabel: 'FindEZ',
  );
}
