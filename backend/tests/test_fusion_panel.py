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


@pytest.mark.parametrize('payload', ['OK', '{}', '{"status":"OK"}', '', 'x' * 5000],
                         ids=['plain', 'empty-object', 'json', 'empty-string', 'large'])
def test_qt_acknowledgements_do_not_reenter_command_dispatch(workspace, monkeypatch, payload):
    module, _ = workspace
    sent, task = Mock(), Mock()
    monkeypatch.setattr(module, 'send', sent)
    monkeypatch.setattr(module, 'task', task)
    module.Incoming().notify(NS(action='response', data=payload))
    sent.assert_not_called()
    task.assert_not_called()


def test_sign_in_queues_pairing_once_despite_qt_acknowledgement(workspace, monkeypatch):
    module, panel = workspace
    module.open_panel()
    module.executor = NS(submit=Mock())
    incoming = module.Incoming()
    def acknowledge(kind, payload):
        incoming.notify(NS(action='response', data='OK'))
    panel.sendInfoToHTML = Mock(side_effect=acknowledge)
    args = NS(action='connect', data='{}')
    incoming.notify(args)
    module.executor.submit.assert_called_once()
    assert module.busy
    panel.sendInfoToHTML.assert_called_once_with('busy', '{"busy": true}')
    assert args.returnData == 'OK'


def test_pairing_opens_browser_without_acknowledgement_errors(workspace, monkeypatch):
    import json
    module, panel = workspace
    module.open_panel()
    incoming = module.Incoming()
    panel.sendInfoToHTML = Mock(side_effect=lambda kind, payload:
                               incoming.notify(NS(action='response', data='{}')))
    open_browser, task = Mock(), Mock()
    monkeypatch.setattr(module.webbrowser, 'open', open_browser)
    monkeypatch.setattr(module, 'task', task)
    module.Result().notify(NS(additionalInfo=json.dumps({
        'kind': 'pairing', 'generation': module.session.generation,
        'data': {'user_code': 'ABCD-EFGH', 'device_code': 'private-device-fixture'},
    })))
    open_browser.assert_called_once_with('https://www.findez.ai/cad/fusion/connect?code=ABCD-EFGH')
    assert task.call_args.args[0] == 'connected'
    assert [call.args[0] for call in panel.sendInfoToHTML.call_args_list] == ['busy', 'pairing']
    assert 'private-device-fixture' not in str(panel.sendInfoToHTML.call_args_list)


def test_unrecognized_user_commands_still_report_an_error(workspace, monkeypatch):
    module, _ = workspace
    sent = Mock()
    monkeypatch.setattr(module, 'send', sent)
    module.Incoming().notify(NS(action='not-a-command', data='{}'))
    sent.assert_called_once_with('error', {'message': 'Unsupported panel command.'})


def test_ai_search_uses_only_current_session_and_clears_stale_parts(workspace, monkeypatch):
    module,_=workspace
    module.context={'inventory_id':'inventory'}
    module.parts={'old':{'item_id':'old'}}
    task=Mock();request=Mock(return_value={})
    monkeypatch.setattr(module,'task',task);monkeypatch.setattr(module.session,'request',request)
    module.Incoming().notify(NS(action='search',data='{"query":"Find 12 bearings","source":"inventory"}'))
    assert module.parts=={}
    assert task.call_args.args[0]=='search'
    task.call_args.args[1](module.session.generation)
    request.assert_called_once_with('/search',method='POST',data={'query':'Find 12 bearings','source':'inventory','location':None})


def test_native_insert_requires_explicit_model_confirmation(workspace,monkeypatch):
    module,_=workspace
    module.context={'inventory_id':'inventory'};module.parts={'part':{'item_id':'part'}}
    insert=Mock();monkeypatch.setattr(module.placement,'insert_model',insert)
    sent=Mock();monkeypatch.setattr(module,'send',sent)
    module.Incoming().notify(NS(action='insert_model',data='{"id":"part","model_id":"opaque","confirmed":false}'))
    insert.assert_not_called()
    assert sent.call_args.args[0]=='error'
