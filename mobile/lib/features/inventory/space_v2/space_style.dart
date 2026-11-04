import 'package:mobile/core/ui/app_typography.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/ui/swipe_down_sheet.dart';

// Local to Space v2; never changes the app's global theme.
abstract final class SpaceStyle {
  static SpacePalette of(BuildContext context) =>
      SpacePalette(Theme.of(context).brightness);
  static const bg = Color(0xFF0B0B0C);
  static const s1 = Color(0xFF1C1C1E);
  static const s2 = Color(0xFF252527);
  static const s3 = Color(0xFF2E2E31);
  static const sheet = Color(0xFF19191B);
  static const ask = Color(0xFF141415);
  static const menu = Color(0xFF242426);
  static const line = Color(0x14FFFFFF);
  static const line2 = Color(0x1FFFFFFF);
  static const tx = Color(0xFFFAFAFA);
  static const tx2 = Color(0xFF9A9AA0);
  static const tx3 = Color(0xFF626268);
  static const white = Color(0xFFF2F2F2);
  static const amber = Color(0xFFD6A84E);
  static const curve = Cubic(.32, .72, 0, 1);
  static TextStyle text(double size, [Color color = tx]) => TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: AppTypography.standardSize(size),
    height: 1.35,
    color: color,
    fontWeight: FontWeight.w400,
  );
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  static BoxDecoration card([double radius = 22, Color color = s1]) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line),
      );
  static ThemeData theme(BuildContext context) {
    final palette = of(context);
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: palette.bg,
      colorScheme: Theme.of(context).colorScheme.copyWith(
        surface: palette.s1,
        primary: palette.white,
        onPrimary: palette.bg,
        onSurface: palette.tx,
      ),
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: palette.tx,
        displayColor: palette.tx,
        fontFamily: 'CupertinoSystemText',
      ),
      iconTheme: IconThemeData(color: palette.tx, size: 20),
    );
  }
}

/// Immutable, context-bound colours also follow live System appearance changes.
class SpacePalette {
  const SpacePalette(this.brightness);
  final Brightness brightness;
  bool get dark => brightness == Brightness.dark;
  Color get bg => dark ? SpaceStyle.bg : const Color(0xFFF8F8FA);
  Color get s1 => dark ? SpaceStyle.s1 : const Color(0xFFEEEEF0);
  Color get s2 => dark ? SpaceStyle.s2 : const Color(0xFFE5E5E8);
  Color get s3 => dark ? SpaceStyle.s3 : const Color(0xFFDADADF);
  Color get sheet => dark ? SpaceStyle.sheet : const Color(0xFFF9F9FA);
  Color get ask => dark ? SpaceStyle.ask : const Color(0xFFFAFAFB);
  Color get menu => dark ? SpaceStyle.menu : const Color(0xFFF0F0F2);
  Color get line => dark ? SpaceStyle.line : const Color(0x14000000);
  Color get line2 => dark ? SpaceStyle.line2 : const Color(0x1F000000);
  Color get tx => dark ? SpaceStyle.tx : const Color(0xFF19191B);
  Color get tx2 => dark ? SpaceStyle.tx2 : const Color(0xFF616167);
  Color get tx3 => dark ? const Color(0xFF929298) : const Color(0xFF6B6B72);
  Color get white => dark ? SpaceStyle.white : const Color(0xFF242426);
  Color get amber => dark ? SpaceStyle.amber : const Color(0xFF795B16);
  Color get button => dark ? const Color(0xFF242424) : const Color(0xFFE7E7E9);
  TextStyle text(double size, [Color? color]) => TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: AppTypography.standardSize(size),
    height: 1.35,
    color: color ?? tx,
    fontWeight: FontWeight.w400,
  );
  BoxDecoration card([double radius = 22, Color? color]) => BoxDecoration(
    color: color ?? s1,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: line),
  );
}

String spaceCount(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

Future<T?> showSpaceSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool ask = false,
}) {
  final reduced = SpaceStyle.reduced(context);
  final duration = reduced
      ? 350
      : ask
      ? 550
      : 500;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: Duration(milliseconds: duration),
    transitionBuilder: (_, _, _, child) => child,
    pageBuilder: (ctx, animation, secondary) {
      final motion = CurvedAnimation(
        parent: animation,
        curve: SpaceStyle.curve,
      );
      final scrim = CurvedAnimation(
        parent: animation,
        curve: Interval(0, 350 / duration, curve: SpaceStyle.curve),
      );
      final sheet = Padding(
        padding: EdgeInsets.fromLTRB(
          ask ? 0 : 8,
          ask ? 56 : 8,
          ask ? 0 : 8,
          MediaQuery.viewInsetsOf(ctx).bottom > 0
              ? MediaQuery.viewInsetsOf(ctx).bottom
              : (ask ? 0 : MediaQuery.paddingOf(ctx).bottom),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                (MediaQuery.sizeOf(ctx).height -
                        MediaQuery.viewInsetsOf(ctx).bottom -
                        MediaQuery.paddingOf(ctx).top -
                        24)
                    .clamp(0, MediaQuery.sizeOf(ctx).height * .9),
          ),
          child: Material(
            color: ask ? SpaceStyle.of(ctx).ask : SpaceStyle.of(ctx).sheet,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ask ? 32 : 38),
                bottom: Radius.circular(ask ? 0 : 38),
              ),
              side: BorderSide(color: SpaceStyle.of(ctx).line2),
            ),
            clipBehavior: Clip.antiAlias,
            child: MediaQuery.removeViewInsets(
              context: ctx,
              removeBottom: true,
              child: SwipeDownSheet(child: builder(ctx)),
            ),
          ),
        ),
      );
      return Theme(
        data: SpaceStyle.theme(ctx),
        child: Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: scrim,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).maybePop(),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: const ColoredBox(color: Color(0x8C000000)),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FadeTransition(
                opacity: motion,
                child: reduced
                    ? sheet
                    : SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 1.05),
                          end: Offset.zero,
                        ).animate(motion),
                        child: sheet,
                      ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class SpaceHandle extends StatelessWidget {
  const SpaceHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 38,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 14),
      decoration: BoxDecoration(
        color: SpaceStyle.of(context).tx.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(9),
      ),
    ),
  );
}

class SpaceCircle extends StatelessWidget {
  const SpaceCircle({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.white = false,
    this.size = 44,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool white;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: white
            ? SpaceStyle.of(context).white
            : SpaceStyle.of(context).s1,
        foregroundColor: white
            ? SpaceStyle.of(context).bg
            : SpaceStyle.of(context).tx,
        disabledForegroundColor: SpaceStyle.of(context).tx3,
        side: BorderSide(color: SpaceStyle.of(context).line2),
      ),
      icon: Icon(icon, size: 22),
    ),
  );
}
