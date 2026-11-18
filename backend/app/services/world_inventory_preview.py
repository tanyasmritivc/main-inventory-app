"""Keep inventory facts readable within the shared model-data size/depth limits.

Full records remain in server-side receipts. Photo/scan provenance and nested
spreadsheet metadata must not crowd names, quantities and descriptions out of a
simple search result. Imported scalar fields are flattened, never interpreted.
"""

CORE = ('item_id', 'inventory_id', 'name', 'quantity', 'location', 'space_name',
        'part_number', 'brand', '_match_basis')


def inventory_preview(result):
    if not isinstance(result, dict) or not isinstance(result.get('items'), list):
        return result
    rows = result['items'][:20]
    links = {(link.get('inventory_id'), link.get('id')): link.get('href')
             for link in result.get('resource_links', []) if link.get('kind') == 'item'}
    items, details = [], []
    for row in rows:
        if not isinstance(row, dict):
            continue
        item = {key: row[key] for key in CORE if key in row}
        href = links.get((row.get('inventory_id'), row.get('item_id')))
        if href:
            item['href'] = href
        imported = row.get('import_data') or {}
        fields = imported.get('fields', []) if isinstance(imported, dict) else []
        fields = [f for f in fields if isinstance(f, dict)
                  and isinstance(f.get('name'), str)
                  and (f.get('value') is None or isinstance(f.get('value'), (str, int, float, bool)))]
        description = row.get('description') or next((f['value'] for f in fields
            if f['name'].strip().casefold() in ('description', 'item description', 'part description')
            and f.get('value')), None)
        if description:
            item['description'] = description
        items.append(item)
        detail = {key: row[key] for key in ('item_id', 'category', 'subcategory',
                  'notes', 'tags', 'reorder_enabled', 'reorder_threshold',
                  'reorder_quantity', 'barcode', 'purchase_source', 'unit_price',
                  'currency', 'expires_on', 'inventory_role', 'created_at',
                  'updated_at', 'space_id', 'inventory_name', 'workspace_name') if key in row}
        if fields:
            detail['imported_fields'] = fields[:20]
        details.append(detail)
    # Essential rows precede optional detail. The provider boundary still strips
    # private fields/URLs and enforces its shared budget. Do not falsely claim a
    # full result when either the repository or this presentation caps the rows.
    return {**{k: v for k, v in result.items() if k not in (
                'items', 'resource_links', 'inventories', 'spaces')},
            'preview_truncated': len(result['items']) > len(items),
            'preview_note': 'Answer from these matching records. Details may be abbreviated; '
                'do not repeatedly query individual variants just to fill a broad inventory table. '
                'A complete count does not mean every row is displayed.',
            'items': items, 'item_details': details,
            **{k: result[k] for k in ('inventories', 'spaces') if k in result}}
