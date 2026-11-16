"""Docked Fusion client. All adsk reads/writes remain on the main thread."""
import csv
import json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import threading
import time
import webbrowser

import adsk.core
import adsk.fusion
from .client import Session, call, ClientError, search_path
from .exporter import extract
from . import placement

PALETTE='FindEZWorkspace'
EVENT='FindEZWorkspaceResult'
COMMAND='FindEZOpenWorkspace'
handlers=[]
app=None
palette=None
executor=None
session=Session()
stop_event=threading.Event()
parts={}
comparison=None
context=None
busy=False


def attach(event,handler):
    event.add(handler)
    handlers.append(handler)


def send(kind,data):
    if palette and palette.isValid:
        palette.sendInfoToHTML(kind,json.dumps(data,allow_nan=False))


def task(kind,fn):
    global busy
    if busy:
        raise ClientError('Wait for the current request to finish.')
    busy=True
    generation=session.generation
    send('busy',{'busy':True})
    def work():
        try:
            data=fn(generation)
            result={'kind':kind,'data':data,'generation':generation}
        except ClientError as exc:
            result={'kind':'error','data':{'message':str(exc)},'generation':generation}
        except Exception:
            result={'kind':'error','data':{'message':'The request could not be completed. Try again.'},'generation':generation}
        if not stop_event.is_set():
            try:
                app.fireCustomEvent(EVENT,json.dumps(result))
            except RuntimeError:
                pass  # Fusion may have unloaded the add-in while the request ended.
    executor.submit(work)


def open_panel():
    global palette
    if palette and palette.isValid:
        palette.isVisible=True
        return
    # Fusion's embedded browser needs a URL, not a Windows drive/backslash path.
    # as_uri also escapes spaces, Unicode, # and % in the installation folder.
    html_url=Path(__file__).resolve().with_name('palette.html').as_uri()
    palette=app.userInterface.palettes.add(PALETTE,'FindEZ',html_url,False,True,True,400,700,True)
    attach(palette.incomingFromHTML,Incoming())
    palette.dockingState=adsk.core.PaletteDockingStates.PaletteDockStateRight
    palette.isVisible=True


def disconnect_remote(token):
    try:
        call('/session',method='DELETE',token=token)
    except ClientError:
        raise ClientError('Signed out locally, but server revocation failed. Revoke the connection at findez.ai/cad/fusion/connect or wait for its eight-hour expiry.') from None
    return {'message':'Disconnected from FindEZ.'}


def begin_pair(generation):
    return call('/pairing',method='POST')


def wait_pair(device,generation):
    deadline=time.monotonic()+600
    while time.monotonic()<deadline and not stop_event.wait(5) and generation==session.generation:
        result=call('/pairing/poll',method='POST',data={'device_code':device})
        if result['status']=='expired':
            raise ClientError('Connection expired. Start sign-in again.')
        if result['status']=='connected':
            if not session.connect(result['access_token'],generation):
                # A late approved session cannot restore a disconnected account.
                call('/session',method='DELETE',token=result['access_token'])
                return {}
            return session.request('/session')
    raise ClientError('Connection canceled or expired. Start sign-in again.')


class Result(adsk.core.CustomEventHandler):
    def notify(self,args):
        global busy,parts,comparison,context
        try:
            message=json.loads(args.additionalInfo)
            if message['generation']!=session.generation:
                return
            busy=False
            send('busy',{'busy':False})
            kind,data=message['kind'],message['data']
            if kind=='pairing':
                code=data['user_code']
                # Never send the device secret or bearer token to the HTML page.
                send('pairing',{'code':code})
                webbrowser.open('https://www.findez.ai/cad/fusion/connect?code='+code)
                task('connected',lambda generation:wait_pair(data['device_code'],generation))
                return
            if kind=='connected':
                context=data
            elif kind=='inventory':
                parts={str(p['item_id']):p for p in data['items']}
            elif kind=='catalog':
                parts={str(p['catalog_id']):p for p in data['parts']}
            elif kind=='comparison':
                comparison=data
            send(kind,data)
        except Exception:
            busy=False
            send('busy',{'busy':False})
            send('error',{'message':'The response could not be displayed. Try again.'})


class Incoming(adsk.core.HTMLEventHandler):
    def notify(self,args):
        global busy,parts,comparison,context
        try:
            if len(args.data or '')>4096:
                raise ClientError('This command is too large.')
            data=json.loads(args.data or '{}')
            if not isinstance(data,dict):
                raise ClientError('Invalid panel command.')
            action=args.action
            if action=='ready':
                send('connected',context) if context else send('disconnected',{})
            elif action=='connect':
                if context:
                    raise ClientError('Disconnect before changing inventory.')
                task('pairing',begin_pair)
            elif action=='disconnect':
                token=session.clear()
                parts,comparison,context={},None,None
                busy=False
                send('disconnected',{})
                if token:
                    task('notice',lambda generation:disconnect_remote(token))
            elif action in ('inventory','catalog'):
                if not context:
                    raise ClientError('Connect your inventory first.')
                path=search_path(action,data.get('q',''),data.get('offset',0),data.get('location'))
                parts={}
                task(action,lambda generation:session.request(path))
            elif action=='compare':
                if not context:
                    raise ClientError('Connect your inventory first.')
                design=adsk.fusion.Design.cast(app.activeProduct)
                if not design:
                    raise ClientError('Open a Fusion design first.')
                snapshot=extract(design,app.version)
                comparison=None
                task('comparison',lambda generation:session.request('/compare',method='POST',data=snapshot))
            elif action=='insert':
                part=parts.get(str(data.get('id')))
                if not part or not context or busy:
                    raise ClientError('Search again and choose a current part.')
                ui=app.userInterface
                if ui.messageBox('Choose an existing STEP or F3D file for this exact part. FindEZ has not verified its geometry, dimensions, material or compatibility. Check the model before engineering use. Inserting does not reserve or consume stock. Continue?', 'Insert local CAD model', adsk.core.MessageBoxButtonTypes.YesNoButtonType)!=adsk.core.DialogResults.DialogYes:
                    return
                dialog=ui.createFileDialog()
                dialog.title='Choose a CAD model for '+str(part.get('name') or part.get('canonical_name'))
                dialog.filter='CAD files (*.step;*.stp;*.f3d)'
                if dialog.showOpen()==adsk.core.DialogResults.DialogOK:
                    placement.insert(app,part,dialog.filename,context['inventory_id'])
                    send('notice',{'message':'Use the placement handles and confirm. Local model geometry is unverified. Refresh the BOM after placement.'})
            elif action=='export':
                if not comparison:
                    raise ClientError('Compare the current assembly first.')
                dialog=app.userInterface.createFileDialog()
                dialog.title='Export FindEZ shortages'
                dialog.filter='CSV (*.csv)'
                dialog.initialFilename='findez-shortages.csv'
                if dialog.showSave()!=adsk.core.DialogResults.DialogOK:
                    return
                with open(dialog.filename,'w',encoding='utf-8-sig',newline='') as output:
                    writer=csv.writer(output)
                    writer.writerow(['Part','Manufacturer','Part number','Required','Assigned','Shortage','Status'])
                    for row in comparison['items']:
                        if not row['missing'] and row['status']!='needs_review':
                            continue
                        values=[row[k] for k in ('name','manufacturer','part_number','required','assigned','missing','status')]
                        writer.writerow(["'"+v if isinstance(v,str) and v.lstrip().startswith(('=','+','-','@')) else v for v in values])
                send('notice',{'message':'Shortages exported. Review uncertain matches before ordering.'})
            else:
                raise ClientError('Unsupported panel command.')
        except (ClientError,ValueError) as exc:
            send('error',{'message':str(exc)})
        except Exception:
            send('error',{'message':'Fusion could not complete this action. Check the active design and try again.'})


class Open(adsk.core.CommandEventHandler):
    def notify(self,args):
        open_panel()

class Created(adsk.core.CommandCreatedEventHandler):
    def notify(self,args):
        attach(args.command.execute,Open())


def run():
    global app,executor
    app=adsk.core.Application.get()
    stop_event.clear()
    executor=ThreadPoolExecutor(max_workers=2,thread_name_prefix='FindEZ')
    attach(app.registerCustomEvent(EVENT),Result())
    definitions=app.userInterface.commandDefinitions
    definition=definitions.itemById(COMMAND) or definitions.addButtonDefinition(COMMAND,'Open FindEZ','Browse inventory, insert local CAD and compare your assembly.')
    attach(definition.commandCreated,Created())
    panel=app.userInterface.allToolbarPanels.itemById('SolidScriptsAddinsPanel')
    if not panel:
        raise RuntimeError('Open the Design workspace first.')
    if not panel.controls.itemById(COMMAND):
        panel.controls.addCommand(definition)


def stop():
    global palette,executor,context,parts,comparison,busy
    stop_event.set()
    token=session.clear()
    if executor:
        if token:
            executor.submit(lambda:call('/session',method='DELETE',token=token))
        executor.shutdown(wait=False,cancel_futures=False)
        executor=None
    if app:
        placement.stop(app.userInterface)
        panel=app.userInterface.allToolbarPanels.itemById('SolidScriptsAddinsPanel')
        control=panel.controls.itemById(COMMAND) if panel else None
        if control: control.deleteMe()
        definition=app.userInterface.commandDefinitions.itemById(COMMAND)
        if definition: definition.deleteMe()
        app.unregisterCustomEvent(EVENT)
    if palette and palette.isValid:
        palette.deleteMe()
    palette,context,parts,comparison,busy=None,None,{},None,False
    handlers.clear()
