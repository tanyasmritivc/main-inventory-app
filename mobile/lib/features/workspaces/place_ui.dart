import 'package:flutter/material.dart';

abstract final class PlaceTokens {
  static const background = Color(0xFFF5F5F5),
      card = Color(0xFFFFFFFF),
      border = Color(0xFFEAEAEA),
      separator = Color(0xFFEFEFEF);
  static const primary = Color(0xFF111112),
      secondary = Color(0xFF878787),
      dim = Color(0xFF696969),
      label = Color(0xFF979797);
  static const orange = Color(0xFF727272),
      darkOrange = Color(0xFF595959),
      destructive = Color(0xFF414141);
  static const icon = Color(0xFF3D3D3D),
      chevron = Color(0xFFC1C1C1),
      outline = Color(0xFFE0E0E0);
  static const blue = Color(0xFFEBEBEB),
      blueText = Color(0xFF4F4F4F),
      green = Color(0xFFECECEC),
      greenText = Color(0xFF585858);
  static const purple = Color(0xFFEAEAEA),
      purpleText = Color(0xFF484848),
      owner = Color(0xFFEAEAEA),
      ownerText = Color(0xFF4C4C4C);
  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = primary,
    double? spacing,
  }) => TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.25,
    letterSpacing: spacing,
  );
  static TextStyle get title =>
      text(24, weight: FontWeight.w400, spacing: -.6).copyWith(height: 1.2);
  static TextStyle get rowTitle =>
      text(16, weight: FontWeight.w400, spacing: -.24).copyWith(height: 1.2);
  static TextStyle get subtitle =>
      text(13, color: secondary).copyWith(height: 1.2);
  static TextStyle get section => const TextStyle(
    fontFamily: 'CupertinoSystemText',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: .66,
    height: 1.4,
    color: label,
  );
  static Color muted(BuildContext context, Color normal) =>
      MediaQuery.highContrastOf(context) ? dim : normal;
}

/// Theme-bound roles; never mutate global tokens when the account/theme changes.
class PlacePalette {
  PlacePalette.of(BuildContext context)
    : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color resolve(Color light) {
    if (!dark) {
      return [PlaceTokens.secondary, PlaceTokens.label].contains(light)
          ? PlaceTokens.dim
          : light;
    }
    return <Color, Color>{
          PlaceTokens.background: const Color(0xFF111112),
          PlaceTokens.card: const Color(0xFF1C1C1E),
          PlaceTokens.border: const Color(0xFF343436),
          PlaceTokens.separator: const Color(0xFF2C2C2E),
          PlaceTokens.primary: const Color(0xFFF4F4F2),
          PlaceTokens.secondary: const Color(0xFFB7B7B7),
          PlaceTokens.dim: const Color(0xFFBFBFBF),
          PlaceTokens.label: const Color(0xFFB7B7B7),
          PlaceTokens.icon: const Color(0xFFBFBFBF),
          PlaceTokens.chevron: const Color(0xFFA9A9A9),
          PlaceTokens.outline: const Color(0xFF696969),
          PlaceTokens.destructive: const Color(0xFFB0B0B0),
        }[light] ??
        light;
  }

  Color get background => resolve(PlaceTokens.background);
  Color get card => resolve(PlaceTokens.card);
  Color get border => resolve(PlaceTokens.border);
  Color get separator => resolve(PlaceTokens.separator);
  Color get primary => resolve(PlaceTokens.primary);
  Color get secondary => resolve(PlaceTokens.secondary);
  Color get dim => resolve(PlaceTokens.dim);
  Color get label => resolve(PlaceTokens.label);
  Color get icon => resolve(PlaceTokens.icon);
  Color get chevron => resolve(PlaceTokens.chevron);
  Color get outline => resolve(PlaceTokens.outline);
  Color get destructive => resolve(PlaceTokens.destructive);
  Color get orange => PlaceTokens.orange;
  Color get darkOrange => PlaceTokens.darkOrange;
  TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? spacing,
  }) => PlaceTokens.text(
    size,
    weight: weight,
    color: color ?? primary,
    spacing: spacing,
  );
  TextStyle get title => PlaceTokens.title.copyWith(color: primary);
  TextStyle get rowTitle => PlaceTokens.rowTitle.copyWith(color: primary);
  TextStyle get subtitle => PlaceTokens.subtitle.copyWith(color: secondary);
  TextStyle get section => PlaceTokens.section.copyWith(color: label);
  Color muted(BuildContext context, Color normal) =>
      MediaQuery.highContrastOf(context) ? dim : normal;
}

class PlaceTheme extends StatelessWidget {
  const PlaceTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = PlacePalette.of(context);
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: p.background,
        textTheme: base.textTheme.apply(
          fontFamily: 'CupertinoSystemText',
          bodyColor: p.primary,
          displayColor: p.primary,
        ),
        colorScheme: base.colorScheme.copyWith(
          surface: p.background,
          onSurface: p.primary,
          onSurfaceVariant: p.secondary,
          outline: p.outline,
          outlineVariant: p.border,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: p.darkOrange,
            foregroundColor: Colors.white,
            textStyle: p.text(14, weight: FontWeight.w400),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: p.primary,
            backgroundColor: p.card,
            side: BorderSide(color: p.outline),
            textStyle: p.text(14, weight: FontWeight.w400),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: p.background,
          foregroundColor: p.primary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: child,
    );
  }
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
              ? PlacePalette.of(context).chevron
              : PlacePalette.of(context).icon),
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
          weight: FontWeight.w400,
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
        style: PlaceTokens.text(12, weight: FontWeight.w400, color: fg),
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
        ? (const Color(0xFFE5E5E5), const Color(0xFF545454))
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
          style: PlaceTokens.text(13, weight: FontWeight.w400, color: fg),
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
      color: PlacePalette.of(context).card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: selected ? PlaceTokens.orange : PlacePalette.of(context).border,
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
                Divider(
                  height: 0,
                  thickness: 1,
                  color: PlacePalette.of(context).separator,
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
                  Text(title, style: PlacePalette.of(context).rowTitle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: PlacePalette.of(context).subtitle.copyWith(
                        color: PlacePalette.of(
                          context,
                        ).muted(context, PlacePalette.of(context).secondary),
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
