"use client";
import { useEffect, useRef, useState } from "react";
import { useApiSession } from "@/lib/use-api-session";
import { accountRequest } from "@/lib/account-request";

export function OnshapeCallback() {
  const { accountId, error } = useApiSession();
  const grant = useRef<{ code: string; state: string } | null>(null);
  const started = useRef(false);
  const live = useRef(false);
  const [message, setMessage] = useState("Finishing Onshape connection...");
  useEffect(() => {
    live.current = true;
    const params = new URLSearchParams(window.location.search);
    if (!grant.current) grant.current = { code: params.get("code") || "", state: params.get("state") || "" };
    window.history.replaceState(null, "", "/cad/onshape/callback");
    return () => { live.current = false; };
  }, []);
  useEffect(() => {
    if (!accountId || !grant.current || started.current) return;
    started.current = true;
    if (!grant.current.code || !grant.current.state) {
      // This depends on the browser callback URL, which is scrubbed after hydration.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setMessage("Onshape authorization was cancelled. Connect again when ready."); return;
    }
    void accountRequest(accountId, "/onshape/callback", { method: "POST", body: JSON.stringify(grant.current) })
      .then(() => {
        if (!live.current) return;
        const path = sessionStorage.getItem(`findez:onshape:return:${accountId}`) || "/cad/onshape";
        sessionStorage.removeItem(`findez:onshape:return:${accountId}`);
        const destination = new URL(path, window.location.origin);
        window.location.replace(destination.origin === window.location.origin && destination.pathname === "/cad/onshape" ? destination.href : "/cad/onshape");
      }).catch(e => { if (live.current) setMessage(e instanceof Error ? e.message : "Onshape could not connect. Try again."); });
  }, [accountId]);
  return <main><h1>Connect Onshape</h1><p role="status">{error || message}</p><a href="/cad/onshape">Return to CAD Intelligence</a></main>;
}
