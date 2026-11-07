"use client";
import Image from "next/image";
import { privateImageSrc } from "@/lib/private-image";

import { useCallback, useEffect, useRef, useState } from "react";
import "./item-details.css";
import { ImagePlus, RefreshCw, Maximize2 } from "lucide-react";
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
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const preview = photos.find(photo => photo.photo_id === selectedId) || photos.find(photo => photo.is_primary) || photos[0];
  const [deleting, setDeleting] = useState<ItemPhoto | null>(null);
  const input = useRef<HTMLInputElement>(null);
  const previewButton = useRef<HTMLButtonElement>(null);
  const viewerTitle = useRef<HTMLHeadingElement>(null);
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
    <section className="item-gallery item-photo-preview" aria-label="Item photos">
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
      {preview && (
        <>
          <button
            className="item-photo-hero"
            ref={previewButton}
            type="button"
            aria-label={`Open item photo ${photos.indexOf(preview) + 1}${preview.is_primary ? ", primary" : ""}`}
            onClick={() => { setViewing(preview); setImageError(false); }}
          >
            <img key={preview.photo_id} src={privateImageSrc(preview.image_url, accountId)} alt={`Item photo ${photos.indexOf(preview) + 1}`} />
            <span className="item-photo-expand" aria-hidden="true"><Maximize2 size={16} /></span>
          </button>
          {photos.length > 1 && <div className="item-photo-thumbnails" aria-label="Choose a photo">
            {photos.map((photo, i) => <button
              key={photo.photo_id}
              type="button"
              aria-label={`Select item photo ${i + 1}`}
              aria-pressed={preview.photo_id === photo.photo_id}
              onClick={() => setSelectedId(photo.photo_id)}
            ><Image unoptimized width={48} height={48} src={privateImageSrc(photo.image_url, accountId)} alt="" /></button>)}
          </div>}
        </>
      )}
      {!loading && !error && !photos.length && (
        <p className="workspace-muted">No photos attached.</p>
      )}
      <Dialog
        open={!!viewing}
        onOpenChange={(open) => {
          if (!open) setViewing(null);
        }}
      >
        <DialogContent className="workspace-dialog item-photo-viewer" aria-describedby={undefined} onOpenAutoFocus={event => { event.preventDefault(); viewerTitle.current?.focus(); }} onCloseAutoFocus={event => { event.preventDefault(); previewButton.current?.focus(); }}>
          <DialogTitle ref={viewerTitle} tabIndex={-1}>Item photo</DialogTitle>
          {imageError ? (
            <p role="alert">
              This photo could not be loaded. Close and refresh the gallery to
              try again.
            </p>
          ) : (
            viewing && (
              <img
                className="gallery-full-image"
                src={privateImageSrc(viewing.image_url, accountId)}
                alt="Full item photo"
                onError={() => setImageError(true)}
              />
            )
          )}
          {canEdit && viewing && <button
            className="workspace-button photo-delete"
            type="button"
            disabled={busy}
            onClick={() => setDeleting(viewing)}
          >Delete photo</button>}
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
