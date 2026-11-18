"""Private response ratings: diagnostic evidence, never inventory authority."""
from collections import Counter
from datetime import datetime, timedelta, timezone
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from app.services.supabase_client import get_supabase_raw
from app.services.personalization.transport import client as learning_client

REASONS = {
    'wrong_inventory': 'Wrong inventory information',
    'misunderstood': 'Misunderstood my request',
    'action_failed': 'Failed to perform or save the action',
    'incomplete': 'Missing or incomplete results',
    'forgot_context': 'Forgot my preferences or context',
    'unsafe_action': 'Incorrect or unsafe action',
    'clarity': 'Poor explanation or excessive verbosity',
    'other': 'Other',
}
DIMENSIONS = {'wrong_inventory': 'retrieval_accuracy', 'misunderstood': 'intent_accuracy',
    'action_failed': 'operation_success', 'incomplete': 'completeness',
    'forgot_context': 'personalization_quality', 'unsafe_action': 'groundedness',
    'clarity': 'response_clarity', 'other': 'unclassified'}
RESPONSE_VERSION = 'verified-chat-feedback-v1'


class Rating(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True)
    rating: int = Field(ge=-1, le=1)
    reason: str | None = Field(default=None, max_length=64)
    comment: str | None = Field(default=None, max_length=1000)
    expected_revision: int = Field(default=0, ge=0)

    @field_validator('rating')
    @classmethod
    def binary(cls, value):
        if value not in (-1, 1): raise ValueError('Choose positive or negative feedback')
        return value

    @field_validator('comment')
    @classmethod
    def clean_comment(cls, value):
        return value.strip() or None if value is not None else None

    @model_validator(mode='after')
    def valid_reason(self):
        if self.reason is not None and self.reason not in REASONS:
            raise ValueError('Choose a supported feedback reason')
        if self.rating == 1 and self.reason is not None:
            raise ValueError('Reasons apply to negative feedback')
        return self


def owned_message(actor, message_id):
    client = get_supabase_raw()
    rows = client.table('messages').select('id,conversation_id,role,content,answer_context,created_at').eq('id', str(message_id)).limit(1).execute().data or []
    if not rows: raise HTTPException(404, 'Response not found.')
    row = rows[0]
    conversations = client.table('conversations').select('id,world_key').eq('id', row['conversation_id']).eq('user_id', actor).limit(1).execute().data or []
    if not conversations or row['role'] != 'assistant' or not row['content'].strip():
        raise HTTPException(404, 'Response not found.')
    world = conversations[0].get('world_key')
    if world:
        from app.services.world_chat import authorize
        authorize(actor, world)
    context = row.get('answer_context') or {}
    if any(context.get(k) for k in ('direct_receipt', 'attachment_receipt', 'response_failed')):
        raise HTTPException(422, 'This message cannot be rated.')
    # Regenerated prose references the original action receipt rather than copying
    # an action ID to a second persisted message. Reauthorize every hop.
    seen = {row['id']}
    reference = context.get('action_message_id') or context.get('retry_of')
    while reference and reference not in seen and len(seen) < 50:
        seen.add(reference)
        parents = client.table('messages').select('id,answer_context').eq('id', reference).eq('conversation_id', row['conversation_id']).limit(1).execute().data or []
        if not parents: break
        parent = parents[0].get('answer_context') or {}
        for field in ('world_actions', 'pending_actions', 'completed_actions', 'operation_diagnostics', 'chat_capture_id', 'chat_capture', 'photo_attachment'):
            if field in parent: context = {**context, field: parent[field]}
        reference = parent.get('action_message_id') or parent.get('retry_of')
    return {**row, 'answer_context': context}


def diagnostics(context):
    """Only receipts establish execution; ratings and prose never do."""
    actions = [a for key in ('world_actions', 'pending_actions', 'completed_actions')
               for a in context.get(key, []) if isinstance(a, dict)]
    executed = [a for a in actions if a.get('status') == 'confirmed' and isinstance(a.get('receipt'), dict)]
    metadata = context.get('response_metadata') or {}
    operations = context.get('operation_diagnostics') or []
    return {
        'operation': 'inventory_action' if actions else 'answer',
        'operations': operations[:20],
        'outcome_basis': 'server_receipts_at_rating_time',
        'request_message_id': context.get('request_message_id'),
        'clarification': 'not_observed',
        'reporting_accuracy': 'unreviewed',
        'action_count': len(actions), 'confirmed_action_count': len(executed),
        'pending_action_count': sum(a.get('status') == 'pending' for a in actions),
        'execution': 'confirmed' if executed and len(executed) == len(actions) else 'mixed' if executed else 'pending' if any(a.get('status') == 'pending' for a in actions) else 'not_executed' if actions else 'not_observed',
        'validation': 'passed' if metadata.get('validation') == 'passed' else 'not_observed',
        'retrieval': 'performed' if context.get('sources') or context.get('rows') or context.get('resource_links') else 'not_observed',
        'factual_correctness': 'unreviewed',
        'model_version': str(metadata.get('model_version') or 'unknown')[:100],
        'response_version': str(metadata.get('response_version') or 'legacy')[:100],
    }


def submit(actor, message_id, rating):
    message = owned_message(actor, message_id)
    try:
        result = get_supabase_raw().rpc('findez_response_feedback', {
            'p_actor': actor, 'p_message': str(message_id), 'p_rating': rating.rating,
            'p_reason': rating.reason, 'p_comment': rating.comment,
            'p_revision': rating.expected_revision,
            'p_diagnostics': diagnostics(message.get('answer_context') or {}),
        }).execute().data
        if not isinstance(result, dict) or result.get('message_id') != str(message_id) or result.get('rating') != rating.rating:
            raise HTTPException(503, 'Feedback was not confirmed. Please retry.')
        return public_rating(result)
    except HTTPException: raise
    except Exception as error:
        code = getattr(error, 'code', None)
        if code in ('40001', 'PT409'): raise HTTPException(409, 'Feedback changed. Refresh and try again.') from None
        if code in ('42501', 'P0002'): raise HTTPException(404, 'Response not found.') from None
        raise HTTPException(503, 'Feedback could not be saved. Please retry.') from None


def public_rating(row):
    return {k: row.get(k) for k in ('id', 'message_id', 'rating', 'reason', 'comment', 'revision', 'updated_at')}


def list_for_conversation(actor, conversation_id):
    client = get_supabase_raw()
    rows = client.table('conversations').select('id,world_key').eq('id', str(conversation_id)).eq('user_id', actor).execute().data or []
    if not rows: raise HTTPException(404, 'Conversation not found.')
    if rows[0].get('world_key'):
        from app.services.world_chat import authorize
        authorize(actor, rows[0]['world_key'])
    try:
        ratings = client.table('response_feedback').select('id,message_id,rating,reason,comment,revision,updated_at').eq('user_id', actor).eq('conversation_id', str(conversation_id)).limit(1000).execute().data or []
        return {'ratings': [public_rating(r) for r in ratings], 'reasons': REASONS}
    except Exception:
        raise HTTPException(503, 'Feedback is temporarily unavailable.') from None


def forget(actor, message_id=None):
    query = get_supabase_raw().table('response_feedback').delete().eq('user_id', actor)
    if message_id: query = query.eq('message_id', str(message_id))
    try: query.execute()
    except Exception: raise HTTPException(503, 'Feedback could not be deleted. Please retry.') from None
    return {'deleted': True}


def learning_guidance(actor):
    """Repeated opt-in signals request verification, never overwrite facts/style."""
    try:
        from app.services.personalization.repository import profile
        client = learning_client()
        settings = profile(actor, client=client)
        if not settings.get('effective_enabled'): return []
        rows = client.table('response_feedback').select('rating,reason').eq('user_id', actor).eq('learning_generation', settings['generation']).gte('updated_at', (datetime.now(timezone.utc)-timedelta(days=60)).isoformat()).order('updated_at', desc=True).limit(100).execute().data or []
        counts = Counter(r.get('reason') for r in rows if r.get('rating') == -1)
        messages = {
            'wrong_inventory': 'Double-check quantities and locations using current authorized records.',
            'misunderstood': 'Clarify genuinely ambiguous targets before acting.',
            'action_failed': 'Distinguish pending proposals from confirmed operation receipts.',
            'incomplete': 'Check the requested list for omissions; ask about unknown counts.',
            'forgot_context': 'Check relevant explicit preferences and current conversation references.',
            'unsafe_action': 'Verify the intended target and existing authorization before changes.',
        }
        return [messages[k] for k, n in counts.most_common(2) if k in messages and n >= 3 and n / max(len(rows), 1) >= .5]
    except Exception:
        return []  # Optional learning never breaks chat; no private error logging.
