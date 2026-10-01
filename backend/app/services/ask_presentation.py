"""Public Ask evidence, derived only from access-scoped reads, never generated text."""

from datetime import datetime, timezone


def _text(value: object, limit: int = 200) -> str:
    return ' '.join(str(value or '').split())[:limit]


def _count(value: object) -> int:
    try:
        return max(0, int(value))
    except (ValueError, TypeError, OverflowError):
        return 0


def project_answer_context(detail: dict) -> dict:
    rows = []
    for item in (detail.get('items') or [])[:100]:
        required = _count(item.get('required_quantity'))
        available = _count(item.get('available_quantity'))
        rows.append({
            'id': _text(item.get('id')),
            'name': _text(item.get('name')) or 'Unnamed part',
            'available_quantity': available,
            'required_quantity': required,
            'status': 'have' if available >= required else ('low' if available else 'missing'),
        })
    return {
        'sources': [{
            'kind': 'project',
            'label': _text(detail.get('name')) or 'Project requirements',
            'detail': 'Project requirements and current inventory, including reservations',
        }, {
            'kind': 'inventory',
            'label': _text(detail.get('location')) or 'Project inventory',
            'detail': 'Available stock after reservations for other projects',
        }],
        'rows': rows,
        'rows_truncated': len(detail.get('items') or []) > len(rows),
        'checked_at': datetime.now(timezone.utc).isoformat(),
    }


def project_answer_text(detail: dict) -> str:
    items = detail.get('items') or []
    if not items:
        return 'This project has no requirements yet. Add its parts list to check what you need.'
    ready = sum(_count(row.get('available_quantity')) >= _count(row.get('required_quantity')) for row in items)
    missing = [row for row in items if _count(row.get('available_quantity')) < _count(row.get('required_quantity'))]
    intro = f'You have enough stock for {ready} of the {len(items)} required parts.'
    if not missing:
        return f'{intro} Everything on this parts list is available.'
    shortages = '; '.join(
        f"{_text(row.get('name'))}: {_count(row.get('available_quantity'))} of {_count(row.get('required_quantity'))} available"
        for row in missing[:5]
    )
    remaining = f' There are {len(missing) - 5} more shortages in the list.' if len(missing) > 5 else ''
    return f'{intro} You still need {shortages}.{remaining}'


def answer_context_from_reads(context: dict, tool_trace: list[dict]) -> dict:
    sources: list[dict] = []
    rows: list[dict] = []
    seen_sources: set[tuple[str, str]] = set()
    seen_items: set[str] = set()

    def source(kind: str, label: str, detail: str) -> None:
        key = (kind, label)
        if key not in seen_sources:
            seen_sources.add(key)
            sources.append({'kind': kind, 'label': label, 'detail': detail})

    def inventory(items: list[dict], *, show_rows: bool) -> None:
        if items:
            source('inventory', 'Inventory', f'{len(items)} matching item records checked')
        for item in items:
            if not isinstance(item, dict):
                continue
            item_id = _text(item.get('item_id'))
            if not show_rows or not item_id or item_id in seen_items:
                continue
            seen_items.add(item_id)
            rows.append({
                'id': item_id,
                'name': _text(item.get('name')) or 'Unnamed item',
                'available_quantity': _count(item.get('quantity')),
                'location': _text(item.get('space_name') or item.get('location')),
            })

    # These are the bounded records actually supplied to the assistant, not all
    # records in the account. Metadata is not claimed to be full document text.
    inventory(context.get('inventory_preview') or [], show_rows=False)
    inventory(context.get('shared_inventory_preview') or [], show_rows=False)
    for doc in context.get('documents_preview') or []:
        if isinstance(doc, dict):
            source('document', _text(doc.get('display_name') or doc.get('filename')) or 'Document details', 'Document details supplied to this answer')
    if context.get('recent_activity_preview'):
        source('history', 'Recent activity', 'Recent activity records supplied to this answer')

    for entry in tool_trace:
        if not isinstance(entry, dict):
            continue
        result = entry.get('result')
        if isinstance(result, dict) and (result.get('error') or result.get('success') is False):
            continue
        tool = entry.get('tool')
        if tool == 'project_kit_readiness' and isinstance(result, dict):
            return project_answer_context(result)
        if tool == 'inventory_knowledge_search' and isinstance(result, dict):
            inventory(result.get('personal_items') or [], show_rows=True)
            inventory(result.get('shared_and_joined_items') or [], show_rows=True)
            for kit in result.get('project_kits') or []:
                source('project', _text(kit.get('name')) or 'Project kit', 'Project requirements and location checked')
            if result.get('spaces'):
                source('spaces', 'Spaces', 'Accessible inventory locations checked')
        elif tool == 'inventory_search' and isinstance(result, list):
            inventory(result, show_rows=True)
            if not result:
                source('inventory', 'Inventory', 'No matching items found')
        elif tool == 'inventory_recall' and isinstance(result, dict):
            source('history', 'Item history', f"{len(result.get('events') or [])} item events checked")
        elif tool == 'documents_list' and isinstance(result, list):
            for doc in result:
                if isinstance(doc, dict):
                    source('document', _text(doc.get('display_name') or doc.get('filename')) or 'Document details', 'Document details checked')
    return {
        'sources': sources[:20],
        'rows': rows[:100],
        'rows_truncated': len(rows) > 100,
        'checked_at': datetime.now(timezone.utc).isoformat(),
    }
