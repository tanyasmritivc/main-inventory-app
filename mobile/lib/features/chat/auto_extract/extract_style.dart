import 'dart:ui';
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
  static TextStyle text(
    double size, {
    Color color = tx,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: size,
    color: color,
    fontWeight: weight,
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
        textStyle: text(15, weight: FontWeight.w600),
      );
}

Future<T?> extractSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close sheet',
      barrierColor: Colors.black.withValues(alpha: .55),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, _, _) => SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  8,
                  8,
                  MediaQuery.viewInsetsOf(context).bottom + 8,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 560,
                    maxHeight:
                        MediaQuery.sizeOf(context).height * .8 -
                        MediaQuery.viewInsetsOf(context).bottom.clamp(
                          0,
                          MediaQuery.sizeOf(context).height * .45,
                        ),
                  ),
                  child: Material(
                    color: ExtractStyle.sheet,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(38),
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
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 38,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            builder(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: ExtractStyle.curve,
        );
        return FadeTransition(
          opacity: curved,
          child: MediaQuery.disableAnimationsOf(context)
              ? child
              : SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 1.1),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
        );
      },
    );

Future<bool?> showExtractPhotoSheet(BuildContext context) => extractSheet<bool>(
  context,
  (ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Add from a photo',
        style: ExtractStyle.text(22, weight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        'Snap a shelf, drawer or bin. FindEZ lists every item, and nothing saves until you approve.',
        style: ExtractStyle.text(14.5, color: ExtractStyle.tx2),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: ExtractStyle.pill(height: 52),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(CupertinoIcons.camera, size: 18),
              label: const Text('Camera'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: ExtractStyle.pill(height: 52),
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(CupertinoIcons.photo, size: 18),
              label: const Text('Library'),
            ),
          ),
        ],
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
                  style: ExtractStyle.text(
                    14,
                    color: ExtractStyle.ink,
                    weight: FontWeight.w600,
                  ),
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
