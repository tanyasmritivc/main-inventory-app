"""Run on the self-hosted VM; prepares/tests only, never activates production."""
from pathlib import Path
import subprocess as sp,time,uuid,json,os,socket,urllib.request,urllib.error
os.umask(0o077)
root=Path('/home/ubuntu/findez-permission-release-20261018');candidate=root/'kong-private-images.yml'
name='findez-photo-gateway-qa-'+uuid.uuid4().hex[:10]
network=name+'-internal'
with socket.socket() as socket_probe:
 socket_probe.bind(('127.0.0.1',0));port=socket_probe.getsockname()[1]
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
image=sp.check_output(['docker','inspect','supabase-kong','--format','{{.Config.Image}}'],text=True).strip()
try:
 sp.run(['docker','network','create','--internal',network],check=True,stdout=sp.DEVNULL)
 sp.run(['docker','run','-d','--name',name,'--network',network,'--user','root','-e','KONG_DATABASE=off','-e','KONG_ROUTER_FLAVOR=expressions','-e','KONG_DECLARATIVE_CONFIG=/candidate.yml','-e','KONG_PREFIX=/tmp/photo-qa','-e','KONG_PROXY_LISTEN=0.0.0.0:18080','-e','KONG_ADMIN_LISTEN=off','--mount',f'type=bind,src={candidate},dst=/candidate.yml,readonly','--entrypoint','sh',image,'-c','kong start && tail -f /dev/null'],check=True,stdout=sp.DEVNULL)
 for _ in range(60):
  if sp.run(['docker','exec',name,'kong','health','-p','/tmp/photo-qa'],stdout=sp.DEVNULL,stderr=sp.DEVNULL).returncode==0:break
  time.sleep(.3)
 else:
  (root/'gateway-start.log').write_bytes(sp.check_output(['docker','logs',name],stderr=sp.STDOUT));raise RuntimeError('Review private gateway-start.log')
 address=sp.check_output(['docker','inspect',name,'--format','{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'],text=True).strip()
 for _ in range(100):
  try:
   opener.open(f'http://{address}:18080/',timeout=1);break
  except urllib.error.HTTPError:break
  except urllib.error.URLError:time.sleep(.2)
 else:
  (root/'gateway-start.log').write_bytes(sp.check_output(['docker','logs',name],stderr=sp.STDOUT));raise RuntimeError('Review private gateway-start.log')
 routes=['/storage/v1/object/public/item-images/qa.jpg','/storage/v1/object/sign/item-images/qa.jpg?token=old','/storage/v1/render/image/public/item-images/qa.jpg','/storage/v1/render/image/sign/item-images/qa.jpg?token=old','/storage/v1/object/sign/%69tem-images/qa.jpg?token=old','/storage/v1/object/public/item-images','/storage/v1/object/public/item-images/../item-images/qa.jpg']
 for path in routes:
  try:
   status=str(opener.open(f'http://{address}:18080'+path,timeout=10).status)
  except urllib.error.HTTPError as error: status=str(error.code)
  if status!='404':raise RuntimeError('Gateway privacy route returned '+status+' for '+path)
 receipt={'isolated_gateway_http_tests':len(routes),'all_denied':True,'network':'internal, internet egress disabled, no published ports','live_gateway_unchanged':True}
 (root/'gateway-http-tests.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
finally:
 sp.run(['docker','rm','-f',name],stdout=sp.DEVNULL)
 sp.run(['docker','network','rm',network],stdout=sp.DEVNULL)
