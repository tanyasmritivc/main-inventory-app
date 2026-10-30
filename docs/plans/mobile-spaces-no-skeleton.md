# Spaces without skeleton loaders

Mobile only, based on TestFlight159. Build160 removes skeleton rows/blocks and
shimmer from the Spaces tab, inventory directories, Space contents and related
workspace, documents, activity, review, imports, project and restock pages.
Missing data uses a small static status. Loaded directories remain visible during
refresh; inventory search/header stay mounted during the initial request. Empty
states still wait for a successful response. Errors and retry behavior remain.
The existing short navigation fades, typography, actions and data contracts stay.
Chat initialization/history skeletons are outside this requested flow.

1,229 host tests passed with one existing skip. Flutter analysis passed. Twelve
native iOS simulator checks passed for World/Spaces navigation, pending requests,
retained refreshes, directories and inventory scrolling in dark/light themes.
Reviewed pending and loaded screenshots; the harness uses Flutter navigation
controls on the native simulator. Restored the normal production-configured
build160 simulator app after checks. Physical-device acceptance is unverified.

Signed production build160 passed 34 archive and 34 exported device-executable
checks, strict signature verification, 26 privacy manifests, production HTTPS
configuration and SF Pro font verification. All five exact-source CI gates passed (41009171988). Apple acknowledged TestFlight
1.1.1 (160), delivery `45c98b81-d3fa-419a-8c7d-0f4efcfa56bf`. Processing was not
polled; tester availability is unverified. Runtime `4ef1ef3`; PR279; main unchanged.
