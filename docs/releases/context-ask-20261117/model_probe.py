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
sys.path.insert(0,str(Path(__file__).parent/'backend'))
from app.services import world_chat as world
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
results=[]
for question in ['Were are my gears','Where are my gears?']:
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
 with patch.object(world,'authorize',return_value=ORG),patch.object(world,'execute',side_effect=execute),patch('httpx.Client.send',guarded_send),patch('app.services.personalization.chat.execute',side_effect=AssertionError('No personalization in fixture')):
  for event in world.stream_turn(ACTOR,ORG,question,[],'context-fixture-'+str(uuid4()),contextual=True):
   if event['type']=='reset':visible=''
   if event['type']=='delta':visible+=event['delta']
   if event['type']=='done':done=event
 assert done and done['assistant_message']==visible, 'No confirmed matching final answer'
 answer=done['assistant_message']
 print(json.dumps({'question':question,'operations':calls,'fixture_answer':answer}),flush=True)
 assert '**' in answer and '|' in answer, 'Expected formatted answer'
 assert answer.count('|')>=12 and 'Workshop' in answer and 'Storage' in answer, 'Expected inventory table with both locations'
 assert any(n in calls for n in ('world_search','world_inventory','world_query')), 'No fresh inventory read'
 result={'question':question,'seconds':round(time.monotonic()-start,1),'operations':calls,'answer':answer,'passed':True}
 results.append(result);print(json.dumps(result),flush=True)
(Path(__file__).parent/'model-probe-results.json').write_text(json.dumps(results,indent=2))
