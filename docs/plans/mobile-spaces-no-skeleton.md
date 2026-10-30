# Spaces without skeleton loaders

Mobile only, based on TestFlight159. Build160 removes skeleton rows/blocks and
shimmer from the Spaces tab, inventory directories, Space contents and related
workspace, documents, activity, review, imports, project and restock pages.
Missing data uses a small static status. Loaded directories remain visible during
refresh; inventory search/header stay mounted during the initial request. Empty
states still wait for a successful response. Errors and retry behavior remain.
The existing short navigation fades, typography, actions and data contracts stay.
Chat initialization/history skeletons are outside this requested flow.

1,229 host tests passed with one existing skip. Flutter analysis passed. Native
checks, CI and TestFlight delivery are pending. Physical-device acceptance remains
unverified.
