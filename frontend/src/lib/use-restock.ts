"use client";
import { useCallback, useSyncExternalStore } from "react";
import { accountToken } from "@/lib/account-request";
import {
  changeRestock,
  decodeRestock,
  RESTOCK_EVENT,
  restockKey,
  type RestockEntry,
  type RestockPlan,
} from "@/lib/restock-plan";
type Snapshot = { plan: RestockPlan; error: string; ready: boolean };
const EMPTY: Snapshot = { plan: {}, error: "", ready: false };
const UNREADABLE: Snapshot = {
  plan: {},
  error:
    "Your saved restock plan could not be read. It has been preserved. Try reloading this page.",
  ready: false,
};
const cache = new Map<string, { raw: string | null; snapshot: Snapshot }>();
function snapshot(account: string | null): Snapshot {
  if (!account || typeof window === "undefined") return EMPTY;
  try {
    const key = restockKey(account),
      raw = localStorage.getItem(key),
      previous = cache.get(key);
    if (previous?.raw === raw) return previous.snapshot;
    let next: Snapshot;
    try {
      next = { plan: decodeRestock(raw), error: "", ready: true };
    } catch {
      next = UNREADABLE;
    }
    cache.set(key, { raw, snapshot: next });
    return next;
  } catch {
    return UNREADABLE;
  }
}
function subscribe(listener: () => void) {
  window.addEventListener("storage", listener);
  window.addEventListener(RESTOCK_EVENT, listener);
  return () => {
    window.removeEventListener("storage", listener);
    window.removeEventListener(RESTOCK_EVENT, listener);
  };
}
export function useRestock(accountId: string | null) {
  const getSnapshot = useCallback(() => snapshot(accountId), [accountId]);
  const state = useSyncExternalStore(subscribe, getSnapshot, () => EMPTY);
  const reload = useCallback(() => {
    if (accountId) cache.delete(restockKey(accountId));
    window.dispatchEvent(new Event(RESTOCK_EVENT));
  }, [accountId]);
  const change = useCallback(
    async (id: string, update: (entry: RestockEntry) => RestockEntry) => {
      if (!accountId) throw new Error("Please sign in again.");
      await accountToken(accountId);
      try {
        changeRestock(localStorage, accountId, id, update);
      } catch {
        throw new Error(
          "Could not save your restock plan. Your previous plan has been preserved.",
        );
      }
      window.dispatchEvent(new Event(RESTOCK_EVENT));
    },
    [accountId],
  );
  return { ...state, change, reload };
}
