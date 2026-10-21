class ChatItemAction {
  const ChatItemAction({
    required this.id,
    required this.inventoryId,
    required this.operation,
    required this.status,
    required this.items,
    this.destinationLabel,
  });
  final String id, inventoryId, operation, status;
  final List<ChatActionItem> items;
  final String? destinationLabel;
  static final _uuid = RegExp(
    r'^[a-f\d]{8}(?:-[a-f\d]{4}){3}-[a-f\d]{12}$',
    caseSensitive: false,
  );
  static ChatItemAction? parse(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        !_uuid.hasMatch(value['id']) ||
        value['inventory_id'] is! String ||
        !_uuid.hasMatch(value['inventory_id']) ||
        !const ['add', 'delete'].contains(value['operation']) ||
        !const [
          'pending',
          'confirmed',
          'cancelled',
        ].contains(value['status']) ||
        value['items'] is! List) {
      return null;
    }
    final raw = value['items'] as List;
    if (raw.isEmpty || raw.length > 100) return null;
    final items = <ChatActionItem>[];
    for (final item in raw) {
      if (item is! Map ||
          item['name'] is! String ||
          (item['name'] as String).trim().isEmpty ||
          item['location'] is! String ||
          (item['location'] as String).trim().isEmpty ||
          (item['quantity'] != null &&
              (item['quantity'] is! int || item['quantity'] < 0))) {
        return null;
      }
      items.add(
        ChatActionItem(item['name'], item['quantity'], item['location']),
      );
    }
    return ChatItemAction(
      id: value['id'],
      inventoryId: value['inventory_id'],
      operation: value['operation'],
      status: value['status'],
      items: items,
      destinationLabel: value['destination_label'] is String
          ? value['destination_label']
          : null,
    );
  }
}

class ChatActionItem {
  const ChatActionItem(this.name, this.quantity, this.location);
  final String name, location;
  final int? quantity;
}

class ChatItemActionResult {
  const ChatItemActionResult({
    required this.action,
    this.assistantMessage,
    this.replyId,
    this.answerError,
  });
  final ChatItemAction action;
  final String? assistantMessage, replyId, answerError;
}
