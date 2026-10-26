"""Conversational controls: model arguments never constitute consent.

Only the current, complete user message can authorize a private preference write.
No inventory mutation is performed here. Existing settings remain the master switch.
"""
import re
from uuid import UUID, uuid5, NAMESPACE_URL
from pydantic import BaseModel, ConfigDict
from app.schemas.personalization import ProfileChange, AliasChange, ResetChange
from app.services.personalization import repository

HELP = ('Personalization is optional. To use recent inventory activity for search, say '
        '"Enable personalization". Say "Disable personalization" to pause it or '
        '"Reset personalization" to forget it. For an item alias, say '
        '\'Remember "my alias" as "exact saved item name"\' and include in inventory "Inventory name" when you have several inventories. '
        'Notifications are off by default. To opt in, say '
        '"Enable low stock notifications in America/Los_Angeles" or '
        '"Enable scan review notifications in America/Los_Angeles", using your timezone. '
        'They are limited to one a day, three a week, outside 9pm–9am. '
        'Say "Disable notifications" to stop these alerts. Existing Memory settings control all personalization.')


class Arguments(BaseModel):
    model_config = ConfigDict(extra='forbid')
    inventory_id: str | None = None


def parse(message):
    text = message.strip().rstrip('.!?').strip()
    if re.fullmatch(r'(?:please )?(enable|disable|reset) personalization', text, re.I):
        return {'action': text.lower().removeprefix('please ').split()[0]}
    if re.fullmatch(r'(?:please )?disable notifications', text, re.I):
        return {'action': 'notifications_off'}
    match = re.fullmatch(r'(?:please )?enable (low stock|scan review) notifications in ([A-Za-z_]+(?:/[A-Za-z_+-]+)+|UTC)', text, re.I)
    if match:
        return {'action': 'notifications', 'category': 'low_stock' if match[1].lower()=='low stock' else 'scan_review', 'timezone': match[2]}
    match = re.fullmatch(r'(?:please )?remember ["“]([^"”]{1,60})["”] as ["“]([^"”]{1,200})["”](?: in inventory ["“]([^"”]{1,100})["”])?', text, re.I)
    if match: return {'action':'alias', 'alias':match[1], 'name':match[2], 'inventory_name':match[3]}
    match = re.fullmatch(r'(?:please )?forget (?:the )?alias ["“]([^"”]{1,60})["”](?: in inventory ["“]([^"”]{1,100})["”])?', text, re.I)
    if match: return {'action':'alias', 'alias':match[1], 'name':None, 'inventory_name':match[2]}
    return None


def execute(actor, world, args, *, message, turn_id):
    from app.services.world_chat import in_inventory, authorize, directory
    from app.services.items_repo import list_items
    authorize(actor, world)
    parsed = Arguments.model_validate(args, strict=True)
    command = parse(message)
    if not command:
        state = repository.read(actor)['profile']
        return {'saved': False, 'personalization_enabled': state['effective_enabled'],
                'instructions': ('Personalization is already on. Use the current conversation to recall the request; ask which request only if the history is missing or ambiguous. Do not claim a new preference was saved.' if state['effective_enabled'] else
                    'Personalization is off. Current-conversation recall still works from the provided history. Enable it in Memory settings to use durable preferences.')}
    if not turn_id:
        return {'instructions':'Please update FindEZ before changing personalization in chat. Memory settings still work.', 'saved':False}
    current = repository.read(actor)['profile']
    if command['action'] in ('enable', 'disable') and 'effective_enabled' in current:
        from app.services import account_memory
        from app.schemas.memory import MemoryChange
        memory = account_memory.snapshot(actor)
        desired = command['action'] == 'enable'
        if memory['enabled'] != desired:
            account_memory.change(actor, MemoryChange(action='settings', enabled=desired,
                expected_revision=memory['revision'],
                operation_id=uuid5(NAMESPACE_URL, 'findez:memory-control:'+str(actor)+':'+str(turn_id))))
            current = repository.read(actor)['profile']
    # A stable operation for this exact user turn makes provider/tool retries safe.
    operation = uuid5(NAMESPACE_URL, 'findez:personalization:'+str(actor)+':'+str(UUID(str(turn_id))))
    common = {'operation_id':operation,'expected_revision':current['revision']}
    action = command['action']
    if action=='reset':
        result = repository.change(actor, ResetChange(**common), 'reset')
    elif action=='alias':
        if not parsed.inventory_id: return {'saved':False,'clarification':'Which inventory contains this item?'}
        inventories = directory(actor, world)['inventories']
        requested = command.get('inventory_name')
        eligible = [i for i in inventories if not requested or i['name'].casefold()==requested.casefold()]
        if len(eligible)!=1 or eligible[0]['inventory_id']!=parsed.inventory_id:
            return {'saved':False, 'clarification':'Include in inventory \"Inventory name\" in the alias request so I can use one exact destination.'}
        with in_inventory(actor, world, parsed.inventory_id) as inv:
            item = None
            if command['name']:
                candidates = [r for r in list_items(user_id=inv['owner_user_id'])
                    if str(r.get('name','')).strip().casefold()==command['name'].strip().casefold()]
                if len(candidates)!=1:
                    return {'saved':False,'clarification':'Use one unambiguous, exact saved item name. No alias was changed.'}
                item = candidates[0]['item_id']
            result = repository.change(actor, AliasChange(**common,inventory_id=parsed.inventory_id,
                alias=command['alias'],item_id=item), 'alias')
    else:
        fields={k:current[k] for k in ('enabled','categories','timezone','quiet_start','quiet_end','daily_cap','weekly_cap')}
        if action in ('enable','disable'): fields['enabled']=action=='enable'
        elif action=='notifications_off': fields['categories']=[]
        else:
            if not current['effective_enabled']:
                return {'saved':False,'clarification':'Enable Memory in settings, then say "Enable personalization" first. Notifications remain off.'}
            fields['categories']=sorted(set(fields['categories']+[command['category']]))
            fields['timezone']=command['timezone']
        result = repository.change(actor, ProfileChange(**common,**fields), 'settings')
    confirmation = {
        'enable':'Inventory personalization is on. Alerts remain controlled by your notification preferences.',
        'disable':'Inventory personalization is off. Your saved data is kept until you reset it.',
        'reset':'Your activity, item aliases and personalized notification history have been cleared.',
        'alias':'Your private item alias has been saved.' if command.get('name') else 'Your private item alias has been removed.',
        'notifications_off':'Personalized inventory alerts are off.',
        'notifications':'Those alerts are enabled, with your frequency limits and quiet hours.',
    }[action]
    if result.get('replayed'):
        confirmation = 'That request was already applied. Your later preferences have been kept.'
    return {**result, 'confirmation':confirmation, 'inventory_changed':False, 'action':action,
        'note':'Private preferences only. Stock and locations always come from current authorized records.'}
