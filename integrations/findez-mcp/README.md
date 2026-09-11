# FindEZ inventory connector

Connect Claude Desktop or a private ChatGPT GPT to the existing FindEZ integration
API. The connector reads, adds, updates, and bulk-syncs inventory in linked Team
Spaces. It has no delete, arbitrary HTTP, raw SQL, or key-management tool.

User setup and downloads: <https://findez.ai/docs/api#ai-assistants>.

For every tool, create a dedicated key with `items:read`, `workspace:read`,
`items:write`, and `import:write`; for all owned Teams use `org:read` and `org:write`.
Read-only keys still work for reads; write-only keys cannot read. Existing API
scope checks, RLS, expiration, revocation and per-key rate limits remain in force.
Keys never appear in tool parameters or downloadable artifacts.

## Claude Desktop

Download `findez-inventory.mcpb` from the guide. In Claude Desktop, open Settings →
Extensions → Advanced settings → Install Extension and choose the file. Enter your
key in its private configuration field and enable FindEZ in a conversation. The
field is marked sensitive for the host's secure credential storage. Review tool
approvals before permitting changes. This local extension is for Desktop chat;
it does not install a remote connector for claude.ai, mobile or Cowork.

## ChatGPT

Create a private GPT with Actions. Import the guide's `chatgpt-actions.json` URL;
choose API Key authentication and Bearer, and enter the FindEZ key in that setting.
Use the assistant instructions from the guide. Keep sharing set to Only me: the
configured key is shared by anyone allowed to use that GPT, not per-user sign-in.
Write operations are marked consequential. Actions uses at most 10 records per
page or import batch to fit ChatGPT payload limits; the API and Desktop connector
retain their 100-record pages and 500-record batch limits.

## Develop and verify

Requires Node 20.10+ (latest Node 20 recommended for development).

```bash
npm ci
npm test
npm run build
```

`generate` derives tool inputs and the Actions subset from the canonical public
OpenAPI file. `check` fails on drift. The fixed operation allowlist prevents new
routes from becoming tools implicitly. Additions need an explicit review here.
The bundle includes the official MCP SDK and runtime validation dependencies;
customers do not run npm or install Node separately in Claude Desktop.

The API destination is fixed to `https://api.findez.ai`. Redirects are rejected,
requests time out after 30 seconds, response size is bounded, upstream error
bodies are not exposed, and writes are never automatically retried. SDK clients
in the tests exercise initialization, discovery, each operation, partial updates,
null clearing, validation, permission errors, and rejected deletion. All test HTTP
traffic is stubbed; no live key or inventory is needed.

For another local MCP client, launch `node /absolute/path/to/src/stdio.mjs` with
`FINDEZ_API_KEY` supplied by that client's secret/environment settings. Never put
the key in a command argument or chat message. No OpenAI or Anthropic API key is
required by this connector; it only calls FindEZ.

## Write behavior

Resolve and confirm the item and exact linked location before writing. Updates
set an absolute quantity; they cannot perform atomic increments or subtract
reservations. PATCH sends only supplied changes. Bulk upsert matches the stable
workspace/source/external identity and uses create defaults for omitted fields;
send the intended quantity/category. It never deletes omitted rows. After an
uncertain write result, read inventory before retrying, especially after POST.
Space/Team management, documents, billing, and other app-only features remain in
FindEZ and are outside the integration API.

Official integration references:

- <https://developers.openai.com/api/docs/actions/authentication>
- <https://developers.openai.com/api/docs/actions/production>
- <https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop>
- <https://github.com/modelcontextprotocol/mcpb/blob/main/MANIFEST.md>
