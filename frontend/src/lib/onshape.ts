export type OnshapeAssembly = { document_id: string; element_id: string; wvm: "w" | "v" | "m"; wvm_id: string; configuration: string };
const id = /^[a-f0-9]{24}$/;
export function onshapeContext(params: Record<string, string | string[] | undefined>): OnshapeAssembly | null {
  if (params.server && params.server !== "https://cad.onshape.com" && params.server !== "https://cad.onshape.com/") return null;
  const { documentId, elementId, wvm, wvmId, configuration = "" } = params;
  if (typeof documentId !== "string" || !id.test(documentId) || typeof elementId !== "string" || !id.test(elementId)
      || typeof wvmId !== "string" || !id.test(wvmId) || !["w", "v", "m"].includes(String(wvm))
      || typeof configuration !== "string" || configuration.length > 4096) return null;
  return { document_id: documentId, element_id: elementId, wvm: wvm as "w" | "v" | "m", wvm_id: wvmId, configuration };
}
export function onshapeQuery(context: OnshapeAssembly | null) {
  return context ? new URLSearchParams({ documentId: context.document_id, elementId: context.element_id, wvm: context.wvm, wvmId: context.wvm_id, configuration: context.configuration }).toString() : "";
}
export function parseOnshapeUrl(value: string): OnshapeAssembly {
  const url = new URL(value);
  const match = url.pathname.match(/^\/documents\/([a-f0-9]{24})\/(w|v|m)\/([a-f0-9]{24})\/e\/([a-f0-9]{24})\/?$/);
  if (url.origin !== "https://cad.onshape.com" || url.username || url.password || !match) throw new Error("Use an assembly link from https://cad.onshape.com.");
  const context = onshapeContext({ documentId: match[1], wvm: match[2], wvmId: match[3], elementId: match[4], configuration: url.searchParams.get("configuration") || "" });
  if (!context) throw new Error("This assembly link is not supported.");
  return context;
}
