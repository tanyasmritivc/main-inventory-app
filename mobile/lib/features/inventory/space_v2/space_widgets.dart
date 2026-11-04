import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/api_client.dart';
import '../../../core/private_image.dart';
import 'space_style.dart';
import '../../founding_access/riso_art.dart';

String spaceItemSubtitle(InventoryItem item) => [
  if (item.displayDescription != null) item.displayDescription!,
  item.category,
].join(' · ');

bool spaceItemIsLow(InventoryItem item, int? threshold, {int? quantity}) {
  final limit = item.reorderEnabled ? item.reorderThreshold : threshold;
  final count = quantity ?? item.quantity;
  return count <= 0 || (limit != null && limit >= 0 && count <= limit);
}

class SpaceThumbnail extends StatelessWidget {
  const SpaceThumbnail({
    super.key,
    required this.item,
    this.size = 52,
    this.height,
    this.radius = 13,
  });
  final InventoryItem item;
  final double size, radius;
  final double? height;
  @override
  Widget build(BuildContext context) {
    final fallback = RisoTile(
      palette: RisoPalette.forCategory(item.category, item.location),
      radius: radius,
      child: Center(
        child: Icon(
          spaceItemIcon(item),
          size: height == null ? 22 : 44,
          color: Colors.white.withValues(alpha: .90),
          shadows: const [
            Shadow(
              color: Color(0x40000000),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
    return Container(
      width: size,
      height: height ?? size,
      decoration: SpaceStyle.of(context).card(radius),
      clipBehavior: Clip.antiAlias,
      child: (item.imageUrl ?? '').trim().isEmpty
          ? fallback
          : PrivateImage(
              item.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

IconData spaceItemIcon(InventoryItem item) {
  final text = '${item.name} ${item.category}'.toLowerCase();
  if (['belt', 'chain'].any(text.contains)) return Icons.link;
  if (['screw', 'bolt', 'nut', 'washer', 'standoff'].any(text.contains)) {
    return Icons.hexagon_outlined;
  }
  if (['wire', 'cable'].any(text.contains)) return Icons.cable;
  if (text.contains('battery')) return Icons.battery_std_outlined;
  if (['motor', 'servo', 'gear'].any(text.contains)) {
    return Icons.settings_outlined;
  }
  if (text.contains('tool')) return Icons.build_outlined;
  return Icons.inventory_2_outlined;
}

class SpaceItemRow extends StatelessWidget {
  const SpaceItemRow({
    super.key,
    required this.item,
    required this.onTap,
    this.low = false,
    this.divider = true,
    this.compact = false,
    this.quantity,
    this.subtitleSuffix = '',
  });
  final InventoryItem item;
  final VoidCallback onTap;
  final bool low, divider, compact;
  final int? quantity;
  final String subtitleSuffix;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                SpaceThumbnail(item: item, size: compact ? 38 : 52),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: SpaceStyle.of(context)
                            .text(15.5)
                            .copyWith(
                              height: 1.25,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -.155,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${spaceItemSubtitle(item)}$subtitleSuffix',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SpaceStyle.of(
                          context,
                        ).text(13, SpaceStyle.of(context).tx2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${quantity ?? item.quantity}',
                      style: SpaceStyle.of(context)
                          .text(
                            17,
                            low
                                ? SpaceStyle.of(context).amber
                                : SpaceStyle.of(context).tx,
                          )
                          .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                    Text(
                      low ? 'low' : 'qty',
                      style: SpaceStyle.of(context).text(
                        11,
                        low
                            ? SpaceStyle.of(context).amber
                            : SpaceStyle.of(context).tx3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      if (divider)
        Padding(
          padding: const EdgeInsets.only(left: 77),
          child: Divider(height: 1, color: SpaceStyle.of(context).line),
        ),
    ],
  );
}

class SpaceStatusCard extends StatelessWidget {
  const SpaceStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.active = false,
    this.onLongPress,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool active;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$title, $subtitle',
    selected: active,
    button: true,
    child: Material(
      color: active ? const Color(0xFFF4F4F5) : const Color(0xFFD4D4D8),
      shape: StadiumBorder(
        side: active
            ? BorderSide(color: SpaceStyle.of(context).tx2, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: SpaceStyle.of(context).text(14.5, const Color(0xFF19191B)),
          ),
        ),
      ),
    ),
  );
}

/// Uniform blur behind the entire control area, including the status bar.
class SpaceHeaderGlass extends StatelessWidget {
  const SpaceHeaderGlass({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: ColoredBox(
        color: SpaceStyle.of(context).bg.withValues(alpha: .68),
        child: child,
      ),
    ),
  );
}

class SpacePinnedHeader extends SliverPersistentHeaderDelegate {
  SpacePinnedHeader({required this.child});
  final Widget child;
  @override
  double get minExtent => 68;
  @override
  double get maxExtent => 68;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SpaceHeaderGlass(child: child);
  @override
  bool shouldRebuild(SpacePinnedHeader oldDelegate) => true;
}

class SpaceAction extends StatelessWidget {
  const SpaceAction({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => ListTile(
    minVerticalPadding: 12,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    leading: Container(
      width: 44,
      height: 44,
      decoration: SpaceStyle.of(context).card(14, SpaceStyle.of(context).s2),
      child: Icon(icon),
    ),
    title: Text(title, style: SpaceStyle.of(context).text(16)),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: SpaceStyle.of(context).text(13, SpaceStyle.of(context).tx2),
          ),
    trailing: selected
        ? Icon(Icons.check_circle, color: SpaceStyle.of(context).white)
        : Icon(
            Icons.chevron_right,
            size: 18,
            color: SpaceStyle.of(context).tx3,
          ),
    onTap: onTap,
  );
}

class SpaceSheetList extends StatelessWidget {
  const SpaceSheetList({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SpaceHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Text(title, style: SpaceStyle.of(context).text(20)),
          ),
          ...children,
        ],
      ),
    ),
  );
}
