# CAD documentation hub

CAD Intelligence (/docs/cad) is the central entry point for downloads, setup,
generation, inventory comparison, saved BOMs, connections, and troubleshooting.
Removed redundant CAD entries from Tools, account menu, and profile settings.
The comparison route keeps file uploads and saved history; it links to the hub
instead of repeating full Fusion onboarding. Existing routes/anchors remain.

Added a first-model walkthrough, separate pairing/write permission instructions,
job-state next steps, and troubleshooting for disabled generation and placement.
Connection checkboxes now occupy separate blocks; write access remains optional
and unchecked by default, with existing editor checks unchanged.

Validation: 711 web tests across 96 suites; TypeScript; lint of changed components;
production webpack build. Initial Turbopack build rejected the shared dependency
symlink; webpack is the deployment build mode. No backend or database changes.
No plugin update: all remaining download links retain 0.4.0, checksum
49083752baabac5a09c7c0174fdf6f36a35b6a0b899fe4a0548efb880ae8aff7.

Base: /home/ubuntu/findez-connections-docs-20261116/frontend.
Candidate: /home/ubuntu/findez-cad-docs-hub-20261116/frontend.
Only the ten files in manifest.json are overlaid; World Tools applies the CAD
removal to the newer production version, retaining unrelated Space changes.
Public landing sources/assets are unchanged. Source hashes guard concurrent
releases. Prior immutable chunks are retained. Activation rolls back on failure.

Live Safari verification confirmed Tools has no CAD card, the sidebar opens the
hub, grouped guides and first-model instructions render, the comparison page
shows uploads/history, and both connection checkboxes are separately visible.
No live pairing, generation job, or inventory mutation was performed.

The visual check also found /cad/fusion/connect still selected Tools. The final
navigation overlay recognizes /cad and all /cad/* pages as CAD and selects the
/docs/cad sidebar route. Two navigation tests pass. It is staged on the first hub
release, retaining all ten previous changes and the newer World/Connections work.
Final candidate: /home/ubuntu/findez-cad-docs-hub-final-20261116/frontend.
Its build cache uses /dev/shm to avoid filling production storage.

Final live build: m-24zClfCwocqLXVGyYsI. Activation and route checks passed,
including public landing, CAD marketing, API docs, Connections docs, CAD tool,
Fusion connection and the unchanged plugin download. See activation.json.
Final navigation TypeScript and changed-file lint passed; no new stock, pairing,
provider jobs, purchases, or database writes were part of verification.
