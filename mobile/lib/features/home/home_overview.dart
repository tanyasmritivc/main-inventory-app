import '../../core/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'package:mobile/core/ui/app_text.dart';

class HomeColors {
  static const background = Color(0xFF09090B);
  static const surface = Color(0xFF171719);
  static const text = Color(0xFFF1F1F3);
  static const secondary = Color(0xFFA1A1AA);
  static const hint = Color(0xFF85858E);
  static const orange = Color(0xFFFF7A2F);
  static const amber = Color(0xFFE4AF46);
}

class HomeOverview extends StatefulWidget {
  const HomeOverview({
    super.key,
    required this.items,
    required this.spaces,
    required this.pendingReviews,
    required this.lowStock,
    required this.outOfStock,
    required this.lentOut,
    required this.onAsk,
    required this.onChooseSpace,
    required this.onOpenReview,
    required this.onOpenLowStock,
    required this.onOpenOutOfStock,
    required this.onOpenCheckouts,
    required this.onOpenItem,
    required this.onOpenSpace,
    this.error,
  });
  final List<InventoryItem> items;
  final List<Map<String, dynamic>> spaces;
  final int? pendingReviews, lowStock, outOfStock, lentOut;
  final String? error;
  final ValueChanged<String> onAsk;
  final VoidCallback onChooseSpace,
      onOpenReview,
      onOpenLowStock,
      onOpenOutOfStock,
      onOpenCheckouts;
  final ValueChanged<InventoryItem> onOpenItem;
  final ValueChanged<Map<String, dynamic>> onOpenSpace;
  @override
  State<HomeOverview> createState() => _HomeOverviewState();
}

class _HomeOverviewState extends State<HomeOverview> {
  final _question = TextEditingController();
  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _ask() {
    final question = _question.text.trim();
    if (question.isEmpty) return;
    _question.clear();
    FocusScope.of(context).unfocus();
    widget.onAsk(question);
  }

  @override
  Widget build(BuildContext context) {
    final recent = widget.items.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final suggestions = recent
        .map((item) => item.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .take(2)
        .toList();
    final photos = recent
        .where((item) => (item.imageUrl ?? '').trim().isNotEmpty)
        .toList();
    final now = DateTime.now();
    final today = photos.where((item) {
      final date = item.createdAt.toLocal();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
    final captures = (today.isEmpty ? photos : today).take(12).toList();
    return ColoredBox(
      color: AppTheme.adaptive(context, HomeColors.background),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'My home, choose a Space',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onChooseSpace,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: AppText(
                          'My home',
                          boldWeight: FontWeight.w600,
                          style: TextStyle(
                            fontSize: 28,
                            height: 1.15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.8,
                            color: AppTheme.foreground(
                              context,
                              HomeColors.text,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 7),
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 15,
                        color: AppTheme.foreground(context, HomeColors.hint),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          MediaQuery(
            data: MediaQuery.of(context).copyWith(boldText: false),
            child: TextField(
              controller: _question,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _ask(),
              style: AppTypography.bodyStyleOf(
                context,
                TextStyle(
                  fontSize: 17,
                  fontWeight: MediaQuery.boldTextOf(context)
                      ? FontWeight.w500
                      : FontWeight.w400,
                  color: AppTheme.foreground(context, HomeColors.text),
                ),
              ),
              decoration: InputDecoration(
                hintText: 'Where is the soldering iron?',
                hintStyle: AppTypography.bodyStyleOf(
                  context,
                  TextStyle(
                    fontSize: 17,
                    fontWeight: MediaQuery.boldTextOf(context)
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: AppTheme.foreground(context, HomeColors.hint),
                  ),
                ),
                filled: true,
                fillColor: AppTheme.adaptive(context, HomeColors.surface),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions
                  .map(
                    (name) => _Suggestion(
                      name: name,
                      onTap: () => widget.onAsk('Where is my $name?'),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionLabel('Needs a decision'),
          const SizedBox(height: 12),
          Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DecisionTile(
                        count: widget.pendingReviews,
                        label: 'need identifying',
                        color: AppTheme.adaptive(context, HomeColors.orange),
                        onTap: widget.onOpenReview,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DecisionTile(
                        count: widget.lowStock,
                        label: 'to buy',
                        color: AppTheme.adaptive(context, HomeColors.amber),
                        onTap: widget.onOpenLowStock,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DecisionTile(
                        count: widget.outOfStock,
                        label: 'out of stock',
                        onTap: widget.onOpenOutOfStock,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DecisionTile(
                        count: widget.lentOut,
                        label: 'lent out',
                        onTap: widget.onOpenCheckouts,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 12),
            AppText(
              widget.error!,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.foreground(context, HomeColors.secondary),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionLabel(
            today.isNotEmpty || photos.isEmpty
                ? 'Captured today'
                : 'Recent captures',
          ),
          const SizedBox(height: 12),
          if (captures.isEmpty)
            AppText(
              'No photo captures yet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.foreground(context, HomeColors.hint),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 20) / 3;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < captures.length; index++) ...[
                        if (index > 0) const SizedBox(width: 10),
                        _CaptureCard(
                          item: captures[index],
                          width: width,
                          onTap: () => widget.onOpenItem(captures[index]),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          const _SectionLabel('Where things live'),
          const SizedBox(height: 12),
          if (widget.spaces.isEmpty)
            AppText(
              'No Spaces yet',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.foreground(context, HomeColors.hint),
              ),
            )
          else
            Material(
              color: AppTheme.adaptive(context, HomeColors.surface),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final space in widget.spaces)
                    InkWell(
                      onTap: () => widget.onOpenSpace(space),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 17,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppText(
                                (space['name'] ?? '').toString(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.foreground(
                                    context,
                                    HomeColors.text,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            AppText(
                              '${(space['item_count'] as num?)?.toInt() ?? 0}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.foreground(
                                  context,
                                  HomeColors.hint,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 14,
                              color: AppTheme.foreground(
                                context,
                                HomeColors.hint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => AppText(
    label,
    boldWeight: FontWeight.w600,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppTheme.foreground(context, HomeColors.secondary),
    ),
  );
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.name, required this.onTap});
  final String name;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.adaptive(context, HomeColors.surface),
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 44) / 2,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: AppText(
            '$name?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.foreground(context, HomeColors.secondary),
            ),
          ),
        ),
      ),
    ),
  );
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({
    required this.count,
    required this.label,
    required this.onTap,
    this.color = HomeColors.text,
  });
  final int? count;
  final String label;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.adaptive(context, HomeColors.surface),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: count == null ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: AppText(
                count?.toString() ?? '-',
                boldWeight: FontWeight.w600,
                style: TextStyle(
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.foreground(context, color),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AppText(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w400,
                color: AppTheme.foreground(context, HomeColors.secondary),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CaptureCard extends StatelessWidget {
  const _CaptureCard({
    required this.item,
    required this.width,
    required this.onTap,
  });
  final InventoryItem item;
  final double width;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              item.imageUrl!,
              width: width,
              height: width,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w400,
              color: AppTheme.foreground(context, HomeColors.secondary),
            ),
          ),
        ],
      ),
    ),
  );
}
