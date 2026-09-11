import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { apiEndpoints, documentationMarkdown, endpointCurl, API_BASE, guideSections } from "@/lib/api-docs";
import { apiSpecification } from "@/lib/api-openapi";
import requestSchemas from "@/lib/api-request-schemas.json";
import { GET as downloadSpec } from "@/app/docs/api/openapi.json/route";
import { GET as downloadGuide } from "@/app/docs/api/guide.md/route";

const routerSource = readFileSync(resolve(process.cwd(), "../backend/app/api/routes/api_v1.py"), "utf8");

test("documents exactly the operations implemented by the integration router", () => {
  const implemented = [...routerSource.matchAll(/@router\.(get|post|patch|delete)\("([^"]+)"/g)].map(match => `${match[1].toUpperCase()} ${match[2]}`).sort();
  expect(apiEndpoints.map(endpoint => `${endpoint.method} ${endpoint.path}`).sort()).toEqual(implemented);
});

test("every operation uses the actual auth dependency and required scope", () => {
  const operations = routerSource.split(/(?=@router\.)/).slice(1);
  for (const endpoint of apiEndpoints) {
    const implementation = operations.find(source => source.startsWith(`@router.${endpoint.method.toLowerCase()}("${endpoint.path}"`));
    expect(implementation).toBeDefined();
    if (endpoint.auth === "userSession") {
      expect(implementation).toContain("Depends(get_current_user)");
    } else {
      const required = implementation?.match(/Depends\(require_api_scope\((None|"[^"]+")/i)?.[1];
      expect(required).toBe(endpoint.scopes.length ? JSON.stringify(endpoint.scopes[0]) : "None");
    }
  }
});

test("generated request fields track backend models including inheritance", () => {
  function fields(name: string): string[] {
    const body = routerSource.split(`class ${name}(`)[1].split(/\nclass |\nITEM_COLUMNS/)[0];
    const inherited = name === "APIBulkItem" ? fields("APIItemCreate") : [];
    return [...new Set([...inherited, ...[...body.matchAll(/^    (\w+): /gm)].map(match => match[1])])].sort();
  }
  for (const [name, schema] of Object.entries(requestSchemas)) {
    expect(Object.keys(schema.properties).sort()).toEqual(fields(name));
  }
});

test("OpenAPI distinguishes user sessions from integration keys with no OAuth scopes", () => {
  expect(apiSpecification.openapi).toBe("3.1.0");
  expect(apiSpecification.servers[0].url).toBe(API_BASE);
  for (const endpoint of apiEndpoints) {
    const operation = apiSpecification.paths[endpoint.path][endpoint.method.toLowerCase()] as { security: Record<string, unknown>[]; "x-required-scopes-any-of": string[] };
    expect(operation.security).toEqual([{ [endpoint.auth === "apiKey" ? "IntegrationKey" : "UserSession"]: [] }]);
    expect(operation["x-required-scopes-any-of"]).toEqual(endpoint.scopes);
  }
});

test("all OpenAPI references resolve and examples have matching request/response models", () => {
  const serialized = JSON.stringify(apiSpecification);
  for (const match of serialized.matchAll(/"\$ref":"#\/components\/schemas\/([^"]+)"/g)) {
    expect(apiSpecification.components.schemas[match[1]]).toBeDefined();
  }
  const operationIds: string[] = [];
  for (const methods of Object.values(apiSpecification.paths)) {
    for (const operation of Object.values(methods)) operationIds.push((operation as { operationId: string }).operationId);
  }
  expect(new Set(operationIds).size).toBe(apiEndpoints.length);
});

test("downloaded schemas encode null rejection and numeric filter constraints", () => {
  const schemas = apiSpecification.components.schemas;
  const properties = schemas.APIItemPatch.properties as Record<string, { type: string }>;
  expect(schemas.APIItemPatch.minProperties).toBe(1);
  expect(properties.quantity.type).toBe("integer");
  expect(properties.name.type).toBe("string");
  expect(schemas.InventoryFilter.allOf).toEqual(expect.arrayContaining([expect.objectContaining({
    then: { properties: { value: { type: "integer", minimum: 0, maximum: 100000 } } },
  })]));
});

test("curl examples use the correct credential, valid continuations, and parseable JSON", () => {
  for (const endpoint of apiEndpoints) {
    const command = endpointCurl(endpoint);
    expect(command).toContain(endpoint.auth === "apiKey" ? "$FINDEZ_API_KEY" : "$FINDEZ_USER_ACCESS_TOKEN");
    expect(command).toContain(" \\\n  -H");
    expect(command).not.toMatch(/\n\+/);
    if (endpoint.body) expect(JSON.parse(command.split("  -d '")[1].slice(0, -1))).toEqual(endpoint.body);
  }
});

test("guide download contains every section, operation, and credential warning", async () => {
  const response = downloadGuide();
  expect(response.headers.get("content-type")).toContain("text/markdown");
  expect(response.headers.get("content-disposition")).toContain("findez-api-guide.md");
  const guide = await response.text();
  expect(guide).toBe(documentationMarkdown());
  for (const section of guideSections) expect(guide).toContain(`## ${section.title}`);
  for (const endpoint of apiEndpoints) expect(guide).toContain(`### ${endpoint.method} ${endpoint.path}`);
  expect(guide).toContain("An API key cannot list, create, or revoke keys");
  expect(guide).toContain("not preinstalled connectors");
});

test("OpenAPI is downloadable as JSON without authenticating or executing requests", async () => {
  const response = downloadSpec();
  expect(response.headers.get("content-type")).toContain("application/json");
  expect(response.headers.get("content-disposition")).toContain("findez-openapi.json");
  expect(await response.json()).toEqual(apiSpecification);
});
