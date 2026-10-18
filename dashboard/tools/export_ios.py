"""Export the dashboard archive using the existing Apple API signing identity."""
import json
from pathlib import Path
import subprocess

root=Path(__file__).resolve().parents[1]
auth=json.loads(Path('/Users/tanyasmritivictorcharles/Documents/FindEZ/AppStore/1.0.7-review-fix/apple-api-metadata.json').read_text())
key=Path.home()/'.private_keys'/('AuthKey_'+auth['key_id']+'.p8')
args=['xcodebuild','-exportArchive','-archivePath',str(root/'mobile/build/ios/archive/Runner.xcarchive'),
      '-exportPath',str(root/'mobile/build/ios/ipa'),'-exportOptionsPlist',str(root/'mobile/ios/DashboardExportOptions.plist'),
      '-allowProvisioningUpdates','-authenticationKeyPath',str(key),'-authenticationKeyID',auth['key_id'],
      '-authenticationKeyIssuerID',auth['issuer_id']]
with (root/'verification/export.log').open('w') as out:
    subprocess.run(args,stdout=out,stderr=subprocess.STDOUT,check=True)
print('Signed dashboard IPA exported.')
