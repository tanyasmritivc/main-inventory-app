"""Read-only candidate HTTP and ZIP consistency; no accounts or stock changes."""
from pathlib import Path
from urllib.request import urlopen
import hashlib,json,re,io,zipfile
root=Path('/home/ubuntu/findez-cad-native-planning-20261116')
base='http://127.0.0.1:3108'
def get(path):
    with urlopen(base+path,timeout=20) as response:return response.read()
html=get('/docs/cad').decode()
assert 'Plan several projects against shared stock' in html
assert 'Enable purchase plans and receiving' in html
assert 'purchasing inside Fusion, automatic' not in html
assert 'zip template 0.4.2' not in html
assert 'href="#planning"' in html
links=set(re.findall(r'href="([^\"]*findez-fusion-workspace\.zip[^\"]*)"',html))
public=get('/cad-intelligence').decode();links.update(re.findall(r'href="([^\"]*findez-fusion-workspace\.zip[^\"]*)"',public))
expected=hashlib.sha256((root/'frontend/public/downloads/findez-fusion-workspace.zip').read_bytes()).hexdigest()
assert links and all('v=0.5.0' in link for link in links)
for link in links:
    data=get(link);assert hashlib.sha256(data).hexdigest()==expected
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        assert json.loads(archive.read('FindEZ/FindEZ.manifest'))['version']=='0.5.0'
        for name in ['FindEZ/purchasing.js','FindEZ/planning.js']:assert name in archive.namelist()
for path in ['/','/docs/api','/docs/connections','/cad','/cad/fusion/connect']:get(path)
result={'candidate_http':True,'documentation_and_download_consistent':True,'zip_sha256':expected,'production_modified':False}
(root/'web-results.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
