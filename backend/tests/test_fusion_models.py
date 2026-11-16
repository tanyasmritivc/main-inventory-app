import importlib.util
from pathlib import Path
from types import ModuleType, SimpleNamespace as NS
from unittest.mock import Mock
import sys
import pytest


def collection(items): return NS(count=len(items), item=lambda index:items[index])


@pytest.fixture
def browser(monkeypatch):
    adsk=ModuleType('adsk');fusion=ModuleType('adsk.fusion');adsk.fusion=fusion
    fusion.Design=NS(cast=lambda value:value)
    monkeypatch.setitem(sys.modules,'adsk',adsk);monkeypatch.setitem(sys.modules,'adsk.fusion',fusion)
    path=Path(__file__).resolve().parents[2]/'integrations/findez-fusion/FindEZ/models.py'
    spec=importlib.util.spec_from_file_location('models_test',path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    root=object(); component=NS(name='Bearing',attributes=NS(itemByName=lambda *a:None),isValid=True)
    design=NS(rootComponent=root,allComponents=collection([root,component]),parentDocument=NS(dataFile=None))
    return module.ModelBrowser(),NS(activeProduct=design),component


def test_current_model_has_opaque_id_and_requires_same_design_part_inventory(browser):
    picker,app,component=browser
    page=picker.browse(app,{'item_id':'part','name':'Bearing'},'inv')
    assert len(page['models'])==1 and page['mode']=='design'
    key=page['models'][0]['id']
    assert picker.resolve(app,{'item_id':'part'},'inv',key)==('component',component)
    with pytest.raises(ValueError):picker.resolve(app,{'item_id':'other'},'inv',key)
    assert not picker.models


def test_refresh_invalidates_old_model_choices(browser):
    picker,app,_=browser
    first=picker.browse(app,{'item_id':'part'},'inv')['models'][0]['id']
    picker.browse(app,{'item_id':'part'},'inv')
    with pytest.raises(ValueError):picker.resolve(app,{'item_id':'part'},'inv',first)


def test_unsaved_design_explains_project_requirement(browser):
    picker,app,_=browser
    page=picker.browse(app,{'item_id':'part'},'inv','project')
    assert page['models']==[] and 'Save this design' in page['note']


def test_project_folder_browsing_excludes_active_design_and_non_models(browser):
    picker,app,_=browser
    file=NS(id='bearing',name='Bearing model',fileExtension='f3d',versionNumber=2)
    child=NS(name='Parts',dataFolders=collection([]),dataFiles=collection([file]))
    folder=NS(name='Robot project',dataFolders=collection([child]),dataFiles=collection([
        NS(id='active',fileExtension='f3d'), NS(id='image',fileExtension='png')]))
    app.activeProduct.parentDocument.dataFile=NS(id='active',parentProject=NS(rootFolder=folder))
    page=picker.browse(app,{'item_id':'part'},'inv','project')
    assert page['models']==[] and len(page['folders'])==1
    nested=picker.browse(app,{'item_id':'part'},'inv','project',page['folders'][0]['id'])
    assert nested['parent']==page['folder_id'] and nested['models'][0]['version']==2
    assert picker.resolve(app,{'item_id':'part'},'inv',nested['models'][0]['id'])==('data_file',file)


def test_design_switch_blocks_stale_model_insertion(browser):
    picker,app,_=browser
    key=picker.browse(app,{'item_id':'part'},'inv')['models'][0]['id']
    app.activeProduct=object()
    with pytest.raises(ValueError):picker.resolve(app,{'item_id':'part'},'inv',key)
