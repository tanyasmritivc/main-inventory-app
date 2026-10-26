"""Reviewed photo links to existing stock. A name suggestion is never a write."""
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from difflib import SequenceMatcher
import re
from uuid import UUID, uuid4, uuid5, NAMESPACE_URL
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field
from app.services.supabase_client import get_supabase_admin, get_supabase_raw


class PhotoTarget(BaseModel):
    model_config = ConfigDict(extra='forbid')
    query: str = Field(min_length=1, max_length=200)
    inventory_id: str | None = None


def normalized(value):
    return ' '.join(re.findall(r'\w+', str(value or '').casefold()))


def rank(query, item):
    query = normalized(query)
    if not query:
        return 0
    values = [normalized(item.get(k)) for k in ('name', 'part_number', 'barcode')]
    if query in values:
        return 1.0
    scores = []
    for value in values:
        if not value:
            continue
        scores.append(SequenceMatcher(None, query, value).ratio())
        # A part name within a longer saved label remains a suggestion, not an
        # exact identity. Digits are retained: different model numbers need review.
        if len(query) >= 3 and query in value:
            scores.append(.9)
        words = value.split()
        count = len(query.split())
        scores.extend(SequenceMatcher(None, query, ' '.join(words[i:i+count])).ratio() * .95
                      for i in range(max(0, len(words)-count+1)))
    return max(scores, default=0)


def propose(actor, key, args):
    from app.services import world_chat as world
    from app.services.ai_agent import _current_items
    from app.services.chat_item_actions import photo_observations
    from app.services.item_photos import _storage_path
    parsed = PhotoTarget.model_validate(args, strict=True)
    photo = photo_observations.get()
    if not photo or not _storage_path(user_id=actor, image_url=photo.get('source_url', '')):
        raise HTTPException(422, 'Attach a photo in this chat first.')
    inventories = ([world.inventory_scope(actor, key, parsed.inventory_id)] if parsed.inventory_id
                   else world.directory(actor, key)['inventories'])
    matches = []
    for choice in inventories:
        with world.in_inventory(actor, key, choice['inventory_id']) as inv:
            if not inv['can_edit']:
                continue
            for item in _current_items(user_id=inv['owner_user_id'], q=''):
                score = rank(parsed.query, item)
                if score < .68:
                    continue
                matches.append({'item_id': item['item_id'], 'inventory_id': inv['inventory_id'],
                    'name': item['name'], 'location': item.get('location') or 'Unsorted',
                    'inventory_name': inv['name'], 'workspace_name': inv['workspace']['name'],
                    'match': 'exact' if score == 1 else 'similar', '_score': score})
    matches.sort(key=lambda row: (-row['_score'], row['name'], row['inventory_id'], row['item_id']))
    # Duplicate exact names across locations must all stay selectable.
    if any(row['_score'] == 1 for row in matches):
        matches = [row for row in matches if row['_score'] == 1]
    if not matches:
        return {'matched': False, 'next_step': 'No close saved item was found. Ask for the saved name, part number or location. Do not create an item.'}
    return {'photo_attachment': {'version': 1, 'id': str(uuid4()), 'revision': 1,
        'status': 'pending', 'query': parsed.query, 'source_url': photo['source_url'],
        'expires_at': (datetime.now(timezone.utc)+timedelta(minutes=30)).isoformat(),
        'choices': [{k: v for k,v in row.items() if k != '_score'} for row in matches[:5]],
        'more_matches': len(matches) > 5},
        'saved': False, 'next_step': 'Ask Did you mean for similar names or which location for duplicate names. The user must choose the exact item and tap Attach photo in the card. No quantity changes or new records.'}


def load(actor, key, cid, attachment_id):
    from app.services import world_chat as world
    world.conversation(actor, key, cid)
    rows = (get_supabase_raw().table('messages').select('id,answer_context')
            .eq('conversation_id', cid).eq('answer_context->photo_attachment->>id', attachment_id)
            .limit(1).execute().data or [])
    if not rows:
        raise HTTPException(404, 'This photo request is no longer available in this chat.')
    return rows[0]


def replace(cid, row, card):
    old = row['answer_context']['photo_attachment']
    result = (get_supabase_raw().table('messages')
              .update({'answer_context': {**row['answer_context'], 'photo_attachment': card}})
              .eq('id', row['id']).eq('conversation_id', cid)
              .eq('answer_context->photo_attachment->>revision', str(old['revision']))
              .eq('answer_context->photo_attachment->>status', old['status']).execute().data)
    if not result:
        raise HTTPException(409, 'This photo request changed. Refresh it and try again.')
    return card


def _link(actor, inv, card, target):
    from app.services.item_photos import _get_item, _photo_events, _photos_for_item, _storage_path, MAX_ITEM_PHOTOS
    from app.services.items_repo import invalidate_inventory_cache
    owner = inv['owner_user_id']
    source = card['source_url']
    if not _storage_path(user_id=actor, image_url=source):
        raise HTTPException(422, 'This chat photo is unavailable. Attach it again.')
    client = get_supabase_admin()
    item = _get_item(user_id=owner, item_id=target['item_id'])
    # Freeze identity/location at confirmation; retries after a committed photo
    # use its durable receipt even if the item is subsequently renamed.
    event_id = str(uuid5(NAMESPACE_URL, 'findez:chat-photo:' + card['id']))
    def receipt():
        rows = (client.table('item_events').select('event_id,image_url').eq('user_id', owner)
                .eq('item_id', target['item_id']).eq('event_id', event_id).limit(1).execute().data or [])
        return any(row.get('image_url') == source for row in rows)
    if not receipt():
        if item['name'] != target['name'] or (item.get('location') or 'Unsorted') != target['location']:
            raise HTTPException(409, 'This item changed. Ask again to choose its current name and location.')
        photos = _photos_for_item(item=item, events=_photo_events(user_id=owner, item_id=target['item_id']))
        if not any(p['image_url'] == source for p in photos):
            if len(photos) >= MAX_ITEM_PHOTOS:
                raise HTTPException(409, f'This item already has {MAX_ITEM_PHOTOS} photos. Remove a photo before adding another.')
            try:
                client.table('item_events').insert({'event_id': event_id, 'item_id': target['item_id'],
                    'user_id': owner, 'event_type': 'photo', 'content': 'Added from chat',
                    'image_url': source, 'created_at': datetime.now(timezone.utc).isoformat()}).execute()
            except Exception:
                if not receipt():
                    raise HTTPException(503, 'The photo could not be confirmed. Retry this same request safely.') from None
            if not receipt():
                raise HTTPException(503, 'The photo could not be confirmed. Retry this same request safely.')
    # Only fill an empty primary. Another editor's primary photo is preserved.
    for empty in (None, ''):
        query = client.table('items').update({'image_url': source}).eq('user_id', owner).eq('item_id', target['item_id'])
        query = query.is_('image_url', 'null') if empty is None else query.eq('image_url', '')
        query.execute()
    item = _get_item(user_id=owner, item_id=target['item_id'])
    if not item.get('image_url'):
        raise HTTPException(503, 'The photo is in the gallery. Retry to finish setting the item preview.')
    invalidate_inventory_cache(owner)
    return {'item_id': target['item_id'], 'inventory_id': inv['inventory_id'], 'name': item['name'],
            'location': item.get('location') or 'Unsorted', 'photo_added': True,
            'primary': item.get('image_url') == source}


def decide(actor, key, cid, attachment_id, decision, inventory_id=None, item_id=None):
    from app.services import world_chat as world
    row = load(actor, key, cid, attachment_id)
    card = deepcopy(row['answer_context']['photo_attachment'])
    if card['status'] in ('confirmed', 'cancelled'):
        return card
    if decision == 'cancel':
        if card['status'] != 'pending':
            raise HTTPException(409, 'Saving already started. Retry to check the result.')
        card.update(status='cancelled', revision=card['revision']+1)
        return replace(cid, row, card)
    target = next((c for c in card['choices'] if c['item_id'] == item_id and c['inventory_id'] == inventory_id), None)
    if not target or (card.get('selected') and card['selected'] != target):
        raise HTTPException(409, 'Choose one of the displayed items. A saving request cannot change targets.')
    if card['status'] == 'pending' and datetime.fromisoformat(card['expires_at']) < datetime.now(timezone.utc):
        raise HTTPException(409, 'This photo request expired. Ask again for a fresh match.')
    with world.in_inventory(actor, key, inventory_id) as inv:
        if not inv['can_edit']:
            raise HTTPException(403, 'You no longer have permission to add a photo to this item.')
        if card['status'] == 'pending':
            card.update(status='saving', selected=target, revision=card['revision']+1)
            replace(cid, row, card)
            row = {**row, 'answer_context': {**row['answer_context'], 'photo_attachment': deepcopy(card)}}
        result = _link(actor, inv, card, target)
        card.update(status='confirmed', receipt=result, revision=card['revision']+1)
        try:
            return replace(cid, row, card)
        except HTTPException:
            latest = load(actor, key, cid, attachment_id)['answer_context']['photo_attachment']
            if latest['status'] == 'confirmed':
                return latest
            raise
