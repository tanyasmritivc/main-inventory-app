from pathlib import Path
import hashlib,json,subprocess,urllib.request,re
out=Path('/Users/tanyasmritivictorcharles/projects/findez-cad-workspace/docs/releases/shell-polish-20261118')
remote='/home/ubuntu/findez-shell-polish-20261118'
def sha(data):return hashlib.sha256(data).hexdigest()
def ssh(cmd):return subprocess.check_output(['ssh','findez',cmd])
activation=json.loads(ssh('cat '+remote+'/activation.json'));(out/'activation.json').write_text(json.dumps(activation,indent=2))
manifest=json.loads((out/'manifest.json').read_text()); hashes={}
for name,record in manifest.items():
 digest=ssh('sha256sum '+remote+'/'+name).decode().split()[0];assert digest==record['after'];hashes[name]=digest
receipt=json.loads(ssh('cat '+remote+'/receipt.json'));unchanged=sum(receipt['after'].get(k)==v for k,v in receipt['before'].items())
checks={};html=''
for path in ['/','/signin','/spaces','/assist']:
 with urllib.request.urlopen('https://findez.ai'+path,timeout=30) as r:
  data=r.read().decode();checks[path]={'status':r.status,'url':r.url}
  assert r.status==200
  html+='\n'+data
assets={}
for name in ['findez-sidebar-wordmark.svg','findez-sidebar-wordmark-white.svg']:
 with urllib.request.urlopen('https://findez.ai/brand/'+name,timeout=30) as r:
  digest=sha(r.read());assert digest==manifest['frontend/public/brand/'+name]['after'];assets[name]=digest
styles={}
for url in set(re.findall(r'href="([^" ]+\.css[^" ]*)"',html)):
 with urllib.request.urlopen('https://findez.ai'+url,timeout=30) as r:styles[url]=r.read().decode()
css='\n'.join(styles.values());assert 'clamp(24px,2.4vw,30px)' in css
result={'activation':activation,'source_hashes':hashes,'preserved_other_source_files':unchanged,'routes':checks,'public_assets':assets,'css_urls':list(styles),'caption_css':True,'service':ssh('systemctl is-active findez-web').decode().strip()}
(out/'live-verification.json').write_text(json.dumps(result,indent=2));print(json.dumps({'routes':checks,'source_files':len(hashes),'preserved_sources':unchanged,'public_assets':len(assets),'caption_css':True,'service':result['service']}))
