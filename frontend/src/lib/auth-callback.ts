export function normalizeAuthNext(value: string | null | undefined) {
  return value?.startsWith("/") && !value.startsWith("//") ? value : "/inventory";
}
