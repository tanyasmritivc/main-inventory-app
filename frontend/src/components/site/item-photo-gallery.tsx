"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { ImagePlus, RefreshCw } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { useApiSession } from "@/lib/use-api-session";
import { accountRequest } from "@/lib/account-request";
import {
  photoPath,
  type ItemPhoto,
  type PhotoContext,
} from "@/lib/item-photos";
import { type InventoryItem } from "@/lib/api";
import { userFacingError } from "@/lib/user-facing-error";
type GalleryProps = {
  itemId: string;
  context?: PhotoContext;
  canEdit?: boolean;
  onChanged?: (item: InventoryItem) => void;
};
export function ItemPhotoGallery(props: GalleryProps) {
  const { accountId } = useApiSession();
  return (
    <ItemPhotoGalleryWorkspace
      key={`${accountId || "signed-out"}:${photoPath(props.itemId, props.context || { kind: "personal" })}`}
      {...props}
    />
  );
}
function ItemPhotoGalleryWorkspace({
  itemId,
  context = { kind: "personal" },
  canEdit = false,
  onChanged,
}: GalleryProps) {
  const { accountId } = useApiSession(),
    path = photoPath(itemId, context);
  const generation = useRef(0),
    owner = useRef(accountId);
  useEffect(() => {
    owner.current = accountId;
    return () => {
      owner.current = null;
    };
  }, [accountId]);
  const [photos, setPhotos] = useState<ItemPhoto[]>([]),
    [loading, setLoading] = useState(true),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [viewing, setViewing] = useState<ItemPhoto | null>(null),
    [imageError, setImageError] = useState(false);
  const [deleting, setDeleting] = useState<ItemPhoto | null>(null);
  const input = useRef<HTMLInputElement>(null);
  const load = useCallback(async () => {
    if (!accountId) return;
    const account = accountId,
      ticket = ++generation.current;
    setLoading(true);
    setPhotos([]);
    setError("");
    try {
      const result = await accountRequest<{ photos: ItemPhoto[] }>(
        account,
        path,
      );
      if (owner.current === account && ticket === generation.current)
        setPhotos(result.photos);
    } catch (e) {
      if (owner.current === account && ticket === generation.current)
        setError(userFacingError(e, "Could not load item photos."));
    } finally {
      if (owner.current === account && ticket === generation.current)
        setLoading(false);
    }
  }, [accountId, path]);
  useEffect(() => {
    setViewing(null);
    void load();
    return () => {
      generation.current++;
    };
  }, [load]);
  async function mutate(file?: File, photo?: ItemPhoto) {
    if (!accountId || !canEdit || busy) return;
    const account = accountId,
      ticket = generation.current;
    if (
      file &&
      (!file.size ||
        file.size > 10 * 1024 * 1024 ||
        !file.type.startsWith("image/"))
    ) {
      setError("Choose an image smaller than 10 MB.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      const form = new FormData();
      if (file) form.append("file", file);
      const result = await accountRequest<{
        item: InventoryItem;
        photos: ItemPhoto[];
      }>(
        account,
        photo ? `${path}/${encodeURIComponent(photo.photo_id)}` : path,
        { method: photo ? "DELETE" : "POST", body: photo ? undefined : form },
      );
      if (result.item.item_id !== itemId)
        throw new Error("The updated photos could not be confirmed.");
      if (owner.current === account && ticket === generation.current) {
        setPhotos(result.photos);
        onChanged?.(result.item);
        setViewing(null);
        setDeleting(null);
      }
    } catch (e) {
      if (owner.current === account && ticket === generation.current)
        setError(
          userFacingError(e, "The photo change could not be completed."),
        );
    } finally {
      if (owner.current === account && ticket === generation.current)
        setBusy(false);
    }
  }
  return (
    <section className="item-gallery" aria-label="Item photos">
      <div className="workspace-section-heading">
        <h2>Photos {photos.length ? `(${photos.length}/10)` : ""}</h2>
        <div className="workspace-actions">
          <button
            type="button"
            className="workspace-button"
            aria-label="Refresh item photos"
            disabled={busy}
            onClick={() => void load()}
          >
            <RefreshCw size={13} />
          </button>
          {canEdit && (
            <button
              type="button"
              className="workspace-button"
              disabled={busy || loading || photos.length >= 10}
              onClick={() => input.current?.click()}
            >
              <ImagePlus size={14} />
              {busy ? "Saving…" : "Add photo"}
            </button>
          )}
        </div>
      </div>
      <input
        ref={input}
        type="file"
        accept="image/*"
        hidden
        onChange={(e) => {
          const file = e.target.files?.[0];
          e.target.value = "";
          if (file) void mutate(file);
        }}
      />
      {loading && (
        <p className="workspace-muted" role="status">
          Loading photos…
        </p>
      )}
      {error && (
        <div className="workspace-error" role="alert">
          {error}
        </div>
      )}
      <div className="item-gallery-grid">
        {photos.map((photo, i) => (
          <div key={photo.photo_id}>
            <button
              type="button"
              aria-label={`Open item photo ${i + 1}${photo.is_primary ? ", primary" : ""}`}
              onClick={() => {
                setViewing(photo);
                setImageError(false);
              }}
            >
              <img src={photo.image_url} alt={`Item photo ${i + 1}`} />
            </button>
            {canEdit && (
              <button
                className="photo-delete"
                type="button"
                disabled={busy}
                onClick={() => setDeleting(photo)}
              >
                Delete photo
              </button>
            )}
          </div>
        ))}
      </div>
      {!loading && !error && !photos.length && (
        <p className="workspace-muted">No photos attached.</p>
      )}
      <Dialog
        open={!!viewing}
        onOpenChange={(open) => {
          if (!open) setViewing(null);
        }}
      >
        <DialogContent className="workspace-dialog">
          <DialogTitle>Item photo</DialogTitle>
          <DialogDescription>
            {viewing?.is_primary ? "Primary photo" : "Additional photo"}
          </DialogDescription>
          {imageError ? (
            <p role="alert">
              This photo could not be loaded. Close and refresh the gallery to
              try again.
            </p>
          ) : (
            viewing && (
              <img
                className="gallery-full-image"
                src={viewing.image_url}
                alt="Full item photo"
                onError={() => setImageError(true)}
              />
            )
          )}
        </DialogContent>
      </Dialog>
      <Dialog
        open={!!deleting}
        onOpenChange={(open) => {
          if (!open && !busy) setDeleting(null);
        }}
      >
        <DialogContent className="workspace-dialog">
          <DialogTitle>Delete this photo?</DialogTitle>
          <DialogDescription>
            The other item photos will be kept.
          </DialogDescription>
          {error && <p role="alert">{error}</p>}
          <div className="workspace-actions">
            <button
              className="workspace-button"
              disabled={busy}
              onClick={() => setDeleting(null)}
            >
              Cancel
            </button>
            <button
              className="workspace-button primary"
              disabled={busy}
              onClick={() => void mutate(undefined, deleting || undefined)}
            >
              Delete photo
            </button>
          </div>
        </DialogContent>
      </Dialog>
    </section>
  );
}
