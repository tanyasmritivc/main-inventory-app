"""Docked Fusion client. All adsk reads/writes remain on the main thread."""
import csv
import json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import threading
import time
import webbrowser
from uuid import UUID, uuid4
from urllib.parse import urlencode

import adsk.core
import adsk.fusion
from .client import Session, call, ClientError, search_path, download_step
from .exporter import extract
from . import placement
from .models import ModelBrowser

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
search_design=None
model_browser=ModelBrowser()
save_retry=None
generated_design=None
generated_jobs={}
library_choice=None


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
            result={'kind':'purchase_error' if kind=='purchase_saved' else 'error','data':{'message':str(exc),'status':exc.status},'generation':generation}
        except Exception:
            result={'kind':'purchase_error' if kind=='purchase_saved' else 'error','data':{'message':'The request could not be completed. Retry the same change.'},'generation':generation}
        if not stop_event.is_set():
            try:
                app.fireCustomEvent(EVENT,json.dumps(result))
            except RuntimeError:
                if result['kind'] in ('library_file','generated_file'): Path(result['data']['path']).unlink(missing_ok=True)
        elif result['kind'] in ('library_file','generated_file'):
            Path(result['data']['path']).unlink(missing_ok=True)
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
            return session.request_at(generation,'/session')
    raise ClientError('Connection canceled or expired. Start sign-in again.')


def require_cad_write():
    if not context or not context.get('allow_cad_writes'):
        raise ClientError('Disconnect and reconnect with permission to save CAD work and generate models.')
    if busy: raise ClientError('Wait for the current request to finish.')


def valid_offset(value):
    if type(value) is not int or not 0<=value<=10000: raise ClientError('Choose a valid history page.')
    return value


def compare_design(expected=None):
    global comparison
    if busy:
        raise ClientError('Wait for the current request to finish.')
    if not context:
        raise ClientError('Connect your inventory first.')
    design=adsk.fusion.Design.cast(app.activeProduct)
    if not design:
        raise ClientError('Open a Fusion design first, then ask again.')
    if expected is not None and design != expected:
        raise ClientError('The active design changed while search was running. Ask again for this design.')
    snapshot=extract(design,app.version)
    comparison=None
    send('comparison_started',{'name':snapshot['document']['name']})
    task('comparison',lambda generation:session.request_at(generation,'/compare',method='POST',data=snapshot))


def read_shortcuts(generation, path, ids):
    data = session.request_at(generation, path)
    rows = {part['item_id']: part for part in data['items']}
    # Older servers ignore the new filter. Never show unrelated inventory.
    if data.get('filtered_ids') is not True or rows.keys() - set(ids):
        raise ClientError('Update the FindEZ server to load saved and frequently used parts.')
    items = [rows[key] for key in ids if key in rows]
    return {**data, 'items': items, 'total': len(items), 'offset': 0, 'next_offset': None}


def usage_callback(part):
    active_generation = session.generation
    item_id = part.get('item_id')
    def record():
        if item_id and context and active_generation == session.generation:
            send('part_used', {'id': item_id})
    return record


class Result(adsk.core.CustomEventHandler):
    def notify(self,args):
        global busy,parts,comparison,context,save_retry,library_choice
        try:
            message=json.loads(args.additionalInfo)
            if message['generation']!=session.generation:
                if message['kind'] in ('generated_file', 'library_file'):
                    Path(message['data']['path']).unlink(missing_ok=True)
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
            elif kind=='search':
                if data.get('intent')=='compare_design':
                    if search_design is None:
                        raise ClientError('Open a Fusion design first, then ask again.')
                    compare_design(search_design)
                    return
                rows=data['items'] if data['source']=='inventory' else data['parts']
                parts={str(p.get('item_id') or p.get('catalog_id')):p for p in rows}
            elif kind=='purchase_csv':
                export_purchase(data)
                return
            elif kind=='version_saved':
                save_retry=None
                send('version_saved',data)
                send('notice',{'message':'BOM version '+str(data['version'])+' saved to this inventory.'})
                return
            elif kind=='correction_saved':
                compare_design()
                return
            elif kind in ('library_preview', 'library_file'):
                try:
                    if not library_choice or library_choice['design'] != adsk.fusion.Design.cast(app.activeProduct):
                        raise ClientError('The active design changed. Choose the catalog model again.')
                    if kind == 'library_preview':
                        model = data['model']
                        part = library_choice['part']
                        if model and (model['catalog_id'] != str(part['catalog_id'])
                                      or any(part.get(field) and part[field].strip().casefold() != model[key].strip().casefold()
                                             for field,key in [('part_number','part_number'), ('brand','manufacturer')])):
                            raise ClientError('The inventory identifiers differ from this catalog model. Review the part association.')
                        library_choice['model'] = model
                        send(kind, data)
                    else:
                        choice = library_choice
                        placement.insert(app, choice['part'], data['path'], context['inventory_id'],
                                         catalog_model=choice['model'], on_confirm=usage_callback(choice['part']))
                    return
                finally:
                    if kind == 'library_file':
                        Path(data['path']).unlink(missing_ok=True)
            elif kind=='generation_job':
                generated_jobs[data['id']]=data
            elif kind=='generated_file':
                try:
                    if generated_design != adsk.fusion.Design.cast(app.activeProduct) or not context:
                        raise ClientError('The active design changed. Insert the generated model again in the intended design.')
                    placement.insert(app,{'name':data['name']},data['path'],context['inventory_id'],generated_job=data['id'])
                finally:
                    Path(data['path']).unlink(missing_ok=True)
                send('notice',{'message':'Generated geometry is unverified. Check dimensions, position the copy and confirm. Cancel removes it.'})
                return
            elif kind=='version':
                comparison=data['comparison']
            elif kind=='comparison':
                comparison=data
            send(kind,data)
        except (ClientError,ValueError) as exc:
            busy=False
            send('busy',{'busy':False})
            send('error',{'message':str(exc)})
        except Exception:
            busy=False
            send('busy',{'busy':False})
            send('error',{'message':'The response could not be displayed. Try again.'})


class Incoming(adsk.core.HTMLEventHandler):
    def notify(self,args):
        global busy,parts,comparison,context,search_design,save_retry,generated_design,library_choice
        try:
            # Qt returns sendInfoToHTML acknowledgements through this same event.
            # They are not user commands. Replying to one creates an error loop.
            if args.action == 'response':
                return
            args.returnData = 'OK'
            if len(args.data or '')>70000:
                raise ClientError('This command is too large.')
            data=json.loads(args.data or '{}')
            if not isinstance(data,dict):
                raise ClientError('Invalid panel command.')
            action=args.action
            if action in ('inventory','inventory_shortcuts','catalog','search','models','disconnect'):
                library_choice = None
            if action=='ready':
                send('connected',context) if context else send('disconnected',{})
            elif action=='connect':
                if context:
                    raise ClientError('Disconnect before changing inventory.')
                task('pairing',begin_pair)
            elif action=='disconnect':
                token=session.clear()
                parts,comparison,context={},None,None
                search_design=None
                save_retry=None
                generated_jobs.clear()
                model_browser.clear()
                busy=False
                send('disconnected',{})
                if token:
                    task('notice',lambda generation:disconnect_remote(token))
            elif action in ('inventory','catalog'):
                if not context:
                    raise ClientError('Connect your inventory first.')
                path=search_path(action,data.get('q',''),data.get('offset',0),data.get('location'))
                parts={}
                model_browser.clear()
                task(action,lambda generation:session.request_at(generation,path))
            elif action=='inventory_shortcuts':
                ids = data.get('ids')
                if not context or busy or not isinstance(ids, list) or not 1 <= len(ids) <= 50:
                    raise ClientError('Reconnect and choose up to 50 saved or frequently used parts.')
                ids = [str(UUID(key)) for key in ids]
                path = '/inventory?' + urlencode({'item_id': ids}, doseq=True)
                parts = {}
                model_browser.clear()
                task('inventory', lambda generation: read_shortcuts(generation, path, ids))
            elif action=='search':
                query=data.get('query','')
                source=data.get('source','inventory')
                location=data.get('location')
                if not context or not isinstance(query,str) or not query.strip() or len(query)>500 or source not in ('inventory','catalog'):
                    raise ClientError('Connect an inventory and enter a parts question.')
                if location is not None and (not isinstance(location,str) or len(location)>512):
                    raise ClientError('Choose a saved location.')
                parts={}
                model_browser.clear()
                search_design=adsk.fusion.Design.cast(app.activeProduct)
                task('search',lambda generation:session.request_at(generation,'/search',method='POST',data={'query':query,'source':source,'location':location}))
            elif action=='models':
                part=parts.get(str(data.get('id')))
                if not part or not context or busy or placement.pending is not None:
                    raise ClientError('Finish placement or search again and choose a current part.')
                result=model_browser.browse(app,part,context['inventory_id'],data.get('mode','design'),data.get('folder_id'),data.get('offset',0))
                result['has_catalog_identity'] = bool(context.get('model_library_enabled') and part.get('catalog_id'))
                send('models',result)
            elif action == 'library_preview':
                part = parts.get(str(data.get('id')))
                if busy or not context or not context.get('model_library_enabled') or not part or not part.get('catalog_id'):
                    raise ClientError('Choose a current catalog-linked part first.')
                design = adsk.fusion.Design.cast(app.activeProduct)
                if not design or design != model_browser.design or model_browser.part_id != str(data.get('id')):
                    raise ClientError('Reopen the model picker for the active design.')
                library_choice = {'design':design, 'part':part, 'model':None}
                path = '/catalog/' + str(UUID(str(part['catalog_id']))) + '/model'
                task('library_preview', lambda generation: session.request_at(generation, path))
            elif action == 'library_insert':
                choice = library_choice
                if (busy or not context or not choice or not choice['model'] or data.get('confirmed') is not True
                        or placement.pending is not None or choice['design'] != adsk.fusion.Design.cast(app.activeProduct)):
                    raise ClientError('Review the exact model again before insertion.')
                model = choice['model']
                path = '/catalog/' + model['catalog_id'] + '/model/' + model['revision_id'] + '/' + model['step_sha256']
                token = session.token
                task('library_file', lambda generation: {'path': download_step(path,token)})
            elif action=='insert_model':
                part=parts.get(str(data.get('id')))
                if not part or not context or busy or data.get('confirmed') is not True:
                    raise ClientError('Choose a current part and confirm the selected model matches it.')
                model=model_browser.resolve(app,part,context['inventory_id'],data.get('model_id'))
                placement.insert_model(app,part,model,context['inventory_id'], on_confirm=usage_callback(part))
                send('notice',{'message':'Position the component with the handles and confirm. Cancel removes this copy. Refresh BOM afterward.'})
            elif action=='compare':
                compare_design()
            elif action=='save_version':
                require_cad_write()
                design=adsk.fusion.Design.cast(app.activeProduct)
                if not design: raise ClientError('Open a saved Fusion design first.')
                snapshot=extract(design,app.version)
                if snapshot['document']['external_id'].startswith('unsaved:'):
                    raise ClientError('Save this design to a Fusion project first.')
                # Retain the exact snapshot for a failed save, so retry cannot duplicate it.
                if save_retry is None:
                    save_retry={'request_id':str(uuid4()),'snapshot':snapshot}
                elif save_retry['snapshot']['document']['external_id']!=snapshot['document']['external_id']:
                    raise ClientError('Return to the design with the pending save, or disconnect before starting another save.')
                task('version_saved',lambda generation:session.request_at(generation,'/bom/versions',method='POST',data=save_retry))
            elif action=='versions':
                task('versions',lambda generation:session.request_at(generation,'/bom/versions?offset='+str(valid_offset(data.get('offset',0)))))
            elif action=='version':
                key=str(UUID(data.get('id','')))
                task('version',lambda generation:session.request_at(generation,'/bom/versions/'+key))
            elif action=='correct':
                require_cad_write()
                line=next((r for r in (comparison or {}).get('items',[]) if r['key']==data.get('key')),None)
                if not line or not line.get('review_token'): raise ClientError('Compare the current design before correcting its match.')
                decision=data.get('decision')
                if decision not in ('match','no_match','reset'): raise ClientError('Choose a match decision.')
                item=data.get('item_id') if decision=='match' else None
                if decision=='match' and item not in {str(r['item_id']) for r in line.get('candidates',[])}:
                    raise ClientError('Choose one of the current inventory candidates.')
                payload={'review_token':line['review_token'],'decision':decision,'item_id':item}
                task('correction_saved',lambda generation:session.request_at(generation,'/bom/corrections',method='POST',data=payload))
            elif action.startswith('purchase_'):
                if not context or not context.get('allow_purchasing'):
                    raise ClientError('Reconnect and enable optional purchase plans and receiving.')
                if action=='purchase_list':
                    path='/purchases?offset='+str(valid_offset(data.get('offset',0)))
                    task('purchase_list',lambda generation:session.request_at(generation,path))
                elif action=='purchase_detail':
                    key=str(UUID(data.get('id','')))
                    task('purchase_detail',lambda generation:session.request_at(generation,'/purchases/'+key))
                elif action=='purchase_candidates':
                    q=data.get('q','')
                    if not isinstance(q,str) or not 2<=len(q)<=100: raise ClientError('Enter 2 to 100 characters to find the delivery destination.')
                    task('purchase_candidates',lambda generation:session.request_at(generation,'/purchase-candidates?'+urlencode({'q':q})))
                elif action=='purchase_write':
                    payload=data.get('body')
                    if not isinstance(payload,dict): raise ClientError('Choose a valid purchase action.')
                    UUID(payload.get('request_id',''))
                    path='/purchases'
                    if data.get('id'): path+='/'+str(UUID(data['id']))+'/actions'
                    task('purchase_saved',lambda generation:session.request_at(generation,path,method='POST',data=payload))
                elif action=='purchase_export':
                    key=str(UUID(data.get('id','')))
                    task('purchase_csv',lambda generation:session.request_at(generation,'/purchases/'+key))
                else:
                    raise ClientError('Choose a supported purchase action.')
            elif action=='plan_projects':
                ids=data.get('version_ids',[])
                if not isinstance(ids,list) or not 1<=len(ids)<=20: raise ClientError('Choose up to twenty saved projects.')
                payload={'version_ids':[str(UUID(key)) for key in ids]}
                task('planning',lambda generation:session.request_at(generation,'/bom/planning',method='POST',data=payload))
            elif action=='revision_diff':
                query=urlencode({k:str(UUID(data.get(k,''))) for k in ('before','after')})
                task('revision_diff',lambda generation:session.request_at(generation,'/bom/revision-diff?'+query))
            elif action=='generate':
                require_cad_write()
                if data.get('confirmed') is not True: raise ClientError('Confirm the specifications and external generation first.')
                payload={k:data.get(k) for k in ('prompt','name','units','request_id','confirmed')}
                UUID(payload['request_id'])
                task('generation_job',lambda generation:session.request_at(generation,'/generation/jobs',method='POST',data=payload))
            elif action=='generation_jobs':
                task('generation_jobs',lambda generation:session.request_at(generation,'/generation/jobs'))
            elif action in ('generation_status','generation_resume','generation_cancel','generation_answer','generation_insert'):
                key=str(UUID(data.get('id','')))
                path='/generation/jobs/'+key
                if action=='generation_status':
                    task('generation_job',lambda generation:session.request_at(generation,path))
                elif action=='generation_insert':
                    if busy or not context: raise ClientError('Wait for the current request, then try insertion again.')
                    job=generated_jobs.get(key)
                    if not job or job.get('state')!='succeeded' or data.get('confirmed') is not True:
                        raise ClientError('Refresh the model and confirm you will check its dimensions before insertion.')
                    generated_design=adsk.fusion.Design.cast(app.activeProduct)
                    if not generated_design or placement.pending is not None: raise ClientError('Open a design and finish the current placement first.')
                    token=session.token
                    task('generated_file',lambda generation:{'id':key,'name':job['name'],'path':download_step(path+'/download',token)})
                else:
                    require_cad_write()
                    suffix={'generation_resume':'/resume','generation_cancel':'/cancel','generation_answer':'/answers'}[action]
                    payload={k:data.get(k) for k in ('version','question_id','answer','request_id')} if action=='generation_answer' else None
                    task('generation_job',lambda generation:session.request_at(generation,path+suffix,method='POST',data=payload))
            elif action=='insert_local':
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
                    placement.insert(app,part,dialog.filename,context['inventory_id'], on_confirm=usage_callback(part))
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
    definition=definitions.itemById(COMMAND) or definitions.addButtonDefinition(COMMAND,'Open FindEZ','AI search, insert Fusion project models and compare your assembly.')
    attach(definition.commandCreated,Created())
    panel=app.userInterface.allToolbarPanels.itemById('SolidScriptsAddinsPanel')
    if not panel:
        raise RuntimeError('Open the Design workspace first.')
    if not panel.controls.itemById(COMMAND):
        panel.controls.addCommand(definition)


def stop():
    global palette,executor,context,parts,comparison,busy,search_design,save_retry,generated_design,generated_jobs,library_choice
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
    search_design=None
    save_retry,generated_design,generated_jobs,library_choice=None,None,{},None
    model_browser.clear()
    handlers.clear()


def export_purchase(plan):
    dialog=app.userInterface.createFileDialog()
    dialog.title='Export purchase plan by vendor'
    dialog.filter='CSV (*.csv)'
    dialog.initialFilename='findez-purchase-plan.csv'
    if dialog.showSave()!=adsk.core.DialogResults.DialogOK: return
    def cell(value):
        text=str(value if value is not None else '')
        return "'"+text if text.lstrip().startswith(('=','+','-','@')) else text
    with open(dialog.filename,'w',newline='',encoding='utf-8-sig') as stream:
        writer=csv.writer(stream)
        writer.writerow(['Vendor','Part','Part number','Required shortage','Order quantity','Received','Currency','Subtotal excluding tax/shipping','Source','Catalog ID','Required specifications'])
        for line in sorted(plan['lines'],key=lambda row:(row.get('selected_quote') or {}).get('vendor','')):
            quote=line.get('selected_quote') or {}; estimate=quote.get('estimate') or {}
            writer.writerow([cell(v) for v in [quote.get('vendor'),line['name'],line.get('part_number'),line['quantity'],
                estimate.get('order_quantity'),line['received'],quote.get('currency'),estimate.get('subtotal'),quote.get('product_url'),line.get('catalog_id'),json.dumps(line.get('specifications') or {},sort_keys=True)]])
    send('notice',{'message':'Purchase plan exported. No order was placed.'})
