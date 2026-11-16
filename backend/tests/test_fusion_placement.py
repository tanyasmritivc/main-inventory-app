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
    triad=NS(transform='positioned',setFullVisibility=Mock(),hideAllScaling=Mock(),setFlipVisibility=Mock())
    inputs=NS(addTriadCommandInput=Mock(return_value=triad),itemById=Mock(return_value=triad))
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
