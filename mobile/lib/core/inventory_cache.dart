import 'api_client.dart';

class InventoryCache {
  static final Map<String, List<InventoryItem>> _collections = {};
  static List<InventoryItem> get items => forContext('legacy');
  static List<InventoryItem> forContext(String key) =>
      _collections[key] ?? const [];
  static void setItems(
    List<InventoryItem> items, {
    String contextKey = 'legacy',
  }) {
    _collections[contextKey] = List<InventoryItem>.unmodifiable(items);
  }

  static void clear() => _collections.clear();
  static void removeSpace(String spaceId, {String contextKey = 'legacy'}) {
    setItems(
      forContext(contextKey).where((item) => item.spaceId != spaceId).toList(),
      contextKey: contextKey,
    );
  }

  static void updateItem(InventoryItem item, {String contextKey = 'legacy'}) {
    final items = forContext(contextKey);
    final index = items.indexWhere((entry) => entry.itemId == item.itemId);
    if (index == -1) return;
    final next = List<InventoryItem>.from(items);
    next[index] = item;
    setItems(next, contextKey: contextKey);
  }
}
