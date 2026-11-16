# Fusion browser approval JSON fix

November 15, 2026

User photo IMG_3563.DNG shows the connection page with a generic approval error.
Production status lines show POST /fusion/pairing/approve returned 422. The form
passed JSON.stringify output to accountRequest without a JSON Content-Type.
apiRequest passes string bodies through, while object bodies are serialized and
marked application/json. Browsers send an otherwise untyped string as text/plain,
which FastAPI rejects for the approval model.

Changed one runtime line in fusion-connect.tsx to pass an object. No global API
helper changes. Updated existing form test and added a transport regression
through real accountRequest/apiRequest with mocked authentication and fetch.
The new test reproduced the same generic error before the fix and passes after,
checking JSON Content-Type, actor-bound authorization, and selected inventory.
20 frontend tests and scoped lint passed; production-source webpack build passed.

Self-hosted findez-web release:
`/home/ubuntu/findez-fusion-approval-20261115/frontend`
Build ID: `FV1ruq8pdGXnjVyJUq2bu`.
Previous release: `/home/ubuntu/findez-fusion-023-20261115/frontend`.

Prepared from active production source, with source guards and a one-module
change assertion. Previous service configuration preserved for rollback. Live
corrected JavaScript downloaded and matched to built asset. Fusion 0.2.3 ZIP
hash unchanged. No new add-in installation required. No backend/database/mobile,
Vercel or Render deployment. No git push to avoid external preview automation.

A real authenticated approval from the user's Windows Fusion remains pending.
Reload the connection page before retry; if the ten-minute code expired, start
a fresh connection from Fusion. No user pairing code or token was saved here.
