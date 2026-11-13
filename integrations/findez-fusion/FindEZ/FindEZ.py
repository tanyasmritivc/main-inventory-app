"""Fusion command: export a local snapshot; upload only from signed-in FindEZ."""

import json
from pathlib import Path

import adsk.core
import adsk.fusion
from .exporter import extract

COMMAND_ID = 'FindEZExportBOM'
handlers = []
control = None
definition = None


class Execute(adsk.core.CommandEventHandler):
    def notify(self, args):
        app = adsk.core.Application.get()
        ui = app.userInterface
        try:
            design = adsk.fusion.Design.cast(app.activeProduct)
            if not design:
                ui.messageBox('Open a Fusion design first.', 'FindEZ')
                return
            snapshot = extract(design, app.version)
            dialog = ui.createFileDialog()
            dialog.title = 'Save FindEZ BOM - local export only'
            dialog.filter = 'FindEZ BOM (*.json)'
            dialog.initialFilename = 'findez-bom.json'
            if dialog.showSave() != adsk.core.DialogResults.DialogOK:
                return
            Path(dialog.filename).write_text(json.dumps(snapshot, indent=2), encoding='utf-8')
            ui.messageBox('BOM exported locally. Open FindEZ /cad, select an inventory, and upload this JSON to compare. '
                          'The CAD assembly and geometry were not uploaded. '
                          + ('This export has warnings; review them before relying on its counts.' if snapshot['warnings'] else ''),
                          'FindEZ BOM exported')
        except ValueError as exc:
            ui.messageBox(str(exc), 'FindEZ export needs attention')
        except Exception:
            # Do not expose design contents, local paths or credentials in errors.
            ui.messageBox('The export could not be completed. Check the design references and destination folder, then retry.', 'FindEZ')


class Created(adsk.core.CommandCreatedEventHandler):
    def notify(self, args):
        handler = Execute()
        args.command.execute.add(handler)
        handlers.append(handler)


def run(context):
    global control, definition
    ui = adsk.core.Application.get().userInterface
    try:
        definition = ui.commandDefinitions.itemById(COMMAND_ID)
        if not definition:
            definition = ui.commandDefinitions.addButtonDefinition(COMMAND_ID, 'Export FindEZ BOM',
                                                                   'Export component metadata for inventory comparison.')
        handler = Created()
        definition.commandCreated.add(handler)
        handlers.append(handler)
        panel = ui.allToolbarPanels.itemById('SolidScriptsAddinsPanel')
        if panel is None:
            raise RuntimeError('Design utilities panel is unavailable.')
        control = panel.controls.itemById(COMMAND_ID) or panel.controls.addCommand(definition)
    except Exception:
        stop(context)
        ui.messageBox('Open the Design workspace, then start FindEZ again.', 'FindEZ')


def stop(context):
    global control, definition
    if control and control.isValid:
        control.deleteMe()
    if definition and definition.isValid:
        definition.deleteMe()
    control, definition = None, None
    handlers.clear()
