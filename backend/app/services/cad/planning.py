"""Read-only, ordered multi-project requirements sharing one finite stock pool."""
from uuid import UUID, uuid4
from pydantic import Field, model_validator, ValidationError
from fastapi import HTTPException
from .snapshot import Model, Snapshot
from . import projects, corrections, purchasing
from .comparison import compare
from .repository import read_inventory, authorize_inventory
from app.services.supabase_client import get_supabase_raw


class Request(Model):
    version_ids: list[UUID] = Field(min_length=1, max_length=20)

    @model_validator(mode='after')
    def unique(self):
        if len(set(self.version_ids)) != len(self.version_ids):
            raise ValueError('Choose one version of each project.')
        return self


def combine(versions):
    """Keep contextual occurrences; attach each tree under a new synthetic root."""
    definitions=[{'key':'plan','name':'Selected projects','procurement_policy':'assembly'}]
    occurrences=[{'key':'plan','definition_key':'plan','parent_key':None,'source_path':'plan','suppression':'active'}]
    warnings=[]; partial=False
    for index,version in enumerate(versions):
        snapshot=Snapshot.model_validate(version['snapshot']); prefix=f'p{index}.'
        if len(definitions)+len(snapshot.definitions)>5000 or len(occurrences)+len(snapshot.occurrences)>20000:
            raise HTTPException(413,'Select fewer projects; combined assembly exceeds the supported size.')
        for definition in snapshot.definitions:
            definitions.append({**definition.model_dump(),'key':prefix+definition.key})
        for occurrence in snapshot.occurrences:
            occurrences.append({**occurrence.model_dump(),'key':prefix+occurrence.key,
                'definition_key':prefix+occurrence.definition_key,
                'parent_key':prefix+occurrence.parent_key if occurrence.parent_key else 'plan'})
        partial |= snapshot.completeness=='partial'
        warnings.extend(f'{snapshot.document.name}: {warning}'[:2000] for warning in snapshot.warnings)
    if len(warnings)>200:
        warnings=warnings[:199]+['Additional project warnings omitted. Open the individual saved versions.']
    return Snapshot.model_validate({'schema_version':1,'provider':'fusion','extraction_id':uuid4(),
        'adapter_version':'findez-planning','host_version':'server','document':{'external_id':'planning','name':'Selected projects'},
        'revision':{'kind':'unsaved_session','id':'planning','dirty':True,'configuration':''},
        'completeness':'partial' if partial else 'complete','warnings':warnings,'definitions':definitions,'occurrences':occurrences})


def evaluate(inventory, actor, request):
    projects.require_enabled();authorize_inventory(inventory,actor)
    rows=get_supabase_raw().table('cad_bom_versions').select('id,project_id,version,snapshot,created_at').eq(
        'inventory_id',inventory).in_('id',[str(v) for v in request.version_ids]).execute().data or []
    by_id={row['id']:row for row in rows}
    if any(str(v) not in by_id for v in request.version_ids):
        raise HTTPException(404,'A selected BOM is unavailable in this inventory.')
    ordered=[by_id[str(v)] for v in request.version_ids]
    if len({v['project_id'] for v in ordered})!=len(ordered):
        raise HTTPException(422,'Choose only one saved version of each project.')
    try: snapshot=combine(ordered)
    except ValidationError:
        raise HTTPException(422, "The combined assembly is too deep or has unsupported metadata. Review projects separately.") from None
    items,reserved,checked=read_inventory(inventory,actor)
    result=compare(snapshot,items,reserved,checked,corrections.load(snapshot,inventory,actor))
    groups=[]
    for index,version in enumerate(ordered):
        lines=[row for row in result['items'] if row['key'].startswith(f'p{index}.')]
        groups.append({'version_id':version['id'],'name':version['snapshot']['document']['name'],
            'priority':index+1,'required':sum(r['required'] for r in lines),'assigned':sum(r['assigned'] for r in lines),
            'missing':sum(r['missing'] for r in lines),'review_lines':sum(r['status']=='needs_review' for r in lines),'items':lines})
    incoming=[]
    if purchasing.enabled():
        plans=get_supabase_raw().table('cad_purchase_plans').select('id,name,lines').eq('inventory_id',inventory).eq('state','ordered').limit(201).execute().data or []
        if len(plans)>200: raise HTTPException(413,'Too many open orders for a complete planning preview.')
        for plan in plans:
            for line in plan['lines']:
                quantity=line['selected_quote']['estimate']['order_quantity']-line['received']
                if quantity>0: incoming.append({'plan_id':plan['id'],'project':plan['name'],'name':line['name'],
                    'manufacturer':line.get('manufacturer',''),'part_number':line.get('part_number',''),'quantity':quantity})
    authorize_inventory(inventory,actor)
    return {'inventory_id':inventory,'projects':groups,'incoming':incoming,'summary':result['summary'],
        'inventory_as_of':result['inventory_as_of'],'completeness':result['completeness'],'warnings':result['warnings'],
        'basis':'selected_priority_after_all_existing_reservations_and_checkouts',
        'note':'Preview only. Earlier selected projects receive free stock first. Existing reservations are excluded, including reservations for these projects. Incoming orders are shown separately and do not count as physical stock. Nothing is reserved or purchased.'}
