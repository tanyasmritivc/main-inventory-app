import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_error.dart';
import '../../core/app_theme.dart';
import '../inventory/item_detail_sheet.dart';
import '../inventory/world_views.dart';

class NeedsIdentifyingPage extends StatefulWidget {
  const NeedsIdentifyingPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<NeedsIdentifyingPage> createState() => _NeedsIdentifyingPageState();
}

class _NeedsIdentifyingPageState extends State<NeedsIdentifyingPage> {
  List<InventoryItem>? _items;
  int _index = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final result = await widget.api.searchItems(query: '');
      if (!mounted) return;
      setState(() {
        _items = result.items.where((item) => !item.identityConfirmed).toList();
        _index = _items!.isEmpty ? 0 : _index.clamp(0, _items!.length - 1);
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = describeError(error).$1);
    }
  }

  Future<void> _confirm(InventoryItem item) async {
    setState(() => _busy = true);
    try {
      await widget.api.updateItem(
        request: UpdateItemRequest(
          itemId: item.itemId,
          identityConfirmed: true,
        ),
      );
      if (!mounted) return;
      setState(() {
        _items!.removeWhere((candidate) => candidate.itemId == item.itemId);
        _index = _items!.isEmpty ? 0 : _index.clamp(0, _items!.length - 1);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(error).$1)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(InventoryItem item) async {
    await showItemDetailSheet(
      context,
      item: item,
      api: widget.api,
      spaceName: item.location,
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final items = _items;
    final item = items == null || items.isEmpty ? null : items[_index];
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorldHeader(title: 'Review', onBack: () => Navigator.pop(context)),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  children: [
                    if (items == null && _error == null)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      WorldSection(
                        title: 'Could not load review',
                        children: [
                          WorldRow(title: _error!, count: ''),
                          WorldRow(title: 'Try again', count: '', onTap: _load),
                        ],
                      )
                    else if (item == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'Everything has a confirmed identity.',
                          style: TextStyle(color: t.text2, fontSize: 15),
                        ),
                      )
                    else ...[
                      Text(
                        '${_index + 1} of ${items!.length}',
                        style: TextStyle(
                          color: t.text2,
                          fontSize: 13,
                          fontFamily: 'IBMPlexMono',
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTokens.radius),
                        child: Container(
                          height: 220,
                          color: t.s2,
                          child: item.imageUrl == null || item.imageUrl!.isEmpty
                              ? Center(
                                  child: Text(
                                    'No photograph on record',
                                    style: TextStyle(color: t.text2),
                                  ),
                                )
                              : Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                        child: Text(
                                          'Photograph unavailable',
                                          style: TextStyle(color: t.text2),
                                        ),
                                      ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        item.name.trim().isEmpty
                            ? 'Identity unknown'
                            : item.name,
                        style: TextStyle(color: t.ink, fontSize: 24),
                      ),
                      if (item.confidence != null)
                        Text(
                          '${(item.confidence! * 100).round()}% confidence',
                          style: TextStyle(
                            color: t.accentText,
                            fontSize: 14,
                            fontFamily: 'IBMPlexMono',
                          ),
                        ),
                      const SizedBox(height: 20),
                      WorldSection(
                        title: 'On this record',
                        children: [
                          WorldRow(
                            title: 'Place',
                            count: '',
                            subtitle: item.location.trim().isEmpty
                                ? 'No place saved'
                                : item.location,
                          ),
                          if (item.partNumber != null &&
                              item.partNumber!.trim().isNotEmpty)
                            WorldRow(
                              title: 'Part number',
                              count: '',
                              subtitle: item.partNumber,
                            ),
                          if (item.barcode != null &&
                              item.barcode!.trim().isNotEmpty)
                            WorldRow(
                              title: 'Barcode',
                              count: '',
                              subtitle: item.barcode,
                            ),
                          if (item.category.trim().isNotEmpty)
                            WorldRow(
                              title: 'Category',
                              count: '',
                              subtitle: item.category,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : () => _confirm(item),
                        child: const Text('Confirm this identity'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _open(item),
                        child: const Text('Edit or inspect object'),
                      ),
                      if (items.length > 1)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _index = (_index + 1) % items.length,
                                ),
                          child: const Text('Next object'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
