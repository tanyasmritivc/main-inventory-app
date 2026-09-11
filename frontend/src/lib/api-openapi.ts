import requestSchemas from "./api-request-schemas.json";
import { API_BASE, apiEndpoints, DOCS_UPDATED } from "./api-docs";

type Schema = Record<string, unknown>;
const ref = (name: string): Schema => ({ $ref: `#/components/schemas/${name}` });
const object = (properties: Record<string, Schema>, required = Object.keys(properties)): Schema => ({ type: "object", properties, required });
const array = (items: Schema): Schema => ({ type: "array", items });
const text: Schema = { type: "string" };
const integer: Schema = { type: "integer", minimum: 0 };
const uuid: Schema = { type: "string", format: "uuid" };
const nullableUuid: Schema = { type: ["string", "null"], format: "uuid" };
const timestamp: Schema = { type: "string", format: "date-time" };
const nullableTimestamp: Schema = { type: ["string", "null"], format: "date-time" };
const nullableText: Schema = { type: ["string", "null"] };

/** Raw request models are generated from the actual FastAPI router. Custom model
 * validators are expressed below because Pydantic does not emit those constraints. */
const schemas: Record<string, Schema> = JSON.parse(JSON.stringify(requestSchemas));
const patchProperties = schemas.APIItemPatch.properties as Record<string, Schema>;
for (const name of ["name", "category", "location", "quantity"]) {
  const alternatives = patchProperties[name].anyOf as Schema[];
  patchProperties[name] = { ...alternatives.find(schema => schema.type !== "null"), title: patchProperties[name].title };
}
schemas.APIItemPatch.minProperties = 1;
for (const name of ["APIItemCreate", "APIBulkItem", "APIItemPatch"]) {
  const properties = schemas[name].properties as Record<string, Schema>;
  for (const field of ["name", "category", "location"]) properties[field].pattern = "\\S";
}
for (const field of ["source_system", "external_id"]) {
  (schemas.APIBulkItem.properties as Record<string, Schema>)[field].pattern = "\\S";
}
(schemas.CreateKeyRequest.properties as Record<string, Schema>).name.pattern = "\\S";
schemas.InventoryFilter.allOf = [{
  if: { properties: { field: { const: "quantity" } }, required: ["field"] },
  then: { properties: { value: { type: "integer", minimum: 0, maximum: 100000 } } },
  else: { properties: { value: { type: "string", maxLength: 200 }, op: { enum: ["eq", "neq"] } } },
}];
schemas.CreateKeyRequest.description = "Owner session required. Team keys use workspace scopes; null/omitted workspace_id requires organization scopes. expires_at must be in the future when supplied. Scope names are trimmed before validation.";
schemas.APIBulkItem.description = "Organization keys must supply workspace_id. Stable identity is workspace_id + source_system + external_id. Defaults also apply to upsert updates; this is not PATCH.";
schemas.APIItemCreate.description = "Organization keys must supply workspace_id. location must exactly match one unambiguous Space linked to that workspace.";

schemas.Item = object({
  item_id: uuid, workspace_id: uuid, name: text, category: text, quantity: integer, location: text,
  image_url: nullableText, barcode: nullableText, purchase_source: nullableText, notes: nullableText,
  brand: nullableText, part_number: nullableText, source_system: nullableText, external_id: nullableText, created_at: timestamp,
});
schemas.ItemPage = object({ items: array(ref("Item")), page: { type: "integer", minimum: 1 }, page_size: { type: "integer", minimum: 1, maximum: 100 }, total: integer });
schemas.QueryResult = { oneOf: [
  object({ resource: { const: "items" }, aggregate: { type: "string", enum: ["count", "sum_quantity"] }, value: integer }),
  { allOf: [ref("ItemPage"), object({ resource: { const: "items" } })] },
] };
schemas.KeyIdentity = object({ key_id: uuid, workspace_id: nullableUuid, scopes: array(text) });
schemas.CreatedItem = object({ item: object({
  ...(requestSchemas.APIItemCreate.properties as Record<string, Schema>), item_id: uuid, workspace_id: uuid,
}, ["item_id", "workspace_id", "name", "location", "category", "quantity"]) });
schemas.UpdatedItem = object({ updated: { const: true }, item_id: uuid });
schemas.BulkResult = object({ processed: { type: "integer", minimum: 1, maximum: 500 } });
schemas.LocationList = object({ spaces: array(object({ workspace_id: uuid, location: text, item_count: integer })) });
schemas.WorkspaceList = object({ workspaces: array(object({ workspace_id: uuid, name: text, item_count: integer, space_count: integer })) });
schemas.OwnedWorkspaces = object({ workspaces: array(object({ team_id: uuid, name: text })) });
schemas.KeyMetadata = object({ id: uuid, workspace_id: nullableUuid, name: text, key_prefix: text, scopes: array(text), created_at: timestamp,
  last_used_at: nullableTimestamp, expires_at: nullableTimestamp, revoked_at: nullableTimestamp });
schemas.CreatedKey = { allOf: [ref("KeyMetadata"), object({ org_id: uuid, created_by: uuid, key: { type: "string", description: "Full secret, returned only once. Store privately and redact from logs." } })] };
schemas.KeyList = object({ keys: array(ref("KeyMetadata")) });
schemas.RevokedKey = object({ revoked: { const: true }, id: uuid, revoked_at: timestamp });
schemas.ApiError = object({ detail: object({ code: text, message: text, correlation_id: text }) });
schemas.SessionError = { oneOf: [ref("ApiError"), object({ detail: text })] };

const paths: Record<string, Record<string, unknown>> = {};
for (const endpoint of apiEndpoints) {
  const scopeDescription = endpoint.scopes.length ? `Required permission: ${endpoint.scopes.join(" OR ")}.` : "";
  const security = endpoint.auth === "apiKey" ? "IntegrationKey" : "UserSession";
  const correlationHeader = { description: "Request reference for troubleshooting; never includes the credential.", schema: text };
  const responses: Record<string, unknown> = {
    [endpoint.status]: { description: "Success", headers: { "x-correlation-id": correlationHeader }, content: { "application/json": { schema: ref(endpoint.responseSchema), example: endpoint.response } } },
  };
  for (const [status, description] of Object.entries({ "400": "Invalid request or workspace configuration", "401": "Missing, invalid, expired, or revoked credential", "403": "Insufficient permission or workspace access", "404": "Resource not found or not accessible", "409": "External identity conflict", "413": "Configured batch limit exceeded", "422": "Request validation failed", "429": "Request budget exceeded", "500": "Unexpected server error", "503": "Service temporarily unavailable" })) {
    responses[status] = { description, headers: {
      "x-correlation-id": correlationHeader,
      ...(status === "429" ? { "Retry-After": { description: "For per-key rate limiting, seconds to wait before retrying.", schema: { type: "string", example: "60" } } } : {}),
    }, content: { "application/json": { schema: ref(endpoint.auth === "userSession" ? "SessionError" : "ApiError") } } };
  }
  paths[endpoint.path] ??= {};
  paths[endpoint.path][endpoint.method.toLowerCase()] = {
    operationId: endpoint.id.replace(/-([a-z])/g, (_, letter: string) => letter.toUpperCase()),
    summary: endpoint.title, description: [endpoint.description, scopeDescription, ...endpoint.notes].filter(Boolean).join("\n\n"),
    tags: [endpoint.auth === "apiKey" ? "Inventory integrations" : "Key management (user session)"],
    security: [{ [security]: [] }], "x-required-scopes-any-of": endpoint.scopes,
    ...(endpoint.parameters ? { parameters: endpoint.parameters } : {}),
    ...(endpoint.requestSchema ? { requestBody: { required: true, content: { "application/json": { schema: ref(endpoint.requestSchema), example: endpoint.body } } } } : {}),
    responses,
  };
}

export const apiSpecification = {
  openapi: "3.1.0",
  info: { title: "FindEZ Integration API", version: "1.0.0", description: `API v1 reference reviewed ${DOCS_UPDATED}. HTTPS inventory integrations for owned Team Spaces. API-key and user-session authentication are separate. No public sandbox or raw SQL endpoint is provided.`, contact: { name: "FindEZ support", email: "info@findez.ai" } },
  servers: [{ url: API_BASE, description: "Production — requests can affect real inventory" }],
  externalDocs: { description: "Integration guide and operations reference", url: "https://findez.ai/docs/api" },
  tags: [{ name: "Inventory integrations" }, { name: "Key management (user session)" }],
  paths,
  components: { schemas, securitySchemes: {
    IntegrationKey: { type: "http", scheme: "bearer", bearerFormat: "FindEZ API key", description: "A full findez_live_sk_ credential created in Settings → API keys. Required permissions are documented per operation; these are not OAuth scopes." },
    UserSession: { type: "http", scheme: "bearer", bearerFormat: "JWT", description: "The normal signed-in FindEZ user's access token, used only for key management. An API key cannot replace it." },
  } },
};
