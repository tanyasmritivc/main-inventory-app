"""Panel URL contract tests. Native Fusion browser acceptance remains separate."""
import importlib
from pathlib import Path, PurePosixPath, PureWindowsPath
import sys
from types import ModuleType, SimpleNamespace as NS
from unittest.mock import Mock

import pytest


@pytest.fixture
def workspace(monkeypatch):
    core = ModuleType('adsk.core')
    fusion = ModuleType('adsk.fusion')
    adsk = ModuleType('adsk')
    adsk.core, adsk.fusion = core, fusion
    for name in ('CommandCreatedEventHandler', 'CommandEventHandler',
                 'CustomEventHandler', 'HTMLEventHandler'):
        setattr(core, name, type(name, (), {}))
    core.PaletteDockingStates = NS(PaletteDockStateRight='right')
    package = ModuleType('findez_panel_test')
    package.__path__ = [str(Path(__file__).resolve().parents[2] /
                            'integrations/findez-fusion/FindEZ')]
    for name, module in [('adsk', adsk), ('adsk.core', core),
                         ('adsk.fusion', fusion), ('findez_panel_test', package)]:
        monkeypatch.setitem(sys.modules, name, module)
    module = importlib.import_module('findez_panel_test.workspace')
    panel = NS(isValid=True, incomingFromHTML=Mock(), isVisible=False)
    module.app = NS(userInterface=NS(palettes=NS(add=Mock(return_value=panel))))
    yield module, panel
    for name in list(sys.modules):
        if name.startswith('findez_panel_test.'):
            sys.modules.pop(name, None)


@pytest.mark.parametrize('path,expected', [
    (PureWindowsPath(r'C:\Users\Tanya\Downloads\FindEZ workspace (2)\FindEZ\workspace.py'),
     'file:///C:/Users/Tanya/Downloads/FindEZ%20workspace%20%282%29/FindEZ/palette.html'),
    (PureWindowsPath('C:/Users/Tanyá/Downloads/CAD #1 100%/FindEZ/workspace.py'),
     'file:///C:/Users/Tany%C3%A1/Downloads/CAD%20%231%20100%25/FindEZ/palette.html'),
    (PurePosixPath('/Users/tanya/Downloads/FindEZ workspace/FindEZ/workspace.py'),
     'file:///Users/tanya/Downloads/FindEZ%20workspace/FindEZ/palette.html'),
])
def test_panel_loads_encoded_local_file_url(workspace, monkeypatch, path, expected):
    module, panel = workspace
    monkeypatch.setattr(module, 'Path', lambda value: NS(resolve=lambda: path))
    module.open_panel()
    assert module.app.userInterface.palettes.add.call_args.args[2] == expected
    panel.incomingFromHTML.add.assert_called_once()
    assert panel.isVisible and panel.dockingState == 'right'


def test_reopening_panel_preserves_existing_session(workspace):
    module, panel = workspace
    module.open_panel()
    panel.isVisible = False
    module.open_panel()
    module.app.userInterface.palettes.add.assert_called_once()
    panel.incomingFromHTML.add.assert_called_once()
    assert panel.isVisible
