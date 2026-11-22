/** Keep CAD navigation within the selected organization. The API verifies access. */
export function cadWorldPath(path: string, world?: string | null) {
  if (!world || world === "personal") return path;
  const [base, fragment] = path.split("#", 2);
  const url = base + (base.includes("?") ? "&" : "?") + "world=" + encodeURIComponent(world);
  return fragment === undefined ? url : url + "#" + fragment;
}
