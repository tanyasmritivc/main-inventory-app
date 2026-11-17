"""Compare immutable design requirements, never historical stock allocations."""
from collections import defaultdict
from fastapi import HTTPException
from . import projects


def changes(before, after):
    def aggregate(comparison):
        rows = defaultdict(lambda: {'required': 0, 'names': set(), 'review': False})
        for line in comparison['items']:
            # A name is not an engineering identity. Without a manufacturer and
            # explicit part number, preserve the definition key and require review.
            manufacturer = line.get('manufacturer', '').strip().casefold()
            part = line.get('part_number', '').strip().casefold()
            identified = bool(manufacturer and part)
            key = ('part', manufacturer, part, line['procurement_policy']) if identified else (
                'definition', line['key'], line['name'], line['procurement_policy'])
            row = rows[key]
            row['required'] += line['required']
            row['names'].add(line['name'])
            row['review'] |= not identified or line['status'] == 'needs_review'
        return rows
    old, new = aggregate(before), aggregate(after)
    result = []
    for key in sorted(old.keys() | new.keys()):
        a, b = old.get(key), new.get(key)
        previous, current = a['required'] if a else 0, b['required'] if b else 0
        if previous == current:
            continue
        result.append({'name': ' / '.join(sorted((b or a)['names'])),
            'before': previous, 'after': current, 'delta': current - previous,
            'change': 'added' if a is None else 'removed' if b is None else 'quantity',
            'needs_review': bool((a and a['review']) or (b and b['review']))})
    return result


def compare(inventory, actor, before_id, after_id):
    before = projects.version(inventory, actor, before_id)
    after = projects.version(inventory, actor, after_id)
    if before['project_id'] != after['project_id']:
        raise HTTPException(422, 'Choose two versions of the same CAD project.')
    return {'inventory_id': inventory, 'before_id': before_id, 'after_id': after_id,
        'changes': changes(before['comparison'], after['comparison']),
        'basis': 'saved_design_requirements_not_current_stock'}
