import 'package:mobile/core/ui/app_typography.dart';
import 'package:mobile/core/ui/swipe_down_sheet.dart';
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

/// The source picker follows app appearance independently of the extraction
/// review surfaces. Keep its typography local, including OS Bold Text handling.
Future<bool?> showExtractPhotoSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: false,
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
      builder: (_) => const AppTypography(child: _ExtractPhotoPicker()),
    );

class _ExtractPhotoPicker extends StatelessWidget {
  const _ExtractPhotoPicker();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFFFAFAFA) : const Color(0xFF19191B);
    final muted = dark ? const Color(0xFF9A9AA0) : const Color(0xFF616167);
    final button = dark ? const Color(0xFF242424) : const Color(0xFFE7E7E9);
    TextStyle text(double size, [Color? color]) => TextStyle(
      fontFamily: 'CupertinoSystemText',
      fontWeight: FontWeight.w400,
      fontSize: size,
      height: 1.35,
      color: color ?? ink,
    );
    final style = FilledButton.styleFrom(
      backgroundColor: button,
      foregroundColor: ink,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: const StadiumBorder(),
      textStyle: text(AppTypography.bodySize),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ).copyWith(backgroundBuilder: (_, _, child) => child!);
    final camera = FilledButton.icon(
      style: style,
      onPressed: () => Navigator.pop(context, true),
      icon: const Icon(CupertinoIcons.camera, size: 20),
      label: const Text('Camera'),
    );
    final library = FilledButton.icon(
      style: style,
      onPressed: () => Navigator.pop(context, false),
      icon: const Icon(CupertinoIcons.photo, size: 20),
      label: const Text('Library'),
    );
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, keyboard + 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (constraints.maxHeight - keyboard - 16).clamp(
                  0,
                  constraints.maxHeight * .9,
                ),
              ),
              child: SwipeDownSheet(
                child: Material(
                  key: const ValueKey('auto-extract-source-sheet'),
                  color: dark
                      ? const Color(0xFF19191B)
                      : const Color(0xFFF9F9FA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(color: ink.withValues(alpha: .1)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            key: const ValueKey('auto-extract-source-handle'),
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: .24),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        Text('Add from a photo', style: text(18)),
                        const SizedBox(height: 8),
                        Text(
                          'Take a photo or choose one from your library. Review the items before saving.',
                          style: text(AppTypography.bodySize, muted),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, bounds) {
                            if (bounds.maxWidth < 300 ||
                                MediaQuery.textScalerOf(context).scale(16) >
                                    20) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  camera,
                                  const SizedBox(height: 10),
                                  library,
                                ],
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
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
