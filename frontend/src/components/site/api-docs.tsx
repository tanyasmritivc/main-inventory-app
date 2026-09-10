import Link from "next/link";
import { apiOrigin, apiReference, endpoints, requestExamples, resolveSchema, schemaConstraints, schemaType, type Schema, type Endpoint } from "@/lib/api-reference";
import { CodeExample, DocsNavigation } from "./api-docs-controls";
import styles from "./api-docs.module.css";

function Fields({ schema, label }: { schema: Schema; label: string }) {
  const resolved = resolveSchema(schema);
  const alternatives = resolved.oneOf ?? resolved.anyOf;
  if (alternatives) return <>{alternatives.map((entry, index) => <Fields key={index} schema={entry} label={`${label}: ${schemaType(entry)}`} />)}</>;
  if (!resolved.properties) return <p>{schemaType(schema)}. {resolved.description}</p>;
  return <div className={styles.tableWrap}><table><caption>{label}</caption><thead><tr><th>Field</th><th>Type / presence</th><th>Meaning & constraints</th></tr></thead><tbody>
    {Object.entries(resolved.properties).map(([name, field]) => <tr key={name}><td><code>{name}</code></td><td><code>{schemaType(field)}</code><small>{resolved.required?.includes(name) ? "Required" : "Optional"}</small></td><td>{field.description}<small>{schemaConstraints(field)}</small>{(field.$ref || field.items?.$ref || field.properties) && <details><summary>Nested fields</summary><Fields schema={field.items ?? field} label={`${name} fields`} /></details>}</td></tr>)}
  </tbody></table></div>;
}

function EndpointReference({ endpoint }: { endpoint: Endpoint }) {
  const [status, response] = Object.entries(endpoint.responses).find(([code]) => code.startsWith("2"))!;
  const content = response.content["application/json"];
  const body = endpoint.requestBody?.content["application/json"];
  const management = Boolean(endpoint.security[0].UserSession);
  return <section id={endpoint.operationId} className={styles.endpoint} aria-labelledby={`${endpoint.operationId}-title`}>
    <div className={styles.endpointPath}><span>{endpoint.method}</span><code>{endpoint.path}</code></div>
    <h2 id={`${endpoint.operationId}-title`}>{endpoint.summary}</h2>
    <p className={styles.requirement}>{management ? "Owner user session required" : endpoint["x-required-scope"] ? `Permission: ${endpoint["x-required-scope"]}${endpoint["x-required-scope"]?.includes("read") ? " or org:read" : " or org:write"}` : "Any valid integration key"} · HTTP {status}{endpoint["x-rate-bucket"] ? ` · ${endpoint["x-rate-bucket"]} request budget` : ""}</p>
    <p>{endpoint.description}</p>
    {endpoint.parameters?.length ? <div className={styles.tableWrap}><table><caption>URL parameters</caption><thead><tr><th>Parameter</th><th>Type / location</th><th>Meaning & constraints</th></tr></thead><tbody>{endpoint.parameters.map((field) => <tr key={field.name}><td><code>{field.name}</code><small>{field.required ? "Required" : "Optional"}</small></td><td>{schemaType(field.schema)} · {field.in}</td><td>{field.description}<small>{schemaConstraints(field.schema)}</small></td></tr>)}</tbody></table></div> : <p className={styles.muted}>No URL parameters.</p>}
    {body ? <Fields schema={body.schema} label="JSON request body" /> : <p className={styles.muted}>No request body.</p>}
    <CodeExample label={`${endpoint.method} ${endpoint.path} request`} examples={requestExamples(endpoint)} />
    <CodeExample label={`HTTP ${status} response`} examples={{ JSON: JSON.stringify(content.example, null, 2) }} />
    <details className={styles.responseFields}><summary>Response fields</summary><Fields schema={content.schema} label="Success response" /></details>
    {Object.entries(endpoint["x-extra-examples"]).map(([title, example]) => <details className={styles.responseFields} key={title}><summary>{title}</summary><CodeExample label={title} examples={requestExamples(endpoint, example.request)} />{example.response !== undefined && <CodeExample label={`${title} response`} examples={{ JSON: JSON.stringify(example.response, null, 2) }} />}</details>)}
  </section>;
}

const permissionRows = [
  ["items:read", "Workspace", "List items and run structured queries"],
  ["workspace:read", "Workspace", "Read location counts and workspace summaries"],
  ["items:write", "Workspace", "Create and patch items"],
  ["import:write", "Workspace", "Bulk upsert items"],
  ["org:read", "Organization", "Item queries, lists, locations, and summaries across owned teams"],
  ["org:write", "Organization", "Create, patch, and bulk upsert across owned teams"],
];

export function ApiDocs() {
  const limits = apiReference["x-limits"];
  const queryEndpoint = endpoints.find((entry) => entry.path === "/api/v1/query")!;
  return <div className={styles.page}>
    <a href="#api-docs-content" className={styles.skipLink}>Skip to documentation</a>
    <header className={styles.header}><Link href="/" className={styles.brand}>FindEZ <span>/ Developers</span></Link><div><Link href="/docs/api/openapi.json" download="findez-openapi.json">OpenAPI JSON</Link><Link href="/settings/api-keys">Manage API keys ↗</Link></div></header>
    <div className={styles.layout}>
      <aside className={styles.sidebar}><DocsNavigation /></aside>
      <main id="api-docs-content" className={styles.content}>
        <div className={styles.hero}><p className={styles.eyebrow}>Integration API · v1</p><h1>Build with your inventory.</h1><p>Connect FindEZ Team Spaces to reports, scripts, and external tools. Start with a read-only request, then explore the complete endpoint reference.</p><div className={styles.baseUrl}><span>Base URL</span><code>{apiOrigin}/api/v1</code></div><p className={styles.muted}>Public documentation · No sign-in needed · Examples use fictional data</p></div>

        <section id="quickstart"><h2>Your first connection</h2><ol>
          <li>Sign in to FindEZ and open <Link href="/teams">Teams</Link>. Create or use a Team you own, then link a Space containing inventory. Being a team member alone does not allow key creation.</li>
          <li>Open <Link href="/settings/api-keys">Settings → API keys</Link>. Name the integration, choose the team, keep the default read permissions, and choose an expiration. The web form defaults to 90 days.</li>
          <li>Create the key and copy it to your integration’s private credential settings. The full value is shown once. Use <strong>Test connection</strong> before dismissing it: read keys run an inventory count; workspace-only keys check the summary; write-only keys check authentication without writing.</li>
          <li>For the examples below, use macOS Terminal (zsh or bash). Run this command on its own, paste the key at the hidden prompt, then press Return:</li>
        </ol>
        <CodeExample label="Enter your API key" examples={{ Shell: "read -rs FINDEZ_API_KEY" }} />
        <p>Export it for the Python and Node.js examples. Keep the same terminal open; never paste the actual key into the example source.</p>
        <CodeExample label="Export your API key" examples={{ Shell: "export FINDEZ_API_KEY" }} />
        <CodeExample label="First inventory request" examples={requestExamples(endpoints.find((entry) => entry.path === "/api/v1/items" && entry.method === "GET")!)} />
        <p>A successful response contains <code>items</code>, <code>page</code>, <code>page_size</code>, and <code>total</code>. An empty array is a valid result: check that the selected Team has a linked Space with items. Response examples below are illustrative; your IDs, dates, and values will differ.</p>
        <p>When finished, run <code>unset FINDEZ_API_KEY</code>. The cURL examples use <code>--fail-with-body</code> (cURL 7.76+); Python uses the standard library, and JavaScript runs in Node.js 18+ with no packages. On Windows, use your tool’s private credential settings or run the shell instructions in WSL.</p>
        </section>

        <section id="authentication"><h2>Authentication & permissions</h2><p>Send <code>Authorization: Bearer &lt;credential&gt;</code> on every API request over HTTPS. Use the API host above; <code>findez.ai</code> serves the web app. Credentials belong in the header, never the URL. Production keys start with <code>findez_live_sk_</code>, followed by 32 URL-safe characters; development keys start with <code>findez_test_sk_</code>. Each environment only accepts its own keys. A test prefix does not create a production sandbox, and the public service does not offer a documented test-data environment.</p>
        <p><strong>Integration requests</strong> use your API key. <strong>Key management</strong> uses the signed-in owner’s Supabase user <code>access_token</code>. An API key cannot create, list, or revoke keys, and a user session cannot replace the API key on inventory integration endpoints. Most users should manage keys in Settings; programmatic management examples assume you already have a valid user session. Load that access token privately into <code>FINDEZ_USER_ACCESS_TOKEN</code>, using the same separate <code>read -rs</code> and <code>export</code> steps. Never substitute an anonymous project key, a refresh token, or a service-role credential.</p>
        <div className={styles.tableWrap}><table><caption>Available scopes</caption><thead><tr><th>Scope</th><th>Key type</th><th>Allows</th></tr></thead><tbody>{permissionRows.map(([scope, type, description]) => <tr key={scope}><td><code>{scope}</code></td><td>{type}</td><td>{description}</td></tr>)}</tbody></table></div>
        <p>Read and write are independent. <code>items:write</code> does not include bulk import or reads. <code>import:write</code> does not include single-item create/patch. <code>workspace:read</code> does not allow item reads. Organization read/write scopes provide the corresponding operations across teams owned by the issuing account. Workspace and organization scopes cannot be mixed in one key. Every valid key can call <code>GET /whoami</code>.</p>
        <p>Use one key per integration and grant only the required permissions. Keep it in a server-side secret manager or your automation tool’s private credentials, outside source control, browser code, public spreadsheets, and logs. Arbitrary browser origins are not enabled for CORS; call the API from your own server, which keeps the secret private. A key does not install an integration or schedule jobs by itself.</p>
        <p>To rotate a key: create a replacement, test the required access, update the integration, verify it works, then revoke the old key. Revocation is permanent. Lost keys cannot be retrieved; exposed keys should be revoked and replaced. No endpoint updates an issued key’s scopes or expiry.</p></section>

        <section id="workspaces"><h2>Teams, Spaces & visibility</h2><p>A <strong>workspace</strong> is a FindEZ Team: <code>workspace_id</code> is its <code>team_id</code> UUID. A <strong>Space</strong> is a place containing inventory. The integration API sees inventory in Spaces linked to the Team. Personal Spaces outside Teams, and Teams you only belong to, are outside this API’s access.</p>
        <p>A workspace key is fixed to one Team. An organization key covers all Teams currently owned by the same account, including newly owned teams. Here, “organization” means that owner account, not a separate company record. Organization writes need a <code>workspace_id</code> in every item; organization lists and queries can omit it to read across owned teams.</p>
        <p>API writes use the exact linked Space name as <code>location</code>. Create and link the Space in FindEZ first. If two linked Spaces have the same name, rename one before writing through the API. The API preserves the destination Space’s actual owner and places the item in that Space. Moving an item by PATCH is limited to its existing workspace.</p>
        <p>New app items in linked Spaces become visible through the API. Detaching a Space removes that Team’s API access while preserving its inventory; moving it changes which Team can see it. Ownership changes and Team deletion also remove data access. The key may still authenticate at <code>/whoami</code>, so use a read/query to check actual visibility.</p>
        <p><code>GET /spaces</code> groups item locations and omits empty Spaces. <code>space_count</code> in a summary counts distinct location strings with inventory. Neither is a complete directory of linked Space records. Use FindEZ to manage the actual links and Space names.</p></section>

        <section id="requests"><h2>Requests & responses</h2><p>Use JSON for POST/PATCH bodies and set <code>Content-Type: application/json</code>. Unknown JSON properties are rejected, including nested item/filter properties. Use the exact field names in the tables. Unknown URL query parameters are currently ignored; only parameters explicitly documented on an endpoint are supported.</p>
        <p>UUIDs are strings. Quantities are whole numbers between 0 and 100000. Send text identifiers as strings so leading zeroes survive. Name, category, and location are trimmed and cannot be blank. Optional text can be null where specified. For PATCH, omitted fields stay unchanged; null clears only nullable fields. For creates and bulk upserts, send the intended values explicitly, especially quantity and category.</p>
        <p>Pages start at 1 with a default size of 50 and a maximum of 100. <code>GET /items</code> accepts any page ≥ 1; <code>POST /query</code> additionally caps page at 1000000. Both sort newest first, then by item ID. <code>total</code> counts all matching records. Pagination is offset based with no snapshot or cursor; a changing inventory can cause repeats or omissions across requests.</p>
        <p><code>created_at</code> is the creation timestamp, not a modification checkpoint. The API returns the stored timestamp representation; clients should handle ISO 8601 dates without assuming an offset is always present in older inventory records. There is no <code>updated_at</code> filter or incremental change feed.</p>
        <p>The readable item representation contains only the fields in the response reference. It does not expose user IDs, Space IDs, reservations, available-to-build stock, tags, checkout state, or document contents. An image URL is a stored reference, not an uploaded file or a guarantee of long-term accessibility.</p>
        <p>Download the <Link href="/docs/api/openapi.json" download="findez-openapi.json">OpenAPI 3.1 document</Link> to inspect schemas or import requests into a compatible API client. Its server URL is the API origin, and its paths already include <code>/api/v1</code>; do not add the version prefix twice. Backend <code>/docs</code>, <code>/redoc</code>, and <code>/openapi.json</code> are disabled in production; use this public reference.</p></section>

        <section id="recipes"><h2>Integration recipes</h2><h3>How many units of a part do we have?</h3><p>Use the exact stored <code>part_number</code> and <code>sum_quantity</code>. Three records holding 4, 2, and 2 units total 8, while <code>count</code> returns 3. Totals include all matching pages and return 0 for no matches. They reflect stored quantity, without subtracting checkouts or reservations.</p>
        <CodeExample label="Total units by part number" examples={requestExamples(queryEndpoint)} />
        <h3>Low-stock report for one location</h3><p>Combine filters with AND. This finds records at or below five units in Shelf B. It does not read device-specific thresholds or send alerts; your integration schedules checks and decides what to do.</p>
        <CodeExample label="Low-stock location query" examples={requestExamples(queryEndpoint, { filters: [{ field: "location", op: "eq", value: "Shelf B" }, { field: "quantity", op: "lte", value: 5 }], page: 1, page_size: 50 })} />
        <h3>Export all visible records</h3><p>Fetch each page until the number collected reaches <code>total</code>, or a page is empty. The example stops on empty pages and deduplicates item IDs, but concurrent writes can still move rows; run during a quiet period if you need a consistent report. The export includes fields such as notes, so store it only where intended readers have access.</p>
        <CodeExample label="Paginated Python export" examples={{ Python: `import json\nimport os\nfrom urllib.request import Request, urlopen\n\nitems = {}\npage = 1\nwhile True:\n    request = Request(\n        "${apiOrigin}/api/v1/items?page=" + str(page) + "&page_size=100",\n        headers={"Authorization": "Bearer " + os.environ["FINDEZ_API_KEY"]},\n    )\n    with urlopen(request, timeout=30) as response:\n        result = json.load(response)\n    for item in result["items"]:\n        items[item["item_id"]] = item\n    if not result["items"] or page * result["page_size"] >= result["total"]:\n        break\n    page += 1\nprint(json.dumps(list(items.values()), indent=2))` }} />
        <h3>Connect a spreadsheet, automation, or AI tool</h3><p>Configure an HTTP action with the API URL, method, Bearer credential, and JSON body from the reference. Use item reads for reporting and bulk upsert for a source-of-truth sync. Keep the credential in private connection settings; a visible spreadsheet cell is not private storage. Map <code>items</code> for lists or <code>value</code> for totals, and handle non-2xx responses before using data. An AI tool must call this API with supported structured filters; the API has no natural-language or SQL execution endpoint. There is no bundled SDK, MCP server, webhook subscription, or automatic third-party connection in this API release.</p></section>

        <section id="sync"><h2>Reliable writes & sync</h2><ol>
          <li>Choose which system owns each field to avoid overwriting edits made in FindEZ.</li>
          <li>Link the destination Spaces and verify their exact names. For organization keys, map each record to an owned Team UUID.</li>
          <li>Choose a stable <code>source_system</code> namespace and an <code>external_id</code> for each source record. The same identity in a different workspace is a different record.</li>
          <li>Send the full intended quantity and category every time. Bulk upsert uses create defaults for omitted fields; it is not a partial PATCH. Keep optional columns consistent across a batch, and use PATCH for explicit null clearing.</li>
          <li>Split into batches within the server cap, remove duplicate identities, and record which batches succeeded. Each batch is atomic; a multi-batch job is not one transaction.</li>
          <li>Reconcile results with a read-enabled key. <code>processed</code> acknowledges row processing; it does not include item IDs or inserted/updated counts.</li>
        </ol><p>Repeating the same bulk identities avoids duplicate rows, but a retry still overwrites the values it supplies. New external IDs create new records, and omitting a record does not delete it. There is no delete-item endpoint for integration keys. PATCH can clear or change external identities, which affects future matching; avoid changing them after a sync is established.</p>
        <p>Single-item POST always creates a row and has no idempotency header. After a timeout, inspect existing inventory before creating again. Absolute PATCH values can be resent, but may overwrite a newer edit. There are no compare-and-set preconditions, atomic increments, transactions across HTTP requests, or concurrency locks exposed to clients.</p></section>

        <section id="limits"><h2>Limits & retries</h2><div className={styles.tableWrap}><table><caption>Default per-key budgets</caption><thead><tr><th>Limit</th><th>Default</th><th>Applies to</th></tr></thead><tbody>
          <tr><td>Standard requests</td><td>{limits.api_key_requests_per_minute} / minute</td><td>All API-key endpoints except bulk, including /whoami</td></tr>
          <tr><td>Bulk requests</td><td>{limits.api_key_bulk_requests_per_minute} / minute</td><td>POST /items/bulk, in a separate budget</td></tr>
          <tr><td>Bulk items</td><td>{limits.api_key_bulk_max_items} / request</td><td>At least 1; schema hard maximum 500</td></tr>
        </tbody></table></div><p>These are server defaults and can be configured. Limits are shared by all clients using the same key. Standard and bulk budgets are independent, use fixed minute windows, and are checked after authentication and scope validation. Requests that pass those checks can consume budget even if later validation or database work fails. Key-management endpoints use a user session and do not use these per-key budgets.</p>
        <p>The per-key limiter responds with HTTP 429 and <code>Retry-After: 60</code>. Wait at least that long, add jitter, and cap retry attempts. There are no remaining-budget or reset-time headers. A proxy may also reject a request, so handle absent headers and non-JSON responses. HTTP 401/403 normally needs a credential or permission change, not repeated retries; 400/404/409/413/422 needs request or state correction.</p>
        <p>Use a client timeout; examples use 30 seconds. For transient network or 5xx failures, retry reads with bounded exponential backoff. For writes, first determine whether the operation may have committed. Prefer a queued sync with stable identities and a single writer over uncontrolled parallel writes. No uptime SLA, retry guarantee, or rate-limit increase is promised by this reference.</p></section>

        <section id="errors"><h2>Errors & troubleshooting</h2><p>Integration errors normally contain <code>detail.code</code>, a safe <code>detail.message</code>, and <code>detail.correlation_id</code>. Branch on status and code; messages are human-readable. Validation errors are generic and do not list failing fields. Key-management authentication uses the shared session handler and can return a string <code>detail</code>; middleware and gateway failures can also return a different shape or non-JSON body. Check status and content before parsing.</p>
        <CodeExample label="Error response example" examples={{ JSON: JSON.stringify({ detail: { code: "insufficient_scope", message: "This endpoint requires items:read.", correlation_id: "example-request-id" } }, null, 2) }} />
        <p>The app normally returns <code>X-Correlation-ID</code>. You may supply your own value (truncated to 64 characters); keep it free of secrets and personal information. If an error occurs before normal response handling, this header may be absent. Retain the ID with your request time and method for support.</p>
        <div className={styles.tableWrap}><table><caption>Error code reference</caption><thead><tr><th>HTTP</th><th>Code</th><th>What to do</th></tr></thead><tbody>{apiReference["x-error-codes"].map((entry) => <tr key={`${entry.status}-${entry.code}`}><td>{entry.status}</td><td><code>{entry.code}</code></td><td>{entry.description}</td></tr>)}</tbody></table></div>
        <h3>Connected, but the inventory is empty</h3><p>Check the key’s team, current ownership, and linked Spaces in FindEZ. Personal unlinked items are excluded. Check exact filter case and part-number formatting. A workspace key cannot override its team; an organization query targeting an unowned team returns no visible rows. A passing /whoami check only confirms the credential.</p>
        <h3>A Space is missing, or a location write fails</h3><p>Empty Spaces do not appear in /spaces. Verify the actual linked Space exists and use its exact name. Resolve duplicate names within the Team. Setting <code>location</code> cannot create or attach a Space.</p>
        <h3>A quantity or sync result looks wrong</h3><p>Use <code>sum_quantity</code> for units and <code>count</code> for records. Quantity is an absolute value, not an increment or available-stock calculation. Check stable external IDs and whether omitted bulk quantity/category values applied defaults. A repeated single-item POST can create another record.</p></section>

        <section id="endpoint-reference"><p className={styles.eyebrow}>Complete reference</p><h2>Every integration endpoint</h2><p>Each operation includes authentication, parameters, request fields, runnable examples, a success response, and expandable response fields. The same schemas are available in the OpenAPI download. Write examples change real inventory when used with a live key; replace the fictional IDs and Space names before running them.</p></section>
        {endpoints.map((entry) => <EndpointReference key={entry.operationId} endpoint={entry} />)}

        <section id="support"><h2>Support & API coverage</h2><p>This reference covers all public <code>/api/v1</code> integration endpoints, including the owner-session key-management routes. Other routes used by FindEZ’s own apps have a separate user-session contract and are not enabled by integration keys. This API does not expose deletion of inventory, Space/Team management, document uploads, chat streaming, billing, or account deletion. Use FindEZ for those actions.</p>
        <p>The request contract is generated from the current router and validated by the test suite. The route version is <code>v1</code>; no deprecation timetable or compatibility guarantee beyond the documented behavior has been announced. Keep clients tolerant of additional response fields and unexpected errors.</p>
        <p>Contact <a href="mailto:info@findez.ai">info@findez.ai</a> with the method, path, HTTP status, error code, correlation ID, approximate UTC request time, and a redacted example. Never send the key, user token, Authorization header, or private inventory data.</p>
        <div className={styles.footerLinks}><Link href="/settings/api-keys">Manage API keys ↗</Link><Link href="/docs/api/openapi.json" download="findez-openapi.json">Download OpenAPI JSON ↓</Link><a href="#quickstart">Back to start ↑</a></div></section>
      </main>
    </div>
  </div>;
}
