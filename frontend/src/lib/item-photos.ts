export type PhotoContext =
  | { kind: "personal" }
  | { kind: "shared"; shareId: string }
  | { kind: "team"; teamId: string; spaceId: string };
export type ItemPhoto = {
  photo_id: string;
  image_url: string;
  is_primary: boolean;
  created_at?: string;
};
export function photoPath(itemId: string, context: PhotoContext) {
  const item = encodeURIComponent(itemId);
  return context.kind === "shared"
    ? `/sharing/${encodeURIComponent(context.shareId)}/items/${item}/photos`
    : context.kind === "team"
      ? `/teams/${encodeURIComponent(context.teamId)}/spaces/${encodeURIComponent(context.spaceId)}/items/${item}/photos`
      : `/items/${item}/photos`;
}
