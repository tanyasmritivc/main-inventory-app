import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/low_stock_prefs.dart';
import '../../core/upgrade_sheet.dart';

class ShoppingListPage extends StatefulWidget {
  final ApiClient api;
  const ShoppingListPage({required this.api, super.key});
  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  List<_ShoppingItem> _items = [];
  bool _loading = true;
  final Set<String> _checked = {};
  static const _kCheckedKey = 'shopping_list_checked';

  @override
  void initState() {
    super.initState();
    _load();
    _loadChecked();
  }

  Future<void> _loadChecked() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kCheckedKey) ?? [];
    setState(() => _checked.addAll(saved));
  }

  Future<void> _saveChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kCheckedKey, _checked.toList());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api.searchItems(query: '');
      final thresholds = await LowStockPrefs.loadAll();

      final lowStock = <_ShoppingItem>[];

      for (final item in result.items) {
        final threshold = thresholds[item.itemId];
        final isLow = threshold != null && threshold > 0 && item.quantity <= threshold;
        final isZero = item.quantity <= 0;

        if (isLow || isZero) {
          final needed = threshold != null && threshold > 0
              ? (threshold * 2) - item.quantity
              : 5;
          lowStock.add(_ShoppingItem(
            item: item,
            suggestedQty: needed.clamp(1, 999),
            reason: isZero ? 'Out of stock' : 'Low stock (${item.quantity} left, need ${threshold}+)',
          ));
        }
      }

      lowStock.sort((a, b) {
        if (a.item.quantity <= 0 && b.item.quantity > 0) return -1;
        if (b.item.quantity <= 0 && a.item.quantity > 0) return 1;
        return a.item.location.compareTo(b.item.location);
      });

      setState(() {
        _items = lowStock;
        _loading = false;
      });
    } on dio.DioException catch (e) {
      if (e.response?.statusCode == 429) {
        if (mounted) {
          setState(() => _loading = false);
          showUpgradeSheet(context, widget.api, reason: 'Upgrade to Pro for unlimited access');
        }
        return;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _buildShareText() {
    final buffer = StringBuffer();
    buffer.writeln('🛒 FindEZ AI — Shopping List');
    buffer.writeln('Generated ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('');

    final bySpace = <String, List<_ShoppingItem>>{};
    for (final item in _items) {
      if (_checked.contains(item.item.itemId)) continue;
      (bySpace[item.item.location] ??= []).add(item);
    }

    for (final space in bySpace.keys.toList()..sort()) {
      buffer.writeln('📦 ${space.toUpperCase()}');
      for (final si in bySpace[space]!) {
        final partNum = si.item.partNumber != null ? ' [${si.item.partNumber}]' : '';
        final brand = si.item.brand != null ? ' — ${si.item.brand}' : '';
        buffer.writeln('  • ${si.item.name}$partNum$brand');
        buffer.writeln('    Qty needed: ${si.suggestedQty}  |  ${si.reason}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final unchecked = _items.where((i) => !_checked.contains(i.item.itemId)).toList();
    final checkedItems = _items.where((i) => _checked.contains(i.item.itemId)).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Shopping List',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (_checked.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all_outlined, color: Colors.white70, size: 20),
              onPressed: () async {
                setState(() => _checked.clear());
                await _saveChecked();
              },
              tooltip: 'Clear ordered items',
            ),
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 20),
              onPressed: () {
                final text = _buildShareText();
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shopping list copied to clipboard')),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.white70, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _items.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: Colors.white,
                  backgroundColor: const Color(0xFF1C1C1E),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: unchecked.isEmpty
                              ? const Color(0x0A30D158)
                              : const Color(0x0AEF4444),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: unchecked.isEmpty
                                ? const Color(0x3330D158)
                                : const Color(0x33EF4444),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              unchecked.isEmpty
                                  ? Icons.check_circle_outline
                                  : Icons.shopping_cart_outlined,
                              color: unchecked.isEmpty
                                  ? const Color(0xFF30D158)
                                  : const Color(0xFFEF4444),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    unchecked.isEmpty
                                        ? 'All items ordered!'
                                        : '${unchecked.length} items need restocking',
                                    style: TextStyle(
                                      color: unchecked.isEmpty
                                          ? const Color(0xFF30D158)
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (unchecked.isNotEmpty)
                                    const Text(
                                      'Tap items to mark as ordered',
                                      style: TextStyle(
                                        color: Color(0x73FFFFFF),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (unchecked.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  final text = _buildShareText();
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Shopping list copied — paste into WhatsApp, email, or notes'),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: const Text(
                                    'Share',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (unchecked.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'NEEDS RESTOCKING',
                            style: TextStyle(
                              color: Color(0x4DFFFFFF),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        ...unchecked.map((si) => _ShoppingItemCard(
                          shoppingItem: si,
                          isChecked: false,
                          onTap: () {
                            setState(() => _checked.add(si.item.itemId));
                            _saveChecked();
                          },
                          onQtyChanged: (qty) => setState(() => si.suggestedQty = qty),
                        )),
                      ],

                      if (checkedItems.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'ORDERED',
                            style: TextStyle(
                              color: Color(0x4DFFFFFF),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        ...checkedItems.map((si) => _ShoppingItemCard(
                          shoppingItem: si,
                          isChecked: true,
                          onTap: () {
                            setState(() => _checked.remove(si.item.itemId));
                            _saveChecked();
                          },
                          onQtyChanged: (qty) => setState(() => si.suggestedQty = qty),
                        )),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF30D158), size: 56),
          const SizedBox(height: 16),
          const Text(
            'All stocked up!',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'No items are low on stock.\nSet thresholds on items to track them.',
            style: TextStyle(color: Color(0x73FFFFFF), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x14FFFFFF)),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingItem {
  final InventoryItem item;
  int suggestedQty;
  final String reason;
  _ShoppingItem({required this.item, required this.suggestedQty, required this.reason});
}

class _ShoppingItemCard extends StatelessWidget {
  final _ShoppingItem shoppingItem;
  final bool isChecked;
  final VoidCallback onTap;
  final ValueChanged<int> onQtyChanged;
  const _ShoppingItemCard({
    required this.shoppingItem,
    required this.isChecked,
    required this.onTap,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final item = shoppingItem.item;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isChecked ? const Color(0x06FFFFFF) : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isChecked
                ? const Color(0x0AFFFFFF)
                : item.quantity <= 0
                    ? const Color(0x33EF4444)
                    : const Color(0x33FBBF24),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isChecked ? const Color(0xFF30D158) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked ? const Color(0xFF30D158) : const Color(0x40FFFFFF),
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: isChecked ? const Color(0x60FFFFFF) : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.quantity <= 0
                              ? const Color(0x1AEF4444)
                              : const Color(0x1AFBBF24),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.quantity <= 0 ? 'OUT OF STOCK' : '${item.quantity} left',
                          style: TextStyle(
                            color: item.quantity <= 0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFFBBF24),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.location,
                        style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 11),
                      ),
                      if (item.partNumber != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '#${item.partNumber}',
                          style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  if (!isChecked) ...[
                    const SizedBox(height: 4),
                    Text(
                      shoppingItem.reason,
                      style: const TextStyle(color: Color(0x4DFFFFFF), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isChecked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (shoppingItem.suggestedQty > 1) {
                        onQtyChanged(shoppingItem.suggestedQty - 1);
                      }
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.remove, color: Colors.white70, size: 14),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${shoppingItem.suggestedQty}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onQtyChanged(shoppingItem.suggestedQty + 1),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0x0AFFFFFF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.add, color: Colors.white70, size: 14),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
