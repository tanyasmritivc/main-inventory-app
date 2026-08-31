import 'api_client.dart';

class InventoryCache {
  static List<InventoryItem> _items = const [];

  static List<InventoryItem> get items => _items;

  static void setItems(List<InventoryItem> items) {
    _items = List<InventoryItem>.unmodifiable(items);
  }

  static void clear() {
    _items = const [];
  }

  static void removeSpace(String spaceId) {
    _items = List<InventoryItem>.unmodifiable(
      _items.where((item) => item.spaceId != spaceId),
    );
  }
}
