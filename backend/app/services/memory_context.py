"""Bounded explicit personalization. Current records remain factual authority."""
import logging
from uuid import UUID
from app.services.supabase_client import get_supabase_raw
from app.services.inventory_scope import current_inventory
from app.services.resource_access import request_actor

logger = logging.getLogger(__name__)


def load_preferences(user_id):
    scope=current_inventory.get()
    actor=scope.actor_id if scope else (request_actor.get().actor_id if request_actor.get() else user_id)
    try:
        UUID(actor)
        client=get_supabase_raw()
        rows=client.table('user_memory').select('key,memory_kind,payload,confirmed_at').eq('user_id',actor).in_('key',['__settings_v1','answer_length','answer_format']).limit(3).execute().data or []
        control=next((r for r in rows if r['key']=='__settings_v1' and r.get('memory_kind')=='settings'),{})
        if (control.get('payload') or {}).get('enabled') is not True:
            return {}
        result={}
        choices={'answer_length':('brief','standard','detailed'),'answer_format':('paragraphs','bullets')}
        for row in rows:
            value=(row.get('payload') or {}).get('value')
            if row.get('memory_kind')=='preference' and row.get('confirmed_at') and value in choices.get(row['key'],()):
                result[row['key']]=value
        if scope:
            aliases=client.table('inventory_user_memory').select('payload,confirmed_at').eq('user_id',actor).eq('inventory_id',scope.inventory_id).eq('memory_kind','alias').limit(50).execute().data or []
            result['aliases']=[r['payload'] for r in aliases if r.get('confirmed_at') and isinstance(r.get('payload'),dict)]
        return result
    except Exception:
        # A missing migration or failed optional preference read cannot expose old
        # extracted text, impersonate another account, or block grounded answers.
        logger.info('Personalization unavailable; using default presentation')
        return {}


def style_instruction(preferences):
    length={'brief':'Use concise phrasing, preserving all relevant facts, uncertainty and sources.',
            'detailed':'Explain the retrieved evidence and its limits without adding unsupported facts.'}.get(preferences.get('answer_length'),'')
    layout={'bullets':'Use a bullet list for the answer.','paragraphs':'Use short paragraphs for the answer.'}.get(preferences.get('answer_format'),'')
    return ' '.join(x for x in (length,layout) if x)


def present(text, preferences, evidence=False):
    """Presentation only; never truncate a saved fact, caveat or action outcome."""
    if preferences.get('answer_length')=='detailed' and evidence:
        text+='\n\nThis uses your saved records, not a live inspection. A recorded location can be outdated.'
    if preferences.get('answer_format')=='bullets':
        text='\n'.join(line if line.startswith(('- ','* ')) else '- '+line for line in text.splitlines() if line.strip())
    return text


def personalize(answer, preferences):
    answer=dict(answer)
    answer['assistant_message']=present(answer.get('assistant_message') or '',preferences,bool((answer.get('answer_context') or {}).get('rows')))
    return answer
