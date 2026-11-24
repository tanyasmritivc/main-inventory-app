"""Native API contract checks with fake Fusion objects, not host acceptance."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace as NS, ModuleType
from unittest.mock import Mock
import sys
import pytest


@pytest.fixture
def host(monkeypatch, tmp_path):
    core=ModuleType('adsk.core'); fusion=ModuleType('adsk.fusion'); adsk=ModuleType('adsk')
    adsk.core=core; adsk.fusion=fusion
    for name in ('CommandCreatedEventHandler','CommandEventHandler'):
        setattr(core,name,type(name,(),{}))
    core.Matrix3D=NS(create=lambda:'identity')
    fusion.Design=NS(cast=lambda value:value)
    for name,module in [('adsk',adsk),('adsk.core',core),('adsk.fusion',fusion)]:
        monkeypatch.setitem(sys.modules,name,module)
    source=Path(__file__).resolve().parents[2]/'integrations/findez-fusion/FindEZ/placement.py'
    spec=importlib.util.spec_from_file_location('placement_under_test',source)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    wrapper=NS(isValid=True,component=NS(attributes=Mock()),deleteMe=Mock(),transform2='identity')
    design=NS(rootComponent=NS(occurrences=NS(addNewComponent=Mock(return_value=wrapper))),snapshots=NS(hasPendingSnapshot=False))
    definition=NS(execute=Mock(return_value=True),commandCreated=Mock(),deleteMe=Mock())
    definitions=NS(itemById=Mock(return_value=None),addButtonDefinition=Mock(return_value=definition))
    manager=NS(createSTEPImportOptions=Mock(return_value='step-options'),createFusionArchiveImportOptions=Mock(return_value='f3d-options'),importToTarget2=Mock(return_value=NS(count=1)))
    app=NS(activeProduct=design,importManager=manager,userInterface=NS(commandDefinitions=definitions))
    core.Application=NS(get=lambda:app)
    app.userInterface.messageBox=Mock()
    path=tmp_path/'bearing.step';path.write_bytes(b'fixture geometry')
    return NS(module=module,app=app,wrapper=wrapper,definition=definition,path=path)


def command():
    triad=NS(positionTransform='positioned',transform='scaled',isVisible=False,isEnabled=False,isValidExpressions=True,setFullVisibility=Mock(),hideAllScaling=Mock(),setFlipVisibility=Mock())
    inputs=NS(addTriadCommandInput=Mock(return_value=triad),addTextBoxCommandInput=Mock(),itemById=Mock(return_value=triad))
    return NS(command=NS(commandInputs=inputs,execute=Mock(),executePreview=Mock(),destroy=Mock())),triad


def test_insert_preserves_identity_and_cancel_removes_import(host):
    p=host.module
    p.insert(host.app,{'name':'Bearing','part_number':'608','brand':'Vendor'},str(host.path),'inventory')
    host.app.importManager.importToTarget2.assert_called_once_with('step-options',host.wrapper.component)
    assert host.wrapper.component.partNumber=='608'
    host.wrapper.component.attributes.add.assert_any_call('FindEZ','model_quality','unverified')
    args,triad=command();p.Created().notify(args)
    triad.hideAllScaling.assert_called_once();triad.setFlipVisibility.assert_called_once_with(False)
    p.Preview().notify(args);assert host.wrapper.transform2=='positioned'
    p.Destroyed().notify(args)
    host.wrapper.deleteMe.assert_called_once()
    assert p.pending is None and not p.command_handlers
    args.command.execute.remove.assert_called_once()


def test_confirm_keeps_component_and_repeated_commands_release_handlers(host):
    p=host.module
    for _ in range(3):
        p.insert(host.app,{'catalog_id':'canonical-part'},str(host.path),'inventory')
        args,_=command();p.Created().notify(args);p.Execute().notify(args);p.Destroyed().notify(args)
        assert not p.command_handlers
    host.wrapper.deleteMe.assert_not_called()


@pytest.mark.parametrize('failure',['empty_import','import_exception','command_failure'])
def test_failed_import_or_placement_start_rolls_back_wrapper(host,failure):
    if failure=='empty_import':host.app.importManager.importToTarget2.return_value=NS(count=0)
    if failure=='import_exception':host.app.importManager.importToTarget2.side_effect=RuntimeError('native failure')
    if failure=='command_failure':host.definition.execute.return_value=False
    with pytest.raises((ValueError,RuntimeError)):
        host.module.insert(host.app,{},str(host.path),'inventory')
    host.wrapper.deleteMe.assert_called_once()
    assert host.module.pending is None


def test_unsupported_format_never_creates_occurrence(host):
    bad=host.path.with_suffix('.stl');bad.write_bytes(b'fixture')
    with pytest.raises(ValueError):host.module.insert(host.app,{},str(bad),'inventory')
    host.app.activeProduct.rootComponent.occurrences.addNewComponent.assert_not_called()


def test_placement_ui_failure_cleans_import_and_explains_failure(host):
    p=host.module
    p.insert(host.app,{},str(host.path),'inventory')
    args,_=command();args.command.commandInputs.addTriadCommandInput.side_effect=RuntimeError('UI unavailable')
    p.Created().notify(args)
    host.wrapper.deleteMe.assert_called_once()
    host.app.userInterface.messageBox.assert_called_once()
    assert p.pending is None
    p.Destroyed().notify(args)
    assert not p.command_handlers


def test_failed_execute_does_not_commit_partial_placement(host):
    p=host.module
    p.insert(host.app,{},str(host.path),'inventory')
    args,_=command();p.Created().notify(args)
    host.app.activeProduct.snapshots.hasPendingSnapshot=True
    host.app.activeProduct.snapshots.add=Mock(side_effect=RuntimeError('Cannot snapshot'))
    p.Execute().notify(args)
    assert args.executeFailed and not p.pending['committed']
    p.Destroyed().notify(args)
    host.wrapper.deleteMe.assert_called_once()


def test_insert_current_component_copies_geometry_and_keeps_original_untouched(host):
    p=host.module
    original=NS(name='Source bearing',entityToken='source-token',attributes=Mock())
    occurrences=NS(addNewComponentCopy=Mock(return_value=object()), addByInsert=Mock())
    host.wrapper.component.occurrences=occurrences
    p.insert_model(host.app,{'name':'Bearing','item_id':'stock'},('component',original),'inventory')
    occurrences.addNewComponentCopy.assert_called_once_with(original,'identity')
    occurrences.addByInsert.assert_not_called()
    original.attributes.add.assert_not_called()
    host.wrapper.component.attributes.add.assert_any_call('FindEZ','inventory_item_id','stock')
    args,_=command();p.Created().notify(args);p.Destroyed().notify(args)
    host.wrapper.deleteMe.assert_called_once()


def test_saved_project_design_inserts_embedded_without_local_file(host):
    p=host.module
    host.app.activeProduct.parentDocument=NS(dataFile=NS(id='active'))
    cloud=NS(id='model',fileExtension='f3d',versionNumber=4)
    host.wrapper.component.occurrences=NS(addByInsert=Mock(return_value=object()))
    p.insert_model(host.app,{'catalog_id':'bearing'},('data_file',cloud),'inventory')
    host.wrapper.component.occurrences.addByInsert.assert_called_once_with(cloud,'identity',False)
    host.app.importManager.importToTarget2.assert_not_called()
    host.wrapper.component.attributes.add.assert_any_call('FindEZ','model_version','4')
    args,_=command();p.Created().notify(args);p.Execute().notify(args);p.Destroyed().notify(args)
    host.wrapper.deleteMe.assert_not_called()


def test_failed_project_model_insert_rolls_back(host):
    original=NS(entityToken='source-token')
    host.wrapper.component.occurrences=NS(addNewComponentCopy=Mock(return_value=None))
    with pytest.raises(ValueError): host.module.insert_model(host.app,{},('component',original),'inventory')
    host.wrapper.deleteMe.assert_called_once()
    assert host.module.pending is None

def test_native_handles_are_shown_with_measured_size(host):
    host.wrapper.preciseBoundingBox = NS(minPoint=NS(x=-1, y=0, z=0), maxPoint=NS(x=1, y=1, z=0.05))
    host.module.insert(host.app, {}, str(host.path), 'inventory')
    args, triad = command()
    host.module.Created().notify(args)
    assert triad.isVisible and triad.isEnabled
    args.command.commandInputs.addTextBoxCommandInput.assert_called_once_with(
        'findezModelSize', 'Model size', 'Initial solid extents (X × Y × Z): 20 × 10 × 0.5 mm', 2, True)
    host.module.Execute().notify(args)
    assert host.wrapper.transform2 == triad.positionTransform


@pytest.mark.parametrize('high', [0, -1, float('nan'), float('inf')])
def test_invalid_geometry_never_reports_measured_size(host, high):
    host.wrapper.preciseBoundingBox = NS(minPoint=NS(x=0,y=0,z=0), maxPoint=NS(x=high,y=1,z=2))
    assert 'unavailable' in host.module.measured_extents(host.wrapper)


@pytest.mark.parametrize('reason', ['invalid expression', 'design switched'])
def test_invalid_placement_cannot_commit(host, reason):
    host.module.insert(host.app, {}, str(host.path), 'inventory')
    args, triad = command()
    host.module.Created().notify(args)
    if reason == 'invalid expression':
        triad.isValidExpressions = False
    else:
        host.app.activeProduct = object()
    host.module.Execute().notify(args)
    assert args.executeFailed
    assert host.wrapper.transform2 == 'identity'
    host.module.Destroyed().notify(args)
    host.wrapper.deleteMe.assert_called_once()


def test_cancel_and_confirm_flow_through_real_bom_comparison(host):
    from copy import deepcopy
    from tests.test_cad_prototype import component, design, occurrence, exporter, stock
    from app.services.cad.snapshot import Snapshot
    from app.services.cad.comparison import compare

    model = design([], dirty=True)
    model.snapshots = NS(hasPendingSnapshot=False)
    host.app.activeProduct = model
    root = model.rootComponent.occurrences
    stock_item = stock(1, name='Bearing', part_number='608')
    inventory = [stock_item]
    initial_inventory = deepcopy(inventory)
    serial = 0

    def add_wrapper(transform):
        nonlocal serial
        serial += 1
        key = f'wrapper-{serial}'
        comp = component(key)
        def add_attribute(group, name, value):
            assert group == 'FindEZ'
            comp.attributes.values[name] = value
        comp.attributes.add = add_attribute
        instance = occurrence(comp, key)
        instance.transform2 = transform
        instance.isValid = True
        instance.deleteMe = lambda: root.values.remove(instance)
        root.values.append(instance)
        return instance

    def totals():
        snap = Snapshot.model_validate(exporter.extract(model, 'contract fixture'))
        rows = compare(snap, inventory, [], [])['items']
        return tuple(sum(row[field] for row in rows) for field in ('required', 'assigned', 'missing'))

    root.addNewComponent = add_wrapper
    for confirm, expected in [(False, (0, 0, 0)), (True, (1, 1, 0)), (True, (2, 1, 1))]:
        host.module.insert(host.app, stock_item, str(host.path), 'test-inventory')
        args, _ = command()
        host.module.Created().notify(args)
        host.module.Preview().notify(args)
        if confirm:
            host.module.Execute().notify(args)
        host.module.Destroyed().notify(args)
        assert totals() == expected
        assert inventory == initial_inventory


@pytest.mark.parametrize('confirm', [True, False])
def test_usage_recorded_once_only_on_confirm(host, confirm):
    record = Mock()
    host.module.insert(host.app, {}, str(host.path), 'inventory', on_confirm=record)
    args, _ = command()
    host.module.Created().notify(args)
    host.module.Preview().notify(args)
    if confirm:
        host.module.Execute().notify(args)
    record.assert_not_called()
    host.module.Destroyed().notify(args)
    host.module.Destroyed().notify(args)
    assert record.call_count == int(confirm)


def test_catalog_placement_uses_reviewed_source_and_exact_digest(host):
    import hashlib
    model = {'catalog_id':'variant', 'step_sha256':hashlib.sha256(host.path.read_bytes()).hexdigest(),
             'source':'manufacturer', 'revision':'A', 'units':'mm', 'source_url':'https://example.org/model'}
    host.module.insert(host.app, {'catalog_id':'variant'}, str(host.path), 'inv', catalog_model=model)
    host.wrapper.component.attributes.add.assert_any_call('FindEZ','model_quality','source_reviewed')
    host.wrapper.component.attributes.add.assert_any_call('FindEZ','procurement_policy','purchase')
    args, _ = command()
    host.module.Destroyed().notify(args)
    with pytest.raises(ValueError, match='no longer matches'):
        host.module.insert(host.app, {'catalog_id':'different'}, str(host.path), 'inv', catalog_model=model)
    assert host.module.pending is None
