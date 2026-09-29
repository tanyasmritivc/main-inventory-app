import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import 'item_detail_sheet.dart';

class WorldHeader extends StatelessWidget {
  const WorldHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          if (onBack != null) ...[
            TextButton(onPressed: onBack, child: const Text('Back')),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.text2, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class WorldSection extends StatelessWidget {
  const WorldSection({
    super.key,
    required this.title,
    required this.children,
    this.flat = false,
  });

  final String title;
  final List<Widget> children;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
          child: Text(
            title,
            style: TextStyle(
              color: t.text2,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (flat)
          Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: t.separator),
                children[i],
              ],
            ],
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            child: Material(
              color: t.card,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: t.separator,
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class WorldRow extends StatelessWidget {
  const WorldRow({
    super.key,
    required this.title,
    required this.count,
    this.countSemantics,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.warning = false,
    this.showCrop = false,
    this.imageUrl,
  });

  final String title;
  final String count;
  final String? countSemantics;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool warning;
  final bool showCrop;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
    return Semantics(
      button: onTap != null,
      label: [
        title,
        if (subtitle != null && subtitle!.isNotEmpty) subtitle!,
        if (count.isNotEmpty) countSemantics ?? 'quantity $count',
      ].join(', '),
      hint: onLongPress == null ? null : 'Long press for actions',
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  if (showCrop) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 42,
                        height: 42,
                        color: t.s2,
                        child: imageUrl == null || imageUrl!.isEmpty
                            ? Icon(
                                Icons.inventory_2_outlined,
                                color: t.text3,
                                size: 20,
                              )
                            : Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      color: t.text3,
                                      size: 20,
                                    ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: largeText ? null : 2,
                          overflow: largeText
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: TextStyle(color: t.ink, fontSize: 15),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: largeText ? null : 2,
                            overflow: largeText
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: TextStyle(
                              color: warning ? t.warn : t.text2,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    count,
                    style: TextStyle(
                      color: t.text2,
                      fontFamily: 'IBMPlexMono',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorldItems extends StatelessWidget {
  const WorldItems({
    super.key,
    required this.items,
    required this.onOpen,
    this.onLongPress,
    this.emptyMessage = 'No objects here yet.',
  });

  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onOpen;
  final ValueChanged<InventoryItem>? onLongPress;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          emptyMessage,
          style: TextStyle(color: t.text2, fontSize: 15),
        ),
      );
    }
    final hasPhotoLessItems = items.any(
      (item) => (item.imageUrl ?? '').trim().isEmpty,
    );
    if (items.length > 40 ||
        hasPhotoLessItems ||
        MediaQuery.textScalerOf(context).scale(1) >= 1.3 ||
        MediaQuery.sizeOf(context).width < 360) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: t.separator),
        itemBuilder: (context, index) {
          final item = items[index];
          return Material(
            color: t.bg,
            child: WorldRow(
              title: item.displayName,
              subtitle: item.displayDescription ?? item.category,
              count: '${item.quantity}',
              showCrop: (item.imageUrl ?? '').trim().isNotEmpty,
              imageUrl: item.imageUrl,
              onTap: () => onOpen(item),
              onLongPress: onLongPress == null
                  ? null
                  : () => onLongPress!(item),
            ),
          );
        },
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: .83,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onOpen(item),
          onLongPress: onLongPress == null ? null : () => onLongPress!(item),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    color: t.s2,
                    child: item.imageUrl == null || item.imageUrl!.isEmpty
                        ? Center(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: t.text3,
                              size: 30,
                            ),
                          )
                        : Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: t.text3,
                                    size: 30,
                                  ),
                                ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                item.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.ink, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.quantity}',
                style: TextStyle(
                  color: t.text2,
                  fontFamily: 'IBMPlexMono',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AllObjectsPage extends StatefulWidget {
  const AllObjectsPage({
    super.key,
    required this.api,
    this.items,
    this.initialQuery = '',
  });

  final ApiClient api;
  final List<InventoryItem>? items;
  final String initialQuery;

  @override
  State<AllObjectsPage> createState() => _AllObjectsPageState();
}

class _AllObjectsPageState extends State<AllObjectsPage> {
  final Set<String> _deletedItemIds = {};
  late final TextEditingController _search = TextEditingController(
    text: widget.initialQuery,
  );
  List<InventoryItem>? _loadedItems;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.items == null) _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _loadError = null);
    try {
      final result = await widget.api.searchItems(query: '');
      if (!mounted) return;
      setState(() => _loadedItems = result.items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Objects could not be loaded.');
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final query = _search.text.trim().toLowerCase();
    final source = (widget.items ?? _loadedItems ?? const <InventoryItem>[])
        .where((item) => !_deletedItemIds.contains(item.itemId))
        .toList();
    final items = query.isEmpty
        ? source
        : source
              .where(
                (item) =>
                    item.name.toLowerCase().contains(query) ||
                    (item.partNumber ?? '').toLowerCase().contains(query) ||
                    item.category.toLowerCase().contains(query),
              )
              .toList();
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorldHeader(
              title: 'All objects',
              onBack: () => Navigator.of(context).pop(),
            ),
            if (widget.items == null &&
                _loadedItems == null &&
                _loadError == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_loadError != null && _loadedItems == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, style: TextStyle(color: t.ink)),
                      TextButton(
                        onPressed: _loadItems,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Search objects'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '${items.length} objects',
                  style: TextStyle(
                    color: t.text2,
                    fontFamily: 'IBMPlexMono',
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: WorldItems(
                  items: items,
                  onOpen: (item) => showItemDetailSheet(
                    context,
                    item: item,
                    api: widget.api,
                    onDeleted: () =>
                        setState(() => _deletedItemIds.add(item.itemId)),
                  ),
                  emptyMessage: query.isEmpty
                      ? 'No objects captured yet.'
                      : 'No objects match this search.',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BinItemsPage extends StatelessWidget {
  const BinItemsPage({
    super.key,
    required this.api,
    required this.name,
    required this.place,
    required this.items,
  });

  final ApiClient api;
  final String name;
  final String place;
  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorldHeader(title: name, onBack: () => Navigator.of(context).pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                '$place / $name  /  ${items.length} objects',
                style: TextStyle(color: t.text2, fontSize: 13),
              ),
            ),
            Expanded(
              child: WorldItems(
                items: items,
                onOpen: (item) =>
                    showItemDetailSheet(context, item: item, api: api),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorldPlacePage extends StatefulWidget {
  const WorldPlacePage({
    super.key,
    required this.api,
    required this.name,
    required this.items,
    required this.onBack,
    required this.onOpenItem,
    this.onLongPressItem,
    this.onAdd,
    this.onActions,
  });

  final ApiClient api;
  final String name;
  final List<InventoryItem> items;
  final VoidCallback onBack;
  final ValueChanged<InventoryItem> onOpenItem;
  final ValueChanged<InventoryItem>? onLongPressItem;
  final VoidCallback? onAdd;
  final VoidCallback? onActions;

  @override
  State<WorldPlacePage> createState() => _WorldPlacePageState();
}

class _WorldPlacePageState extends State<WorldPlacePage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final query = _search.text.trim().toLowerCase();
    final items = query.isEmpty
        ? widget.items
        : widget.items
              .where(
                (item) =>
                    item.name.toLowerCase().contains(query) ||
                    (item.partNumber ?? '').toLowerCase().contains(query) ||
                    (item.binName ?? '').toLowerCase().contains(query),
              )
              .toList();
    final bins = <String, List<InventoryItem>>{};
    final loose = <InventoryItem>[];
    for (final item in items) {
      final bin = item.binName?.trim() ?? '';
      if (bin.isEmpty) {
        loose.add(item);
      } else {
        bins.putIfAbsent(bin, () => []).add(item);
      }
    }
    final binNames = bins.keys.toList()..sort();
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WorldHeader(
              title: widget.name,
              onBack: widget.onBack,
              actions: [
                if (widget.onActions != null)
                  TextButton(
                    onPressed: widget.onActions,
                    child: const Text('Actions'),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                '${items.length} objects',
                style: TextStyle(
                  color: t.text2,
                  fontFamily: 'IBMPlexMono',
                  fontSize: 13,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search this place',
                ),
              ),
            ),
            if (widget.onAdd != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.onAdd,
                    child: const Text('Add an object'),
                  ),
                ),
              ),
            if (binNames.isEmpty)
              Expanded(
                child: WorldItems(
                  items: items,
                  onOpen: widget.onOpenItem,
                  onLongPress: widget.onLongPressItem,
                  emptyMessage: query.isEmpty
                      ? 'Nothing has been captured in this place yet.'
                      : 'No objects match this search.',
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  children: [
                    WorldSection(
                      title: 'Inside this place',
                      children: [
                        for (final bin in binNames)
                          WorldRow(
                            title: bin,
                            subtitle: widget.name,
                            count: '${bins[bin]!.length}',
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => BinItemsPage(
                                  api: widget.api,
                                  name: bin,
                                  place: widget.name,
                                  items: bins[bin]!,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (loose.isNotEmpty)
                      WorldSection(
                        title: 'Not in a bin',
                        children: [
                          for (final item in loose)
                            WorldRow(
                              title: item.displayName,
                              subtitle:
                                  item.displayDescription ?? item.category,
                              count: '${item.quantity}',
                              onTap: () => widget.onOpenItem(item),
                              onLongPress: widget.onLongPressItem == null
                                  ? null
                                  : () => widget.onLongPressItem!(item),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
