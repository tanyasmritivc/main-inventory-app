import '../../../core/app_theme.dart';
import '../../../core/ui/native_presentation.dart';
import 'package:mobile/core/ui/app_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class ExtractStyle {
  static ExtractPalette of(BuildContext context) => ExtractPalette(context);
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

class ExtractPalette {
  const ExtractPalette(this.context);
  final BuildContext context;
  bool get dark => Theme.of(context).brightness == Brightness.dark;
  Color get bg => AppTheme.bg(context);
  Color get sheet => AppTheme.surface(context);
  Color get s1 => AppTheme.surface(context);
  Color get s2 => dark ? const Color(0xFF242424) : const Color(0xFFE7E7E9);
  Color get s3 => AppTheme.surface2(context);
  Color get tx => AppTheme.textPrimary(context);
  Color get tx2 => AppTheme.textSecondary(context);
  Color get tx3 => AppTheme.textMuted(context);
  Color get line => AppTheme.border(context);
  Color get line2 => AppTheme.border(context);
  Color get white => tx;
  Color get ink => dark ? const Color(0xFF0B0B0C) : Colors.white;
  Color get red => AppTheme.danger;
  TextStyle text(double size, {Color? color}) =>
      ExtractStyle.text(size, color: color ?? tx);
  ButtonStyle pill({bool primary = false, double height = 46}) =>
      ExtractStyle.pill(primary: primary, height: height).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => (primary ? white : s2).withValues(
            alpha: states.contains(WidgetState.disabled) ? .35 : 1,
          ),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? tx3
              : (primary ? ink : tx),
        ),
        textStyle: WidgetStatePropertyAll(text(AppTypography.bodySize)),
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
                  color: ExtractStyle.of(context).sheet,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(color: ExtractStyle.of(context).line2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context),
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
                                color: ExtractStyle.of(
                                  context,
                                ).tx.withValues(alpha: .2),
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

/// Return only after the native action sheet has dismissed so image_picker can
/// present Camera or Photo Library from the originating chat without a race.
Future<bool?> showExtractPhotoSheet(BuildContext context) async {
  if (usesNativePresentation) {
    final result = await NativePresentation.show(
      context,
      model: {'kind': 'photoSource'},
    );
    if (context.mounted && result?['error'] is String) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(result!['error'] as String)));
    }
    return switch (result?['action']) {
      'camera' => true,
      'library' => false,
      _ => null,
    };
  }
  return showCupertinoModalPopup<bool>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext, true),
          child: const AppText('Camera'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext, false),
          child: const AppText('Photo Library'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: const AppText('Cancel'),
      ),
    ),
  );
}

class ExtractReply extends StatelessWidget {
  const ExtractReply({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final reply = DefaultTextStyle(
      style: ExtractStyle.of(context).text(15.5).copyWith(height: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: ExtractStyle.of(context).white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              CupertinoIcons.square_grid_2x2_fill,
              size: 15,
              color: ExtractStyle.of(context).ink,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
    return reply;
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
                child: AppText(
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
