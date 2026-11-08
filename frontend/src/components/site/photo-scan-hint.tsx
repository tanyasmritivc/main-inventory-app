export const PHOTO_SCAN_TIMING = "Crowded photos can take around 4 minutes.";
export const PHOTO_SCAN_TIP = "For quicker results, photograph smaller groups of items.";

export function PhotoScanHint({ tips = true }: { tips?: boolean }) {
  return <p style={{ margin: "8px 0", fontSize: 12, lineHeight: 1.5, color: "var(--text-secondary)", fontWeight: 400 }}>
    {PHOTO_SCAN_TIMING}{tips && <> {PHOTO_SCAN_TIP}</>}
  </p>;
}
