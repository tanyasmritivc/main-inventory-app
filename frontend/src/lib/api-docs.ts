/** Public integration contract. Examples contain synthetic identifiers only. */
export const API_BASE = "https://api.findez.ai/api/v1";
export const DOCS_UPDATED = "September 10, 2026";
export const TEAM_ID = "10000000-0000-0000-0000-000000000001";
export const ITEM_ID = "40000000-0000-0000-0000-000000000001";
export const KEY_ID = "50000000-0000-0000-0000-000000000001";

export type DocCode = { label: string; language: string; value: string };
export type DocTable = { columns: string[]; rows: string[][] };
export type DocSection = {
  id: string; title: string; paragraphs: string[];
  steps?: string[]; table?: DocTable; codes?: DocCode[]; note?: string;
};
export type DocParameter = { name: string; in: "path" | "query"; required?: boolean; description: string; schema: Record<string, unknown> };
export type ApiEndpoint = {
  id: string; title: string; method: "GET" | "POST" | "PATCH" | "DELETE"; path: string;
  auth: "apiKey" | "userSession"; scopes: string[]; description: string; notes: string[];
  status: number; requestSchema?: string; body?: Record<string, unknown>;
  parameters?: DocParameter[]; response: Record<string, unknown>; responseSchema: string;
};

const motor = { name: "Motor", category: "Hardware", quantity: 4, location: "Shelf A", part_number: "5202" };
export const itemExample = {
  item_id: ITEM_ID, workspace_id: TEAM_ID, ...motor, image_url: null, barcode: null,
  purchase_source: null, notes: null, brand: null, source_system: null, external_id: null,
  created_at: "2026-09-10T12:00:00Z",
};
const keyExample = { id: KEY_ID, workspace_id: TEAM_ID, name: "Inventory reporting", key_prefix: "findez_live_sk_EXAMPL",
  scopes: ["items:read", "workspace:read"], created_at: "2026-09-10T12:00:00Z", last_used_at: null, expires_at: null, revoked_at: null };
const workspaceParameter: DocParameter = { name: "workspace_id", in: "query", description: "Optional team UUID. Narrows an organization key; a workspace key cannot target another team.", schema: { type: "string", format: "uuid" } };

export const apiEndpoints: ApiEndpoint[] = [
  { id: "verify-key", title: "Verify a connection", method: "GET", path: "/whoami", auth: "apiKey", scopes: [], status: 200,
    description: "Authenticate a key and inspect its workspace and granted permissions without reading or changing inventory.",
    notes: ["Any valid, active key can call this endpoint, including write-only keys. It consumes one standard request.", "A successful response verifies the credential, not a successful inventory read or write. workspace_id is null for an organization key."],
    response: { key_id: KEY_ID, workspace_id: TEAM_ID, scopes: ["items:read", "workspace:read"] }, responseSchema: "KeyIdentity" },
  { id: "list-items", title: "List inventory", method: "GET", path: "/items", auth: "apiKey", scopes: ["items:read", "org:read"], status: 200,
    description: "Retrieve a page of inventory visible to the key. Each record includes its team, quantity, location, and available identifiers.",
    parameters: [
      { name: "page", in: "query", description: "One-based page number. Default 1.", schema: { type: "integer", minimum: 1, default: 1 } },
      { name: "page_size", in: "query", description: "Records per page; default 50, maximum 100.", schema: { type: "integer", minimum: 1, maximum: 100, default: 50 } }, workspaceParameter,
    ],
    notes: ["Sorted by created_at descending, then item_id ascending. total counts matching records, not physical units.", "Use POST /query for filters. Continue paging until the returned page is empty or you have fetched total records. Concurrent changes can shift pages; deduplicate exports by item_id. There is no snapshot or incremental-sync cursor."],
    response: { items: [itemExample], page: 1, page_size: 50, total: 1 }, responseSchema: "ItemPage" },
  { id: "query-items", title: "Query inventory and totals", method: "POST", path: "/query", auth: "apiKey", scopes: ["items:read", "org:read"], status: 200,
    description: "Run a read-only, structured query with exact text filters, numeric quantity comparisons, and optional aggregation.", requestSchema: "InventoryQuery",
    body: { resource: "items", filters: [{ field: "part_number", op: "eq", value: "5202" }], aggregate: "sum_quantity" },
    notes: ["resource defaults to items, the only supported resource. Omit aggregate (or use null) for {resource, items, page, page_size, total}.", "count returns the number of records; sum_quantity returns stored units across all matches, regardless of page/page_size. Both return value: 0 when nothing matches. Totals do not subtract reservations or determine compatibility.", "An organization key may supply workspace_id in the JSON body; a workspace key cannot select another team. Unauthorized organization targets return no visible inventory.", "At most 10 ANDed filters. page defaults to 1 and is limited to 1–1,000,000; page_size defaults to 50 and is limited to 1–100. See Query language for field and value rules."],
    response: { resource: "items", aggregate: "sum_quantity", value: 4 }, responseSchema: "QueryResult" },
  { id: "create-item", title: "Create an inventory item", method: "POST", path: "/items", auth: "apiKey", scopes: ["items:write", "org:write"], status: 201,
    description: "Create one item in an existing Space linked to the selected team.", requestSchema: "APIItemCreate", body: motor,
    notes: ["name and location are required. category defaults to Other; quantity defaults to 1. location must exactly match one unambiguous linked Space. Create or attach the Space in FindEZ first.", "Organization keys must include workspace_id. Workspace keys may omit it. FindEZ resolves the actual Space owner; do not send user_id or space_id.", "The response echoes accepted fields plus item_id and workspace_id; it is not a full read-back of database defaults. Repeating this POST can create duplicates. For repeatable synchronization use bulk upsert."],
    response: { item: { ...motor, workspace_id: TEAM_ID, item_id: ITEM_ID } }, responseSchema: "CreatedItem" },
  { id: "update-item", title: "Update an inventory item", method: "PATCH", path: "/items/{item_id}", auth: "apiKey", scopes: ["items:write", "org:write"], status: 200,
    description: "Set fields on an existing item visible to the key. Only fields supplied in the request are changed.", requestSchema: "APIItemPatch", body: { quantity: 6 },
    parameters: [{ name: "item_id", in: "path", required: true, description: "Inventory UUID returned when listing or creating an item.", schema: { type: "string", format: "uuid" } }],
    notes: ["quantity is an absolute stock value, not an increment. Concurrent writers are last-write-wins; there is no version precondition or atomic increment endpoint.", "At least one field is required. name, category, location, and quantity cannot be null. Optional descriptive fields can be cleared with null.", "Changing location moves the item to an existing, unambiguous Space within its current workspace. workspace_id and user_id cannot be patched. A missing or inaccessible item returns 404."],
    response: { updated: true, item_id: ITEM_ID }, responseSchema: "UpdatedItem" },
  { id: "bulk-import", title: "Import or synchronize a batch", method: "POST", path: "/items/bulk", auth: "apiKey", scopes: ["import:write", "org:write"], status: 200,
    description: "Insert or update inventory by the stable identity (workspace_id, source_system, external_id). Repeating an identity updates the same record.", requestSchema: "APIBulkRequest",
    body: { items: [{ ...motor, source_system: "erp", external_id: "part-5202-shelf-a" }] },
    notes: ["Each item requires name, location, source_system, and external_id. Use 1–500 items per batch; a deployment may configure a lower cap. The bulk budget is separate from the standard request budget.", "source_system and external_id are trimmed, must not be blank, and must be unique as a pair within each workspace in the batch. Duplicate normalized identities return 400 before a write. A database identity conflict returns 409.", "This is an upsert, not a sparse PATCH. Always send authoritative quantity and category: their defaults (1 and Other) also apply during an update. Avoid mixing different field sets within one batch. Do not rely on omitted or null optional fields to clear existing data; use PATCH with explicit null.", "Use separate external IDs for the same part held in different locations. Keeping the identity while changing location moves the existing record within the workspace. Organization keys need workspace_id on every item.", "A batch is submitted as one database operation; a failed batch is not reported as partial success. After a timeout the outcome can be unknown: resend the same identities and intended values, not newly generated IDs. An omitted record is not deleted."],
    response: { processed: 1 }, responseSchema: "BulkResult" },
  { id: "list-locations", title: "List inventory locations", method: "GET", path: "/spaces", auth: "apiKey", scopes: ["workspace:read", "org:read"], status: 200,
    description: "List distinct item location names, grouped by workspace, with record counts.",
    notes: ["This is an inventory-location report, not a directory of all Space objects. Empty Spaces are absent. item_count counts records, not units.", "No pagination or workspace filter parameter is supported here. An organization key can return locations across owned teams. Create, attach, rename, and detach Spaces in the FindEZ app."],
    response: { spaces: [{ workspace_id: TEAM_ID, location: "Shelf A", item_count: 1 }] }, responseSchema: "LocationList" },
  { id: "workspace-summary", title: "Summarize workspaces", method: "GET", path: "/workspaces/summary", auth: "apiKey", scopes: ["workspace:read", "org:read"], status: 200,
    description: "Read visible team names and aggregate inventory counts. Organization keys can report across teams owned by the same account.",
    notes: ["item_count counts item records. space_count counts distinct locations represented by items, not every Space object. Empty workspaces can have zero counts.", "No request body or pagination parameters. For physical-unit totals, use POST /query with sum_quantity instead."],
    response: { workspaces: [{ workspace_id: TEAM_ID, name: "Workshop", item_count: 1, space_count: 1 }] }, responseSchema: "WorkspaceList" },
  { id: "owned-workspaces", title: "List teams available for key creation", method: "GET", path: "/keys/workspaces", auth: "userSession", scopes: [], status: 200,
    description: "List teams owned by the signed-in user. Use team_id as workspace_id when creating a key.",
    notes: ["Requires a normal FindEZ user access token, not an API key. Membership or a manager role alone does not qualify; the caller must own the team."],
    response: { workspaces: [{ team_id: TEAM_ID, name: "Workshop" }] }, responseSchema: "OwnedWorkspaces" },
  { id: "create-key", title: "Create an API key", method: "POST", path: "/keys", auth: "userSession", scopes: [], status: 201,
    description: "Issue a credential under the signed-in owner's account. Most users should use Settings → API keys instead of this management endpoint.", requestSchema: "CreateKeyRequest",
    body: { name: "Inventory reporting", workspace_id: TEAM_ID, scopes: ["items:read", "workspace:read"] },
    notes: ["name: 1–100 characters, not blank. scopes: 1–8 entries, using only permissions for the selected key type. For organization access omit workspace_id or set it to null and use org:read and/or org:write.", "expires_at is optional: a future ISO 8601 timestamp with a timezone is recommended. Omitted/null means no expiration. A timezone-less value is interpreted as UTC. The web form defaults to 90 days; the API itself does not.", "The response includes key exactly once. The example is deliberately not a usable credential. Store the returned value privately before discarding the response. List calls never return the raw key or its hash. Cache-Control is no-store.", "A timeout may leave a key created even if its raw value was never received. List keys, identify and revoke the unusable one, then create a replacement. There is no idempotency-key header or key-recovery endpoint."],
    response: { ...keyExample, org_id: "20000000-0000-0000-0000-000000000001", created_by: "20000000-0000-0000-0000-000000000001", key: "findez_live_sk_REPLACE_WITH_RETURNED_SECRET" }, responseSchema: "CreatedKey" },
  { id: "list-keys", title: "List key metadata", method: "GET", path: "/keys", auth: "userSession", scopes: [], status: 200,
    description: "List keys issued under the signed-in owner's account, newest first, including expired and revoked entries.",
    notes: ["Returns metadata only. last_used_at is updated on a best-effort basis at most once per five minutes and can remain null until first use. It is not an audit log or a billing counter.", "Cache-Control is no-store. No pagination parameters are supported. Use a fresh user session if the access token has expired."],
    response: { keys: [keyExample] }, responseSchema: "KeyList" },
  { id: "revoke-key", title: "Revoke an API key", method: "DELETE", path: "/keys/{key_id}", auth: "userSession", scopes: [], status: 200,
    description: "Revoke one credential owned by the signed-in user. Inventory is preserved; subsequent requests with the revoked key fail authentication.",
    parameters: [{ name: "key_id", in: "path", required: true, description: "The key metadata UUID, not the raw secret or prefix.", schema: { type: "string", format: "uuid" } }],
    notes: ["Revocation cannot be undone. Unknown, already-revoked, or another owner's key returns 404. Revocation cannot cancel a write that already completed.", "For planned rotation, create and validate a replacement, update the integration's secret, then revoke the old key. For a leak, revoke immediately."],
    response: { revoked: true, id: KEY_ID, revoked_at: "2026-09-10T12:30:00Z" }, responseSchema: "RevokedKey" },
];

export function endpointCurl(endpoint: ApiEndpoint): string {
  const path = endpoint.path.replace("{item_id}", ITEM_ID).replace("{key_id}", KEY_ID);
  const variable = endpoint.auth === "userSession" ? "FINDEZ_USER_ACCESS_TOKEN" : "FINDEZ_API_KEY";
  const lines = [`curl --fail-with-body --max-time 30 -X ${endpoint.method} '${API_BASE}${path}'`, `  -H "Authorization: Bearer $${variable}"`];
  if (endpoint.body) lines.push('  -H "Content-Type: application/json"', `  -d '${JSON.stringify(endpoint.body, null, 2)}'`);
  return lines.join(" \\\n");
}

export const guideSections: DocSection[] = [
  { id: "quickstart", title: "Quick start", paragraphs: ["Connect software to your real Team inventory over HTTPS. Start with a read-only key and verify one request before building a scheduled integration. All examples use synthetic data; replace identifiers and part numbers with your own."], steps: [
    "Sign in to FindEZ as a team owner. Create a Team if needed, then create or attach Spaces containing the inventory you want to expose. Unlinked personal inventory is not included.",
    "Open Settings → API keys. Choose one team, name the integration, keep Read inventory and Read workspace summary selected, and choose an expiration.",
    "Create the key, copy it to a private credential store, and click Test connection. The full key is displayed only once. The web test checks authentication and, with inventory-read permission, runs an inventory count; it does not test writes.",
    "In macOS Terminal or bash, run the first command below on its own. Paste the key and press Return; input stays hidden. Then run the connection check and inventory request.",
  ], codes: [
    { label: "Read your key privately", language: "Shell", value: "read -rs FINDEZ_API_KEY" },
    { label: "Check the key and read inventory", language: "Shell", value: `curl --fail-with-body --max-time 30 '${API_BASE}/whoami' \\\n  -H "Authorization: Bearer $FINDEZ_API_KEY"\n\ncurl --fail-with-body --max-time 30 '${API_BASE}/items?page=1&page_size=50' \\\n  -H "Authorization: Bearer $FINDEZ_API_KEY"\n\nunset FINDEZ_API_KEY` },
  ], note: "Do not paste the secret into this documentation, a chat, a spreadsheet cell, or a public code repository. This page does not execute API requests. A key enables access; it does not install a connector or schedule a job." },
  { id: "authentication", title: "Authentication and access boundaries", paragraphs: [
    "Send Authorization: Bearer <key> with every integration request. Use Content-Type: application/json for JSON bodies. The production base URL is https://api.findez.ai/api/v1. Keep credentials in headers, never in URLs.",
    "There are two credential types. Inventory, queries, summaries, and /whoami use an API key. All /keys management endpoints use the short-lived access token from a normal signed-in FindEZ user session. An API key cannot list, create, or revoke keys. Neither token is a Supabase anon key or service-role key.",
    "A workspace is a FindEZ Team, identified by its team UUID. A workspace key is restricted to one owned team. An organization key covers teams owned by the same account, including teams that account owns later; it is not a separate enterprise organization entity. Use individual workspace keys when that wider reach is unnecessary.",
    "Only owners can issue keys. A Space linked to a Team can belong to another team member; API-created items stay associated with the real Space and its owner. Detaching a Space removes the team's API access without deleting its items. Changing team ownership also removes access for keys under the former owner.",
    "Production keys begin findez_live_sk_; non-production keys begin findez_test_sk_. A test prefix is not a dry-run flag and is rejected by production. This guide does not provide a public sandbox. For safe testing, use a separate team with synthetic data and revoke its test credentials afterward.",
  ], table: { columns: ["Credential", "Used for", "How to obtain it"], rows: [
    ["API key", "/whoami, /items, /query, /spaces, /workspaces/summary", "Settings → API keys; shown once."],
    ["User access token", "/keys and /keys/workspaces", "Your authenticated FindEZ client session. Keep refresh tokens and session secrets private; do not use a captured session token as a permanent company integration key."],
  ] } },
  { id: "permissions", title: "Permissions", paragraphs: ["Grant only the permissions required by the integration. Workspace and organization scope names cannot be mixed on one key. Read and write are independent: write permission does not grant HTTP read access. /whoami needs no particular scope beyond a valid key."], table: {
    columns: ["Scope", "Key type", "Allows"], rows: [
      ["items:read", "Workspace", "GET /items and POST /query"], ["workspace:read", "Workspace", "GET /spaces and GET /workspaces/summary"],
      ["items:write", "Workspace", "POST /items and PATCH /items/{item_id}"], ["import:write", "Workspace", "POST /items/bulk"],
      ["org:read", "Organization", "All item reads, queries, location listings, and workspace summaries across owned teams"],
      ["org:write", "Organization", "Item creation, updates, and bulk imports across owned teams; workspace_id is required for creates/imports"],
    ],
  }, note: "For reporting, start with items:read and optionally workspace:read. For an ERP that only sends stock, use import:write. Add read permission separately if it must verify the resulting inventory." },
  { id: "query-language", title: "Query language", paragraphs: [
    "POST /query accepts structured JSON, not SQL or a natural-language question. Filters are combined with AND. Text comparisons are exact and case-sensitive: part_number = 5202 does not match 5202-0002, and location = Shelf A does not match shelf a.",
    "Supported text fields are name, category, location, brand, part_number, barcode, source_system, and external_id. Each text value must be a string of at most 200 characters; eq and neq are the only text operators. Null comparisons, contains, OR, wildcards, joins, grouping, and arbitrary projections are not supported. A nullable field with no value does not match either a text eq or neq comparison.",
    "quantity values must be JSON integers from 0 to 100000, not quoted numbers, fractions, or booleans. eq, neq, gt, gte, lt, and lte are supported. Supply at most 10 filters; an empty list matches all visible inventory.",
    "count counts records. sum_quantity adds physical quantities across all matching records, not just the returned page. For a part held in two records with quantities 4 and 2, count is 2 and sum_quantity is 6. This is not available-to-promise stock: reservations and compatibility are not evaluated.",
  ], codes: [
    { label: "Total units of an exact part", language: "JSON", value: JSON.stringify({ resource: "items", filters: [{ field: "part_number", op: "eq", value: "5202" }], aggregate: "sum_quantity" }, null, 2) },
    { label: "Records with two or fewer units at Shelf A", language: "JSON", value: JSON.stringify({ filters: [{ field: "location", op: "eq", value: "Shelf A" }, { field: "quantity", op: "lte", value: 2 }], page: 1, page_size: 50 }, null, 2) },
  ], note: "The low-stock filter above applies to each record, not a sum grouped by part. For a part-level alert, query sum_quantity for its exact identifier and compare the returned value with your threshold in your integration." },
  { id: "item-fields", title: "Item fields and validation", paragraphs: [
    "Requests reject unknown JSON fields. Never send item ownership fields, database columns outside this reference, or raw SQL. Write requests accept the fields below. See each endpoint for additional requirements; all IDs are UUIDs.",
    "PATCH accepts the same descriptive fields but not workspace_id. Omitted PATCH fields remain unchanged. Optional descriptive fields may be cleared with null; name, category, location, and quantity may not. Empty PATCH bodies fail with 400.",
  ], table: { columns: ["Field", "Type / limit", "Create and bulk behavior"], rows: [
    ["name", "String, 1–200 characters", "Required; trimmed and must not be blank."],
    ["location", "String, 1–200 characters", "Required exact name of one existing linked Space; trimmed. Unknown or ambiguous names fail."],
    ["quantity", "Integer, 0–100000", "Default 1. Absolute quantity, not a delta. Send JSON integers."],
    ["category", "String, 1–100 characters", "Default Other; trimmed and not blank."],
    ["workspace_id", "UUID", "Required for organization-key creates and each bulk item; optional for workspace keys. Cannot be patched."],
    ["brand / part_number / barcode", "Optional string, maximum 100 each", "Descriptive identifiers; use the exact stored part number for queries."],
    ["purchase_source", "Optional string, maximum 200", "Supplier/source description."],
    ["notes / image_url", "Optional string, maximum 2000 each", "Descriptive text or image reference. image_url does not upload or analyze an image."],
    ["source_system", "String, maximum 100", "Optional for single creates; required, trimmed, and nonblank for bulk import."],
    ["external_id", "String, maximum 200", "Optional for single creates; required, trimmed, and nonblank for bulk import. Identity is scoped to workspace plus source_system."],
    ["item_id / created_at", "UUID / timestamp", "Read fields, assigned by FindEZ. item_id is also returned after a create; created_at is returned by item reads."],
  ] } },
  { id: "recipes", title: "Integration use cases", paragraphs: ["The API is a building block for your software. The patterns below describe how to use the endpoints; they are not preinstalled connectors, managed schedules, or promises of third-party compatibility."], table: {
    columns: ["Use case", "Minimum access", "Implementation pattern"], rows: [
      ["Spreadsheet or BI report", "items:read", "Run a private scheduled job; paginate GET /items; map item_id, name, quantity, and location into the report. Keep the key outside the sheet and show the last successful refresh time."],
      ["Low-stock email", "items:read", "Poll POST /query. For total part stock, use exact-part sum_quantity; compare against your configured threshold. Send mail from your own automation, deduplicate alerts, and re-arm only after stock recovers."],
      ["ERP / accounting synchronization", "import:write; add items:read for reconciliation", "Use POST /items/bulk with stable external identities. Choose the stock system of record, send absolute quantities, batch consistently, record outcomes, and reconcile with a read key."],
      ["Warehouse dashboard", "org:read or separate workspace keys", "Use /workspaces/summary for record counts and POST /query with workspace_id for units. Show the workspace on every row and keep permissions aligned with report viewers."],
      ["Private or public inventory website", "items:read", "Your server calls FindEZ, then exposes only the approved fields to visitors. Cache safe results briefly. Never embed a key in client-side JavaScript; a key's team access is broader than a public page's intended data."],
      ["AI inventory lookup", "items:read", "Implement a server-side read-only tool that builds validated /query requests. Put the secret in tool configuration, not in the model prompt. Treat item names and notes as untrusted data, not instructions. Surface errors instead of inventing stock counts."],
      ["No-code HTTP automation", "The scopes required by its calls", "Configure an HTTPS request step with the base URL, method, Bearer credential, JSON body, and error handling. Select a platform that protects connection secrets from unauthorized editors/viewers."],
    ],
  }, note: "Dedicated AI connectors, MCP servers, spreadsheet add-ons, webhooks, and managed email alerts are not included in this API release. APIs for images, documents, Teams administration, item deletion, reservations, and build planning are not exposed to integration keys." },
  { id: "client-examples", title: "Server-side client examples", paragraphs: [
    "These read-only examples use standard libraries and make no requests until you run them. Supply FINDEZ_API_KEY through your deployment's secret environment. They make one call, enforce a timeout, check HTTP errors, and do not log credentials. Add the retry policy below in your production worker.",
    "The quick-start shell variable is intentionally not exported. If using it for a local Python or Node process, run export FINDEZ_API_KEY first, then unset FINDEZ_API_KEY when finished. Never commit an environment file containing the secret.",
  ], codes: [
    { label: "Python · standard library", language: "Python", value: `import json\nimport os\nfrom urllib.error import HTTPError, URLError\nfrom urllib.request import Request, urlopen\n\npayload = {\n    "resource": "items",\n    "filters": [{"field": "part_number", "op": "eq", "value": "5202"}],\n    "aggregate": "sum_quantity",\n}\nrequest = Request(\n    "${API_BASE}/query",\n    data=json.dumps(payload).encode("utf-8"),\n    headers={\n        "Authorization": "Bearer " + os.environ["FINDEZ_API_KEY"],\n        "Content-Type": "application/json",\n    },\n    method="POST",\n)\ntry:\n    with urlopen(request, timeout=30) as response:\n        result = json.load(response)\n    print("Stored units:", result["value"])\nexcept HTTPError as error:\n    reference = error.headers.get("x-correlation-id", "unavailable")\n    raise SystemExit(f"FindEZ HTTP {error.code}; reference {reference}")\nexcept (URLError, TimeoutError):\n    raise SystemExit("FindEZ could not be reached; do not treat this as zero stock.")` },
    { label: "Node.js · built-in fetch", language: "JavaScript", value: `// Save as findez-query.mjs and run with a supported Node.js runtime.\nconst key = process.env.FINDEZ_API_KEY;\nif (!key) throw new Error("Set FINDEZ_API_KEY in the process environment.");\n\nconst response = await fetch("${API_BASE}/query", {\n  method: "POST",\n  headers: {\n    Authorization: "Bearer " + key,\n    "Content-Type": "application/json",\n  },\n  body: JSON.stringify({\n    resource: "items",\n    filters: [{ field: "part_number", op: "eq", value: "5202" }],\n    aggregate: "sum_quantity",\n  }),\n  signal: AbortSignal.timeout(30000),\n});\nif (!response.ok) {\n  const reference = response.headers.get("x-correlation-id") || "unavailable";\n  throw new Error("FindEZ HTTP " + response.status + "; reference " + reference);\n}\nconst result = await response.json();\nconsole.log("Stored units:", result.value);` },
  ] },
  { id: "operations", title: "Limits, retries, and synchronization", paragraphs: [
    "Standard integration endpoints share a per-key budget of 120 requests per minute by default. Bulk imports have a separate per-key budget of 10 requests per minute. Limits are enforced across server workers and may be configured lower or higher by the deployment. /whoami also consumes the standard budget. Do not spread traffic across keys to evade limits.",
    "A per-key 429 response includes Retry-After: 60. Wait at least that long, add jitter, and retry only a bounded number of times. Do not depend on undocumented X-RateLimit headers. For temporary 503 or transport failures, retry safe reads with exponential backoff and jitter; stop after a small retry budget and alert an operator.",
    "POST /query is read-only and can be retried. POST /items and POST /keys are not idempotent: a lost response does not prove the write failed. Reconcile before repeating those operations. Bulk upsert is repeatable only when you retain the same stable identities and intended values; it must not overwrite a newer change from another writer. PATCH sets absolute values and has no concurrency precondition.",
    "Choose one authoritative stock writer per integration boundary. Preserve source identifiers, set an explicit polling cadence, serialize conflicting writes, and record the last successful sync. Prefer one sum query over downloading all records when only a total is needed. Paginated reads are not a point-in-time snapshot; deduplicate by item_id and reconcile periodically.",
    "A 401 or 403 requires credential or permission attention, not a tight retry loop. A 400, 409, 413, or 422 requires correcting the request or batch. Do not turn an authentication or network error into an empty inventory report or a zero-stock alert.",
  ], table: { columns: ["Limit", "Default / maximum", "Applies to"], rows: [
    ["Standard requests", "120 per minute per key", "All integration data endpoints except bulk"],
    ["Bulk requests", "10 per minute per key", "POST /items/bulk"],
    ["Batch size", "1–500 items; server may impose a lower cap", "POST /items/bulk"],
    ["Page size", "50 default; 100 maximum", "GET /items and POST /query"],
    ["Filters", "10 maximum, combined with AND", "POST /query"],
    ["Last-used timestamp", "Best effort; at most one update per five minutes", "Key metadata; not a per-request audit log"],
  ] } },
  { id: "errors", title: "Errors and troubleshooting", paragraphs: [
    "Integration errors normally use {detail: {code, message, correlation_id}}. Validation failures return a generic invalid_request message without echoing the submitted data. Session-authentication failures on key-management endpoints may use a plain detail string. Proxies or connection failures can also return a non-JSON response; check the HTTP status before parsing.",
    "x-correlation-id is returned in API responses. You may supply your own value for tracing; the server truncates it to 64 characters. Never put personal data or credentials in it. When contacting support, include this reference, the endpoint, HTTP status, and UTC time—not the Authorization header or raw key.",
  ], table: { columns: ["HTTP / code", "Meaning", "Next action"], rows: [
    ["400 · invalid_scope / scope_type_mismatch", "Permissions do not match the chosen key type.", "Use workspace scopes for a team UUID, organization scopes for null workspace_id."],
    ["400 · invalid_expiration / workspace_required / empty_update", "Invalid expiry, missing organization write target, or no PATCH fields.", "Correct the request; do not retry unchanged."],
    ["400 · invalid_inventory_request", "Invalid query or unknown/ambiguous linked Space name.", "Check exact location spelling and Team attachment; use the documented filter grammar."],
    ["400 or 409 · duplicate_external_id", "Duplicate batch identity or conflicting stored identity.", "Deduplicate within the workspace and use bulk upsert for existing external records."],
    ["401 · invalid_api_key / wrong_environment", "Missing, malformed, unknown, or wrong-environment credential.", "Send the full production key as a Bearer header. Do not use the prefix alone."],
    ["401 · expired_api_key / revoked_api_key", "The credential is no longer active.", "Generate a replacement and update the integration's secret."],
    ["403 · insufficient_scope", "The key lacks this operation's permission.", "Issue a least-privilege replacement with the required scope; writes do not imply reads."],
    ["403 · workspace_access_denied / organization_required", "Wrong team, no owned team, or access changed.", "Check team ownership and the key's workspace. Only owners can issue keys."],
    ["404 · item_not_found / key_not_found", "Missing/inaccessible item or unknown/already-revoked key.", "Check the UUID and credential owner. Do not assume an inaccessible resource exists."],
    ["413 · bulk_payload_too_large", "Batch exceeds the configured server cap.", "Split the batch. More than 500 items may instead be rejected during validation with 422."],
    ["422 · invalid_request", "Invalid types, bounds, UUIDs, extra fields, or request structure.", "Check the field reference and OpenAPI schema. Query quantity filters require integer values."],
    ["429 · rate_limit_exceeded", "Request budget exhausted.", "Honor Retry-After, add jitter, and reduce polling or batch frequency."],
    ["503 · *_unavailable / database_unavailable", "Temporary key, authentication, limit, workspace, or inventory service failure.", "Retry safe reads with bounded backoff; reconcile uncertain writes before retrying."],
    ["500 · internal_error", "Unexpected server error.", "Record the correlation ID and contact support; treat uncertain writes cautiously."],
    ["200 with no items", "No visible matching inventory; not necessarily a connection failure.", "Check linked Team Spaces, exact/case-sensitive filters, page number, and ownership. /spaces excludes empty Spaces."],
  ] }, codes: [{ label: "Example error response", language: "JSON", value: JSON.stringify({ detail: { code: "insufficient_scope", message: "This endpoint requires items:read.", correlation_id: "example-request-reference" } }, null, 2) }] },
  { id: "security", title: "Company security and key lifecycle", paragraphs: [
    "Treat every key as a password for your data. Store it in a secrets manager or protected connection setting, inject it only into trusted server-side processes, and redact Authorization headers from logs, traces, error reports, and support tickets. FindEZ stores an Argon2 hash, not a recoverable raw key.",
    "Issue one key per integration and environment, give it an identifiable name and owner, prefer a single workspace, and set an expiration. Review unused keys periodically. A key cannot be renamed, re-scoped, or extended through this integration API; create a replacement when requirements change.",
    "For planned rotation: create a replacement with the required scopes, test /whoami and an allowed read, update the receiving system's secret, verify a successful scheduled run, then revoke the old key. Test writes only in synthetic inventory. Never use real customer stock as an integration smoke test.",
    "If a key is leaked, revoke it immediately, stop affected jobs, replace the credential, and review your integration logs and inventory changes. Revocation does not undo completed writes. last_used_at is approximate and cannot establish a complete history of key activity.",
    "Permission to read a workspace is not permission to publish its contents. Limit what downstream dashboards and AI tools receive, restrict access to exported copies, and establish your own retention and deletion process. Detaching a Space or revoking a key cannot erase copies already exported to another system.",
  ], steps: [
    "Assign an integration owner and a support contact; document which teams and fields are in scope.",
    "Validate with a separate team and synthetic records: valid reads, forbidden writes, wrong-workspace access, repeat upserts, rate-limit handling, and revocation.",
    "Set timeouts, bounded retries, sync monitoring, stale-data indicators, and a reconciliation procedure before scheduling production jobs.",
    "Plan key rotation and employee/vendor offboarding; never share one credential across unrelated companies or environments.",
  ] },
  { id: "availability", title: "Coverage, versioning, and support", paragraphs: [
    "This guide describes the current /api/v1 integration surface, reviewed September 10, 2026. It is not a reference for every endpoint used internally by the FindEZ web or mobile app. API keys cannot substitute for a user session on those application routes.",
    "Supported today: scoped key issuance and revocation, inventory listing and structured queries, item creation and absolute updates, external-identity bulk upserts, location reports, and workspace summaries. Not included: item deletion, creating/attaching Spaces by API key, webhooks, change streams, raw SQL, generic file uploads, stock reservations, atomic increments, or automatic reordering.",
    "The downloadable OpenAPI 3.1 specification describes the same endpoints and request models. Bearer permissions are documented per operation; they are not OAuth scopes or an OAuth authorization flow. Importing the file into an API client does not grant permissions or supply credentials.",
    "No public sandbox, uptime SLA, usage-based billing contract, dedicated connector, or deprecation notice period is promised by this guide. Discuss procurement, scale requirements, security review, or additional functionality with info@findez.ai before making them dependencies of a business process.",
    "When requesting help, provide the integration name, affected workspace UUID if appropriate, endpoint, status, correlation ID, UTC timestamp, and a redacted example. Never send passwords, access tokens, raw API keys, or customer inventory exports unless a secure exchange has been agreed.",
  ] },
];

export function documentationMarkdown(): string {
  const output = ["# FindEZ Integration API", `API v1 · Reviewed ${DOCS_UPDATED}`, `Base URL: ${API_BASE}`, "Public documentation: https://findez.ai/docs/api", ""];
  for (const section of guideSections) {
    output.push(`## ${section.title}`, "", ...section.paragraphs.flatMap(p => [p, ""]));
    section.steps?.forEach((step, i) => output.push(`${i + 1}. ${step}`));
    if (section.table) output.push("", `| ${section.table.columns.join(" | ")} |`, `| ${section.table.columns.map(() => "---").join(" | ")} |`, ...section.table.rows.map(row => `| ${row.join(" | ")} |`));
    section.codes?.forEach(code => output.push("", `### ${code.label}`, "", "```" + code.language.toLowerCase(), code.value, "```"));
    if (section.note) output.push("", `Note: ${section.note}`);
    output.push("");
  }
  output.push("## Endpoint reference", "");
  for (const endpoint of apiEndpoints) {
    output.push(`### ${endpoint.method} ${endpoint.path} — ${endpoint.title}`, "", endpoint.description,
      `Authentication: ${endpoint.auth === "apiKey" ? "API key" : "FindEZ user access token"}. ${endpoint.scopes.length ? "Required scope (either): " + endpoint.scopes.join(" or ") + "." : "No additional operation scope."}`, "", ...endpoint.notes, "");
    endpoint.parameters?.forEach(p => output.push(`- ${p.name} (${p.in}${p.required ? ", required" : ", optional"}): ${p.description}`));
    if (endpoint.requestSchema) output.push(`Request model in OpenAPI: ${endpoint.requestSchema}`);
    output.push("", "```bash", endpointCurl(endpoint), "```", "", `Example response (${endpoint.status}):`, "```json", JSON.stringify(endpoint.response, null, 2), "```", "");
  }
  return output.join("\n") + "\n";
}
