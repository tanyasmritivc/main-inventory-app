"use client";
import { PHOTO_SCAN_TIMING, PHOTO_SCAN_TIP } from "./photo-scan-hint";

import { useEffect, useState } from "react";
import { ScanLine, Table2, Search, ChartNoAxesColumnIncreasing } from "lucide-react";

const examples = ["Where are the M5 screws?", "What is running low in Fastener DB?", "Add 24 M4 screws to Fastener DB", "Which Space has the spare batteries?"];
const restingPlaceholder = "Ask about your inventory...";

/** Decorative hint only. Focus, typed text and reduced motion stop it permanently. */
export function useHomePlaceholder(enabled: boolean, value: string) {
  const [stopped, stop] = useState(false);
  const [hint, setHint] = useState(restingPlaceholder);
  useEffect(() => {
    if (!enabled || stopped || value) return;
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    let timer: ReturnType<typeof setTimeout>;
    let index = 0, count = 0, deleting = false;
    const finish = () => { clearTimeout(timer); setHint(restingPlaceholder); stop(true); };
    if (media.matches) return;
    const tick = () => {
      if (index === examples.length) { setHint(restingPlaceholder); return; }
      count += deleting ? -1 : 1;
      setHint(examples[index].slice(0, count));
      let delay = deleting ? 28 : 55;
      if (count === examples[index].length) { deleting = true; delay = 1300; }
      else if (count === 0) { deleting = false; index++; delay = 250; }
      timer = setTimeout(tick, delay);
    };
    timer = setTimeout(tick, 1200);
    media.addEventListener("change", finish);
    return () => { clearTimeout(timer); media.removeEventListener("change", finish); };
  }, [enabled, stopped, value]);
  return { placeholder: enabled && !stopped && !value ? hint : restingPlaceholder, stopPlaceholder: () => stop(true) };
}

export function QuickStart({ disabled, onPhoto, onImport, onFind, onLow }: {
  disabled: boolean; onPhoto: () => void; onImport: () => void; onFind: () => void; onLow: () => void;
}) {
  const cards = [
    { title: "Scan a photo", hint: "", palette: "dusk", Icon: ScanLine, action: onPhoto },
    { title: "Import a sheet", hint: "CSV or Excel", palette: "slate", Icon: Table2, action: onImport },
    { title: "Find an item", hint: "Where and how many", palette: "moss", Icon: Search, action: onFind },
    { title: "Running low", hint: "What to restock", palette: "plum", Icon: ChartNoAxesColumnIncreasing, action: onLow },
  ];
  return <section className="refresh-quick-start" aria-label="Quick start">
    <p>Quick start</p><div>{cards.map(({ title, hint, palette, Icon, action }) =>
      <button key={title} type="button" className="theme-card" title={title === "Scan a photo" ? `${PHOTO_SCAN_TIMING} ${PHOTO_SCAN_TIP}` : undefined} disabled={disabled} onClick={action}>
        <span className={`resource-art resource-tile g-${palette}`}><Icon size={18} aria-hidden="true" /></span>
        <strong>{title}</strong>{hint && <small>{hint}</small>}
      </button>)}
    </div>
  </section>;
}

/** Receives already loaded values only; never fetches or changes inventory data. */
export function SpaceInfoLine({ units, low = 0, addedAt, createdAt }: {
  units?: number; low?: number; addedAt?: string | null; createdAt?: string | null;
}) {
  const [now] = useState(() => Date.now());
  const date = addedAt || createdAt;
  const timestamp = date ? Date.parse(date) : NaN;
  const days = Number.isFinite(timestamp) ? Math.max(0, Math.floor((now - timestamp) / 86400000)) : undefined;
  const age = days === undefined ? null : days === 0 ? "today" : days === 1 ? "1 day ago" : `${days} days ago`;
  if (units === undefined && !low && !age) return null;
  return <p className="refresh-space-info">
    {units !== undefined && <span>{units.toLocaleString()} {units === 1 ? "unit" : "units"}</span>}
    {low > 0 && <span><i aria-hidden="true" />{low} running low</span>}
    {age && <span>{addedAt ? "Added" : "Created"} {age}</span>}
  </p>;
}
