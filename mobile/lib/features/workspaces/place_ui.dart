import 'package:flutter/material.dart';

abstract final class PlaceTokens {
  static const background = Color(0xFFF6F5F3),
      card = Color(0xFFFFFFFF),
      border = Color(0xFFECEAE6),
      separator = Color(0xFFF1EFEB);
  static const primary = Color(0xFF111112),
      secondary = Color(0xFF8A8782),
      dim = Color(0xFF6B6965),
      label = Color(0xFF9A978F);
  static const orange = Color(0xFFE8590C),
      darkOrange = Color(0xFFC2410C),
      destructive = Color(0xFFB42318);
  static const icon = Color(0xFF3F3D39),
      chevron = Color(0xFFC4C1BA),
      outline = Color(0xFFE3E0DA);
  static const blue = Color(0xFFE3ECFB),
      blueText = Color(0xFF2453A8),
      green = Color(0xFFDFF1E6),
      greenText = Color(0xFF1D6B43);
  static const purple = Color(0xFFECE8F6),
      purpleText = Color(0xFF4F3F8C),
      owner = Color(0xFFFDE6D8),
      ownerText = Color(0xFFA8380A);
  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = primary,
    double? spacing,
  }) => TextStyle(
    fontFamily: 'PlaceGeist',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.25,
    letterSpacing: spacing,
  );
  static TextStyle get title =>
      text(24, weight: FontWeight.w600, spacing: -.6).copyWith(height: 1.2);
  static TextStyle get rowTitle =>
      text(16, weight: FontWeight.w500, spacing: -.24).copyWith(height: 1.2);
  static TextStyle get subtitle =>
      text(13, color: secondary).copyWith(height: 1.2);
  static TextStyle get section => const TextStyle(
    fontFamily: 'PlaceGeistMono',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: .66,
    height: 1.4,
    color: label,
  );
  static Color muted(BuildContext context, Color normal) =>
      MediaQuery.highContrastOf(context) ? dim : normal;
}

class PlaceTheme extends StatelessWidget {
  const PlaceTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      scaffoldBackgroundColor: PlaceTokens.background,
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: 'PlaceGeist',
        bodyColor: PlaceTokens.primary,
        displayColor: PlaceTokens.primary,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: PlaceTokens.orange,
        brightness: Brightness.light,
        surface: PlaceTokens.background,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PlaceTokens.darkOrange,
          foregroundColor: Colors.white,
          textStyle: PlaceTokens.text(14, weight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PlaceTokens.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: PlaceTokens.outline),
          textStyle: PlaceTokens.text(14, weight: FontWeight.w500),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: PlaceTokens.background,
        foregroundColor: PlaceTokens.primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    ),
    child: child,
  );
}

enum PlaceSymbol { right, down, search, close, check }

class PlaceGlyph extends StatelessWidget {
  const PlaceGlyph(this.symbol, {super.key, this.color});
  final PlaceSymbol symbol;
  final Color? color;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: switch (symbol) {
      PlaceSymbol.right => const Size(8, 14),
      PlaceSymbol.down => const Size(14, 9),
      PlaceSymbol.check => const Size(18, 14),
      _ => const Size(18, 18),
    },
    painter: _PlacePainter(
      symbol,
      color ??
          (symbol == PlaceSymbol.right
              ? PlaceTokens.chevron
              : PlaceTokens.icon),
    ),
  );
}

class _PlacePainter extends CustomPainter {
  _PlacePainter(this.symbol, this.color);
  final PlaceSymbol symbol;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = (symbol == PlaceSymbol.check
          ? 2.4
          : symbol == PlaceSymbol.right
          ? 1.8
          : 2);
    final path = Path();
    switch (symbol) {
      case PlaceSymbol.right:
        path.moveTo(1, 1);
        path.lineTo(7, 7);
        path.lineTo(1, 13);
      case PlaceSymbol.down:
        path.moveTo(1, 1);
        path.lineTo(7, 7);
        path.lineTo(13, 1);
      case PlaceSymbol.check:
        path.moveTo(1, 7);
        path.lineTo(6, 12);
        path.lineTo(17, 1);
      case PlaceSymbol.close:
        path.moveTo(3, 3);
        path.lineTo(15, 15);
        path.moveTo(15, 3);
        path.lineTo(3, 15);
      case PlaceSymbol.search:
        canvas.drawCircle(const Offset(7.5, 7.5), 6, p);
        path.moveTo(12, 12);
        path.lineTo(17, 17);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_PlacePainter old) =>
      old.symbol != symbol || old.color != color;
}

class PlaceBadge extends StatelessWidget {
  const PlaceBadge(this.name, {super.key, this.type = 'workspace'});
  final String name, type;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: type == 'personal'
            ? PlaceTokens.green
            : type == 'organization'
            ? PlaceTokens.orange
            : PlaceTokens.blue,
      ),
      child: Text(
        name.isEmpty ? '' : name.characters.first.toUpperCase(),
        textScaler: TextScaler.noScaling,
        style: PlaceTokens.text(
          14,
          weight: FontWeight.w600,
          color: type == 'personal'
              ? PlaceTokens.greenText
              : type == 'organization'
              ? Colors.white
              : PlaceTokens.blueText,
        ),
      ),
    ),
  );
}

String placeRole(String raw) =>
    raw.isEmpty ? 'Member' : '${raw[0].toUpperCase()}${raw.substring(1)}';

class RoleTag extends StatelessWidget {
  const RoleTag(this.role, {super.key});
  final String role;
  @override
  Widget build(BuildContext context) {
    final name = placeRole(role);
    final (bg, fg) = switch (name.toLowerCase()) {
      'owner' => (PlaceTokens.owner, PlaceTokens.ownerText),
      'editor' => (PlaceTokens.blue, PlaceTokens.blueText),
      _ => (PlaceTokens.purple, PlaceTokens.purpleText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: PlaceTokens.text(12, weight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class PlaceAvatar extends StatelessWidget {
  const PlaceAvatar(
    this.name, {
    super.key,
    this.current = false,
    this.index = 0,
  });
  final String name;
  final bool current;
  final int index;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = current
        ? (const Color(0xFFFBE1D2), const Color(0xFFB33F08))
        : [
            (PlaceTokens.blue, PlaceTokens.blueText),
            (PlaceTokens.purple, PlaceTokens.purpleText),
            (PlaceTokens.green, PlaceTokens.greenText),
          ][index % 3];
    return ExcludeSemantics(
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
        child: Text(
          name.isEmpty ? '' : name.characters.first.toUpperCase(),
          textScaler: TextScaler.noScaling,
          style: PlaceTokens.text(13, weight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }
}

class PlaceCardList extends StatelessWidget {
  const PlaceCardList({
    super.key,
    required this.children,
    this.selected = false,
  });
  final List<Widget> children;
  final bool selected;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: PlaceTokens.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: selected ? PlaceTokens.orange : PlaceTokens.border,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 0,
                  thickness: 1,
                  color: PlaceTokens.separator,
                ),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}

class PlaceRow extends StatelessWidget {
  const PlaceRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.vertical = 14,
    this.minHeight = 52,
    this.showChevron = true,
  });
  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback? onTap;
  final bool selected;
  final double vertical, minHeight;
  final bool showChevron;
  @override
  Widget build(BuildContext context) {
    final stackTrailing = MediaQuery.textScalerOf(context).scale(16) > 24;
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: vertical),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: PlaceTokens.rowTitle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: PlaceTokens.subtitle.copyWith(
                        color: PlaceTokens.muted(
                          context,
                          PlaceTokens.secondary,
                        ),
                      ),
                    ),
                  ],
                  if (stackTrailing && trailing != null) ...[
                    const SizedBox(height: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
            if (trailing != null && !stackTrailing) ...[
              const SizedBox(width: 12),
              trailing!,
            ] else if (onTap != null && (showChevron || selected)) ...[
              const SizedBox(width: 12),
              PlaceGlyph(
                selected ? PlaceSymbol.check : PlaceSymbol.right,
                color: selected ? PlaceTokens.orange : null,
              ),
            ],
          ],
        ),
      ),
    );
    return onTap == null
        ? content
        : Semantics(
            button: true,
            selected: selected,
            label: [title, if (subtitle != null) subtitle!].join('. '),
            onTap: onTap,
            child: ExcludeSemantics(
              child: InkWell(onTap: onTap, child: content),
            ),
          );
  }
}
