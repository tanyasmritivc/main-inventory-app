"""Pure scoring. Counts/locations are never reconstructed from these signals."""
from datetime import datetime, timezone
import math

HALF_LIFE_DAYS = 14.0
WEIGHTS = {
    'inventory.item_viewed': .25, 'inventory.search_succeeded': 1.0,
    'inventory.item_created': 3.0, 'inventory.item_updated': 2.0,
    'inventory.item_moved': 3.0, 'inventory.quantity_changed': 3.0,
    'inventory.item_consumed': 4.0, 'scan.review_completed': 3.0,
}


def interest_scores(events, now=None, *, half_life_days=HALF_LIFE_DAYS, weights=None):
    now = now or datetime.now(timezone.utc)
    weights = weights or WEIGHTS
    scores = {}
    for event in events:
        if event.get('entity_type') != 'item' or not event.get('entity_id'):
            continue
        try:
            at = datetime.fromisoformat(str(event['occurred_at']).replace('Z', '+00:00'))
            if at.tzinfo is None or at > now:
                continue
            days = (now-at).total_seconds()/86400
            if days > 90: continue
            # Only completed backend operations are learned; device telemetry is not inventory evidence.
            confidence = 1.0 if event.get('source') == 'database' else .7 if event.get('source') == 'search' else 0
            value = weights.get(event.get('event_type'), 0)*math.pow(.5, days/max(1, half_life_days))*confidence
            key = str(event['entity_id'])
            scores[key] = min(20.0, scores.get(key, 0)+value)
        except (ValueError, TypeError, KeyError):
            continue
    return scores


def rank_rows(rows, query, aliases, scores):
    """Evidence class first, behavior only breaks ties. Never auto-select a mutation."""
    from app.services.item_search import score_item, normalize, match_basis
    alias_targets = {str(a['item_id']) for a in aliases if a.get('confirmed_at')
                     and normalize(str(a.get('alias', ''))).strip() == normalize(query).strip()}
    # Conflicting imported/legacy aliases cannot be promoted into a target.
    if len(alias_targets) != 1: alias_targets = set()
    ranked = []
    for row in rows:
        score = score_item(row, query)
        alias = str(row.get('item_id')) in alias_targets
        evidence = max(score, 500 if alias else 0)
        if not evidence: continue
        reason = 'confirmed alias' if alias and evidence == 500 else match_basis(evidence)
        ranked.append((evidence, min(20, scores.get(str(row.get('item_id')), 0)), {**row, '_match_basis': reason}))
    buckets = {}
    for evidence, behavior, _ in ranked:
        count, active = buckets.get(evidence, (0, False))
        buckets[evidence] = (count+1, active or behavior>0)
    for evidence, _, row in ranked:
        count, active = buckets[evidence]
        if count>1 and active:
            row['_personalization_tiebreak'] = True
    ranked.sort(key=lambda r: (r[0], r[1]), reverse=True)
    return [r[2] for r in ranked]


def notification_score(category, *, dismissals=0, completed=0):
    """Useful completion has small influence; opens and silence have none."""
    base = {'low_stock': 90, 'scan_review': 65}.get(category, 0)
    return max(0, min(100, base-min(3, dismissals)*15+min(2, completed)*2))


def clear_reference(question, references, *, actor, conversation, now=None):
    """Return only an unambiguous short-lived ID to look up, never a stock fact."""
    import re
    now = now or datetime.now(timezone.utc)
    if not re.search(r'\b(that|it|more|same|other one)\b', question.casefold()): return None
    valid = set()
    for r in references:
        try:
            stamp = datetime.fromisoformat(str(r['observed_at']).replace('Z', '+00:00'))
            if r['user_id'] == actor and r['conversation_id'] == conversation and 0 <= (now-stamp).total_seconds() <= 900:
                valid.add((r['inventory_id'], r['item_id']))
        except (KeyError, TypeError, ValueError): pass
    return {'inventory_id': next(iter(valid))[0], 'item_id': next(iter(valid))[1], 'requires_fresh_lookup': True} if len(valid)==1 else None


def require_clear_mutation_target(message, target, results):
    """A behavioral tie-break is display ranking, never mutation authority."""
    import re
    for result in reversed(results):
        rows = result.get('items', [])
        selected = next((r for r in rows if r.get('item_id') == target), None)
        if not selected: continue
        if not selected.get('_personalization_tiebreak'): return
        # An exact, unambiguous name explicitly present in the current request is sufficient.
        named = [r for r in rows if r.get('name') and re.search(
            r'(?<!\w)' + re.escape(str(r['name'])) + r'(?!\w)', message, re.I)]
        if len(named)==1 and named[0].get('item_id')==target: return
        raise ValueError('Several items match. Ask which item before changing anything; recent activity is not a selection.')
