import 'package:mobile/core/ui/app_typography.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class ExtractStyle {
  static const bg = Color(0xff111112),
      s1 = Color(0xff1c1c1e),
      s2 = Color(0xff232325),
      s3 = Color(0xff2c2c2f),
      sheet = Color(0xff1a1a1c),
      line = Color(0x14ffffff),
      line2 = Color(0x21ffffff),
      tx = Color(0xfffafafa),
      tx2 = Color(0xff9a9aa0),
      tx3 = Color(0xff5f5f64),
      white = Color(0xfff2f2f2),
      ink = Color(0xff0b0b0c),
      red = Color(0xffe5484d);
  static const curve = Cubic(.32, .72, 0, 1);
  static TextStyle text(double size, {Color color = tx}) => TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: AppTypography.standardSize(size),
    color: color,
    fontWeight: FontWeight.w400,
  );
  static ButtonStyle pill({bool primary = false, double height = 46}) =>
      FilledButton.styleFrom(
        backgroundColor: primary ? white : s2,
        foregroundColor: primary ? ink : tx,
        disabledBackgroundColor: (primary ? white : s2).withValues(alpha: .35),
        disabledForegroundColor: tx3,
        minimumSize: Size(44, height),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height / 2),
        ),
        textStyle: text(15),
      ).copyWith(
        backgroundBuilder: (context, states, child) =>
            child ?? const SizedBox.shrink(),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      );
}

Future<T?> extractSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .32),
      constraints: const BoxConstraints(maxWidth: 560),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 250),
              reverseDuration: Duration(milliseconds: 200),
            ),
      builder: (context) => SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            final availableHeight = (constraints.maxHeight * .9 - keyboard - 16)
                .clamp(0.0, constraints.maxHeight);
            return Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, keyboard + 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: availableHeight),
                child: Material(
                  color: ExtractStyle.sheet,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: const BorderSide(color: ExtractStyle.line2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      brightness: Brightness.dark,
                      colorScheme: const ColorScheme.dark(
                        surface: ExtractStyle.sheet,
                        primary: ExtractStyle.white,
                      ),
                      textTheme: Theme.of(context).textTheme.apply(
                        bodyColor: ExtractStyle.tx,
                        displayColor: ExtractStyle.tx,
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          Builder(builder: builder),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

Future<bool?> showExtractPhotoSheet(BuildContext context) => extractSheet<bool>(
  context,
  (ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Add from a photo', style: ExtractStyle.text(22)),
      const SizedBox(height: 8),
      Text(
        'Take or choose a photo of a shelf, drawer or bin. Review the items before saving.',
        style: ExtractStyle.text(14.5, color: ExtractStyle.tx2),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final camera = FilledButton.icon(
            style: ExtractStyle.pill(height: 52),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(CupertinoIcons.camera, size: 20),
            label: const Text('Camera'),
          );
          final library = FilledButton.icon(
            style: ExtractStyle.pill(height: 52),
            onPressed: () => Navigator.pop(ctx, false),
            icon: const Icon(CupertinoIcons.photo, size: 20),
            label: const Text('Library'),
          );
          final largeText = MediaQuery.textScalerOf(context).scale(15) > 20;
          if (constraints.maxWidth < 300 || largeText) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [camera, const SizedBox(height: 10), library],
            );
          }
          return Row(
            children: [
              Expanded(child: camera),
              const SizedBox(width: 12),
              Expanded(child: library),
            ],
          );
        },
      ),
    ],
  ),
);

class ExtractReply extends StatelessWidget {
  const ExtractReply({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final reply = DefaultTextStyle(
      style: ExtractStyle.text(15.5).copyWith(height: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: ExtractStyle.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.square_grid_2x2_fill,
              size: 15,
              color: ExtractStyle.ink,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
    if (Theme.of(context).brightness == Brightness.dark) return reply;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ExtractStyle.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: reply,
    );
  }
}

void extractToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 104,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: ExtractStyle.curve,
            builder: (_, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(
                  0,
                  MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : -20 * (1 - value),
                ),
                child: child,
              ),
            ),
            child: Material(
              color: ExtractStyle.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  message,
                  style: ExtractStyle.text(14, color: ExtractStyle.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2000), () {
    entry.remove();
    entry.dispose();
  });
}
