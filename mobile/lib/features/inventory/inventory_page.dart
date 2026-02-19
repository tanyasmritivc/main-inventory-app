import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/glass_card.dart';
import '../../core/ui/skeleton.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.api, required this.refreshToken});

  final ApiClient api;
  final int refreshToken;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _search = TextEditingController();
  final ValueNotifier<String> _query = ValueNotifier('');
  final ValueNotifier<List<InventoryItem>> _rows = ValueNotifier(const []);
  final ValueNotifier<bool> _aiSearching = ValueNotifier(false);
  final ValueNotifier<Map<String, int>> _thresholds = ValueNotifier(const {});

  bool _loading = true;
  String? _error;

  List<InventoryItem> _items = const [];

  Timer? _debounce;
  String? _lastAiExpandedFor;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant InventoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadItems();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _query.dispose();
    _rows.dispose();
    _aiSearching.dispose();
    _thresholds.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'Please sign in again.');
        return;
      }
      final resp = await supabase
          .from('items')
          .select('*')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(200);

      final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      final items = rows.map(InventoryItem.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _items = items;
      });
      LowStockPrefs.loadAll().then((value) {
        if (!mounted) return;
        _thresholds.value = value;
      });
      _applyLocalSearch(_query.value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'That didn’t work. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _containsToken(String haystack, String token) {
    if (haystack.isEmpty || token.isEmpty) return false;
    return haystack.toLowerCase().contains(token.toLowerCase());
  }

  int _scoreForToken(InventoryItem it, String token, {required String fullQuery}) {
    final name = it.name;
    final category = it.category;
    final location = it.location;
    final notes = (it.notes ?? '');

    final nameLower = name.toLowerCase();
    final tokenLower = token.toLowerCase();
    final fullLower = fullQuery.toLowerCase();

    var score = 0;

    if (nameLower == fullLower) return 10000;
    if (nameLower.startsWith(fullLower) && fullLower.isNotEmpty) score += 7000;

    if (nameLower == tokenLower) score += 4500;
    if (nameLower.startsWith(tokenLower)) score += 2200;
    if (nameLower.contains(tokenLower)) score += 1500;

    if (_containsToken(category, token)) score += 900;

    final tags = it.tags ?? const <String>[];
    for (final t in tags) {
      if (_containsToken(t, token)) {
        score += 750;
        break;
      }
    }

    if (_containsToken(location, token)) score += 600;
    if (_containsToken(notes, token)) score += 450;
    if (_containsToken(it.purchaseSource ?? '', token)) score += 350;
    if (_containsToken(it.barcode ?? '', token)) score += 250;

    return score;
  }

  List<InventoryItem> _smartLocalSearch(String rawQuery, {List<String> extraTerms = const []}) {
    final q = rawQuery.trim();
    if (q.isEmpty) return _items;

    final tokens = <String>{
      ...q.split(RegExp(r'\s+')).map((t) => t.trim()).where((t) => t.isNotEmpty),
      ...extraTerms.map((t) => t.trim()).where((t) => t.isNotEmpty),
    }.toList();

    final scored = <({InventoryItem item, int score})>[];
    for (final it in _items) {
      var s = 0;
      for (final tok in tokens) {
        s += _scoreForToken(it, tok, fullQuery: q);
      }
      if (s > 0) scored.add((item: it, score: s));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.item.createdAt.compareTo(a.item.createdAt);
    });
    return scored.map((e) => e.item).toList();
  }

  Future<List<String>> _expandQueryWithAi(String query) async {
    final msg =
        'Expand this inventory search query into up to 8 related search terms (synonyms, categories, related items). '
        'Return ONLY JSON like {"terms":["term1","term2"]}. Query: "$query"';

    final out = await widget.api.aiCommand(message: msg);
    final text = out.assistantMessage.trim();
    if (text.isEmpty) return const [];

    try {
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = text.substring(start, end + 1);
        final obj = (json.decode(jsonStr) as Map).cast<String, dynamic>();
        final terms = obj['terms'];
        if (terms is List) {
          return terms.map((e) => e.toString()).where((t) => t.trim().isNotEmpty).take(8).toList();
        }
      }
    } catch (_) {
      // fall through
    }

    return text
        .replaceAll(RegExp(r'[^a-zA-Z0-9,\n\s-]'), '')
        .split(RegExp(r'[,\n]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .take(8)
        .toList();
  }

  void _applyLocalSearch(String v) {
    final q = v.trim();
    _query.value = q;
    _aiSearching.value = false;
    _rows.value = _smartLocalSearch(q);

    _debounce?.cancel();
    if (q.isEmpty) {
      _lastAiExpandedFor = null;
      return;
    }

    if (_rows.value.length >= 4) return;
    if (_lastAiExpandedFor == q) return;

    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final active = _query.value;
      if (active != q || active.isEmpty) return;
      if (_rows.value.length >= 4) return;

      _aiSearching.value = true;
      try {
        final terms = await _expandQueryWithAi(active);
        if (!mounted) return;
        if (_query.value != active) return;
        _lastAiExpandedFor = active;
        _rows.value = _smartLocalSearch(active, extraTerms: terms);
      } on dio.DioException {
        // ignore; keep local results
      } catch (_) {
        // ignore; keep local results
      } finally {
        if (mounted && _query.value == active) _aiSearching.value = false;
      }
    });
  }

  Future<void> _addItem() async {
    final created = await showModalBottomSheet<_ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ItemEditorSheet(),
    );
    if (created == null) return;

    try {
      final out = await widget.api.addItem(item: created.add);
      await LowStockPrefs.setThreshold(itemId: out.itemId, threshold: created.threshold);
      final next = Map<String, int>.from(_thresholds.value);
      if (created.threshold == null || created.threshold! <= 0) {
        next.remove(out.itemId);
      } else {
        next[out.itemId] = created.threshold!;
      }
      _thresholds.value = next;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item added')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate limited. Try again in ~20 seconds.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That didn’t work. Try again.')));
      }
    }
  }

  Future<void> _editItem(InventoryItem item) async {
    final currentThreshold = _thresholds.value[item.itemId];
    final updates = await showModalBottomSheet<_ItemEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ItemEditorSheet(item: item, initialThreshold: currentThreshold),
    );
    if (updates == null) return;

    try {
      await widget.api.updateItem(request: updates.update);
      await LowStockPrefs.setThreshold(itemId: item.itemId, threshold: updates.threshold);
      final next = Map<String, int>.from(_thresholds.value);
      if (updates.threshold == null || updates.threshold! <= 0) {
        next.remove(item.itemId);
      } else {
        next[item.itemId] = updates.threshold!;
      }
      _thresholds.value = next;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate limited. Try again in ~20 seconds.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That didn’t work. Try again.')));
      }
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(item.name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.deleteItem(itemId: item.itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate limited. Try again in ~20 seconds.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That didn’t work. Try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Inventory'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _loadItems, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _search,
              onChanged: _applyLocalSearch,
              decoration: const InputDecoration(
                hintText: 'Search inventory…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: _aiSearching,
              builder: (context, searching, _) {
                if (!searching) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Searching…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                  ),
                );
              },
            ),
            Expanded(
              child: _loading
                  ? GlassCard(
                      padding: const EdgeInsets.all(6),
                      child: ListView.separated(
                        itemCount: 8,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) => const SkeletonListTile(),
                      ),
                    )
                  : (_error != null)
                      ? GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Couldn’t load your inventory.',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Try again in a moment.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.70),
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      height: 1.35,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : GlassCard(
                          padding: const EdgeInsets.all(6),
                          child: ValueListenableBuilder<Map<String, int>>(
                            valueListenable: _thresholds,
                            builder: (context, thresholds, _) {
                              return ValueListenableBuilder<List<InventoryItem>>(
                                valueListenable: _rows,
                                builder: (context, rows, _) {
                                  if (rows.isEmpty) {
                                    final emptyText = _query.value.isNotEmpty
                                        ? 'No results.'
                                        : 'No items yet. Add your first item.';
                                    return Center(
                                      child: Text(
                                        emptyText,
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                                      ),
                                    );
                                  }

                                  return ListView.separated(
                                    itemCount: rows.length,
                                    separatorBuilder: (context, index) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final item = rows[index];
                                      final threshold = thresholds[item.itemId];
                                      final isLow = (threshold != null && threshold > 0 && item.quantity <= threshold);
                                      return Dismissible(
                                        key: ValueKey(item.itemId),
                                        background: Container(
                                          alignment: Alignment.centerLeft,
                                          padding: const EdgeInsets.only(left: 16),
                                          color: AppColors.swipe,
                                          child: const Icon(Icons.edit_outlined),
                                        ),
                                        secondaryBackground: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 16),
                                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.15),
                                          child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                                        ),
                                        confirmDismiss: (direction) async {
                                          if (direction == DismissDirection.startToEnd) {
                                            await _editItem(item);
                                            return false;
                                          }
                                          if (direction == DismissDirection.endToStart) {
                                            await _deleteItem(item);
                                            return false;
                                          }
                                          return false;
                                        },
                                        child: ListTile(
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          title: Text(item.name),
                                          subtitle: Text(
                                            '${item.category} · ${item.location}',
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.60)),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isLow) ...[
                                                Icon(
                                                  Icons.error_outline_rounded,
                                                  size: 18,
                                                  color: Colors.white.withValues(alpha: 0.70),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Text(
                                                'Qty ${item.quantity}',
                                                style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
                                              ),
                                            ],
                                          ),
                                          onTap: () => _editItem(item),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ItemEditorResult {
  const _ItemEditorResult({required this.add, required this.update, required this.threshold});

  final AddItemRequest add;
  final UpdateItemRequest update;
  final int? threshold;
}

class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({this.item, this.initialThreshold});

  final InventoryItem? item;
  final int? initialThreshold;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _location;
  late final TextEditingController _quantity;
  late final TextEditingController _threshold;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _category = TextEditingController(text: widget.item?.category ?? '');
    _location = TextEditingController(text: widget.item?.location ?? '');
    _quantity = TextEditingController(text: (widget.item?.quantity ?? 1).toString());
    _threshold = TextEditingController(text: (widget.initialThreshold ?? '').toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _location.dispose();
    _quantity.dispose();
    _threshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14, bottom: bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item == null ? 'Add item' : 'Edit item',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
          const SizedBox(height: 10),
          TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location')),
          const SizedBox(height: 10),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _threshold,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Low stock threshold (optional)'),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(_quantity.text.trim()) ?? 0;
              final rawThreshold = int.tryParse(_threshold.text.trim());
              final threshold = (rawThreshold != null && rawThreshold > 0) ? rawThreshold : null;
              final location = _location.text.trim().isEmpty ? 'Unsorted' : _location.text.trim();
              if (widget.item == null) {
                Navigator.of(context).pop(
                  _ItemEditorResult(
                    threshold: threshold,
                    add: AddItemRequest(
                      name: _name.text.trim(),
                      category: _category.text.trim(),
                      quantity: qty,
                      location: location,
                    ),
                    update: UpdateItemRequest(itemId: ''),
                  ),
                );
              } else {
                Navigator.of(context).pop(
                  _ItemEditorResult(
                    threshold: threshold,
                    add: AddItemRequest(name: '', category: '', quantity: 0, location: ''),
                    update: UpdateItemRequest(
                      itemId: widget.item!.itemId,
                      name: _name.text.trim(),
                      category: _category.text.trim(),
                      quantity: qty,
                      location: location,
                    ),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
