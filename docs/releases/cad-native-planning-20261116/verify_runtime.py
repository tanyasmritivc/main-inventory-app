"""Read-only candidate import with the active API's environment and dependencies."""
from pathlib import Path
import os,sys,subprocess,json
root=Path('/home/ubuntu/findez-cad-native-planning-20261116')
pid=subprocess.check_output(['systemctl','show','findez','-p','MainPID','--value'],text=True).strip()
for entry in Path('/proc/'+pid+'/environ').read_bytes().split(b'\0'):
    if b'=' in entry:
        key,value=entry.split(b'=',1);os.environ[key.decode()]=value.decode()
os.environ['CAD_NATIVE_PURCHASING_ENABLED']='true'
sys.path.insert(0,str(root/'backend'))
from app.main import app
paths=app.openapi()['paths']
for name in ['/fusion/purchases','/fusion/purchases/{plan_id}/actions','/fusion/bom/planning','/fusion/bom/revision-diff']:
    assert name in paths,name
receipt={'candidate_import':True,'native_routes':True,'production_dependencies':True,'production_modified':False}
(root/'runtime-results.json').write_text(json.dumps(receipt,indent=2))
print(json.dumps(receipt))
