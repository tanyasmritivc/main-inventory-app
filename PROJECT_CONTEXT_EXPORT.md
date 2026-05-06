# PROJECT CONTEXT EXPORT - FindEZ AI Inventory App

==================================================
1. PROJECT OVERVIEW
==================================================

**What the app does:**
FindEZ is an AI-powered inventory management mobile application that helps users track, organize, and search their personal belongings using advanced AI categorization, barcode scanning, and natural language interactions.

**Main purpose:**
- Transform manual inventory tracking into an intelligent, automated experience
- Use AI to categorize and organize items automatically
- Enable natural language inventory queries and commands
- Provide visual item tracking through photo capture
- Support barcode scanning for quick item identification

**Core user experience:**
- Point camera at items → AI automatically identifies and categorizes
- Scan barcodes → Instant product lookup and categorization
- Chat with AI assistant → Natural language inventory management
- Visual organization by spaces/locations (Kitchen, Office, Garage, etc.)
- Smart search across all item attributes

**Main product vision:**
Create the "smart memory layer for physical possessions" - an AI system that remembers everything you own, where it is, and helps you find it when needed. The long-term vision includes semantic search, proactive recommendations, and household intelligence.

**Current development state:**
- Core Flutter mobile app functional (iOS/Android)
- Backend API with AI integration (OpenAI GPT-5)
- Supabase database with Row Level Security
- Account deletion system implemented
- Category normalization partially implemented
- Active development on AI categorization refinement

**Platforms supported:**
- iOS (primary target)
- Android (supported)
- Web (frontend exists but not main focus)

**Major features:**
- AI-powered item identification from photos
- Barcode scanning with product lookup
- Natural language chat interface
- Visual inventory organization by spaces
- Search across all item attributes
- Document storage and linking
- Activity tracking and history
- Account management with deletion

==================================================
2. COMPLETE FILE/FOLDER STRUCTURE
=================================

```
main-inventory-app/
├── README.md                          # Project overview and setup
├── .gitignore
├── mobile/                            # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart                  # App entry point and theme setup
│   │   ├── core/                      # Shared utilities and services
│   │   │   ├── api_client.dart        # HTTP client with auth and API calls
│   │   │   ├── config.dart            # App configuration constants
│   │   │   ├── inventory_cache.dart   # In-memory inventory caching
│   │   │   ├── low_stock_prefs.dart   # Low stock threshold management
│   │   │   ├── document_link_prefs.dart # Document-item linking preferences
│   │   │   └── ui/                    # Shared UI components
│   │   │       ├── app_colors.dart
│   │   │       ├── app_gradient_background.dart
│   │   │       ├── glass_card.dart
│   │   │       ├── primary_gradient_button.dart
│   │   │       └── skeleton.dart
│   │   └── features/                  # Feature-based organization
│   │       ├── activity/             # Activity history and tracking
│   │       ├── auth/                 # Authentication flow
│   │       ├── chat/                 # AI chat interface
│   │       ├── documents/            # Document management
│   │       ├── home/                 # Home screen with quick actions
│   │       ├── inventory/            # Main inventory/spaces screen
│   │       ├── onboarding/           # First-time user experience
│   │       ├── profile/              # User profile and settings
│   │       ├── scan/                 # Barcode and photo scanning
│   │       ├── shell/                # Main navigation shell
│   │       └── splash/               # App launch screen
│   ├── pubspec.yaml                  # Flutter dependencies
│   ├── .env                          # Environment variables
│   ├── android/                      # Android platform files
│   ├── ios/                          # iOS platform files
│   └── assets/                       # App assets and icons
├── backend/                          # FastAPI Python backend
│   ├── app/
│   │   ├── main.py                   # FastAPI app setup
│   │   ├── api/                      # API routes
│   │   │   └── routes/
│   │   │       ├── inventory.py      # Main inventory endpoints
│   │   │       └── router.py         # API router configuration
│   │   ├── core/                     # Backend core utilities
│   │   │   ├── auth.py               # JWT authentication
│   │   │   ├── config.py             # Configuration management
│   │   │   └── errors.py             # Error handling
│   │   ├── schemas/                  # Pydantic models
│   │   │   ├── ai.py                 # AI request/response models
│   │   │   ├── inventory.py          # Inventory data models
│   │   │   └── documents.py          # Document models
│   │   └── services/                 # Business logic services
│   │       ├── ai_agent.py           # AI chat orchestration
│   │       ├── items_repo.py         # Database operations
│   │       ├── openai_service.py     # OpenAI API integration
│   │       ├── documents_repo.py     # Document management
│   │       ├── supabase_client.py    # Database client
│   │       └── storage.py           # File storage
│   ├── requirements.txt              # Python dependencies
│   └── supabase/                     # Database migrations
│       └── migrations/
│           ├── 001_init.sql          # Core tables (items, profiles)
│           ├── 002_items_ai_fields.sql # AI-enhanced item fields
│           ├── 003_documents_activity.sql # Documents and activity tracking
│           └── 004_profiles_usage_type.sql # Profile enhancements
└── supabase/                         # Supabase configuration
    ├── config.toml                   # Supabase project config
    └── functions/
        └── delete-user/             # Account deletion Edge Function
            ├── index.ts              # Edge Function implementation
            ├── deno.json             # Deno runtime config
            └── package.json          # Node dependencies
```

**Important files and their purposes:**

- `mobile/lib/core/api_client.dart`: Central HTTP client with authentication, API endpoints, and AI warmup
- `mobile/lib/features/inventory/inventory_page.dart`: Main inventory interface with spaces, categories, and search
- `mobile/lib/features/scan/scan_page.dart`: Barcode and photo scanning with AI categorization
- `mobile/lib/features/chat/chat_page.dart`: AI chat interface for natural language commands
- `backend/app/services/ai_agent.py`: AI orchestration with tool calling and session management
- `backend/app/services/openai_service.py`: OpenAI API integration for vision and text
- `backend/app/api/routes/inventory.py`: All inventory-related API endpoints
- `supabase/functions/delete-user/index.ts`: Complete account deletion Edge Function

**Feature organization:**
- Each major feature has its own directory under `mobile/lib/features/`
- Shared utilities live in `mobile/lib/core/`
- Backend follows similar feature-based structure
- Database migrations are versioned and sequential

==================================================
3. FRONTEND ARCHITECTURE
========================

**Flutter architecture:**
- Feature-based folder organization
- StatefulWidget pattern for complex screens
- ValueNotifier/ValueListenableBuilder for state management
- Material 3 design system with custom dark theme
- Lazy tab loading in main shell for performance

**State management approach:**
- Local state with StatefulWidget for UI state
- ValueNotifier for reactive data (search, filters, thresholds)
- Supabase real-time for auth state
- In-memory caching for inventory data (InventoryCache)
- SharedPreferences for user preferences (LowStockPrefs)

**Navigation structure:**
```
SplashPage → AuthPage → OnboardingPage → MainShell
MainShell tabs:
  - Tab 0: HomePage (quick actions, recent items)
  - Tab 1: ScanPage (barcode/photo scanning)
  - Tab 2: InventoryPage (spaces, categories, search)
  - Tab 3: ActivityPage (history, documents)
  - Tab 4: ProfilePage (settings, account)
```

**Main screens and their purposes:**

**HomePage (`mobile/lib/features/home/home_page.dart`)**
- Purpose: Quick access to common actions and recent items
- Inputs: API client, navigation callbacks
- Outputs: Quick add dialog, recent items list, navigation to other features
- Dependencies: ApiClient, Supabase auth
- Backend calls: None directly (uses cached data)

**InventoryPage (`mobile/lib/features/inventory/inventory_page.dart`)**
- Purpose: Main inventory interface with spaces organization and filtering
- Inputs: API client, refresh token, optional initial query
- Outputs: Item lists by location, category filters, search results
- Dependencies: ApiClient, Supabase, LowStockPrefs
- Backend calls: search_items_basic, update_item, delete_item

**ScanPage (`mobile/lib/features/scan/scan_page.dart`)**
- Purpose: Barcode scanning and photo capture with AI categorization
- Inputs: API client, save callback
- Outputs: Scanned items, AI categorization results
- Dependencies: ApiClient, mobile_scanner, image_picker
- Backend calls: barcodeLookup, extract_from_image, bulk_create_items

**ChatPage (`mobile/lib/features/chat/chat_page.dart`)**
- Purpose: Natural language AI assistant for inventory management
- Inputs: API client, optional mutation callback, initial message
- Outputs: AI responses, inventory changes, file analysis
- Dependencies: ApiClient, file_picker, Supabase
- Backend calls: ai_command (SSE), upload_document

**MainShell (`mobile/lib/features/shell/main_shell.dart`)**
- Purpose: Navigation container with lazy tab loading
- Inputs: API client
- Outputs: Tab navigation, inventory refresh coordination
- Dependencies: All feature pages, InventoryCache
- Backend calls: Prefetch inventory cache on startup

**Shared widgets/components:**
- `GlassCard`: Frosted glass effect container
- `PrimaryGradientButton`: Custom gradient button
- `Skeleton`: Loading placeholder animations
- `AppColors`: Centralized color scheme
- `AppGradientBackground`: Full-screen gradient background

**Data flow between screens:**
1. **Auth → Shell**: Supabase auth state triggers navigation
2. **Scan → Inventory**: Save callback triggers inventory refresh
3. **Chat → Inventory**: Mutation callback updates inventory cache
4. **Shell → All tabs**: Refresh token forces tab rebuilds
5. **Inventory → Cache**: Changes update InventoryCache for other tabs

**Search system:**
- Real-time search with debouncing
- Searches across name, category, location, notes
- Uses ValueNotifier for reactive UI updates
- Backend search with keyword extraction
- Local filtering after initial results

**Scan system:**
- Mobile scanner for barcodes
- Image picker for photo capture
- AI categorization via OpenAI vision
- Category normalization to top-level categories
- Bulk item creation from single scan

**Inventory organization system:**
- Items grouped by location ("spaces")
- Category-based filtering with chips
- Low stock threshold tracking per item
- Visual grouping with expandable sections
- Search within specific categories/locations

**Profile/auth system:**
- Supabase authentication with email/password
- Account deletion via Edge Function
- Privacy policy and terms of service
- User preferences and settings

==================================================
4. INVENTORY SYSTEM
===================

**How items are created:**
1. **Manual Entry**: Quick-add dialog with name, quantity, category, location
2. **Barcode Scan**: Lookup via external APIs → AI categorization → Auto-fill
3. **Photo Scan**: AI vision analysis → Item extraction → Manual review → Save
4. **Chat Command**: Natural language → AI parsing → Automatic creation

**Barcode scanning flow:**
```
MobileScanner → Barcode value → API barcodeLookup()
├── Try go-UPC API (if key available)
├── Try UPCItemDB API (if key available)  
└── Fallback to OpenAI barcode interpretation
→ ExtractedInventoryItem with normalized category
→ User review in ScanPage
→ bulk_create_items() API call
→ Inventory refresh
```

**AI categorization flow:**
```
Image/Barcode → OpenAI GPT-5 Vision → Structured extraction
├── Item name (cleaned and validated)
├── Category (normalized to top-level)
├── Subcategory (if provided)
├── Brand (if identifiable)
├── Quantity (if countable)
└── Confidence score
→ Category normalization function maps to:
   Food, Cosmetics, Electronics, Clothing, Home, Health, Toys, Office, Supplies, Other
```

**Spaces/categories/filters relationship:**
- **Spaces**: Physical locations (Kitchen, Office, Garage, etc.)
- **Categories**: Item types (Food, Electronics, Clothing, etc.)
- **Filters**: UI chips for category filtering
- **Current Issue**: Raw taxonomy strings from AI sometimes become filter chips
- **Desired**: Only normalized top-level categories as filters

**Inventory filtering logic:**
```dart
// Category filtering (case-insensitive exact match)
_baseItemsForSelectedCategory() {
  if (selectedCategory == 'All') return items;
  return items.where((item) => 
    item.category.toLowerCase() == selectedCategory.toLowerCase()
  ).toList();
}

// Location grouping
_groupByLocation(items) {
  final Map<String, List<InventoryItem>> grouped = {};
  for (final item in items) {
    final location = item.location.trim();
    grouped.putIfAbsent(location, () => []).add(item);
  }
  return grouped;
}
```

**Search behavior:**
- Real-time search with 300ms debounce
- Backend keyword extraction via OpenAI
- Multi-field search: name, category, location, notes
- Local filtering after initial backend search
- Search results update immediately

**Item model structure:**
```dart
class InventoryItem {
  String itemId;           // UUID primary key
  String name;             // Item name
  String category;         // Normalized category (top-level)
  String? subcategory;     // Detailed subcategory (optional)
  int quantity;            // Current quantity
  String location;         // Physical location
  String? imageUrl;        // Reference to stored image
  String? barcode;         // Barcode value if scanned
  String? brand;           // Brand name
  String? partNumber;      // Part/Model number
  List<String>? tags;      // User-defined tags
  double? confidence;      // AI confidence score
  DateTime createdAt;      // Creation timestamp
}
```

**Database schema:**
```sql
-- Core items table
CREATE TABLE items (
  item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT,
  brand TEXT,
  part_number TEXT,
  tags TEXT[],
  confidence DOUBLE PRECISION,
  quantity INTEGER NOT NULL,
  location TEXT NOT NULL,
  image_url TEXT,
  barcode TEXT,
  purchase_source TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Row Level Security policies
-- Users can only access their own items
```

**Organization system:**
- Items grouped by location for main display
- Category chips for filtering within locations
- Search works across all items regardless of grouping
- Low stock alerts based on user-defined thresholds
- Activity tracking for all item changes

**Current UX issues/problems:**
1. **Category Filter Issue**: Raw AI taxonomy strings (e.g., "Food > Pantry > Dry Goods") sometimes become filter chips instead of normalized categories
2. **Inconsistent Categorization**: AI may return different categories for similar items
3. **Barcode Lookup Gaps**: Not all barcodes return product data
4. **Search Precision**: Backend search may miss items without exact keyword matches
5. **Bulk Operations**: No efficient way to update multiple items

**Desired future architecture:**
- Consistent top-level category normalization
- Semantic search with embeddings
- Intelligent category suggestions
- Bulk editing capabilities
- Proactive organization recommendations

==================================================
5. AI ARCHITECTURE
==================

**Current OpenAI usage:**
- **Model**: GPT-5 (gpt-5) for vision, GPT-5 Mini (gpt-5-mini) for text
- **Vision**: Image analysis for item extraction and categorization
- **Text**: Natural language commands and search query processing
- **Tool Calling**: Function calling for inventory operations
- **Streaming**: Server-sent events for real-time chat responses

**Prompts and system instructions:**
```python
# Vision Analysis Prompt
"You are FindEZ Assistant — analyze this image visually. 
When you list items, ALWAYS use bullet points with the '•' character.
If you recognize multiple items, start with: 'I found these items in the image:' then bullets.
Always end with ONE helpful follow-up suggestion."

# Chat System Prompt
"You are FindEZ Assist, a helpful AI assistant for an inventory app.
You help with inventory tracking, everyday items, and projects.
Do not call any tool unless absolutely necessary.
Only call tools when the user explicitly wants to add, remove, update, or search."
```

**Categorization system:**
```python
# Category normalization (frontend)
def _normalizeCategory(rawCategory):
    c = rawCategory.trim().toLowerCase()
    if c.contains('food') || c.contains('grocery') || c.contains('beverage')) return 'Food'
    if c.contains('cosmetic') || c.contains('beauty') || c.contains('makeup')) return 'Cosmetics'
    if c.contains('electronic') || c.contains('tech') || c.contains('gadget')) return 'Electronics'
    # ... more mappings
    return 'Other'
```

**Barcode intelligence:**
- Primary: go-UPC API (if API key available)
- Secondary: UPCItemDB API (if key available)
- Fallback: OpenAI barcode interpretation
- Confidence scoring for all results
- Manual review required for low-confidence results

**Semantic behavior:**
- Search query keyword extraction via OpenAI
- Contextual understanding of inventory terms
- Planning mode for project-based queries
- Follow-up question handling for clarification
- Session state for conversation context

**Future AI plans:**
- **Embeddings**: Vector search for semantic item matching
- **OCR**: Text extraction from labels and receipts
- **Multi-API**: Specialized APIs for different product types
- **Recommendations**: ML-based suggestions for organization
- **Proactive AI**: Automatic inventory insights and alerts

**Planned multi-API architecture:**
```
User Request → Orchestration Layer
├── OpenAI (general intelligence)
├── Specialized APIs (product databases)
├── OCR Service (text extraction)
├── Embedding Service (semantic search)
└── Recommendation Engine (ML insights)
```

**Orchestration concepts:**
- Tool calling for database operations
- Streaming responses for chat interface
- Session management for context
- Error handling and fallback strategies
- Rate limiting and cost optimization

==================================================
6. BACKEND ARCHITECTURE
=======================

**Supabase usage:**
- **Database**: PostgreSQL with Row Level Security (RLS)
- **Auth**: JWT-based authentication with user management
- **Storage**: File storage for images and documents
- **Edge Functions**: Serverless functions for specific operations
- **Realtime**: WebSocket connections for real-time updates (minimal usage)

**Auth flow:**
```
Frontend → Supabase Auth → JWT Token
├── Frontend stores token
├── All API calls include Authorization: Bearer <token>
├── Backend validates JWT via JWKS endpoint
├── Backend extracts user_id from token
└── Backend uses Service Role key for database operations
```

**Database structure:**
- **Primary Database**: Supabase PostgreSQL
- **Connection**: Service Role key for admin operations
- **Security**: RLS policies ensure user isolation
- **Indexes**: Optimized for user_id-based queries

**Edge Functions:**
- **delete-user**: Complete account deletion with data cleanup
- **Future**: Image processing, AI orchestration, webhook handlers

**Storage system:**
- **Bucket**: item-images (configurable public/private)
- **Upload**: Multipart form data with validation
- **Access**: Public URLs or signed URLs based on configuration
- **Cleanup**: Associated files deleted on item deletion

**Realtime usage:**
- Currently minimal (auth state changes only)
- Future potential: live inventory updates, collaboration features

**Account deletion flow:**
```
Delete Account Button → Confirmation Dialog → Edge Function
├── Extract user_id from JWT
├── Delete user data from all tables:
│   ├── items
│   ├── documents  
│   ├── activity_log
│   └── profiles
├── Delete auth user via Supabase Admin API
└── Return success/error response
```

**Error handling:**
- Structured error responses with appropriate HTTP codes
- Retry logic for database connection issues
- Graceful degradation for external API failures
- Comprehensive logging for debugging

==================================================
7. DATABASE SCHEMA
==================

**Core tables:**

**items table**
```sql
CREATE TABLE items (
  item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT,
  brand TEXT,
  part_number TEXT,
  tags TEXT[],
  confidence DOUBLE PRECISION,
  quantity INTEGER NOT NULL,
  location TEXT NOT NULL,
  image_url TEXT,
  barcode TEXT,
  purchase_source TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for performance
CREATE INDEX idx_items_user_created_at ON items (user_id, created_at DESC);
CREATE INDEX idx_items_user_name ON items (user_id, name);
CREATE INDEX idx_items_user_category ON items (user_id, category);
CREATE INDEX idx_items_user_subcategory ON items (user_id, subcategory);
CREATE INDEX idx_items_user_barcode ON items (user_id, barcode);
CREATE INDEX idx_items_user_part_number ON items (user_id, part_number);
```

**profiles table**
```sql
-- Supabase auto-creates basic profiles table
-- Extended with custom fields:
ALTER TABLE profiles ADD COLUMN usage_type TEXT;
ALTER TABLE profiles ADD COLUMN first_name TEXT;
```

**documents table**
```sql
CREATE TABLE documents (
  document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  filename TEXT NOT NULL,
  mime_type TEXT,
  storage_path TEXT NOT NULL,
  url TEXT,
  display_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_documents_user_created_at ON documents (user_id, created_at DESC);
```

**activity_log table**
```sql
CREATE TABLE activity_log (
  activity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  summary TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_activity_user_created_at ON activity_log (user_id, created_at DESC);
```

**Relationships:**
- **user_id**: Foreign key relationship to auth.users (implicit via Supabase)
- **items.user_id**: Each item belongs to exactly one user
- **documents.user_id**: Each document belongs to exactly one user
- **activity_log.user_id**: Each activity belongs to exactly one user
- **items ↔ documents**: Optional linking via metadata in activity_log

**Foreign keys:**
- No explicit foreign key constraints (Supabase auth.users is external)
- User ownership enforced by RLS policies
- Cascading deletes handled by application logic

**Purposes:**
- **items**: Core inventory data with AI-enhanced fields
- **profiles**: User preferences and settings
- **documents**: File storage metadata for receipts, manuals, etc.
- **activity_log**: Audit trail of all inventory changes

**User ownership:**
- All tables have user_id column for multi-tenancy
- RLS policies ensure users can only access their own data
- Service Role key bypasses RLS for admin operations

==================================================
8. API & SERVICE FLOW
=====================

**All external APIs:**

**OpenAI APIs:**
- **Chat Completions**: GPT-5 for text processing
- **Vision**: GPT-5 for image analysis
- **Usage**: Item extraction, categorization, search processing, chat responses

**Barcode APIs:**
- **go-UPC.com**: Primary barcode lookup (requires API key)
- **UPCItemDB**: Secondary barcode lookup (requires API key)
- **Fallback**: OpenAI barcode interpretation

**Supabase APIs:**
- **Auth**: User authentication and JWT management
- **Database**: CRUD operations via REST API
- **Storage**: File upload and retrieval
- **Edge Functions**: Serverless function execution

**Authentication flow:**
```
1. User enters email/password → Supabase Auth
2. Supabase returns JWT token → Frontend stores token
3. All API calls include: Authorization: Bearer <token>
4. Backend validates JWT via JWKS endpoint
5. Backend extracts user_id from token
6. Backend uses Service Role key for database operations
```

**Image upload flow:**
```
1. User captures/selects image → Frontend
2. Image validation (size, type) → Frontend
3. Multipart form upload → Backend /upload_document
4. Backend validates → Supabase Storage
5. Storage returns URL → Backend saves metadata
6. Image analysis → OpenAI Vision API
7. Structured data → Item creation
```

**OCR (not currently implemented):**
- Planned for receipt scanning and label text extraction
- Would integrate with OCR service (Tesseract or cloud API)
- Text extraction → Structured data → Item creation

**AI command flow:**
```
1. User sends message → Frontend ChatPage
2. Streaming request → Backend /ai_command (SSE)
3. OpenAI processes with tools → Backend
4. Tool execution → Database operations
5. Streaming response → Frontend
6. UI updates → Real-time chat display
```

**Barcode processing flow:**
```
1. Camera captures barcode → MobileScanner
2. Barcode value → Frontend ScanPage
3. API call → Backend /process_barcode
4. External API lookup → Product data
5. AI categorization → Normalized category
6. ExtractedInventoryItem → User review
7. Bulk creation → Database
```

**Supabase functions:**
- **delete-user**: Complete account deletion
- **Future**: Image processing, webhooks, batch operations

==================================================
9. CURRENT PROBLEMS / TECH DEBT
=================================

**Known bugs:**
1. **Category Filter Issue**: Raw AI taxonomy strings sometimes become filter chips instead of normalized categories
2. **Search Inconsistency**: Backend search may miss items without exact keyword matches
3. **Barcode Gaps**: Some barcodes return no data from external APIs
4. **Image Upload Limits**: Large images may fail upload or processing

**Architectural weaknesses:**
1. **No Caching Layer**: Every search hits backend API
2. **Limited Offline Support**: App requires network for most operations
3. **State Management**: Mixed patterns (StatefulWidget + ValueNotifier)
4. **Error Handling**: Inconsistent error reporting across features
5. **Database Queries**: Some queries could be optimized with better indexing

**UX issues:**
1. **Category Confusion**: Users see detailed taxonomy in filters instead of simple categories
2. **Bulk Operations**: No way to edit multiple items at once
3. **Search Precision**: Search may not find items with different wording
4. **Onboarding Gaps**: New users may not understand AI capabilities
5. **Feedback Loops**: Limited feedback when AI categorization is wrong

**Scaling concerns:**
1. **OpenAI Costs**: Per-request costs may grow with user base
2. **Database Performance**: No connection pooling configuration
3. **Image Storage**: Unlimited storage could become expensive
4. **API Rate Limits**: External barcode APIs have usage limits
5. **Realtime Features**: Current architecture not optimized for real-time collaboration

**AI limitations:**
1. **Vision Accuracy**: GPT-5 vision may misidentify items
2. **Category Consistency**: Same items may get different categories
3. **Context Memory**: Limited conversation context in chat
4. **Specialized Knowledge**: May not recognize niche products
5. **Confidence Scoring**: No user feedback loop for improving accuracy

**Category/filter problems:**
1. **Taxonomy Overflow**: AI returns hierarchical categories (Food > Pantry > Pasta)
2. **Filter Pollution**: Detailed categories clutter the filter interface
3. **Normalization Gaps**: Inconsistent mapping of similar categories
4. **User Confusion**: Users don't understand why some categories appear/disappear

**Scan inconsistencies:**
1. **Barcode Coverage**: Not all products have barcode data
2. **Image Quality**: Poor photos lead to failed extractions
3. **Lighting Issues**: Low light affects vision accuracy
4. **Multi-Item Photos**: Multiple items in one image cause confusion
5. **Review Workflow**: Users must manually review every scan result

**Partially implemented features:**
1. **Document Linking**: Basic structure but limited UI
2. **Activity Tracking**: Backend exists but frontend is minimal
3. **Low Stock Alerts**: Backend thresholds but limited notifications
4. **Semantic Search**: Planned but not implemented
5. **Collaboration**: Multi-user support planned but not started

==================================================
10. FUTURE ROADMAP
==================

**Intended product direction:**
- **Phase 1**: Fix core categorization and search issues
- **Phase 2**: Enhanced AI with semantic search and embeddings
- **Phase 3**: Proactive intelligence and recommendations
- **Phase 4**: Multi-household and collaboration features
- **Phase 5**: Enterprise and business inventory solutions

**AI memory system vision:**
- **Semantic Embeddings**: Vector search for finding similar items
- **Context Memory**: Remember user preferences and patterns
- **Learning Loop**: User feedback improves AI accuracy
- **Predictive Insights**: Suggest items before users need them
- **Cross-Device Intelligence**: Sync intelligence across user devices

**Semantic retrieval:**
- **Embedding Generation**: Create vectors for all item attributes
- **Similarity Search**: Find items by meaning, not just keywords
- **Category Clustering**: Automatically group similar items
- **Smart Suggestions**: Recommend categories based on similar items
- **Query Expansion**: Expand search queries with related terms

**Household memory layer:**
- **Temporal Patterns**: Track usage patterns over time
- **Seasonal Items**: Remember seasonal needs (holiday decorations, garden supplies)
- **Consumption Tracking**: Monitor usage rates for consumables
- **Purchase History**: Track where items were purchased
- **Maintenance Reminders**: Alert for maintenance or replacement needs

**Intelligent organization:**
- **Auto-Categorization**: Improve category assignment with learning
- **Smart Spaces**: Suggest optimal organization patterns
- **Duplicate Detection**: Identify and merge duplicate items
- **Location Optimization**: Suggest better storage locations
- **Inventory Optimization**: Recommend quantities based on usage

**Proactive recommendations:**
- **Shopping Lists**: Generate lists based on inventory gaps
- **Replacement Alerts**: Suggest replacements for consumables
- **Seasonal Reminders**: Remind about seasonal items
- **Storage Solutions**: Suggest organization improvements
- **Usage Insights**: Show patterns and trends

**Shared spaces/families:**
- **Multi-User Support**: Multiple users per household
- **Permission System**: Different access levels for family members
- **Shared Inventory**: Common household items tracking
- **Collaborative Scanning**: Multiple users can contribute
- **Family Insights**: Household-level usage patterns

**Future infrastructure plans:**
- **Microservices**: Split backend into specialized services
- **Event Streaming**: Use Kafka/Redis for real-time updates
- **CDN Integration**: Global image distribution
- **Edge Computing**: Local AI processing for privacy
- **Advanced Analytics**: Big data processing for insights

==================================================
11. BUILD & DEPLOYMENT
======================

**Flutter build flow:**
```bash
# Development
flutter run                    # Hot reload development
flutter build apk             # Android APK
flutter build ios             # iOS build (requires Xcode)

# Production
flutter build apk --release   # Production Android
flutter build ios --release   # Production iOS
flutter build web             # Web build (secondary)
```

**iOS setup:**
- **Xcode**: Required for iOS builds and testing
- **CocoaPods**: Dependency management for iOS
- **iOS Simulator**: Development testing
- **Physical Device**: Real device testing
- **App Store Connect**: App distribution

**TestFlight flow:**
```bash
1. Build iOS archive: flutter build ios --release
2. Open in Xcode: open ios/Runner.xcworkspace
3. Archive in Xcode: Product → Archive
4. Upload to TestFlight: Distribute App
5. Add testers in App Store Connect
6. Send TestFlight invitations
```

**Transporter IPA flow:**
```bash
1. Build IPA: flutter build ipa
2. Use Apple Transporter app
3. Upload IPA to App Store Connect
4. Submit for App Store review
5. Handle reviewer feedback
6. Release to App Store
```

**Supabase deployment:**
```bash
1. Create project on app.supabase.com
2. Apply migrations via SQL Editor
3. Set up Edge Functions
4. Configure storage buckets
5. Set up auth providers
6. Configure CORS settings
```

**Edge Function deployment:**
```bash
1. Write function in supabase/functions/
2. Test locally: supabase functions serve
3. Deploy: supabase functions deploy
4. Monitor via Supabase dashboard
```

**Required environment variables:**

**Frontend (.env):**
```
SUPABASE_URL=your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
API_BASE_URL=https://your-backend.com
```

**Backend (.env):**
```
SUPABASE_URL=your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_JWKS_URL=https://your-project.supabase.co/auth/v1/keys
OPENAI_API_KEY=your-openai-key
GO_UPC_API_KEY=your-go-upc-key (optional)
UPCITEMDB_USER_KEY=your-upcitemdb-key (optional)
```

**CI/CD considerations:**
- Automated testing on pull requests
- Build and test for multiple platforms
- Environment-specific configurations
- Secret management for API keys
- Rollback strategies for deployments

==================================================
12. DEPENDENCIES & TOOLS
========================

**Flutter packages:**
```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  supabase_flutter: ^2.10.0      # Auth and database
  dio: ^5.9.0                     # HTTP client
  flutter_dotenv: ^6.0.0          # Environment variables
  file_picker: ^10.2.0            # File selection
  url_launcher: ^6.3.2            # External links
  http_parser: ^4.1.2              # HTTP parsing
  image_picker: ^1.1.2            # Camera/photo access
  image: ^4.5.4                   # Image processing
  mobile_scanner: ^7.0.1          # Barcode scanning
  shared_preferences: ^2.3.2      # Local storage
  flutter_launcher_icons: ^0.14.4  # App icons

dev_dependencies:
  flutter_test: sdk
  flutter_lints: ^6.0.0           # Code quality
```

**Python backend packages:**
```python
fastapi==0.104.1              # Web framework
pydantic==2.5.0               # Data validation
pydantic-settings==2.1.0      # Configuration
supabase==2.3.0               # Supabase client
openai==1.3.0                 # OpenAI API
httpx==0.25.2                 # HTTP client
python-jose[cryptography]==3.3.0  # JWT handling
python-multipart==0.0.6       # Form data
anyio==3.7.1                  # Async utilities
```

**AI tools used:**
- **OpenAI GPT-5**: Primary AI model for vision and text
- **OpenAI API**: Structured data extraction and chat
- **Custom prompts**: Optimized for inventory domain
- **Tool calling**: Function execution for database operations
- **Streaming responses**: Real-time chat interface

**Windsurf usage:**
- **IDE Integration**: Primary development environment
- **Code Generation**: AI-assisted code completion
- **Debugging**: Integrated debugging tools
- **Version Control**: Git integration
- **Project Management**: File organization and navigation

**Supabase usage:**
- **Database**: PostgreSQL with RLS
- **Auth**: JWT-based authentication
- **Storage**: File hosting for images
- **Edge Functions**: Serverless compute
- **Realtime**: WebSocket connections (minimal)

**Flutter plugins:**
- **mobile_scanner**: Barcode scanning
- **image_picker**: Camera access
- **supabase_flutter**: Database and auth
- **file_picker**: Document selection
- **shared_preferences**: Local settings

**Image handling:**
- **Flutter image package**: Processing and manipulation
- **Supabase Storage**: Cloud storage
- **Image compression**: Size optimization
- **Format support**: JPEG, PNG, WebP
- **Memory management**: Efficient loading

**Scanning libraries:**
- **mobile_scanner**: Primary barcode scanning
- **ML Kit integration**: Android scanning
- **AVFoundation**: iOS scanning
- **Multiple formats**: EAN-13, UPC-A, QR Code, etc.
- **Real-time detection**: Live camera feed processing

==================================================
13. COMPLETE EXECUTION FLOW
===========================

**End-to-end flow examples:**

**Scanning an item (barcode):**
```
1. User opens ScanPage → MobileScanner initializes
2. User points camera at barcode → MobileScanner detects barcode
3. Barcode value returned → Frontend calls API barcodeLookup()
4. Backend processes barcode:
   a. Try go-UPC API lookup
   b. Try UPCItemDB API lookup  
   c. Fallback to OpenAI interpretation
5. Product data returned → ExtractedInventoryItem created
6. Category normalization applied → Top-level category assigned
7. User reviews item in UI → Can edit name/category/quantity
8. User taps "Save" → bulk_create_items() API call
9. Backend saves to database → Returns success/failure
10. UI updates → Refresh inventory cache → Navigate to inventory
```

**Creating an item (manual):**
```
1. User opens HomePage → Taps "Add Item" button
2. Quick-add dialog opens → User enters item details
3. Form validation → Ensures required fields filled
4. User taps "Add" → add_item() API call
5. Backend validates → Saves to database
6. Success response → UI updates inventory
7. Cache refresh → New item appears in lists
8. Activity logged → activity_log entry created
```

**Deleting account:**
```
1. User opens ProfilePage → Taps "Delete Account"
2. Confirmation dialog shown → User confirms deletion
3. Frontend calls delete-user Edge Function
4. Edge Function:
   a. Extracts user_id from JWT
   b. Deletes user data from items table
   c. Deletes user data from documents table
   d. Deletes user data from activity_log table
   e. Deletes user data from profiles table
   f. Deletes auth user via Supabase Admin API
5. Success response → Frontend signs out user
6. Navigate to login screen → Account fully deleted
```

**Searching inventory:**
```
1. User types in search box → TextChange event
2. 300ms debounce → search_query updated
3. ValueNotifier triggers → search_items_basic() API call
4. Backend processes query:
   a. Extract keywords via OpenAI
   b. Search database with keywords
   c. Return matching items
5. Results displayed → Filter by current category
6. Local filtering applied → UI updates in real-time
7. User can refine → Search continues with new query
```

**Category assignment:**
```
1. Item created via any method → Raw category from AI/external API
2. Category normalization function applied:
   a. Convert to lowercase
   b. Check for keyword matches
   c. Map to top-level category
   d. Fallback to "Other" if no match
3. Normalized category saved → Used in filters
4. UI displays category chips → Based on distinct categories
5. Filter selection → Items filtered by exact category match
```

**AI interaction:**
```
1. User opens ChatPage → Types message
2. Streaming request to /ai_command → Backend processes
3. OpenAI analyzes message → Determines intent
4. Tool calling if needed:
   a. inventory_search() for finding items
   b. add_inventory_item() for creating items
   c. update_inventory_item() for modifications
5. Tool execution → Database operations
6. Response generation → Natural language summary
7. Streaming response → Real-time chat display
8. UI updates → Inventory changes reflected
```

==================================================
14. STRATEGIC PRODUCT CONTEXT
=============================

**Product positioning:**
FindEZ positions itself as the "smart memory layer for physical possessions" - an AI-powered inventory system that goes beyond simple tracking to provide intelligent organization and insights. Unlike generic inventory apps that require manual data entry, FindEZ uses AI to automate categorization, enable natural language interaction, and provide proactive assistance.

**Competitors:**
- **Manual inventory apps** (Sortly, Memento): Require manual entry and categorization
- **Generic organizers** (Evernote, Notion): Not specialized for physical items
- **Home inventory apps** (Nesthub, Smart Home apps): Limited AI capabilities
- **Barcode scanners** (Scanner apps): No inventory management

**Intended moat:**
1. **AI-Powered Automation**: Vision-based item identification and categorization
2. **Natural Language Interface**: Chat-based inventory management
3. **Semantic Organization**: Intelligent categorization beyond manual tagging
4. **Learning System**: Improves accuracy based on user behavior
5. **Cross-Platform Intelligence**: Consistent experience across devices

**AI memory layer vision:**
The core differentiator is creating a persistent "memory" of user possessions that understands relationships, context, and patterns. This goes beyond simple databases to create an intelligent system that can:
- Remember where items are and when they were last used
- Understand relationships between items (batteries for devices, ingredients for recipes)
- Predict needs based on patterns and seasons
- Provide proactive assistance without being asked

**Why this differs from generic inventory apps:**
1. **Zero-Effort Entry**: Point camera → AI identifies and categorizes automatically
2. **Natural Interaction**: "Add 2 AA batteries to the garage" vs manual forms
3. **Intelligent Organization**: AI suggests optimal organization patterns
4. **Contextual Awareness**: Understands user intent and provides relevant suggestions
5. **Learning System**: Gets smarter with each interaction

**Market opportunity:**
- **Home organization**: Growing trend of minimalism and intentional living
- **Remote work**: Need to organize home offices and supplies
- **Sustainability**: Reduce waste by knowing what you already own
- **Sharing economy**: Easy inventory for sharing items with others
- **Aging population**: Help older adults track medications and important items

**Business model potential:**
- **Freemium**: Basic features free, advanced AI features paid
- **Family plans**: Multiple users per household
- **Business tier**: Professional inventory management
- **API access**: Integration with other smart home systems
- **Data insights**: Anonymized trend data for market research

==================================================
15. IMPORTANT NOTES FOR CLAUDE
==============================

**Critical files to inspect first:**
1. `mobile/lib/features/inventory/inventory_page.dart` - Main inventory interface and filtering logic
2. `mobile/lib/features/scan/scan_page.dart` - Scanning flow and category normalization
3. `mobile/lib/core/api_client.dart` - All API endpoints and authentication
4. `backend/app/services/ai_agent.py` - AI orchestration and tool calling
5. `backend/app/services/openai_service.py` - OpenAI integration and prompts
6. `backend/app/api/routes/inventory.py` - All inventory API endpoints

**Fragile areas of the codebase:**
1. **Category Normalization**: The `_normalizeCategory()` function is critical for UI consistency
2. **Filter Logic**: Category filtering in inventory_page.dart must match database categories exactly
3. **AI Prompts**: System prompts in openai_service.py directly affect categorization quality
4. **Auth Flow**: JWT validation and user extraction must remain secure
5. **Database Schema**: Any changes require corresponding migration files

**Things NOT to break:**
1. **Row Level Security**: Never modify RLS policies without thorough testing
2. **Category Consistency**: Frontend categories must match database categories exactly
3. **Auth Integration**: Supabase auth flow is critical for user data isolation
4. **Image Storage**: Don't break existing image URLs or storage paths
5. **Account Deletion**: The delete-user Edge Function must completely remove all user data

**Important architectural assumptions:**
1. **User Isolation**: All data is isolated by user_id via RLS policies
2. **Category Normalization**: All categories should be normalized to top-level categories
3. **AI Confidence**: High confidence AI results can be auto-saved, low confidence requires review
4. **Cache Invalidation**: Inventory cache must be refreshed when data changes
5. **Error Handling**: All API calls should handle network errors gracefully

**Areas requiring careful refactoring:**
1. **State Management**: Mixed StatefulWidget/ValueNotifier patterns could be unified
2. **Search System**: Backend search could be optimized with better indexing
3. **Category System**: The normalization logic could be centralized and made configurable
4. **Error Reporting**: Inconsistent error handling could be standardized
5. **API Client**: Could be split into separate services for better organization

**Performance considerations:**
1. **Image Uploads**: Large images can timeout or fail - implement compression
2. **Search Queries**: Complex searches can be slow - consider database optimization
3. **Memory Usage**: Large inventories can cause memory issues - implement pagination
4. **Network Requests**: Too many concurrent requests can cause rate limiting
5. **AI Costs**: OpenAI API calls should be monitored and optimized

**Security considerations:**
1. **API Keys**: Never expose service role keys to frontend
2. **User Data**: Ensure RLS policies prevent data leakage between users
3. **File Uploads**: Validate all uploaded files for security
4. **Input Validation**: Sanitize all user inputs before processing
5. **Rate Limiting**: Implement rate limiting to prevent abuse

**Testing priorities:**
1. **Auth Flow**: Test login, logout, and account deletion thoroughly
2. **Category System**: Verify normalization works for all AI responses
3. **Search Accuracy**: Test search with various query types
4. **Image Processing**: Test photo upload and AI extraction
5. **Barcode Scanning**: Test with various barcode formats and qualities

**Development workflow:**
1. **Always test auth flows** when making changes to user management
2. **Verify category consistency** when modifying AI or search systems
3. **Test on both platforms** (iOS and Android) for UI changes
4. **Check database performance** when modifying queries or indexes
5. **Monitor AI costs** when changing prompts or model usage

**Debugging tips:**
1. **Check Supabase logs** for database errors
2. **Monitor network requests** in Flutter DevTools
3. **Review AI responses** for categorization issues
4. **Test with real devices** for camera and scanning features
5. **Use database backups** when testing destructive operations

---

**This document provides a comprehensive technical foundation for understanding and working with the FindEZ AI Inventory application. All architectural decisions, data flows, and implementation details are documented to enable rapid onboarding and effective development.**
