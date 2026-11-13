import { onshapeContext, onshapeQuery, parseOnshapeUrl } from "@/lib/onshape";

const context = { document_id: "a".repeat(24), element_id: "b".repeat(24), wvm: "w" as const, wvm_id: "c".repeat(24), configuration: "Size=Small;Color=Black" };
test("Onshape launch context round trips configurations safely", () => {
  expect(onshapeContext(Object.fromEntries(new URLSearchParams(onshapeQuery(context))))).toEqual(context);
});
test("assembly links preserve configuration and reject lookalike hosts", () => {
  const path = `/documents/${context.document_id}/w/${context.wvm_id}/e/${context.element_id}?configuration=Size%3DSmall%3BColor%3DBlack`;
  expect(parseOnshapeUrl(`https://cad.onshape.com${path}`)).toEqual(context);
  for (const origin of ["https://cad.onshape.com.evil.test", "http://cad.onshape.com", "https://evil.test", "https://user:pass@cad.onshape.com"])
    expect(() => parseOnshapeUrl(origin + path)).toThrow();
});
test("invalid and repeated launch parameters are rejected", () => {
  expect(onshapeContext({ documentId: [context.document_id], elementId: context.element_id, wvm: "w", wvmId: context.wvm_id })).toBeNull();
  expect(onshapeContext({ documentId: "../secret", elementId: context.element_id, wvm: "w", wvmId: context.wvm_id })).toBeNull();
});
