import QRCode from "qrcode";
import { inventoryHref } from "@/lib/inventory-selection";
import type { InventoryItem } from "@/lib/api";
import type { PhotoContext } from "@/lib/item-photos";

export type PrintableLabel = { title: string; subtitle: string; details: string[]; data: string };
export function itemLabel(item: InventoryItem, context?: PhotoContext): PrintableLabel {
  const itemPath = `/inventory?item=${encodeURIComponent(item.item_id)}`;
  const path = context && context.kind !== "personal" ? itemPath : inventoryHref(itemPath);
  return { title: item.name, subtitle: item.location || "Unsorted", details: [`Qty: ${item.quantity}`], data: `https://findez.ai${path}` };
}
export function escapeLabel(value: string) {
  return value.replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}
export async function labelImage(label: PrintableLabel): Promise<string> {
  const qr = await QRCode.toString(label.data, { type: "svg", margin: 4, errorCorrectionLevel: "M" });
  const viewBox = qr.match(/viewBox="([^"]+)"/)![1];
  const qrBody = qr.replace(/^[\s\S]*?<svg[^>]*>/, "").replace(/<\/svg>\s*$/, "");
  const measure = typeof CanvasRenderingContext2D !== "undefined" ? document.createElement("canvas").getContext("2d") : null;
  const lines = (value: string, size: number, weight: number) => {
    if (measure) measure.font = `${weight} ${size}px Arial`;
    const width = (text: string) => measure ? measure.measureText(text).width : text.length * size;
    const out: string[] = []; let line = "";
    for (const word of value.split(/\s+/)) {
      if (line && width(`${line} ${word}`) > 430) { out.push(line); line = ""; }
      for (const char of word) {
        if (width(line + char) > 430) { out.push(line); line = ""; }
        line += char;
      }
      line += " ";
    }
    if (line.trim()) out.push(line.trim());
    return out;
  };
  let y = 46;
  const text = (value: string, size: number, color: string, weight = 400) => lines(value, size, weight).map(line => {
    const result = `<text x="226" y="${y}" font-family="Arial, sans-serif" font-size="${size}" font-weight="${weight}" fill="${color}">${escapeLabel(line)}</text>`;
    y += size + 9; return result;
  }).join("");
  const content = text(label.title, 24, "#111111", 600) + text(label.subtitle, 20, "#555555") + label.details.map(v => text(v, 18, "#666666")).join("");
  y += 12;
  const brand = text("FindEZ AI", 22, "#111111", 600) + text("findez.ai", 18, "#666666");
  const height = Math.max(240, y + 16);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="680" height="${height}" viewBox="0 0 680 ${height}" role="img"><title>${escapeLabel(label.title)}</title><rect width="680" height="${height}" rx="20" fill="white"/><svg x="20" y="${(height - 184) / 2}" width="184" height="184" viewBox="${viewBox}">${qrBody}</svg>${content}${brand}</svg>`;
}
export function labelDataUrl(svg: string) { return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`; }
export async function saveLabel(label: PrintableLabel) {
  const svg = await labelImage(label);
  const image = new Image(); image.src = labelDataUrl(svg); await image.decode();
  const canvas = document.createElement("canvas"); canvas.width = image.width * 3; canvas.height = image.height * 3;
  const ctx = canvas.getContext("2d"); if (!ctx) throw new Error("Could not prepare the label.");
  ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
  const a = document.createElement("a"); a.href = canvas.toDataURL("image/png");
  a.download = `${label.title.replace(/[^a-z0-9]+/gi, "-").slice(0, 80) || "findez"}-label.png`; a.click();
}
export async function printLabels(labels: PrintableLabel[]) {
  if (!labels.length) return;
  const images = await Promise.all(labels.map(labelImage));
  const frame = document.createElement("iframe");
  frame.title = "Printable FindEZ labels"; frame.setAttribute("aria-hidden", "true");
  Object.assign(frame.style, { position: "fixed", right: "0", bottom: "0", width: "1px", height: "1px", border: "0", opacity: "0", pointerEvents: "none" });
  document.body.appendChild(frame);
  const doc = frame.contentDocument!, win = frame.contentWindow!;
  doc.open(); doc.write(`<!doctype html><html><head><title>FindEZ labels</title><style>@page{size:auto;margin:12mm}*{box-sizing:border-box}body{margin:0;background:white;color:black}.sheet{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:5mm;align-items:start}article{break-inside:avoid;page-break-inside:avoid;border:.2mm solid #ddd;border-radius:3mm;overflow:hidden}svg{display:block;width:100%;height:auto}@media screen{body{padding:12mm;max-width:210mm}}</style></head><body><main class="sheet">${images.map(svg => `<article>${svg}</article>`).join("")}</main></body></html>`); doc.close();
  // Keep the frame alive through Safari's asynchronous print preview.
  const cleanup = () => { frame.remove(); window.clearTimeout(timer); };
  const timer = window.setTimeout(cleanup, 300000);
  win.addEventListener("afterprint", cleanup, { once: true });
  await new Promise(resolve => window.setTimeout(resolve, 100));
  try { win.focus(); win.print(); } catch (error) { cleanup(); throw error; }
}
