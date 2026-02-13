import 'dart:async';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/ui/app_colors.dart';
import '../../core/ui/glass_card.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.api, required this.refreshToken});

  final ApiClient api;
  final int refreshToken;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;

  List<InventoryItem> _items = const [];
  List<InventoryItem>? _searchResults;

  Timer? _debounce;

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
      final resp = await supabase
          .from('items')
          .select('*')
          .order('created_at', ascending: false)
          .limit(200);

      final rows = (resp as List<dynamic>).cast<Map<String, dynamic>>();
      final items = rows.map(InventoryItem.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _items = items;
        _searchResults = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = _search.text.trim();
      if (q.isEmpty) {
        if (mounted) setState(() => _searchResults = null);
        return;
      }

      try {
        final res = await widget.api.searchItems(query: q);
        if (!mounted) return;
        setState(() {
          _error = null;
          _searchResults = res.items;
        });
      } on dio.DioException catch (e) {
        if (!mounted) return;
        final status = e.response?.statusCode;
        if (status == 429) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate limited. Try again in ~20 seconds.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Request failed')));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    });
  }

  Future<void> _addItem() async {
    final created = await showModalBottomSheet<AddItemRequest>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ItemEditorSheet(),
    );
    if (created == null) return;

    try {
      await widget.api.addItem(item: created);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item added')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate limited. Try again in ~20 seconds.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Request failed')));
      }
    }
  }

  Future<void> _editItem(InventoryItem item) async {
    final updates = await showModalBottomSheet<UpdateItemRequest>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ItemEditorSheet(item: item),
    );
    if (updates == null) return;

    try {
      await widget.api.updateItem(request: updates);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      await _loadItems();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 429) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate limited. Try again in ~20 seconds.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Request failed')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Request failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _searchResults ?? _items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _loadItems, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search inventory…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
              )
            else if (_error != null)
              GlassCard(
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(6),
                  child: rows.isEmpty
                      ? Center(
                          child: Text(
                            _searchResults != null ? 'No results.' : 'No items yet.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: rows.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = rows[index];
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
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${item.category} · ${item.location}',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.60)),
                                ),
                                trailing: Text(
                                  'Qty ${item.quantity}',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w700),
                                ),
                                onTap: () => _editItem(item),
                              ),
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

class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({this.item});

  final InventoryItem? item;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _location;
  late final TextEditingController _quantity;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _category = TextEditingController(text: widget.item?.category ?? '');
    _location = TextEditingController(text: widget.item?.location ?? '');
    _quantity = TextEditingController(text: (widget.item?.quantity ?? 1).toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _location.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item == null ? 'Add item' : 'Edit item',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(_quantity.text.trim()) ?? 0;
              if (widget.item == null) {
                Navigator.of(context).pop(
                  AddItemRequest(
                    name: _name.text.trim(),
                    category: _category.text.trim(),
                    quantity: qty,
                    location: _location.text.trim(),
                  ),
                );
              } else {
                Navigator.of(context).pop(
                  UpdateItemRequest(
                    itemId: widget.item!.itemId,
                    name: _name.text.trim(),
                    category: _category.text.trim(),
                    quantity: qty,
                    location: _location.text.trim(),
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
