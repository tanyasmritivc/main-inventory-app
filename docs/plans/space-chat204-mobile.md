# Space chat204 mobile

LocationItemsPage passes its persistent Space ID and current name to contextual Ask. The sheet displays the Space name, and a bound ApiClient routes text, photos, attachments and history through the Space-specific backend. A missing legacy ID is resolved by an exact unique name in the authorized inventory; failure remains visible instead of opening a broader chat. Account/inventory invalidation is retained.

The contextual attachment menu offers Photo library, Take photo and Choose files. Auto Extract, Import inventory, external context and connections are absent from this fixed-Space question menu. Photos and files are question evidence; PDF, TXT, Markdown, DOCX, CSV, JSON and XLSX are supported, alongside existing photo formats. Main-chat menus and extraction behavior remain unchanged. The same composer, reply rendering, voice, stop, retry and native sheet are reused.

Verification: 1,347 Flutter tests passed / 1 existing skip, including endpoint binding, viewer attachments/history, stale-context rejection, native sheet behavior, completed replies without false Retry, and spreadsheet file attachment as question evidence. Full analysis and native simulator checks are finishing. Companion API branch: fix/space-chat204-api. Build204 signing and upload pending; no public App Store submission.
