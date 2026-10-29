import json,os,secrets,sys,time,urllib.request
from pathlib import Path
config={}
for line in Path('/home/ubuntu/findez/.env').read_text().splitlines():
 if '=' in line and not line.lstrip().startswith('#'):
  k,v=line.split('=',1);config[k.strip()]=v.strip().strip('\"').strip("'")
base=config['SUPABASE_URL'].rstrip('/')
public=config.get('SUPABASE_PUBLIC_URL',base).rstrip('/')
receipt=Path('/tmp/findez-onboarding-v5-approved-qa.json')
def request(method,path,body=None):
 req=urllib.request.Request(base+'/auth/v1'+path,data=json.dumps(body).encode() if body is not None else None,method=method,headers={'apikey':config['SUPABASE_SERVICE_ROLE_KEY'],'Authorization':'Bearer '+config['SUPABASE_SERVICE_ROLE_KEY'],'Content-Type':'application/json'})
 with urllib.request.urlopen(req,timeout=30) as response:
  data=response.read()
  return json.loads(data) if data else {}
mode=sys.argv[1]
if mode=='config': print(json.dumps({'url':public,'anon':config['SUPABASE_ANON_KEY']}))
elif mode=='create':
 if receipt.exists(): raise RuntimeError('A QA receipt already exists; inspect it first')
 email='onboarding-v5-'+str(int(time.time()))+'-'+secrets.token_hex(3)+'@example.test'
 password=secrets.token_urlsafe(32)
 user=request('POST','/admin/users',{'email':email,'password':password,'email_confirm':True,'app_metadata':{'findez_qa_run':'onboarding-v5-approved'}})
 data={'id':user['id'],'email':email,'password':password,'created_at':user['created_at']}
 fd=os.open(receipt,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
 with os.fdopen(fd,'w') as f: json.dump(data,f)
 print(json.dumps(data))
elif mode=='cleanup':
 data=json.loads(receipt.read_text());user=request('GET','/admin/users/'+data['id'])
 assert user['email']==data['email'] and user.get('app_metadata',{}).get('findez_qa_run')=='onboarding-v5-approved'
 saved=user.get('user_metadata',{}).get('onboarding')
 request('DELETE','/admin/users/'+data['id'])
 receipt.unlink()
 print(json.dumps({'removed_approved_qa_account':True,'saved_answers':saved}))
