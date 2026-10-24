"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { accountRequest } from "@/lib/account-request";
import { userFacingError } from "@/lib/user-facing-error";
import {
  parseWorldAction,
  resolvedWorldHref,
  type WorldAction,
  type WorldResource,
} from "@/lib/world-chat";
export function WorldActionCard({
  action: initial,
  accountId,
  worldId,
}: {
  action: WorldAction;
  accountId: string;
  worldId: string;
}) {
  const [action, setAction] = useState(initial),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  const control = useRef<AbortController | null>(null),
    alive = useRef(true),
    locked = useRef(false);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
      control.current?.abort();
    };
  }, []);
  async function decide(decision: "confirm" | "cancel") {
    if (locked.current) return;
    locked.current = true;
    setBusy(true);
    setError("");
    const c = new AbortController();
    control.current = c;
    try {
      const result = await accountRequest<{ action: unknown }>(
        accountId,
        `/worlds/${encodeURIComponent(worldId)}/structure-actions/${encodeURIComponent(action.id)}`,
        {
          method: "POST",
          body: JSON.stringify({ decision, supports_task_actions: true }),
          signal: c.signal,
        },
      );
      const updated = parseWorldAction(result.action);
      if (!updated || updated.id !== action.id || updated.status === "pending")
        throw new Error(
          "The receipt could not be verified. Retry this same card safely.",
        );
      if (alive.current) setAction(updated);
    } catch (e) {
      if (alive.current)
        setError(
          userFacingError(
            e,
            "This action could not be completed. Retry this same card.",
          ),
        );
    } finally {
      locked.current = false;
      if (alive.current) setBusy(false);
    }
  }
  return (
    <section
      className="ask-action-card"
      aria-label="Review organization changes"
    >
      <strong>
        {action.status === "pending"
          ? "Review your new Spaces"
          : action.status === "confirmed"
            ? "Created and completed"
            : "Cancelled"}
      </strong>
      <p className="workspace-muted">{action.workspace_label}</p>
      {action.inventories.map((inv, index) => (
        <div key={index}>
          <strong>{inv.name}</strong>
          {!!inv.spaces.length && <p>{inv.spaces.join(" · ")}</p>}
          <ul>
            {inv.items.map((i, n) => (
              <li key={n}>
                <span>{i.name}</span>
                <small>
                  Qty {i.quantity} · {i.location}
                </small>
              </li>
            ))}
            {inv.moves.map((m, n) => (
              <li key={`m${n}`}>
                Move {m.name} to {m.target_location}
              </li>
            ))}
          </ul>
        </div>
      ))}
      {action.status === "pending" && (
        <div className="ask-action-buttons">
          <button
            className="workspace-button"
            disabled={busy}
            onClick={() => void decide("cancel")}
          >
            Cancel
          </button>
          <button
            className="workspace-button primary"
            disabled={busy}
            onClick={() => void decide("confirm")}
          >
            {busy ? "Completing…" : "Create and complete"}
          </button>
        </div>
      )}
      {error && <p role="alert">{error}</p>}
    </section>
  );
}
export function WorldResourceLinks({
  links,
  accountId,
  worldId,
}: {
  links: WorldResource[];
  accountId: string;
  worldId: string;
}) {
  const router = useRouter(),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const control = useRef<AbortController | null>(null),
    alive = useRef(true);
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
      control.current?.abort();
    };
  }, []);
  async function open(link: WorldResource) {
    if (busy) return;
    setBusy(true);
    setError("");
    const c = new AbortController();
    control.current = c;
    try {
      const value = await accountRequest(
        accountId,
        `/worlds/${encodeURIComponent(worldId)}/resources/${encodeURIComponent(link.inventory_id)}/${link.kind}/${encodeURIComponent(link.id)}`,
        { signal: c.signal },
      );
      const href = resolvedWorldHref(link, value);
      if (alive.current) router.push(href);
    } catch (e) {
      if (alive.current)
        setError(
          userFacingError(e, "This item or Space is no longer available."),
        );
    } finally {
      if (alive.current) setBusy(false);
    }
  }
  if (!links.length) return null;
  return (
    <div className="ask-resource-links">
      <div className="workspace-actions">
        {links.map((l) => (
          <button
            className="workspace-button"
            key={l.href}
            disabled={busy}
            onClick={() => void open(l)}
          >
            Open {l.label}
          </button>
        ))}
      </div>
      {error && <p role="alert">{error}</p>}
    </div>
  );
}
