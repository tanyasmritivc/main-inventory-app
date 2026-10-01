import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.onOpenCapture,
    required this.onOpenAsk,
    required this.onOpenFind,
    required this.onOpenReview,
    required this.onOpenDocuments,
    this.refreshToken = 0,
  });

  final ApiClient api;
  final VoidCallback onOpenCapture;
  final void Function(String? question) onOpenAsk;
  final VoidCallback onOpenFind;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenDocuments;
  final int refreshToken;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TextEditingController _question;
  bool _loading = true;
  String? _error;
  List<InventoryItem> _items = const [];
  List<ActivityEntry> _activity = const [];
  int _pendingReviews = 0;

  @override
  void initState() {
    super.initState();
    _question = TextEditingController();
    _items = InventoryCache.items;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) unawaited(_load());
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.api.searchItems(query: ''),
        widget.api
            .getReviewItems(limit: 4)
            .catchError(
              (_) => ReviewQueueResult(
                items: const [],
                pendingCount: _pendingReviews,
              ),
            ),
        widget.api.getRecentActivity(limit: 6).catchError((_) => _activity),
      ]);
      final inventory = results[0] as SearchItemsResult;
      final reviews = results[1] as ReviewQueueResult;
      final activity = results[2] as List<ActivityEntry>;
      InventoryCache.setItems(inventory.items);
      if (!mounted) return;
      setState(() {
        _items = inventory.items;
        _pendingReviews = reviews.pendingCount;
        _activity = activity;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Your memory could not refresh. Pull down to try again.';
        _items = InventoryCache.items;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _ask() {
    final value = _question.text.trim();
    _question.clear();
    widget.onOpenAsk(value.isEmpty ? null : value);
  }

  String _greeting() {
    final user = Supabase.instance.client.auth.currentUser;
    final metadataName = (user?.userMetadata?['first_name'] ?? '')
        .toString()
        .trim();
    final fallback = (user?.email ?? '').split('@').first.trim();
    final name = metadataName.isNotEmpty ? metadataName : fallback;
    if (name.isEmpty) return 'Your physical memory';
    return 'Good ${_dayPart()}, ${name[0].toUpperCase()}${name.substring(1)}';
  }

  String _dayPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Map<String, int> _spaces() {
    final counts = <String, int>{};
    for (final item in _items) {
      final location = item.location.trim().isEmpty
          ? 'Unsorted'
          : item.location.trim();
      counts[location] = (counts[location] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final recent = _items.take(6).toList();
    final spaces = _spaces().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ColoredBox(
      color: Colors.black,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Text(
              _greeting(),
              style: const TextStyle(
                fontSize: 25,
                height: 1.15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Remember what you own, where it is, and what it means.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 5, 5, 5),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _question,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask(),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Where did I put…?',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    tooltip: 'Ask',
                    onPressed: _ask,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MemoryAction(
                    icon: Icons.camera_alt_outlined,
                    label: 'Remember',
                    subtitle: 'Capture things',
                    onTap: widget.onOpenCapture,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MemoryAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Ask',
                    subtitle: 'Recall anything',
                    onTap: () => widget.onOpenAsk(null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MemoryAction(
                    icon: Icons.search_rounded,
                    label: 'Find',
                    subtitle: 'Browse places',
                    onTap: widget.onOpenFind,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onOpenDocuments,
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Documents and notes'),
              ),
            ),
            if (_pendingReviews > 0) ...[
              const SizedBox(height: 18),
              Material(
                color: const Color(0xFF241B0D),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onOpenReview,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0x24F5A623),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.rule_folder_outlined,
                            color: Color(0xFFF5A623),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_pendingReviews ${_pendingReviews == 1 ? 'item needs' : 'items need'} your review',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Assign uncertain captures when you have a moment.',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Recently remembered',
              action: 'See all',
              onTap: widget.onOpenFind,
            ),
            const SizedBox(height: 9),
            if (recent.isEmpty)
              _EmptyMemory(loading: _loading, onCapture: widget.onOpenCapture)
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var index = 0; index < recent.length; index++) ...[
                      _RecentItemRow(
                        item: recent[index],
                        onTap: widget.onOpenFind,
                      ),
                      if (index < recent.length - 1)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Your places',
              action: 'Find',
              onTap: widget.onOpenFind,
            ),
            const SizedBox(height: 9),
            if (spaces.isEmpty)
              const Text(
                'Your places will appear as you remember items.',
                style: TextStyle(color: Colors.white54),
              )
            else
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: spaces
                    .take(8)
                    .map(
                      (entry) => _SpaceChip(
                        name: entry.key,
                        count: entry.value,
                        onTap: widget.onOpenFind,
                      ),
                    )
                    .toList(),
              ),
            if (_activity.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionHeader(title: 'Memory activity'),
              const SizedBox(height: 9),
              ..._activity
                  .take(3)
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Icon(
                              Icons.circle,
                              size: 6,
                              color: Colors.white38,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.summary,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemoryAction extends StatelessWidget {
  const _MemoryAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(height: 18),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    );
  }
}

class _RecentItemRow extends StatelessWidget {
  const _RecentItemRow({required this.item, required this.onTap});
  final InventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = (item.imageUrl ?? '').trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            if (image.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  image,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.location} · ${item.category}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '${item.quantity}',
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceChip extends StatelessWidget {
  const _SpaceChip({
    required this.name,
    required this.count,
    required this.onTap,
  });
  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: const Icon(Icons.place_outlined, size: 17),
      label: Text('$name  $count'),
      backgroundColor: const Color(0xFF171717),
      side: const BorderSide(color: Colors.white12),
    );
  }
}

class _EmptyMemory extends StatelessWidget {
  const _EmptyMemory({required this.loading, required this.onCapture});
  final bool loading;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (loading)
            const CircularProgressIndicator()
          else ...[
            const Text(
              'Your memory starts with one thing.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Capture it'),
            ),
          ],
        ],
      ),
    );
  }
}
