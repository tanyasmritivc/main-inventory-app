"""Validate and upload only this private dashboard IPA to App Store Connect."""
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import zipfile

root=Path(__file__).resolve().parents[1]
ipa=next((root/'mobile/build/ios/ipa').glob('*.ipa'))
with zipfile.ZipFile(ipa) as package:
    info=plistlib.loads(package.read('Payload/Runner.app/Info.plist'))
    assert info['CFBundleIdentifier']=='com.findez.dashboard'
    assert info['CFBundleShortVersionString']=='1.0.0' and info['CFBundleVersion']=='3'
    compiled=package.read('Payload/Runner.app/Frameworks/App.framework/App')
    assert b'https://findez.ai/api/founder/v1' in compiled, 'Final gateway configuration missing'
    assert b'https://api.findez.ai/dashboard/v1' not in compiled
assert plistlib.loads((root/'mobile/ios/DashboardExportOptions.plist').read_bytes())['testFlightInternalTestingOnly'] is True
auth=json.loads(Path('/Users/tanyasmritivictorcharles/Documents/FindEZ/AppStore/1.0.7-review-fix/apple-api-metadata.json').read_text())
receipt={'bundle_id':info['CFBundleIdentifier'],'version':'1.0.0','build':'3','sha256':hashlib.sha256(ipa.read_bytes()).hexdigest(),'internal_only':True,'compiled_configuration_checked':True}
for operation,name in [('--validate-app','apple-validation.log'),('--upload-app','apple-upload.log')]:
    command=['xcrun','altool',operation,'--file',str(ipa),'--type','ios','--apiKey',auth['key_id'],'--apiIssuer',auth['issuer_id'],'--output-format','json']
    with (root/'verification'/name).open('w') as out:
        subprocess.run(command,stdout=out,stderr=subprocess.STDOUT,check=True)
    print('Apple package validation passed.' if operation=='--validate-app' else 'Dashboard build uploaded to Apple.',flush=True)
receipt['uploaded']=True
(root/'verification/artifact.json').write_text(json.dumps(receipt,indent=2)+'\n')
