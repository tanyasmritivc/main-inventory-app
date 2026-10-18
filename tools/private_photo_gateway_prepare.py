"""Run on the self-hosted VM; prepares/tests only, never activates production."""
from pathlib import Path
import subprocess,json,hashlib,os,re
import yaml
os.umask(0o077)
root=Path('/home/ubuntu/findez-permission-release-20261018');root.mkdir(exist_ok=True)
source=Path('/home/ubuntu/supabase/volumes/api/kong.yml')
original=source.read_bytes();config=yaml.safe_load(original)
name='findez-private-item-images'
config['services']=[s for s in config['services'] if s.get('name')!=name]
priority=max((r.get('priority',0) for service in config['services'] for r in service.get('routes',[])),default=0)+10000
paths=['/storage/v1/'+kind+'/'+mode+'/item-images' for kind in ['object','render/image'] for mode in ['public','sign']]
expression=' || '.join('(http.path == "'+p+'" || http.path ^= "'+p+'/")' for p in paths)
service={'name':name,'url':'http://storage:5000','routes':[{'name':name,'expression':expression,'priority':priority,'strip_path':False}], 'plugins':[{'name':'request-termination','config':{'status_code':404,'message':'Image not found'}}]}
# Preserve the original template byte-for-byte: the entrypoint substitutes Lua
# expressions containing quotes, so reserializing existing YAML is unsafe.
text=original.decode();header=re.search(r'^services:[ \t]*\n',text,re.M)
if header is None:raise RuntimeError('Unexpected services template')
indent=re.search(r'^([ \t]*)- name:',text[header.end():],re.M).group(1)
fragment=''.join(indent+line+'\n' for line in yaml.safe_dump([service],sort_keys=False).splitlines())
rendered=text[:header.end()]+fragment+text[header.end():]
assert rendered.replace(fragment,'',1)==text
candidate=root/'kong-private-images.yml';candidate.write_text(rendered)
(root/'kong-before.yml').write_bytes(original)
image=subprocess.check_output(['docker','inspect','supabase-kong','--format','{{.Config.Image}}'],text=True).strip()
result=subprocess.run(['docker','run','--rm','--network','none','--user','root','-e','KONG_DATABASE=off','-e','KONG_ROUTER_FLAVOR=expressions','--entrypoint','kong','--mount',f'type=bind,src={candidate},dst=/candidate.yml,readonly',image,'config','parse','/candidate.yml'],capture_output=True)
(root/'kong-parse.log').write_bytes(result.stdout+result.stderr)
if result.returncode:raise RuntimeError('Review private kong-parse.log')
receipt={'gateway_validation':True,'version':image,'before_sha256':hashlib.sha256(original).hexdigest(),'candidate_sha256':hashlib.sha256(candidate.read_bytes()).hexdigest(),'live_configuration_changed':False}
(root/'kong-review.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
