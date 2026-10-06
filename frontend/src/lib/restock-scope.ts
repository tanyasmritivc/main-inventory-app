export type RestockScope =
  | { key: string; label: string; kind: "personal"; canEdit: true }
  | {
      key: string;
      label: string;
      kind: "shared";
      shareId: string;
      canEdit: boolean;
    }
  | {
      key: string;
      label: string;
      kind: "team";
      teamId: string;
      spaceId: string;
      canEdit: boolean;
    };
export const PERSONAL_RESTOCK: RestockScope = {
  key: "personal",
  label: "My inventory",
  kind: "personal",
  canEdit: true,
};
export function stockWrite(scope: RestockScope, id: string, quantity: number) {
  if (!scope.canEdit)
    throw new Error(
      "You can plan purchases here, but only an editor can record stock arrivals.",
    );
  if (scope.kind === "personal")
    return { path: "/update_item", body: { item_id: id, quantity } };
  const item = encodeURIComponent(id);
  return {
    path:
      scope.kind === "shared"
        ? `/sharing/${encodeURIComponent(scope.shareId)}/items/${item}`
        : `/teams/${encodeURIComponent(scope.teamId)}/spaces/${encodeURIComponent(scope.spaceId)}/items/${item}`,
    body: { quantity },
  };
}
export function restockItemsPath(scope: RestockScope) {
  return scope.kind === "personal"
    ? "/search_items"
    : scope.kind === "shared"
      ? `/sharing/${encodeURIComponent(scope.shareId)}/items`
      : `/teams/${encodeURIComponent(scope.teamId)}/spaces/${encodeURIComponent(scope.spaceId)}/items`;
}
export function joinedRestockScopes(result: unknown): RestockScope[] {
  const data = result as { shares?: unknown[] },
    rows = Array.isArray(result) ? result : data?.shares || [];
  return rows.flatMap((value) => {
    const membership = value as {
      team_shares?: unknown;
      share_id?: string;
      share_name?: string;
      permission?: string;
    };
    const share = (
      Array.isArray(membership.team_shares)
        ? membership.team_shares[0]
        : membership.team_shares || membership
    ) as typeof membership;
    if (!share || typeof share.share_id !== "string") return [];
    return [
      {
        key: `shared:${share.share_id}`,
        label: share.share_name || "Shared Space",
        kind: "shared" as const,
        shareId: share.share_id,
        canEdit: share.permission === "edit",
      },
    ];
  });
}
