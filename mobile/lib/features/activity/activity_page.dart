import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/skeleton.dart';

class _CommandItem {
  const _CommandItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.location,
    required this.createdAt,
    required this.tags,
  });

  final String name;
  final String category;
  final int quantity;
  final String location;
  final DateTime createdAt;
  final List<String> tags;

  factory _CommandItem.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = (rawTags is List)
        ? rawTags.map((e) => (e ?? '').toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    final qty = (json['quantity'] is num)
        ? (json['quantity'] as num).toInt()
        : int.tryParse((json['quantity'] ?? '0').toString()) ?? 0;

    final created = DateTime.tryParse((json['created_at'] ?? '').toString());

    return _CommandItem(
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      quantity: qty,
      location: (json['location'] ?? '').toString(),
      createdAt: created ?? DateTime.now(),
      tags: tags,
    );
  }
}

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool _loading = true;
  String? _error;
  List<_CommandItem> _items = const [];
  bool _fadeIn = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _fadeIn = false;
    });

    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) {
        if (!mounted) return;
        setState(() {
          _items = const [];
          _loading = false;
          _fadeIn = false;
        });
        return;
      }

      final resp = await supabase
          .from('items')
          .select('name,category,quantity,location,created_at,tags')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final rows = (resp as List<dynamic>)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final items = rows.map(_CommandItem.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _fadeIn = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _fadeIn = true);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load activity';
        _loading = false;
      });
    }
  }
  int _totalItems() => _items.length;

  int _totalCategories() {
    final set = <String>{};
    for (final it in _items) {
      final c = it.category.trim().isEmpty ? 'Unsorted' : it.category.trim();
      set.add(c);
    }
    return set.length;
  }

  String _mostUsedLocation() {
    if (_items.isEmpty) return '—';
    final counts = <String, int>{};
    for (final it in _items) {
      final loc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      counts[loc] = (counts[loc] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });
    return entries.isEmpty ? '—' : entries.first.key;
  }

  List<_CommandItem> _lowStock() {
    final items = _items.where((e) => e.quantity <= 2).toList();
    items.sort((a, b) {
      final byQty = a.quantity.compareTo(b.quantity);
      if (byQty != 0) return byQty;
      return b.createdAt.compareTo(a.createdAt);
    });
    return items.take(5).toList();
  }

  List<({String name, int count})> _duplicates() {
    final counts = <String, ({String name, int count})>{};
    for (final it in _items) {
      final n = it.name.trim();
      if (n.isEmpty) continue;
      final key = n.toLowerCase();
      final prev = counts[key];
      if (prev == null) {
        counts[key] = (name: n, count: 1);
      } else {
        counts[key] = (name: prev.name, count: prev.count + 1);
      }
    }
    final out = counts.values.where((e) => e.count > 1).toList();
    out.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.name.compareTo(b.name);
    });
    return out.take(5).toList();
  }

  List<_CommandItem> _unused() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final items = _items.where((e) => e.createdAt.isBefore(cutoff)).toList();
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items.take(5).toList();
  }

  List<_CommandItem> _recent() {
    final items = List<_CommandItem>.from(_items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(5).toList();
  }

  int _daysAgo(DateTime t) {
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.isNegative) return 0;
    return d.inDays;
  }

  Widget _summaryHeader() {
    final muted = Colors.white.withValues(alpha: 0.65);
    final tLabel = Theme.of(context).textTheme.bodySmall?.copyWith(color: muted);
    final tValue = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    Widget stat({required String label, required Widget value}) {
      return Flexible(
        fit: FlexFit.loose,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: tLabel),
            const SizedBox(height: 6),
            value,
          ],
        ),
      );
    }

    Widget valueText(String v) => Text(v, style: tValue, maxLines: 1, overflow: TextOverflow.ellipsis);

    Widget skeletonValue() => const SkeletonBox(height: 22, width: 90, borderRadius: 10);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Command Center',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(
                label: 'Total items',
                value: _loading ? skeletonValue() : valueText('${_totalItems()}'),
              ),
              const SizedBox(width: 12),
              stat(
                label: 'Categories',
                value: _loading ? skeletonValue() : valueText('${_totalCategories()}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          stat(
            label: 'Most used location',
            value: _loading
                ? const SkeletonBox(height: 18, width: 160, borderRadius: 10)
                : Text(
                    _mostUsedLocation(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  TextStyle? _sectionTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white.withValues(alpha: 0.70),
          fontWeight: FontWeight.w600,
        );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: _sectionTitleStyle(context));
  }

  Widget _emptySectionText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Activity'),
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        color: Colors.black,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryHeader(),
            const SizedBox(height: 12),
            if (_loading)
              const GlassCard(
                padding: EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SkeletonListTile(),
                    Divider(height: 1),
                    SkeletonListTile(),
                    Divider(height: 1),
                    SkeletonListTile(),
                    Divider(height: 1),
                    SkeletonListTile(),
                    Divider(height: 1),
                    SkeletonListTile(),
                  ],
                ),
              )
            else if (_error != null)
              GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _error ?? 'Could not load activity',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.92),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else
              AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                opacity: _fadeIn ? 1 : 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('Low stock'),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final low = _lowStock();
                        if (low.isEmpty) {
                          return GlassCard(child: _emptySectionText('All items sufficiently stocked'));
                        }
                        return GlassCard(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < low.length; i++) ...[
                                if (i != 0) const Divider(height: 1),
                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.warning_amber_outlined,
                                    color: Colors.white.withValues(alpha: 0.80),
                                  ),
                                  title: Text(low[i].name.trim().isEmpty ? '—' : low[i].name.trim()),
                                  subtitle: Text(
                                    low[i].location.trim().isEmpty ? 'Unsorted' : low[i].location.trim(),
                                  ),
                                  trailing: Text('${low[i].quantity}'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('Duplicates detected'),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final dups = _duplicates();
                        if (dups.isEmpty) {
                          return GlassCard(child: _emptySectionText('No duplicates found'));
                        }
                        return GlassCard(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < dups.length; i++) ...[
                                if (i != 0) const Divider(height: 1),
                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.copy_all_outlined,
                                    color: Colors.white.withValues(alpha: 0.80),
                                  ),
                                  title: Text(dups[i].name),
                                  trailing: Text('${dups[i].count}'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('Unused items'),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final unused = _unused();
                        if (unused.isEmpty) {
                          return GlassCard(child: _emptySectionText('No unused items right now'));
                        }
                        return GlassCard(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < unused.length; i++) ...[
                                if (i != 0) const Divider(height: 1),
                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.schedule_outlined,
                                    color: Colors.white.withValues(alpha: 0.80),
                                  ),
                                  title: Text(unused[i].name.trim().isEmpty ? '—' : unused[i].name.trim()),
                                  subtitle: Text(
                                    '${unused[i].location.trim().isEmpty ? 'Unsorted' : unused[i].location.trim()} · Last added ${_daysAgo(unused[i].createdAt)} days ago',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('Recent activity'),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final recent = _recent();
                        if (recent.isEmpty) {
                          return GlassCard(child: _emptySectionText('No recent activity'));
                        }
                        return GlassCard(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < recent.length; i++) ...[
                                if (i != 0) const Divider(height: 1),
                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.bolt_outlined,
                                    color: Colors.white.withValues(alpha: 0.80),
                                  ),
                                  title: Text(recent[i].name.trim().isEmpty ? '—' : recent[i].name.trim()),
                                  subtitle: const Text('added recently'),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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
