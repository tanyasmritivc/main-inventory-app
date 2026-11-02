"use client";

import { useEffect, useState } from "react";
import { accountRequest } from "@/lib/account-request";
import type { LimitsResponse } from "@/lib/api";
import { isPilotPublic } from "@/lib/pilot";
import { getAccessSession } from "@/lib/session";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

/** A stale quota error or cached account must never open a pre-launch paywall. */
export function useUpgradePermission(open: boolean, pilot = false): boolean {
  const [verified, setVerified] = useState(false);
  const publicPilot = isPilotPublic();
  useEffect(() => {
    setVerified(false);
    if (!open || pilot || publicPilot) return;
    let active = true;
    let generation = 0;
    let controller: AbortController | undefined;
    async function check() {
      const run = ++generation;
      controller?.abort();
      controller = new AbortController();
      const signal = controller.signal;
      setVerified(false);
      try {
        const session = await getAccessSession();
        if (!session || !active || run !== generation) return;
        const status = await accountRequest<LimitsResponse>(session.accountId, "/me/limits", { signal });
        if (active && run === generation) {
          setVerified(status.pilot_mode === false && status.limits_enabled === true);
        }
      } catch {
        // Unknown/offline status does not authorize an upgrade interruption.
      }
    }
    const { data } = createSupabaseBrowserClient().auth.onAuthStateChange(() => { void check(); });
    void check();
    return () => { active = false; controller?.abort(); data.subscription.unsubscribe(); };
  }, [open, pilot, publicPilot]);
  return open && !pilot && !publicPilot && verified;
}
