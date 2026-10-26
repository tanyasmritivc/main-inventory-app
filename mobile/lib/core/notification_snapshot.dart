int notificationUnreadCount(Map<String, dynamic> result) {
  final count = result['unread_count'];
  if (count is! num || !count.isFinite || count < 0 || count != count.toInt()) {
    throw const FormatException('The notification count could not be read.');
  }
  return count.toInt();
}

class NotificationSnapshot {
  const NotificationSnapshot(this.items, this.unreadCount);
  final List<Map<String, dynamic>> items;
  final int unreadCount;

  factory NotificationSnapshot.parse(Map<String, dynamic> result) {
    final rows = result['notifications'];
    if (rows is! List || rows.any((row) => row is! Map)) {
      throw const FormatException('The notification feed could not be read.');
    }
    return NotificationSnapshot(
      rows.map((row) => Map<String, dynamic>.from(row as Map)).toList(),
      notificationUnreadCount(result),
    );
  }
}
