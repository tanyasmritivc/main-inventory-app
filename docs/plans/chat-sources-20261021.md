# Chat sources, files and assistant connections

Implemented mobile scope for build 109:

- Immediate anchored plus popover: Auto Extract, Attach, Import inventory,
  Scan barcode, Add context. Back navigation replaces submenu content.
- Attach opens native iPhone camera, native iOS photo library, or system file picker.
  PDF/TXT/Markdown are read as chat evidence. CSV/XLSX use the existing reviewed
  inventory extraction draft and explicit destination/save flow.
- Add context searches Spaces, items, projects and documents/notes in an inventory
  inside the selected world. Up to eight removable selections; up to four files.
  References are reauthorized on every send. They never choose a save destination.
- Files are bounded at 10 MB, 24,000 extracted characters per file, and 48,000 total
  text characters per turn. PDF extraction stops at 50 pages; excerpts are labeled.
  Scanned, encrypted, binary or unsupported files fail explicitly.
- File text stays in the active composer session. Raw uploads are not saved to an
  inventory. Replies retain source labels; reopening history requires reattaching
  files/reselecting references. Removing a chip affects future turns, not earlier
  messages. Model replies remain part of the private chat history.
- Connections is available through Add context and Settings. It links the existing
  Claude Desktop MCP extension guide, ChatGPT Actions guide and API key management.
  Status is Setup on web; no fabricated Connected state. Cloud-file/email OAuth is
  outside this approved first phase.

API dependency: feat/api-chat-sources-20261021; additive world chat source contract.
No migration. Existing Space navigation and deletion work from build 108 is retained.

Validation: full mobile suite plus updated responsive menu checks; native simulator
covers selection/removal/reset, file cancellation/retry, stale file/search results,
keyboard/large-text layouts, and connection search. Physical native camera/photo
picker acceptance for this build remains unverified; implementation uses the existing
native iOS picker plugin. Release receipts are recorded in CURRENT_STATE.
