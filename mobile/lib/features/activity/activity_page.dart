import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/inventory_cache.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/skeleton.dart';
import '../inventory/inventory_page.dart';
import '../scan/scan_page.dart';

enum _ActivityType {
  scan,
  add,
  assist,
  upload,
  delete,
  other,
}

enum _ActivityFilter {
  all,
  scans,
  adds,
  assist,
}

class _FeedItem {
  const _FeedItem({
    required this.sample,
    required this.type,
    required this.title,
    required this.when,
    required this.count,
    required this.key,
    this.inventoryQuery,
  });

  final ActivityEntry sample;
  final _ActivityType type;
  final String title;
  final DateTime when;
  final int count;
  final String key;
  final String? inventoryQuery;
}

class _FeedSection {
  const _FeedSection({required this.title, required this.items});

  final String title;
  final List<_FeedItem> items;
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
  List<ActivityEntry> _activities = const [];

  bool _insightsLoading = true;
  int? _addedThisWeek;
  int? _lowStockCount;
  String? _mostActiveLocation;

  _ActivityFilter _filter = _ActivityFilter.all;
  bool _fadeIn = false;

  static const _bgGradient = LinearGradient(
    colors: [
      Color(0xFF020617),
      Color(0xFF0F172A),
      Color(0xFF020617),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadAll());
  }

  Future<void> _loadAll() async {
    unawaited(_loadInsights());
    await _loadActivity();
  }

  Future<void> _loadActivity() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _fadeIn = false;
    });

    try {
      final items = await widget.api.getRecentActivity(limit: 50);
      if (!mounted) return;
      setState(() {
        _activities = items;
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

  Future<void> _loadInsights() async {
    if (!mounted) return;
    setState(() {
      _insightsLoading = true;
      _addedThisWeek = null;
      _lowStockCount = null;
      _mostActiveLocation = null;
    });

    try {
      final thresholdsFuture = LowStockPrefs.loadAll();

      var items = InventoryCache.items;
      if (items.isEmpty) {
        final supabase = Supabase.instance.client;
        final uid = supabase.auth.currentUser?.id;
        if (uid != null && uid.isNotEmpty) {
          final resp = await supabase
              .from('items')
              .select('item_id,name,category,quantity,location,created_at')
              .eq('user_id', uid)
              .order('created_at', ascending: false)
              .limit(250);

          final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
          items = rows.map(InventoryItem.fromJson).toList();
          InventoryCache.setItems(items);
        }
      }

      final thresholds = await thresholdsFuture;
      if (!mounted) return;

      setState(() {
        _addedThisWeek = _addedThisWeekCount(items);
        _lowStockCount = _lowStockCountFor(items, thresholds);
        _mostActiveLocation = _mostActiveLocationFor(items);
        _insightsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _insightsLoading = false;
      });
    }
  }

  int _addedThisWeekCount(List<InventoryItem> items) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    var sum = 0;
    for (final it in items) {
      if (it.createdAt.isAfter(cutoff)) {
        sum += (it.quantity <= 0 ? 0 : it.quantity);
      }
    }
    return sum;
  }

  int _lowStockCountFor(List<InventoryItem> items, Map<String, int> thresholds) {
    if (thresholds.isEmpty || items.isEmpty) return 0;
    var n = 0;
    for (final it in items) {
      final thr = thresholds[it.itemId];
      if (thr == null || thr <= 0) continue;
      if (it.quantity <= thr) n++;
    }
    return n;
  }

  String _mostActiveLocationFor(List<InventoryItem> items) {
    if (items.isEmpty) return '—';
    final counts = <String, int>{};
    for (final it in items) {
      final loc = it.location.trim().isEmpty ? 'Unsorted' : it.location.trim();
      counts[loc] = (counts[loc] ?? 0) + (it.quantity <= 0 ? 0 : it.quantity);
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return '—';
    return entries.first.key;
  }

  _ActivityType _typeFor(ActivityEntry a) {
    final s = a.summary.toLowerCase();
    if (s.contains('scan') || s.contains('scanned')) return _ActivityType.scan;
    if (s.contains('assist') || s.contains('ai')) return _ActivityType.assist;
    if (s.contains('upload') || s.contains('document') || s.contains('pdf')) return _ActivityType.upload;
    if (s.contains('delete') || s.contains('removed')) return _ActivityType.delete;
    if (s.contains('add') || s.contains('created')) return _ActivityType.add;
    return _ActivityType.other;
  }

  bool _passesFilter(_ActivityType type) {
    return switch (_filter) {
      _ActivityFilter.all => true,
      _ActivityFilter.scans => type == _ActivityType.scan,
      _ActivityFilter.adds => type == _ActivityType.add,
      _ActivityFilter.assist => type == _ActivityType.assist,
    };
  }

  IconData _iconForType(_ActivityType t) {
    return switch (t) {
      _ActivityType.scan => Icons.camera_alt_outlined,
      _ActivityType.add => Icons.add_circle_outline,
      _ActivityType.assist => Icons.auto_awesome_outlined,
      _ActivityType.upload => Icons.description_outlined,
      _ActivityType.delete => Icons.delete_outline,
      _ActivityType.other => Icons.timeline,
    };
  }

  String _improveTitle(ActivityEntry a, _ActivityType t) {
    final raw = a.summary.trim();
    if (raw.isEmpty) {
      return switch (t) {
        _ActivityType.scan => 'Scanned items',
        _ActivityType.add => 'Added items',
        _ActivityType.assist => 'Asked Assist',
        _ActivityType.upload => 'Uploaded a document',
        _ActivityType.delete => 'Removed items',
        _ActivityType.other => 'Activity',
      };
    }

    final lower = raw.toLowerCase();
    if (t == _ActivityType.assist && (lower == 'used assist' || lower == 'assist')) {
      return 'Asked Assist a question';
    }
    if (t == _ActivityType.scan && (lower == 'scan' || lower == 'scanned')) {
      return 'Scanned items';
    }
    if (t == _ActivityType.add && (lower == 'add' || lower == 'added')) {
      return 'Added items';
    }

    final out = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }

  String? _inventoryQueryFor(ActivityEntry a, _ActivityType t) {
    final raw = a.summary.trim();
    if (raw.isEmpty) return null;

    final lower = raw.toLowerCase();
    if (t == _ActivityType.add || t == _ActivityType.delete) {
      final byName = _extractAfter(raw, ['added ', 'created ', 'removed ', 'deleted ']);
      if (byName != null && byName.trim().isNotEmpty) return byName.trim();
    }
    if (lower.contains(' in ')) {
      final loc = _extractLocation(raw);
      if (loc != null && loc.isNotEmpty) return loc;
    }
    return null;
  }

  String? _extractAfter(String s, List<String> prefixes) {
    final lower = s.toLowerCase();
    for (final p in prefixes) {
      final idx = lower.indexOf(p);
      if (idx == -1) continue;
      final start = idx + p.length;
      if (start >= s.length) continue;
      var out = s.substring(start).trim();
      out = out.replaceAll(RegExp('^["“”\']+'), '');
      out = out.replaceAll(RegExp('["“”\']+\$'), '');
      out = out.split(RegExp(r'[\n\r\t\.|,;:!]')).first.trim();
      if (out.isNotEmpty) return out;
    }
    return null;
  }

  String? _extractLocation(String s) {
    final lower = s.toLowerCase();
    final idx = lower.indexOf(' in ');
    if (idx == -1) return null;
    final start = idx + 4;
    if (start >= s.length) return null;
    var out = s.substring(start).trim();
    out = out.split(RegExp(r'[\n\r\t\.|,;:!]')).first.trim();
    if (out.isEmpty) return null;
    if (out.length > 32) return out.substring(0, 32).trim();
    return out;
  }

  String _timeAgo(DateTime t) {
    final now = DateTime.now();
    var d = now.difference(t);
    if (d.isNegative) d = Duration.zero;

    if (d.inSeconds < 45) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    final weeks = (d.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w ago';
    final months = (d.inDays / 30).floor();
    if (months < 12) return '${months}mo ago';
    final years = (d.inDays / 365).floor();
    return '${years}y ago';
  }

  DateTime _dayStart(DateTime t) => DateTime(t.year, t.month, t.day);

  List<_FeedSection> _buildSections() {
    final now = DateTime.now();
    final todayStart = _dayStart(now);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final today = <ActivityEntry>[];
    final yesterday = <ActivityEntry>[];
    final earlier = <ActivityEntry>[];

    final sorted = List<ActivityEntry>.from(_activities)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final a in sorted) {
      final type = _typeFor(a);
      if (!_passesFilter(type)) continue;

      final local = a.createdAt.toLocal();
      if (!local.isBefore(todayStart)) {
        today.add(a);
      } else if (!local.isBefore(yesterdayStart)) {
        yesterday.add(a);
      } else {
        earlier.add(a);
      }
    }

    final out = <_FeedSection>[];
    if (today.isNotEmpty) out.add(_FeedSection(title: 'Today', items: _merge(today)));
    if (yesterday.isNotEmpty) out.add(_FeedSection(title: 'Yesterday', items: _merge(yesterday)));
    if (earlier.isNotEmpty) out.add(_FeedSection(title: 'Earlier', items: _merge(earlier)));
    return out;
  }

  List<_FeedItem> _merge(List<ActivityEntry> items) {
    final merged = <_FeedItem>[];
    final indexByKey = <String, int>{};

    for (final a in items) {
      final type = _typeFor(a);
      final title = _improveTitle(a, type);
      final normalized = title.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      final key = '${type.name}|$normalized';
      final existing = indexByKey[key];
      if (existing == null) {
        indexByKey[key] = merged.length;
        merged.add(
          _FeedItem(
            sample: a,
            type: type,
            title: title,
            when: a.createdAt,
            count: 1,
            key: key,
            inventoryQuery: _inventoryQueryFor(a, type),
          ),
        );
      } else {
        final prev = merged[existing];
        merged[existing] = _FeedItem(
          sample: prev.sample,
          type: prev.type,
          title: prev.title,
          when: prev.when,
          count: prev.count + 1,
          key: prev.key,
          inventoryQuery: prev.inventoryQuery,
        );
      }
    }

    return merged;
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
            'This week',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(
                label: 'Added',
                value: _insightsLoading
                    ? skeletonValue()
                    : valueText('${_addedThisWeek ?? 0}'),
              ),
              const SizedBox(width: 12),
              stat(
                label: 'Low stock',
                value: _insightsLoading
                    ? skeletonValue()
                    : valueText('${_lowStockCount ?? 0}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          stat(
            label: 'Most active location',
            value: _insightsLoading
                ? const SkeletonBox(height: 18, width: 160, borderRadius: 10)
                : Text(
                    _mostActiveLocation ?? '—',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    ChoiceChip chip({required String label, required bool selected, required VoidCallback onTap}) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        selectedColor: Colors.white.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: selected ? 0.95 : 0.78)),
        side: BorderSide(color: Colors.white.withValues(alpha: selected ? 0.18 : 0.10)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(
            label: 'All',
            selected: _filter == _ActivityFilter.all,
            onTap: () => setState(() => _filter = _ActivityFilter.all),
          ),
          const SizedBox(width: 8),
          chip(
            label: 'Scans',
            selected: _filter == _ActivityFilter.scans,
            onTap: () => setState(() => _filter = _ActivityFilter.scans),
          ),
          const SizedBox(width: 8),
          chip(
            label: 'Adds',
            selected: _filter == _ActivityFilter.adds,
            onTap: () => setState(() => _filter = _ActivityFilter.adds),
          ),
          const SizedBox(width: 8),
          chip(
            label: 'Assist',
            selected: _filter == _ActivityFilter.assist,
            onTap: () => setState(() => _filter = _ActivityFilter.assist),
          ),
        ],
      ),
    );
  }

  VoidCallback? _tapFor(_FeedItem it) {
    switch (it.type) {
      case _ActivityType.scan:
        return () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ScanPage(
                api: widget.api,
                onSaved: () {},
              ),
            ),
          );
          if (!mounted) return;
          unawaited(_loadAll());
        };
      case _ActivityType.add:
      case _ActivityType.delete:
      case _ActivityType.upload:
        final q = (it.inventoryQuery ?? '').trim();
        return () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => InventoryPage(
                api: widget.api,
                refreshToken: 0,
                initialQuery: q.isEmpty ? null : q,
              ),
            ),
          );
        };
      case _ActivityType.assist:
      case _ActivityType.other:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tEmpty1 = Theme.of(context).textTheme.titleMedium;
    final tEmpty2 = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.70),
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Activity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: _bgGradient),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryHeader(),
            const SizedBox(height: 12),
            _filterChips(),
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
                      onPressed: _loadAll,
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
            else if (_activities.isEmpty)
              GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('No activity yet', style: tEmpty1, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(
                      'Start by scanning or adding items',
                      style: tEmpty2,
                      textAlign: TextAlign.center,
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
                    for (final section in _buildSections()) ...[
                      Text(
                        section.title,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.70),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      GlassCard(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < section.items.length; i++) ...[
                              if (i != 0) const Divider(height: 1),
                              Builder(
                                builder: (context) {
                                  final it = section.items[i];
                                  final onTap = _tapFor(it);
                                  final title = it.count <= 1 ? it.title : '${it.title} (${it.count} times)';
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onTap,
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(
                                        _iconForType(it.type),
                                        color: Colors.white.withValues(alpha: 0.80),
                                      ),
                                      title: Text(title),
                                      subtitle: Text(_timeAgo(it.when)),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
