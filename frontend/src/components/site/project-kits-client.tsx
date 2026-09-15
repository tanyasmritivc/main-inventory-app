"use client";

import { ChangeEvent, useCallback, useEffect, useRef, useState } from "react";
import { CheckCircle2, FileSpreadsheet, PackageCheck, Plus, RefreshCw, Trash2, Undo2 } from "lucide-react";
import { ProjectKit, createProjectKit, deleteProjectKit, getProjectKit, getProjectKits, getSpaces, releaseProjectKit, reserveProjectKit } from "@/lib/api";
import { useApiSession } from "@/lib/use-api-session";
import { useAppDialog } from "@/components/site/app-dialog-provider";
import { userFacingError } from "@/lib/user-facing-error";

export function ProjectKitsClient() {
  const { token } = useApiSession();
  const { confirmAction } = useAppDialog();
  const [spaces, setSpaces] = useState<string[]>([]);
  const [location, setLocation] = useState("Unsorted");
  const [kits, setKits] = useState<ProjectKit[]>([]);
  const [selected, setSelected] = useState<ProjectKit | null>(null);
  const [creating, setCreating] = useState(false);
  const [name, setName] = useState("");
  const [working, setWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    if (!token) return;
    setWorking(true); setError(null);
    try { const result = await getProjectKits({ token, location }); setKits(result.kits ?? []); }
    catch (reason) { setError(userFacingError(reason, "Could not load project kits.")); }
    finally { setWorking(false); }
  }, [location, token]);

  useEffect(() => { if (!token) return; getSpaces({ token }).then((rows) => setSpaces(rows.map((row) => row.name))).catch(() => {}); }, [token]);
  useEffect(() => { void load(); }, [load]);

  async function create(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]; if (!token || !file || !name.trim()) return;
    setWorking(true); setError(null);
    try { const kit = await createProjectKit({ token, name: name.trim(), location, file }); setCreating(false); setName(""); await load(); setSelected(kit); }
    catch (reason) { setError(userFacingError(reason, "Could not create the project kit.")); }
    finally { setWorking(false); event.target.value = ""; }
  }

  async function open(kitId: string) {
    if (!token) return; setWorking(true);
    try { setSelected(await getProjectKit({ token, kitId })); }
    catch (reason) { setError(userFacingError(reason, "Could not open the project kit.")); }
    finally { setWorking(false); }
  }

  async function mutate(action: "reserve" | "release" | "delete") {
    if (!token || !selected) return;
    if (action === "delete" && !await confirmAction({ title: `Delete “${selected.name}”?`, message: "This removes the saved project kit and its reservations.", confirmLabel: "Delete", danger: true })) return;
    setWorking(true); setError(null);
    try {
      if (action === "reserve") setSelected(await reserveProjectKit({ token, kitId: selected.id }));
      if (action === "release") setSelected(await releaseProjectKit({ token, kitId: selected.id }));
      if (action === "delete") { await deleteProjectKit({ token, kitId: selected.id }); setSelected(null); }
      await load();
    } catch (reason) { setError(userFacingError(reason, "The project kit could not be updated.")); }
    finally { setWorking(false); }
  }

  const summary = selected?.summary;
  return (
    <section className="product-page">
      <header className="product-page-header"><h1>Project kits</h1><div className="product-actions"><button className="app-icon-button" aria-label="Refresh project kits" onClick={() => void load()}><RefreshCw size={15} /></button><button className="product-button primary" onClick={() => setCreating(true)}><Plus size={15} />New kit</button></div></header>
      {error && <div className="notice-error">{error}</div>}
      <div className="kit-filter-bar"><select className="product-select" aria-label="Inventory Space" value={location} onChange={(event) => { setLocation(event.target.value); setSelected(null); }}>{["Unsorted", ...spaces.filter((space) => space !== "Unsorted")].map((space) => <option key={space}>{space}</option>)}</select><span>{kits.length} kit{kits.length === 1 ? "" : "s"}</span></div>
      {creating && <div className="kit-create product-card"><h2>New kit</h2><input className="product-input" value={name} onChange={(event) => setName(event.target.value)} placeholder="Project name" maxLength={120} /><button className="product-button primary" disabled={!name.trim() || working} onClick={() => fileRef.current?.click()}><FileSpreadsheet size={15} />Choose BOM</button><button className="product-button" onClick={() => setCreating(false)}>Cancel</button><input ref={fileRef} hidden type="file" accept=".xlsx,.xls,.csv" onChange={(event) => void create(event)} /></div>}
      {kits.length === 0 && !working ? <div className="bare-empty"><PackageCheck size={24} /><strong>No kits in {location}</strong></div> : <div className={`kits-layout ${selected ? "has-selection" : ""}`}>
        <div className="kit-list">{kits.map((kit) => <button className={selected?.id === kit.id ? "is-active" : ""} onClick={() => void open(kit.id)} key={kit.id}><span><strong>{kit.name}</strong><small>{kit.location}</small></span><span>›</span></button>)}</div>
        {selected && <div className="kit-detail product-card"><div className="kit-detail-header"><div><h2>{selected.name}</h2><p>{selected.location}</p></div><div className="product-actions"><button className="product-button" disabled={working} onClick={() => void mutate("release")}><Undo2 size={14} />Release</button><button className="product-button primary" disabled={working} onClick={() => void mutate("reserve")}><CheckCircle2 size={14} />Reserve</button><button className="app-icon-button" aria-label="Delete kit" disabled={working} onClick={() => void mutate("delete")}><Trash2 size={14} /></button></div></div>{summary && <div className="readiness-summary"><div className="readiness-ring" style={{ "--progress": `${summary.readiness_percent * 3.6}deg` } as React.CSSProperties}><span>{summary.readiness_percent}%</span></div><div><strong>{summary.ready_lines} of {summary.total_lines} ready</strong><span>{summary.partial_lines} partial · {summary.missing_lines} missing</span></div></div>}<div className="kit-items"><div className="kit-items-head"><span>Requirement</span><span>Need</span><span>Have</span><span>Status</span></div>{(selected.items ?? []).map((item, index) => { const status = String(item.status ?? "missing"); return <div className="kit-item-row" key={String(item.id ?? index)}><span><strong>{String(item.name ?? "Part")}</strong><small>{String(item.part_number ?? "")}</small></span><span>{String(item.required_quantity ?? 0)}</span><span>{String(item.available_quantity ?? 0)}</span><span className={`status-pill ${status === "ready" ? "green" : status === "partial" ? "amber" : "red"}`}>{status}</span></div>; })}</div></div>}
      </div>}
    </section>
  );
}
