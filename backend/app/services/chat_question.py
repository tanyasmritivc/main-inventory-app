"""Model-authored follow-up choices. Rendering a question never changes stock."""
from typing import Literal
from uuid import UUID, uuid4
from pydantic import BaseModel, ConfigDict, Field, model_validator


class Choice(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    kind: Literal['answer', 'existing_space', 'new_space']
    label: str = Field(min_length=1, max_length=80)
    reply: str = Field(default='', max_length=400)
    inventory_id: str | None = None
    space_id: str | None = None

    @model_validator(mode='after')
    def valid_target(self):
        if self.kind == 'existing_space':
            if not self.inventory_id or not self.space_id:
                raise ValueError('An existing Space needs verified inventory and Space IDs.')
            UUID(self.inventory_id)
            UUID(self.space_id)
        elif self.inventory_id or self.space_id:
            raise ValueError('Only existing Space choices carry saved target IDs.')
        if self.kind == 'answer' and not self.reply:
            raise ValueError('An answer choice needs a reply.')
        return self


class Question(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)
    prompt: str = Field(min_length=1, max_length=160)
    choices: list[Choice] = Field(min_length=2, max_length=4)


def present(actor, world, args):
    from app.services.world_chat import in_inventory
    from app.services.spaces_repo import list_spaces
    question = Question.model_validate(args, strict=True)
    choices, seen = [], set()
    for choice in question.choices:
        label, detail, reply = choice.label, '', choice.reply
        if choice.kind == 'existing_space':
            with in_inventory(actor, world, choice.inventory_id) as inv:
                if not inv['can_edit']:
                    raise ValueError('Choose a writable Space.')
                target = next((s for s in list_spaces(user_id=inv['owner_user_id'])
                               if str(s['id']) == choice.space_id), None)
                if target is None:
                    raise ValueError('The Space is no longer available.')
                label = target['name']
                detail = inv['name'] + ' · ' + inv['workspace']['name']
                reply = f'Use the existing Space "{label}" in inventory "{inv["name"]}" in workspace "{inv["workspace"]["name"]}" for this draft.'
        elif choice.kind == 'new_space':
            # The model suggests a name, not an executable task. Normal chat
            # permission/confirmation rules apply when the user selects it.
            detail = 'New Space'
            reply = f'I would like a new Space named "{label}" for these items. Please prepare it for review.'
        key = (choice.kind, choice.inventory_id, choice.space_id, label.casefold())
        if key in seen:
            raise ValueError('Offer distinct choices.')
        seen.add(key)
        choices.append({'label': label, 'detail': detail, 'reply': reply, 'kind': choice.kind})
    return {'question': {'id': str(uuid4()), 'prompt': question.prompt, 'choices': choices}, 'saved': False}


def destinations(actor, world):
    from app.services.world_chat import directory, get_supabase_raw
    # directory() reauthorizes each inventory. One bounded metadata query avoids
    # an extra model turn and a separate space-summary query per inventory.
    writable = [g for g in directory(actor, world)['inventories'] if g['can_edit']]
    selected = writable[:200]
    ids = [g['inventory_id'] for g in selected]
    rows = (get_supabase_raw().table('spaces').select('id,name,inventory_id')
            .in_('inventory_id', ids).order('name').order('id').limit(201)
            .execute().data or []) if ids else []
    result = []
    for group in selected:
        result.append({k: group[k] for k in ('inventory_id', 'name', 'workspace_id', 'workspace_name')} | {
            'spaces': [{'id': s['id'], 'name': s['name']} for s in rows[:200]
                       if s['inventory_id'] == group['inventory_id']]})
    return {'inventories': result, 'truncated': len(writable) > 200 or len(rows) > 200}


MARKER = '<findez-question>'
END_MARKER = '</findez-question>'


class QuestionStream:
    """Forward prose immediately; hold only a possible marker prefix/UI payload."""
    def __init__(self):
        self.pending = ''
        self.hidden = False

    def feed(self, delta):
        if self.hidden:
            return ''
        self.pending += delta
        if MARKER in self.pending:
            visible = self.pending.split(MARKER, 1)[0]
            self.pending = ''
            self.hidden = True
            return visible
        keep = 0
        for size in range(1, min(len(MARKER), len(self.pending)) + 1):
            if MARKER.startswith(self.pending[-size:]):
                keep = size
        visible = self.pending[:-keep] if keep else self.pending
        self.pending = self.pending[-keep:] if keep else ''
        return visible

    def finish(self):
        value, self.pending = self.pending, ''
        return value


def separate(content):
    import json
    prose, found, payload = content.partition(MARKER)
    if not found:
        return content, None
    payload, ended, suffix = payload.partition(END_MARKER)
    if not ended or suffix.strip() or len(payload) > 6000:
        return prose.rstrip(), None
    try:
        return prose.rstrip(), Question.model_validate(json.loads(payload), strict=True).model_dump()
    except (ValueError, TypeError):
        return prose.rstrip(), None


GUIDANCE = (
    'Lead your streamed reply with a brief useful summary of the actual result, before any choices; the app shows controls after your words. '
    'When a follow-up choice would help, write the summary and ONE natural-language question first. If you ask the user to choose between two to four concrete options, you MUST append '
    '<findez-question>{"prompt":"Short question?","choices":[{"kind":"answer","label":"Short choice","reply":"User reply"},'
    '{"kind":"new_space","label":"Robotics spares"}]}</findez-question> at the very end. '
    'This final JSON is UI metadata, not displayed prose; never put it in a code fence or discuss the format. '
    'Offer two to four distinct choices, four when useful, never filler. For kind existing_space, include exact inventory_id and space_id '
    'from fresh destination tools plus a label; for kind new_space label is the proposed new name; for kind answer include the actual reply. '
    'Existing choices are revalidated. New Space suggestions never create anything or save items. '
    'For an unplaced draft, suggest relevant actual Spaces plus a category-appropriate new Space name. A question like Which place do you prefer MUST include matching choices in the UI metadata; do not end with only a plain-text choice question. Do not select a destination with world_refine_capture until the user has chosen or named it. '
    'Ask unknown counts first. Do not force choices for greetings or ordinary answers. The user can always type their own response. '
    'Keep the question in prose too for older clients. Do not call another tool just to present choices. '
    'Be warm and concise; never claim a save without its receipt.'
)


def public_links(text, allowed, final=False):
    """Do not briefly expose an invented internal link while its URL is arriving."""
    import re
    if not final:
        start = text.rfind('[')
        if start >= 0 and re.fullmatch(r'\[[^\]\n]*|\[[^\]\n]+\](?:\([^\)\n]*)?', text[start:]):
            text = text[:start]
    return re.sub(r'\[([^\]]+)\]\((findez://[^)]+)\)',
                  lambda m: m.group(0) if m.group(2) in allowed else m.group(1), text)


class PublicReply:
    def __init__(self, validate, allowed_links):
        self.question = QuestionStream()
        self.validate = validate
        self.allowed_links = allowed_links
        self.raw = self.visible = ''

    def _emit(self, final=False):
        candidate = public_links(self.raw, self.allowed_links, final=final)
        self.validate(candidate)
        if not candidate.startswith(self.visible):
            raise RuntimeError('The answer changed its streamed prefix')
        delta = candidate[len(self.visible):]
        self.visible = candidate
        return delta

    def feed(self, delta):
        self.raw += self.question.feed(delta)
        return self._emit()

    def finish(self):
        self.raw += self.question.finish()
        return self._emit(final=True)


class ReceiptClaimError(RuntimeError):
    """A public reply claimed a write without the corresponding receipt."""
