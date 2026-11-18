"""Live gateway, fictional records, no database reads/writes or saved conversations."""
import json,os,sys,time
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4
import subprocess
# Read server configuration without emitting any environment or credentials.
pid=subprocess.check_output(['systemctl','show','findez','-p','MainPID','--value'],text=True).strip()
for pair in Path('/proc/'+pid+'/environ').read_bytes().split(b'\0'):
 if b'=' in pair:
  k,v=pair.split(b'=',1);os.environ[k.decode()]=v.decode()
sys.path.insert(0,'/tmp/findez-chat-readout-20261118/backend')
from app.services import world_chat as world
from app.services.chat_capture import use_capture
from app.services import completion_stream as cs
original_prefix=cs.public_text_prefix
def diagnostic_prefix(text,**kw):
 try:return original_prefix(text,**kw)
 except cs.CompletionStreamError:
  m=cs._CONTROL_MARKUP.search(text)
  print(json.dumps({'bad_markup':m.group(0) if m else 'prefix','position':m.start() if m else -1,'length':len(text)}),flush=True)
  raise
cs.public_text_prefix=diagnostic_prefix
from app.core.config import get_settings
import httpx
from urllib.parse import urlparse
settings=get_settings();gateway=urlparse(str(settings.findez_agent_base_url)).netloc
original_send=httpx.Client.send
def guarded_send(self,request,*args,**kwargs):
 assert request.url.netloc.decode()==gateway, 'Probe blocked non-gateway network request'
 return original_send(self,request,*args,**kwargs)
ACTOR='10000000-0000-0000-0000-000000000001'; ORG='20000000-0000-0000-0000-000000000001'
I1='30000000-0000-0000-0000-000000000001'; I2='30000000-0000-0000-0000-000000000002'
items=[{'item_id':'40000000-0000-0000-0000-000000000001','name':'Gear 30T M0.8','quantity':8,'location':'Workshop','inventory_id':I1,'inventory_name':'Workshop'},
 {'item_id':'40000000-0000-0000-0000-000000000002','name':'Servo Gear 40T','quantity':5,'location':'Storage','inventory_id':I2,'inventory_name':'Storage'},
 {'item_id':'40000000-0000-0000-0000-000000000003','name':'Miter Gear 24T','quantity':3,'location':'Storage','inventory_id':I2,'inventory_name':'Storage'}]
items=[{'item_id':f'40000000-0000-0000-0000-{i:012d}', 'name':f'PN-F{i}',
 'quantity':i, 'location':'Fasteners', 'inventory_id':I1 if i<8 else I2,
 'import_data':{'fields':[{'name':'Description','value':f'Gear M0.8 {i+10}T 6mm D-bore'}, {'name':'Finish','value':'steel'}]},
 'scan_evidence':{'raw':'x'*3000},'image_url':'https://private.invalid/photo'} for i in range(1,16)]
results=[]
for question,contextual,force_recovery in [(q,c,False) for _ in range(2) for q,c in [('what gears do I have?',False),('Were are my gears',False),('gears',True)]]:
 calls=[]
 def execute(actor,org,name,args):
  assert actor==ACTOR and org==ORG
  calls.append(name)
  if name=='world_directory':return {'organization':{'name':'Fixture Robotics'},'inventories':[{'inventory_id':I1,'name':'Workshop'},{'inventory_id':I2,'name':'Storage'}]}
  if name in ('world_search','world_inventory','world_query'):
   rows=items if not args.get('inventory_id') else [r for r in items if r['inventory_id']==args['inventory_id']]
   return {'items':rows,'record_count':len(rows),'known_units':sum(r['quantity'] for r in rows),'unknown_quantity_records':0,'complete':True,'rows_truncated':False}
  if name=='world_spaces':return {'spaces':[{'id':I1,'name':'Workshop'},{'id':I2,'name':'Storage'}]}
  raise ValueError('Read-only fixture; use inventory search')
 start=time.monotonic();visible='';done=None
 from app.services import agent_gateway_client as gc
 from app.services.agent_gateway_client import _as_namespace
 original_gateway=gc.gateway_completion
 attempts=[]
 def model(**kwargs):
  attempts.append(kwargs['stream'])
  if force_recovery and len(attempts)==1:
   return iter([_as_namespace({'choices':[{'delta':{'content':'<tool_call>invalid private protocol'},'finish_reason':'stop'}]})])
  reply=original_gateway(**kwargs)
  if not kwargs['stream']:
   print(json.dumps({'completed_tool_indices':[[getattr(t,'index',None) for t in getattr(c.message,'tool_calls',[]) or []] for c in reply.choices]}),flush=True)
  return reply

 with use_capture(ACTOR,ORG,'fixture',None,enabled=True),patch.object(gc,'gateway_completion',side_effect=model),patch.object(world,'authorize',return_value=ORG),patch.object(world,'execute',side_effect=execute),patch('httpx.Client.send',guarded_send),patch('app.services.personalization.chat.execute',side_effect=AssertionError('No personalization in fixture')):
  for event in world.stream_turn(ACTOR,ORG,question,[],'context-fixture-'+str(uuid4()),contextual=contextual, supports_item_management=True, supports_task_actions=True,user_context={'profile':{'display_name':'Fixture User'},'preferences':{},'personalization_state':{'available':True,'enabled':True}}):
   if event['type']=='reset':visible=''
   if event['type']=='delta':visible+=event['delta']
   if event['type']=='done':done=event
 assert done and done['assistant_message']==visible, 'No confirmed matching final answer'
 answer=done['assistant_message']
 print(json.dumps({'question':question,'operations':calls,'fixture_answer':answer}),flush=True)
 assert answer.count('|')>=50 and '**' in answer, 'Expected bold heading and substantial inventory table'
 assert answer.count('|')>=50 and '**' in answer, 'Expected bold heading and substantial inventory table'
 assert any(n in calls for n in ('world_search','world_inventory','world_query')), 'No fresh inventory read'
 if force_recovery: assert attempts[0] is True and all(a is False for a in attempts[1:])
 result={'contextual':contextual,'forced_recovery':force_recovery,'streams':attempts,'question':question,'seconds':round(time.monotonic()-start,1),'operations':calls,'answer':answer,'passed':True}
 results.append(result);print(json.dumps(result),flush=True)
(Path('/tmp/findez-chat-readout-20261118/model-results.json')).write_text(json.dumps(results,indent=2))
