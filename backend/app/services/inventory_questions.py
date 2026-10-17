"""Small deterministic read capabilities over existing authorized memory services.

No model output or conversation prose is accepted as inventory evidence. This
path handles selected inventories; legacy unscoped callers keep their old path.
"""
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from difflib import SequenceMatcher
import logging
import re
import time

from app.services.ask_presentation import recorded_quantity
from app.services.inventory_scope import current_inventory
from app.services.items_repo import search_memory_candidates
from app.services.documents_repo import list_documents
from app.services.item_events_repo import get_events_for_item
from app.services.supabase_client import get_supabase_admin
from app.services.assistant_tool_safety import mutation_requested

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class Capability:
    purpose: str
    source: str
    arguments: tuple[str, ...] = ('query', 'filters')
    permission: str = 'current authorized inventory viewer'
    read_only: bool = True
    confirmation_required: bool = False
    ambiguity: str = 'show alternatives; clarify before selecting a single record'
    empty: str = 'no matching saved record; not proof of physical absence'


# Question families are registered here. Caller-tool schemas remain in ai_agent.
CAPABILITIES = {
    'item.find': Capability('Find saved items and recorded locations', 'items'),
    'inventory.count': Capability('Count records and known physical units', 'items.quantity'),
    'item.history': Capability('Read persisted item events', 'items + item_events'),
    'item.documents': Capability('Find linked document metadata, not document contents', 'items + documents'),
    'item.evidence': Capability('Explain the current saved fields supporting a result', 'items'),
    'memory.unsupported': Capability('Explain absent structured capabilities honestly', 'capability limits'),
    'action.editor_handoff': Capability('Hand off changes needing receipts or confirmation', 'existing Capture and item editors'),
}


@dataclass
class Question:
    capability: str
    terms: list[str] = field(default_factory=list)
    filters: dict = field(default_factory=dict)
    reference: bool = False
    all_matches: bool = False
    reason: str = ''
    clarification: bool = False


def _tokens(text: str) -> list[str]:
    return re.findall(r'[a-z0-9]+(?:[.-][a-z0-9]+)*', text.casefold())


def _word(word: str) -> str:
    aliases = {'adaptor': 'adapter', 'chargers': 'charger', 'charging': 'charger',
               'batteries': 'battery', 'shelves': 'shelf', 'little': 'small'}
    return aliases.get(word, word[:-1] if len(word) > 3 and word.endswith('s')
                       and not word.endswith(('ss', 'us')) else word)


_STOP = set('a an the my our i we me you do does did have has own owns is are was were '
            'where what which how many much can could would please find locate search '
            'look looking for show list tell about already another all matching saved '
            'record recorded records item items everything anything something of that '
            'this it one ones those these put keep kept remember name called named '
            'in at inside from by with to only on and'.split())


def interpret(message: str) -> Question | None:
    text = ' '.join(message.casefold().split())
    if mutation_requested(text) and (re.search(r'\b(add|delete|remove|create|increase|decrease|restock|log)\b', text)
                                     or re.search(r'\b(quantity|stock|count)\b', text)):
        return Question('action.editor_handoff', reason='No inventory change was made. Use Capture to confirm additions, or the item and Space editors to review quantities, locations and deletions. Chat does not have safe retry receipts for these operations.')
    # Never intercept commands, questions about proposed commands, or project
    # readiness. Existing routes handle these; no read capability writes data.
    if re.search(r'\b(add|delete|remove|update|change|set|move|rename|create|increase|decrease|use|used)\b', text):
        if not re.search(r'\b(last move|last moved|history|when.*move)\b', text):
            return None
    if re.search(r'\b(project|kit|kits)\b', text):
        return None
    limits = (
        (r'\bremind me\b', 'I cannot create reminders from this chat. No reminder has been scheduled.'),
        (r'\blive tracking\b', 'I cannot see or track your physical surroundings. I can retrieve an item\'s recorded location.'),
        (r'\b(compatible|compatibility|goes with|belong to)\b', 'I cannot verify compatibility or a relationship without an explicit supporting record. Matching names do not prove that items work or belong together.'),
        (r'\b(pay|paid|price|cost|buy|bought|purchase date|warranty period)\b', 'I cannot establish that from the structured records available to this chat. A purchase price, purchase date or warranty period needs an explicit supporting document; a filename or item creation date does not prove it.'),
    )
    for pattern, reason in limits:
        if re.search(pattern, text):
            return Question('memory.unsupported', reason=reason)
    reference = bool(re.search(r'\b(it|this|that|one|those|these|the other one|all matching|why did you choose|why this result|smaller one)\b', text))
    if re.search(r'\b(smaller one|the other one)\b', text):
        return Question('memory.unsupported', reason='Which saved item do you mean? Please give its name or recorded location; I cannot infer its size or which alternative you chose.')
    kind = 'item.find'
    if re.search(r'\b(manuals?|receipts?|warranty|warranties|documents?)\b', text):
        kind = 'item.documents'
    elif re.search(r'\b(history|last moved|last move|what did i say|what did we say|what happened|notes? about)\b', text):
        kind = 'item.history'
    elif re.search(r'\b(how many|how much|number of|total|count)\b', text):
        kind = 'inventory.count'
    elif re.search(r'\b(why did you choose|why this result|evidence)\b', text):
        kind = 'item.evidence'
    elif not re.search(r'^(where|find|locate|search|look for|show|list|do i|do we|does|is there|what.*(in|own|have)|tell me about|i can.t remember)', text):
        return None
    filters = {}
    date_filter = re.search(r'\b(?:added\s+)?(since|after|before)\s+(\d{4}-\d{2}-\d{2})\b', text)
    if date_filter:
        try:
            date.fromisoformat(date_filter.group(2))
        except ValueError:
            return Question('memory.unsupported', reason='Please give a valid recorded creation date in YYYY-MM-DD format.')
        filters['created'] = [date_filter.group(1), date_filter.group(2)]
        text = text[:date_filter.start()] + text[date_filter.end():]
    elif re.search(r'\b(today|yesterday|recently|last week|last month|status|condition|maintenance|calibration)\b', text):
        return Question('memory.unsupported', reason='I cannot verify that filter in this read path. Use a saved name, location, category, brand, quantity, or an explicit creation date such as after 2026-10-01. A record date does not prove condition or a physical sighting.')
    # Supported filters have real backing fields. Delimiters keep following
    # filters out of the preceding value, e.g. "in Garage with brand Acme".
    pattern = r'\b(?:in(?:side)?|at|category|brand)\s+(?:my |the )?(.+?)(?=\s+(?:in|at|category|brand|with brand|with category|with quantity|quantity)\b|$)'
    for match in list(re.finditer(pattern, text)):
        keyword = text[match.start():match.start(1)].split()[0]
        field_name = {'in': 'location', 'inside': 'location', 'at': 'location',
                      'category': 'category', 'brand': 'brand'}[keyword]
        filters[field_name] = match.group(1).strip(' ?.,"\'')
    quantity = re.search(r'\b(?:quantity|stock)\s*(below|under|above|over|at least|at most|exactly|=|<|>)\s*(\d+)\b', text)
    if quantity:
        filters['quantity'] = [quantity.group(1), int(quantity.group(2))]
        text = text[:quantity.start()] + text[quantity.end():]
    missing = re.search(r'\b(?:no|missing|without|unknown|unconfirmed) (location|image|category|quantity)\b', text)
    if missing:
        if 'unconfirmed' in missing.group():
            return Question('memory.unsupported', reason='This chat has recorded locations, but no physical confirmation status. I cannot identify which locations are currently confirmed.')
        filters['missing'] = missing.group(1)
        text = text.replace(missing.group(), '')
    for value in filters.values():
        if isinstance(value, str):
            text = text.replace(value, '')
    if kind == 'item.documents':
        text = re.sub(r'\b(manuals?|receipts?|warrant(?:y|ies)|documents?|read|summarize)\b', '', text)
    if kind == 'item.history':
        text = re.sub(r'\b(history|last|moved?|when|happened|say|said|notes?|events?)\b', '', text)
    if kind == 'item.evidence' or reference:
        text = re.sub(r'\b(why|choose|chose|result|evidence|matching)\b', '', text)
    text = re.sub(r"i can.t remember (?:its|the) name[, ]*(?:but)?", '', text)
    text = re.sub(r'\b(number of|total|count|inventory|brand|category|quantity|stock|below|above|under|over|at least|at most|exactly|barcode|identifier|part number)\b', '', text)
    terms = list(dict.fromkeys(_word(t) for t in _tokens(text) if t not in _STOP))
    if not terms and not filters and not reference and not re.search(r'\b(inventory|items|records|everything|own)\b', message, re.I):
        return Question(kind, reason='Which saved item or location do you mean? Please give its name or identifier.', clarification=True)
    if not terms and not filters and any(c.isalpha() and ord(c) > 127 for c in text):
        return Question(kind, reason='I could not interpret that saved name safely. Please give its saved identifier or recorded location.', clarification=True)
    return Question(kind, terms[:12], filters, reference and not terms, 'all matching' in message.casefold())


_FIELDS = ('name', 'part_number', 'barcode', 'brand', 'category', 'subcategory', 'notes', 'location')


def match_item(row: dict, terms: list[str]) -> str | None:
    words = {_word(t) for field_name in _FIELDS for t in _tokens(str(row.get(field_name) or ''))}
    likely = False
    for term in terms:
        if term in words:
            continue
        if not any(c.isdigit() for c in term) and any(word.startswith(term) for word in words if len(term) >= 3):
            likely = True
        elif len(term) >= 4 and not any(c.isdigit() for c in term) and any(
            SequenceMatcher(None, term, word).ratio() >= .8 for word in words if len(word) >= 4
        ):
            likely = True
        else:
            return None
    return 'likely text match' if likely else 'saved field match'


def _filter(row: dict, filters: dict) -> bool:
    for key, value in filters.items():
        if key in ('location', 'category', 'brand'):
            if not all(_word(token) in {_word(t) for t in _tokens(str(row.get(key) or ''))}
                       for token in _tokens(value)):
                return False
        elif key == 'missing':
            field_name = 'image_url' if value == 'image' else value
            if (recorded_quantity(row.get(field_name)) is not None if value == 'quantity'
                    else bool(str(row.get(field_name) or '').strip())):
                return False
        elif key == 'quantity':
            quantity = recorded_quantity(row.get('quantity'))
            op, n = value
            if quantity is None or not {'below': quantity < n, 'under': quantity < n, '<': quantity < n,
                                      'above': quantity > n, 'over': quantity > n, '>': quantity > n,
                                      'at least': quantity >= n, 'at most': quantity <= n,
                                      'exactly': quantity == n, '=': quantity == n}[op]:
                return False
        elif key == 'created':
            try:
                created = date.fromisoformat(str(row.get('created_at') or '')[:10])
                boundary = date.fromisoformat(value[1])
            except ValueError:
                return False
            if not {'since': created >= boundary, 'after': created > boundary,
                    'before': created < boundary}[value[0]]:
                return False
    return True


def _references(user_id: str, conversation_id: str | None) -> list[str]:
    if not conversation_id:
        return []
    client = get_supabase_admin()
    owned = client.table('conversations').select('id').eq('id', conversation_id).eq('user_id', user_id).limit(1).execute().data
    if not owned:
        return []
    messages = client.table('messages').select('answer_context').eq('conversation_id', conversation_id).eq('role', 'assistant').order('created_at', desc=True).limit(5).execute().data or []
    for message in messages:
        context = message.get('answer_context') or {}
        if not isinstance(context, dict):
            continue
        rows = context.get('rows') or []
        ids = [r['id'] for r in rows if isinstance(r, dict) and isinstance(r.get('id'), str)]
        if ids:
            return ids[:100]
    return []


def _text(value: object, length: int = 160) -> str:
    # Saved values are data, never Markdown instructions or external URLs.
    text = re.sub(r'https?://\S+', '[saved link]', str(value or ''))
    return re.sub(r'[\x00-\x1f`*\[\]<>]', ' ', text).strip()[:length]


def answer_question(*, user_id: str, message: str, conversation_id: str | None = None) -> dict | None:
    scope = current_inventory.get()
    if scope is None:
        return None
    question = interpret(message)
    if question is None:
        return None
    started = time.perf_counter()
    status, items, sources = 'supported', [], []
    truncated = False
    try:
        if question.reason:
            status, answer = ('ambiguous' if question.clarification else 'unsupported'), question.reason
        else:
            ids = _references(user_id, conversation_id) if question.reference else None
            if question.reference and not ids:
                status, answer = 'ambiguous', 'Which saved item do you mean? Please give its name or recorded location.'
            else:
                # Prefix candidates permit conservative typo matching without a
                # full inventory fetch. Identifiers are never fuzzy matched.
                candidates = list(question.terms)
                candidates += [t[:3] for t in question.terms if len(t) >= 4 and not any(c.isdigit() for c in t)]
                for key in ('location', 'brand', 'category'):
                    candidates += _tokens(question.filters.get(key, ''))
                if ids is not None:
                    result = get_supabase_admin().table('items').select('*').eq('user_id', user_id).in_('item_id', ids).limit(101).execute()
                    data = {'items': result.data or [], 'truncated': False}
                else:
                    data = search_memory_candidates(user_id=user_id, terms=candidates)
                truncated = data['truncated']
                for row in data['items']:
                    basis = match_item(row, question.terms)
                    if basis and _filter(row, question.filters):
                        items.append({**row, '_match_basis': basis})
                # Multiple observations remain separate, even with equal names.
                items.sort(key=lambda r: (r['_match_basis'] != 'saved field match', str(r.get('name')), str(r.get('item_id'))))
                if question.reference and len(items) != 1 and not question.all_matches:
                    status, answer = 'ambiguous', 'Which saved item do you mean? ' + '; '.join(_text(i.get('name')) for i in items[:5])
                    if not items:
                        answer = 'That result is no longer accessible here. Please name an item in the current inventory.'
                elif not items:
                    status = 'incomplete' if truncated else 'empty'
                    answer = ('I could not find a matching saved record in the records checked. '
                              'This does not establish that the physical item is absent.')
                else:
                    answer, status, sources = _answer(question, items, user_id, truncated)
                    if len(items) > 1 and re.search(r'^where is\b', message, re.I):
                        status = 'ambiguous'
                        answer += '\nSeveral saved records match. Which name and recorded location do you mean?'
        rows = [{'id': _text(i.get('item_id')), 'name': _text(i.get('name')),
                 'available_quantity': recorded_quantity(i.get('quantity')),
                 'location': _text(i.get('location')), 'match_basis': i['_match_basis']} for i in items[:100]]
        if items:
            sources.insert(0, {'kind': 'inventory', 'label': 'Saved inventory records',
                               'detail': 'Saved fields matched your question. Recorded locations are not a physical confirmation.'})
        result = {'tool': None, 'result': None, 'assistant_message': answer,
                  'answer_context': {'sources': sources[:20], 'rows': rows,
                                     'rows_truncated': truncated or len(items) > 100,
                                     'checked_at': datetime.now(timezone.utc).isoformat()},
                  'capability': question.capability, 'capability_state': status}
    except Exception:
        # No exception, record, user identifier or query is logged or sent to a provider.
        status = 'unavailable'
        result = {'tool': None, 'result': None,
                  'assistant_message': 'I could not verify your saved records right now. Please try again.',
                  'answer_context': None, 'capability': question.capability, 'capability_state': status}
    logger.info('ask_read capability=%s state=%s elapsed_ms=%.2f records=%d',
                question.capability, status, (time.perf_counter() - started) * 1000, len(items))
    return result


def _answer(question: Question, items: list[dict], user_id: str, truncated: bool) -> tuple[str, str, list]:
    sources = []
    if question.capability == 'inventory.count':
        quantities = [recorded_quantity(i.get('quantity')) for i in items]
        unknown = sum(q is None for q in quantities)
        answer = f'{len(items)} matching saved records; {sum(q for q in quantities if q is not None)} recorded units with known quantities.'
        if unknown:
            answer += f' Quantity is unknown for {unknown} records; those units are not included in the total.'
    elif question.capability in ('item.documents', 'item.history'):
        if len(items) != 1:
            return 'Which item do you mean? ' + '; '.join(_text(i.get('name')) for i in items[:5]), 'ambiguous', sources
        item = items[0]
        if question.capability == 'item.documents':
            docs = list_documents(user_id=user_id, item_id=item['item_id'], limit=21)
            sources = [{'kind': 'document', 'label': _text(d.get('filename')) or 'Linked document',
                        'detail': 'Item-linked document metadata; contents not read'} for d in docs[:20]]
            answer = ('Linked documents: ' + '; '.join(d['label'] for d in sources) + '. ' if docs else 'No linked document was found for this item. ')
            answer += 'I have not read document contents, so I cannot establish its specifications, price or warranty from the filename.'
            if len(docs) > 20:
                answer += ' Showing the first 20 linked document records.'
        else:
            events = get_events_for_item(user_id=user_id, item_id=item['item_id'], limit=16)
            sources = [{'kind': 'history', 'label': 'Saved item events', 'detail': f'{min(len(events), 15)} recent events checked; not physical confirmation'}]
            answer = ('Recent saved events: ' + '; '.join(
                f"{_text(e.get('created_at'))}: {_text(e.get('event_type'))} {_text(e.get('content'))}" for e in events[:15])
                if events else 'No saved item events were found.')
            if item.get('notes'):
                answer = 'Current saved notes: ' + _text(item['notes'], 500) + '. ' + answer
            answer += ' Event or edit timestamps do not prove where the item is now; a move is known only when explicitly recorded.'
        return answer, 'incomplete', sources
    else:
        lines = []
        for item in items[:20]:
            quantity = recorded_quantity(item.get('quantity'))
            detail = f"{_text(item.get('name')) or 'Unnamed item'}: recorded location {_text(item.get('location')) or 'unknown'}; recorded quantity {quantity if quantity is not None else 'unknown'}"
            if item['_match_basis'] == 'likely text match':
                detail += '; likely text match, please check the identity'
            if 'created' in question.filters:
                detail += '; record created ' + _text(item.get('created_at'))
            if question.capability == 'item.evidence':
                fields = ', '.join(f'{key}: {_text(item[key])}' for key in _FIELDS if item.get(key))
                detail += '; saved fields: ' + fields
            lines.append(detail)
        answer = '\n'.join(lines)
        if len(items) > 20:
            answer += f'\nShowing 20 of {len(items)} matching records checked.'
        answer += '\nThese are saved records, not a live physical sighting.'
    if truncated:
        answer += '\nThe search limit was reached. These results and totals are partial; narrow the name or location.'
    incomplete = truncated or any(recorded_quantity(i.get('quantity')) is None for i in items)
    if question.capability in ('item.find', 'item.evidence'):
        incomplete = incomplete or any(not str(i.get('location') or '').strip() for i in items)
    return answer, 'incomplete' if incomplete else 'supported', sources
