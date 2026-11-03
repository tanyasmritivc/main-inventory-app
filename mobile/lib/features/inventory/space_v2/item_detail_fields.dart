import '../../../core/api_client.dart';

/// Presentation only. Both the existing editor and Space quick view use this
/// ordered list. Never mutate, normalize, or infer values here.
class ItemDetailField {
  const ItemDetailField(this.label, this.value, [this.editKey]);
  final String label, value;
  final String? editKey;
  String get displayValue =>
      editKey != null && value.isEmpty ? 'Not set' : value;
}

List<ItemDetailField> itemDetailFields(
  InventoryItem item, {
  required bool canEdit,
  bool shared = false,
}) => [
  ItemDetailField(
    item.displayDescription == null ? 'Name' : 'Description',
    item.name,
    'name',
  ),
  ItemDetailField('Part number', item.partNumber ?? '', 'part_number'),
  ItemDetailField('Category', item.category, 'category'),
  ItemDetailField('Location', item.location, shared ? null : 'location'),
  ItemDetailField('Quantity', '${item.quantity}', 'quantity'),
  if (canEdit || (item.brand?.isNotEmpty ?? false))
    ItemDetailField('Brand', item.brand ?? '', 'brand'),
  if (canEdit || (item.barcode?.isNotEmpty ?? false))
    ItemDetailField('Barcode', item.barcode ?? '', 'barcode'),
  if (canEdit || (item.subcategory?.isNotEmpty ?? false))
    ItemDetailField('Subcategory', item.subcategory ?? '', 'subcategory'),
  ItemDetailField('Date added', itemDetailDate(item.createdAt)),
  if (canEdit || (item.tags?.isNotEmpty ?? false))
    ItemDetailField('Tags', item.tags?.join(', ') ?? '', 'tags'),
  if (item.confidence != null)
    ItemDetailField(
      'AI confidence',
      '${(item.confidence! * 100).toStringAsFixed(0)}%',
    ),
];

String itemDetailDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
