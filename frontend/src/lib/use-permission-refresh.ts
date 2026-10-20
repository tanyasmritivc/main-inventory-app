"use client";
import { useEffect, useRef } from "react";
export function usePermissionRefresh(refresh: () => void, paused = false) {
  const current = useRef(refresh);
  useEffect(() => { current.current = refresh; }, [refresh]);
  useEffect(() => {
    const check = () => { if (!paused && document.visibilityState !== "hidden") current.current(); };
    const timer = window.setInterval(check, 15_000);
    window.addEventListener("focus", check);
    window.addEventListener("findez-profile-changed", check);
    window.addEventListener("findez-permissions-changed", check);
    document.addEventListener("visibilitychange", check);
    return () => { window.clearInterval(timer); window.removeEventListener("focus", check); window.removeEventListener("findez-profile-changed", check); window.removeEventListener("findez-permissions-changed", check); document.removeEventListener("visibilitychange", check); };
  }, [paused]);
}
