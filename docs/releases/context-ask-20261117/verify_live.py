from pathlib import Path
import hashlib,json,urllib.request,urllib.error,subprocess
root=Path('/home/ubuntu/findez-context-ask-20261117')
web=Path('/home/ubuntu/findez-context-tables-20261117/frontend')
assert subprocess.check_output(['systemctl','show','findez-web','-p','WorkingDirectory','--value'],text=True).strip()==str(web)
for release in [root,web.parent]:
 for name,entry in json.loads((release/'manifest.json').read_text()).items():
  target=(Path('/home/ubuntu/findez')/name) if name.startswith('backend/') else web/name.removeprefix('frontend/')
  assert hashlib.sha256(target.read_bytes()).hexdigest()==entry['after'], name
results={}
for url in ['https://findez.ai/','https://findez.ai/spaces','https://findez.ai/assist','https://findez.ai/docs/cad','https://findez.openstack.ftctools.com/health','https://findez.openstack.ftctools.com/health/db']:
 with urllib.request.urlopen(url,timeout=25) as r:results[url]=r.status
# Production intentionally keeps its generated schema private (404).
try:
 urllib.request.urlopen('https://findez.openstack.ftctools.com/openapi.json',timeout=25)
except urllib.error.HTTPError as e:
 assert e.code==404;results['public_openapi']=404
import ast
module=ast.parse(Path('/home/ubuntu/findez/backend/app/api/routes/world_chat.py').read_text())
question=next(n for n in module.body if isinstance(n,ast.ClassDef) and n.name=='Question')
assert any(isinstance(n,ast.AnnAssign) and n.target.id=='context_inventory_id' for n in question.body)
request=urllib.request.Request('https://findez.openstack.ftctools.com/worlds/20000000-0000-0000-0000-000000000001/ai_command',data=b'{"message":"gears"}',headers={'Content-Type':'application/json'})
try:
 urllib.request.urlopen(request,timeout=20)
 raise AssertionError('Unauthenticated request was accepted')
except urllib.error.HTTPError as e:
 assert e.code in (401,403);results['unauthenticated_chat']=e.code
results.update(source_hashes='matched',context_schema='verified in deployed route source',build=(web/'.next/BUILD_ID').read_text().strip())
(root/'live-verification.json').write_text(json.dumps(results,indent=2));print(json.dumps(results))
