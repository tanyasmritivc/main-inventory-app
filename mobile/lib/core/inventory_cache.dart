import 'api_client.dart';

class InventoryCache {
  static List<InventoryItem> _items = const [];

  static List<InventoryItem> get items => _items;

  static void setItems(List<InventoryItem> items) {
    _items = List<InventoryItem>.unmodifiable(items);
  }
}
