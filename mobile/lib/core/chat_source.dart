/// A reference is resolved afresh by the server; file text is untrusted evidence.
class ChatSource {
  const ChatSource({
    required this.kind,
    required this.name,
    this.inventoryId,
    this.resourceId,
    this.inventoryName,
    this.text,
    this.truncated = false,
  });
  final String kind, name;
  final String? inventoryId, resourceId, inventoryName, text;
  final bool truncated;
  String get key =>
      kind == 'file' ? 'file:$name:$text' : '$kind:$inventoryId:$resourceId';
  factory ChatSource.fromJson(Map<String, dynamic> json) => ChatSource(
    kind: json['kind'] as String,
    name: json['name'] as String,
    inventoryId: json['inventory_id'] as String?,
    resourceId: json['resource_id'] as String?,
    inventoryName: json['inventory_name'] as String?,
    text: json['text'] as String?,
    truncated: json['truncated'] == true,
  );
  Map<String, dynamic> toJson() => kind == 'file'
      ? {'kind': kind, 'name': name, 'text': text, 'truncated': truncated}
      : {'kind': kind, 'inventory_id': inventoryId, 'resource_id': resourceId};
}
