import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';

const _kSortPrefKey = 'item_sort_option';

enum ItemSortOption {
  nameAZ,
  nameZA,
  quantityLowHigh,
  quantityHighLow,
  categoryAZ,
  dateNewest,
  dateOldest,
}

String itemSortLabel(ItemSortOption option) {
  switch (option) {
    case ItemSortOption.nameAZ:
      return 'Name A → Z';
    case ItemSortOption.nameZA:
      return 'Name Z → A';
    case ItemSortOption.quantityLowHigh:
      return 'Quantity: Low → High';
    case ItemSortOption.quantityHighLow:
      return 'Quantity: High → Low';
    case ItemSortOption.categoryAZ:
      return 'Category A → Z';
    case ItemSortOption.dateNewest:
      return 'Newest first';
    case ItemSortOption.dateOldest:
      return 'Oldest first';
  }
}

Future<ItemSortOption> loadSortPref() async {
  final prefs = await SharedPreferences.getInstance();
  final index = prefs.getInt(_kSortPrefKey);
  if (index == null || index < 0 || index >= ItemSortOption.values.length) {
    return ItemSortOption.nameAZ;
  }
  return ItemSortOption.values[index];
}

Future<void> saveSortPref(ItemSortOption option) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kSortPrefKey, option.index);
}

void sortInventoryItems(List<InventoryItem> items, ItemSortOption option) {
  switch (option) {
    case ItemSortOption.nameAZ:
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case ItemSortOption.nameZA:
      items.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    case ItemSortOption.quantityLowHigh:
      items.sort((a, b) => a.quantity.compareTo(b.quantity));
    case ItemSortOption.quantityHighLow:
      items.sort((a, b) => b.quantity.compareTo(a.quantity));
    case ItemSortOption.categoryAZ:
      items.sort((a, b) {
        final c = a.category.toLowerCase().compareTo(b.category.toLowerCase());
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    case ItemSortOption.dateNewest:
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case ItemSortOption.dateOldest:
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
}

void sortRawItems(List<Map<String, dynamic>> items, ItemSortOption option) {
  String name(Map<String, dynamic> it) =>
      (it['name'] ?? '').toString().toLowerCase();
  int qty(Map<String, dynamic> it) => (it['quantity'] as int?) ?? 0;
  String cat(Map<String, dynamic> it) =>
      (it['category'] ?? '').toString().toLowerCase();
  DateTime date(Map<String, dynamic> it) {
    final s = it['created_at'] as String?;
    if (s == null) return DateTime(0);
    return DateTime.tryParse(s) ?? DateTime(0);
  }

  switch (option) {
    case ItemSortOption.nameAZ:
      items.sort((a, b) => name(a).compareTo(name(b)));
    case ItemSortOption.nameZA:
      items.sort((a, b) => name(b).compareTo(name(a)));
    case ItemSortOption.quantityLowHigh:
      items.sort((a, b) => qty(a).compareTo(qty(b)));
    case ItemSortOption.quantityHighLow:
      items.sort((a, b) => qty(b).compareTo(qty(a)));
    case ItemSortOption.categoryAZ:
      items.sort((a, b) {
        final c = cat(a).compareTo(cat(b));
        return c != 0 ? c : name(a).compareTo(name(b));
      });
    case ItemSortOption.dateNewest:
      items.sort((a, b) => date(b).compareTo(date(a)));
    case ItemSortOption.dateOldest:
      items.sort((a, b) => date(a).compareTo(date(b)));
  }
}

void showItemSortSheet(
  BuildContext context,
  ItemSortOption current,
  void Function(ItemSortOption) onSelected,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFFFFFFFF),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Sort by',
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0x14000000)),
          for (final option in ItemSortOption.values)
            InkWell(
              onTap: () {
                Navigator.of(ctx).pop();
                onSelected(option);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        itemSortLabel(option),
                        style: TextStyle(
                          color: option == current
                              ? Colors.black
                              : const Color(0xFF3C3C43),
                          fontSize: 15,
                          fontWeight: option == current
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (option == current)
                      const Icon(Icons.check, color: Colors.black, size: 18),
                  ],
                ),
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      );
    },
  );
}
