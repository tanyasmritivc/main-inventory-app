"use client";
import { useEffect, useRef } from "react";

// Refresh server-owned snapshots without remounting a page or replacing drafts.
// The caller owns error presentation and pauses while its editor is active.
export function usePermissionRefresh(refresh: () => void | Promise<unknown>, paused = false) {
  const current = useRef(refresh);
  const running = useRef(false);
  useEffect(() => { current.current = refresh; }, [refresh]);
  useEffect(() => {
    const check = () => {
      if (paused || running.current || document.visibilityState === "hidden") return;
      running.current = true;
      const finish = () => { running.current = false; };
      try { Promise.resolve(current.current()).then(finish, finish); }
      catch (error) { finish(); throw error; }
    };
    const timer = window.setInterval(check, 15_000);
    const events = ["focus", "online", "findez-profile-changed", "findez-permissions-changed"];
    events.forEach(event => window.addEventListener(event, check));
    document.addEventListener("visibilitychange", check);
    return () => {
      window.clearInterval(timer);
      events.forEach(event => window.removeEventListener(event, check));
      document.removeEventListener("visibilitychange", check);
    };
  }, [paused]);
}
