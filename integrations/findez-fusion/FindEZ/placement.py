"""Native import and placement only. Called on Fusion's main event thread."""
from pathlib import Path
import hashlib
import json
import math
import adsk.core
import adsk.fusion

COMMAND='FindEZPlaceComponent'
handlers=[]
command_handlers=[]
pending=None


def attach(event,handler,command=False):
    event.add(handler)
    (command_handlers if command else handlers).append((event,handler))


def clear_command_handlers():
    for event,handler in command_handlers:
        try:
            event.remove(handler)
        except RuntimeError:
            pass  # Fusion can invalidate command events before destroy completes.
    command_handlers.clear()


def insert(app,part,path,inventory_id,generated_job=None, *, on_confirm=None, catalog_model=None):
    global pending
    design=adsk.fusion.Design.cast(app.activeProduct)
    if not design or pending is not None:
        raise ValueError('Open a design and finish the current placement first.')
    source=Path(path)
    if source.suffix.lower() not in ('.step','.stp','.f3d') or not source.is_file() or source.stat().st_size>100*1024*1024:
        raise ValueError('Choose a STEP or F3D file smaller than 100 MiB.')
    # The file is selected in a native dialog, never through a path from HTML.
    # No file is uploaded. A digest records the local geometry version.
    hasher=hashlib.sha256()
    with source.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):
            hasher.update(chunk)
    digest=hasher.hexdigest()
    manager=app.importManager
    options=manager.createFusionArchiveImportOptions(str(source)) if source.suffix.lower()=='.f3d' else manager.createSTEPImportOptions(str(source))
    wrapper=design.rootComponent.occurrences.addNewComponent(adsk.core.Matrix3D.create())
    try:
        imported=manager.importToTarget2(options,wrapper.component)
        if not imported or imported.count==0:
            raise ValueError('Fusion could not import this model.')
        component=wrapper.component
        component.name=str(part.get('name') or part.get('canonical_name') or 'FindEZ component')
        component.partNumber=str(part.get('part_number') or '')
        attributes={'manufacturer':part.get('brand') or '', 'barcode':part.get('barcode') or '',
                    'procurement_policy':'purchase','inventory_id':inventory_id,
                    'specifications':json.dumps({k:str(v) for k,v in (part.get('specifications') or {}).items() if isinstance(v,(str,int,float))}),
                    'inventory_item_id':part.get('item_id') or '', 'catalog_id':part.get('catalog_id') or '',
                    'model_quality':'unverified','model_sha256':digest,'model_source':'user_selected_local_file'}
        if catalog_model:
            if str(part.get('catalog_id')) != catalog_model['catalog_id'] or digest != catalog_model['step_sha256']:
                raise ValueError('The model no longer matches the selected part and version.')
            attributes.update(model_source=catalog_model['source'], model_version=catalog_model['revision'],
                              model_quality='source_reviewed', model_units=catalog_model['units'],
                              model_reference=catalog_model['source_url'])
        if generated_job:
            attributes.update({'procurement_policy':'fabricate', 'model_quality':'generated_unverified',
                               'model_source':'rexcad', 'generation_job_id':generated_job})
        for key,value in attributes.items():
            component.attributes.add('FindEZ',key,str(value))
        start_placement(app, design, wrapper, on_confirm)
    except Exception:
        pending=None
        if wrapper.isValid:
            wrapper.deleteMe()
        raise


def start_placement(app, design, occurrence, on_confirm):
    global pending
    pending={'occurrence':occurrence,'design':design,'committed':False, 'on_confirm':on_confirm}
    definitions=app.userInterface.commandDefinitions
    definition=definitions.itemById(COMMAND)
    if not definition:
        definition=definitions.addButtonDefinition(COMMAND,'Place FindEZ component','Position this component, then confirm. No inventory is changed.')
        attach(definition.commandCreated,Created())
    if not definition.execute():
        raise ValueError('Fusion could not start placement.')


def insert_model(app, part, model, inventory_id, *, on_confirm=None):
    """Copy geometry already in Fusion. Only this new wrapper gets metadata."""
    global pending
    design=adsk.fusion.Design.cast(app.activeProduct)
    if not design or pending is not None:
        raise ValueError('Open a design and finish the current placement first.')
    kind, value = model
    if kind not in ('component', 'data_file'):
        raise ValueError('Choose a model from this Fusion project.')
    if kind == 'component' and value == design.rootComponent:
        raise ValueError('Choose a component, not the entire active design.')
    wrapper=design.rootComponent.occurrences.addNewComponent(adsk.core.Matrix3D.create())
    try:
        occurrences=wrapper.component.occurrences
        if kind == 'component':
            inserted=occurrences.addNewComponentCopy(value, adsk.core.Matrix3D.create())
            origin='fusion_component'
            reference=str(value.entityToken)
            version='current_design'
        else:
            if str(value.fileExtension).lower() != 'f3d':
                raise ValueError('Select a saved Fusion design.')
            if design.parentDocument.dataFile and value.id == design.parentDocument.dataFile.id:
                raise ValueError('A design cannot be inserted into itself.')
            inserted=occurrences.addByInsert(value, adsk.core.Matrix3D.create(), False)
            origin='fusion_project_file'
            reference=str(value.id)
            version=str(value.versionNumber)
        if not inserted:
            raise ValueError('Fusion could not insert this model. Check its availability and try again.')
        component=wrapper.component
        component.name=str(part.get('name') or part.get('canonical_name') or 'FindEZ component')
        component.partNumber=str(part.get('part_number') or '')
        attributes={'manufacturer':part.get('brand') or '', 'barcode':part.get('barcode') or '',
                    'procurement_policy':'purchase','inventory_id':inventory_id,
                    'specifications':json.dumps({k:str(v) for k,v in (part.get('specifications') or {}).items() if isinstance(v,(str,int,float))}),
                    'inventory_item_id':part.get('item_id') or '', 'catalog_id':part.get('catalog_id') or '',
                    'model_quality':'unverified','model_source':origin,'model_reference':reference,
                    'model_version':version}
        for key,value in attributes.items():
            component.attributes.add('FindEZ',key,str(value))
        start_placement(app,design,wrapper,on_confirm)
    except Exception:
        pending=None
        if wrapper.isValid:
            wrapper.deleteMe()
        raise


def measured_extents(occurrence):
    """Initial axis-aligned solid envelope. Fusion database length units are cm."""
    try:
        box = occurrence.preciseBoundingBox
        dimensions = [
            (getattr(box.maxPoint, axis) - getattr(box.minPoint, axis)) * 10
            for axis in ('x', 'y', 'z')
        ]
        if all(math.isfinite(value) and value > 0 for value in dimensions):
            return 'Initial solid extents (X × Y × Z): ' + ' × '.join(
                f'{value:.6g}' for value in dimensions
            ) + ' mm'
    except (AttributeError, RuntimeError, TypeError):
        pass
    return 'Solid extents unavailable. Use Fusion Measure to check this model.'


def apply_position(args, state):
    triad = args.command.commandInputs.itemById('findezPosition')
    if not triad or not triad.isValidExpressions:
        raise ValueError('Invalid placement input.')
    if state['design'] != adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct):
        raise ValueError('The active design changed.')
    state['occurrence'].transform2 = triad.positionTransform


class Created(adsk.core.CommandCreatedEventHandler):
    def notify(self,args):
        global pending
        if pending is None:
            return
        attach(args.command.destroy,Destroyed(),command=True)
        try:
            triad=args.command.commandInputs.addTriadCommandInput('findezPosition',pending['occurrence'].transform2)
            triad.setFullVisibility(True)
            triad.hideAllScaling()
            triad.setFlipVisibility(False)
            triad.isEnabled = True
            triad.isVisible = True
            args.command.commandInputs.addTextBoxCommandInput(
                'findezModelSize', 'Model size', measured_extents(pending['occurrence']), 2, True
            )
            attach(args.command.execute,Execute(),command=True)
            attach(args.command.executePreview,Preview(),command=True)
        except Exception:
            state,pending=pending,None
            if state and state['occurrence'].isValid:
                state['occurrence'].deleteMe()
            adsk.core.Application.get().userInterface.messageBox('Placement handles could not be created. The imported component was removed. Try again in a supported Fusion version.')


class Preview(adsk.core.CommandEventHandler):
    def notify(self,args):
        args.isValidResult=False
        if pending and pending['occurrence'].isValid:
            try:
                apply_position(args, pending)
            except Exception:
                args.executeFailed=True
                args.executeFailedMessage='The component could not be positioned. Cancel and try again.'


class Execute(adsk.core.CommandEventHandler):
    def notify(self,args):
        if pending and pending['occurrence'].isValid:
            try:
                apply_position(args, pending)
                if pending['design'].snapshots.hasPendingSnapshot:
                    pending['design'].snapshots.add()
                pending['committed']=True
            except Exception:
                args.executeFailed=True
                args.executeFailedMessage='Placement could not be confirmed. Cancel and try again.'


class Destroyed(adsk.core.CommandEventHandler):
    def notify(self,args):
        global pending
        state,pending=pending,None
        clear_command_handlers()
        if state and not state['committed'] and state['occurrence'].isValid:
            state['occurrence'].deleteMe()
        elif state and state['committed'] and state['on_confirm']:
            state['on_confirm']()


def stop(ui):
    global pending
    state,pending=pending,None
    if state and not state['committed'] and state['occurrence'].isValid:
        state['occurrence'].deleteMe()
    definition=ui.commandDefinitions.itemById(COMMAND)
    if definition:
        definition.deleteMe()
    clear_command_handlers()
    handlers.clear()
