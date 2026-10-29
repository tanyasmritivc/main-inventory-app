# Contextual inventory chat and immediate streaming

Main organization chat retains its existing layout and organization client. Every received safe delta now renders immediately with the existing 180 ms fade, without waiting for completion or queuing words. Canonical completion and action receipt validation are preserved.

Inventory items, Spaces, Documents, Review, Check-outs, Project kits and Restock offer a neutral translucent Ask FindEZ sheet. It receives the page's authorized InventoryContext client, explicitly labels “Only in [inventory]”, and refuses an unbound context. Space/document/project pages use the containing inventory boundary. The existing ChatPage supplies history, photos, voice, action review and cancellation. Inventory conversations get their own session rather than the old account singleton. Dismissal disposes pending work, and the keyboard expands the sheet into available safe height.

Validation: full host suite 1,204 passing with one existing skip; final 36 focused chat/Restock checks; clean analysis. Five native iOS checks exercise both themes, immediate deltas, cancellation, inventory isolation, 320 px large-text and keyboard presentation. Synthetic fixture insets match logical device dimensions; bundled fonts preload before native test frames. Native screenshot evidence is kept with the release. Live provider latency and physical-device acceptance remain separate from these checks. No backend or schema migration.

Build 153 is prepared on an isolated branch. Main remains unchanged. Upload receipt will record Apple acknowledgment separately.
