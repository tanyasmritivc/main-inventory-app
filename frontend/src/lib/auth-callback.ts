export function normalizeAuthNext(value: string | null | undefined) {
  return value?.startsWith("/") && !value.startsWith("//") && !/[\\\u0000-\u001f]/.test(value) ? value : "/home";
}
