# MOB-004 Phase A route preservation map

This map records where existing mobile capabilities remain reachable after the
five-destination shell change. It does not claim new backend capability.

| Capability | Phase A entry | Preserved implementation |
|---|---|---|
| Authentication and onboarding | App gate before the shell | Existing AuthPage, recovery, verification, and OnboardingPage |
| Ask and conversation history | Ask | Existing ChatPage with streaming, tools, attachments, voice, and history |
| Photo capture | Capture | Existing ScanPage FIND photo flow |
| Barcode and FindEZ QR | Capture | Existing ScanPage barcode and QR paths |
| Item and Space search | Find | InventoryPage search presentation |
| Spaces and item access | Memory, Spaces segment | Existing InventoryPage and item/Space routes |
| Teams and sharing | Memory, Teams segment | Existing TeamsPage, TeamWorkspacePage, and shared Space routes |
| Documents | Memory tools | Existing DocumentsPage |
| Check-outs | Memory tools and item/Space detail | Existing CheckoutPage and detail flows |
| Low stock | Memory tools and Space detail | Existing ShoppingListPage and local thresholds |
| Activity | Memory tools and Team or shared Space detail | Existing ActivityPage and existing activity tabs |
| Project kits and BOM | Space detail | Existing ProjectKitsPage and BomReadinessPage |
| Spreadsheet import | Space detail and iOS share extension | Existing import flow |
| Labels and Space QR | Space detail | Existing label and QR sheets |
| Notifications | Every primary app bar | Existing NotificationsPage and unread badge |
| Profile and account | Profile | Existing ProfilePage, support, legal, sign out, and deletion |
| Team invite universal links | App-level link handler | Existing authenticated pending invite flow |
| Supabase auth callbacks | App-level auth gate | Existing OAuth and recovery handling |

## Phase boundaries

Phase A changes ownership and navigation only. FIND photo analysis, immediate scan
review, API contracts, item persistence, and all secondary routes keep their current
behavior. Durable Review, crops, source-frame provenance, correction learning,
server paging, offline storage, and new deep links remain later work.
