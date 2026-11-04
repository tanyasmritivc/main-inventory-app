import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/ui/swipe_down_sheet.dart';

// Local to Space v2; never changes the app's global theme.
abstract final class SpaceStyle {
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
  static TextStyle text(double size, [Color color = tx]) =>
      TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w400);
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  static BoxDecoration card([double radius = 22, Color color = s1]) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line),
      );
  static ThemeData theme(BuildContext context) => Theme.of(context).copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      surface: s1,
      primary: white,
      onPrimary: bg,
      onSurface: tx,
    ),
    textTheme: Theme.of(
      context,
    ).textTheme.apply(bodyColor: tx, displayColor: tx),
    iconTheme: const IconThemeData(color: tx, size: 20),
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
          MediaQuery.viewInsetsOf(ctx).bottom +
              (ask ? 0 : MediaQuery.paddingOf(ctx).bottom),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                ((ask
                            ? MediaQuery.sizeOf(ctx).height - 56
                            : MediaQuery.sizeOf(ctx).height * .86) -
                        MediaQuery.viewInsetsOf(ctx).bottom)
                    .clamp(0, double.infinity),
          ),
          child: Material(
            color: ask ? SpaceStyle.ask : SpaceStyle.sheet,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ask ? 32 : 38),
                bottom: Radius.circular(ask ? 0 : 38),
              ),
              side: const BorderSide(color: SpaceStyle.line2),
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
        data: SpaceStyle.theme(context),
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
        color: Colors.white.withValues(alpha: .2),
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
        backgroundColor: white ? SpaceStyle.white : SpaceStyle.s1,
        foregroundColor: white ? SpaceStyle.bg : SpaceStyle.tx,
        disabledForegroundColor: SpaceStyle.tx3,
        side: const BorderSide(color: SpaceStyle.line2),
      ),
      icon: Icon(icon, size: 22),
    ),
  );
}
