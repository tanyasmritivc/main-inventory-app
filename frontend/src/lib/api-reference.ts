import document from "../../public/docs/api/openapi.json";

export type Schema = {
  $ref?: string; type?: string | string[]; description?: string; title?: string;
  properties?: Record<string, Schema>; required?: string[]; items?: Schema;
  anyOf?: Schema[]; oneOf?: Schema[]; enum?: unknown[]; const?: unknown; default?: unknown;
  minimum?: number; maximum?: number; minLength?: number; maxLength?: number;
  minItems?: number; maxItems?: number; format?: string;
};
export type Operation = {
  operationId: string; summary: string; description: string; tags: string[];
  security: Record<string, unknown[]>[]; "x-required-scope": string | null;
  "x-rate-bucket": string | null; "x-path-values": Record<string, string>;
  "x-query-example": Record<string, string | number>;
  "x-extra-examples": Record<string, { request: unknown; response?: unknown }>;
  parameters?: { name: string; in: string; description: string; required: boolean; schema: Schema }[];
  requestBody?: { content: { "application/json": { schema: Schema; example: unknown } } };
  responses: Record<string, { content: { "application/json": { schema: Schema; example?: unknown } } }>;
};
export const apiReference = document as unknown as {
  servers: { url: string }[]; paths: Record<string, Record<string, Operation>>;
  components: { schemas: Record<string, Schema> };
  "x-error-codes": { status: number; code: string; description: string }[];
  "x-limits": { api_key_requests_per_minute: number; api_key_bulk_requests_per_minute: number; api_key_bulk_max_items: number };
};
export const endpoints = Object.entries(apiReference.paths).flatMap(([path, methods]) =>
  Object.entries(methods).map(([method, operation]) => ({ path, method: method.toUpperCase(), ...operation })))
  .sort((a, b) => ["Connection", "Inventory", "Workspaces", "Key management"].indexOf(a.tags[0]) - ["Connection", "Inventory", "Workspaces", "Key management"].indexOf(b.tags[0]));
export type Endpoint = typeof endpoints[number];
export const apiOrigin = apiReference.servers[0].url;

export function resolveSchema(schema: Schema): Schema {
  return schema.$ref ? apiReference.components.schemas[schema.$ref.split("/").pop()!] : schema;
}
export function schemaType(schema: Schema): string {
  if (schema.$ref) return schema.$ref.split("/").pop()!;
  const choices = schema.anyOf ?? schema.oneOf;
  if (choices) return choices.map(schemaType).join(" | ");
  if (schema.const !== undefined) return JSON.stringify(schema.const);
  if (schema.type === "array") return `${schemaType(schema.items ?? {})}[]`;
  return Array.isArray(schema.type) ? schema.type.join(" | ") : schema.format ?? schema.type ?? "object";
}
export function schemaConstraints(schema: Schema): string {
  const concrete = schema.anyOf?.find((entry) => entry.type !== "null") ?? schema;
  const parts: string[] = [];
  if (concrete.enum) parts.push(`Allowed: ${concrete.enum.map((value) => JSON.stringify(value)).join(", ")}`);
  for (const [key, label] of [["minimum", "Minimum"], ["maximum", "Maximum"], ["minLength", "Min characters"], ["maxLength", "Max characters"], ["minItems", "Min entries"], ["maxItems", "Max entries"]] as const) {
    if (concrete[key] !== undefined) parts.push(`${label}: ${concrete[key]}`);
  }
  if (Object.prototype.hasOwnProperty.call(schema, "default")) parts.push(`Default: ${JSON.stringify(schema.default)}`);
  return parts.join(" · ");
}

export function requestExamples(endpoint: Endpoint, body = endpoint.requestBody?.content["application/json"].example): Record<string, string> {
  let path = endpoint.path;
  for (const [key, value] of Object.entries(endpoint["x-path-values"])) path = path.replace(`{${key}}`, encodeURIComponent(value));
  const query = new URLSearchParams(Object.entries(endpoint["x-query-example"]).map(([key, value]) => [key, String(value)])).toString();
  const url = `${apiOrigin}${path}${query ? `?${query}` : ""}`;
  const credential = endpoint.security[0].UserSession ? "FINDEZ_USER_ACCESS_TOKEN" : "FINDEZ_API_KEY";
  const json = body === undefined ? undefined : JSON.stringify(body, null, 2);
  const shellQuote = (value: string) => `'${value.replace(/'/g, `'"'"'`)}'`;
  const curl = [`curl --silent --show-error --fail-with-body --max-time 30 --request ${endpoint.method}`, `  --url ${shellQuote(url)}`, `  --header "Authorization: Bearer $${credential}"`];
  if (json !== undefined) curl.push(`  --header 'Content-Type: application/json'`, `  --data ${shellQuote(json)}`);
  return {
    cURL: curl.join(" \\\n"),
    JavaScript: `// Node.js 18+; save as request.mjs and run: node request.mjs\nconst token = process.env.${credential};\nif (!token) throw new Error("Set ${credential} first");\nconst response = await fetch(${JSON.stringify(url)}, {\n  method: ${JSON.stringify(endpoint.method)},\n  headers: { Authorization: \`Bearer \${token}\`${json === undefined ? "" : ', "Content-Type": "application/json"'} },${json === undefined ? "" : `\n  body: JSON.stringify(${json}),`}\n  signal: AbortSignal.timeout(30000),\n});\nconst text = await response.text();\nif (!response.ok) {\n  // Do not log credentials. Reconcile writes before retrying a timeout.\n  throw new Error(\`HTTP \${response.status}: \${text}\`);\n}\nconsole.log(JSON.parse(text));`,
    Python: `# Python 3; save as request.py and run: python3 request.py\nimport json\nimport os\nfrom urllib.request import Request, urlopen\nfrom urllib.error import HTTPError\n\ntoken = os.environ["${credential}"]\n${json === undefined ? "" : `payload = json.loads(${JSON.stringify(JSON.stringify(body))})\n`}request = Request(\n    ${JSON.stringify(url)},\n    method=${JSON.stringify(endpoint.method)},\n    headers={"Authorization": "Bearer " + token${json === undefined ? "" : ', "Content-Type": "application/json"'}},${json === undefined ? "" : '\n    data=json.dumps(payload).encode("utf-8"),'}\n)\ntry:\n    with urlopen(request, timeout=30) as response:\n        print(json.load(response))\nexcept HTTPError as error:\n    # Includes the API error body, without printing your credential.\n    print("HTTP", error.code, error.read().decode("utf-8"))\n    raise SystemExit(1)`,
  };
}
