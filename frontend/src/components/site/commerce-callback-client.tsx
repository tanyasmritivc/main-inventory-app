"use client";

import Link from "next/link";
import { useLayoutEffect, useRef, useState } from "react";
import { completeCommerceCallback, providerLabel, type OAuthProvider } from "@/lib/commerce";
import styles from "./commerce-client.module.css";

export function CommerceCallbackClient({ provider }: { provider: OAuthProvider }) {
  const request = useRef<Promise<string> | null>(null);
  const [destination, setDestination] = useState<string | null>(null);
  const [error, setError] = useState("");
  useLayoutEffect(() => {
    let live = true;
    // Reuse the request across Strict Mode effect replay; OAuth codes are single-use.
    request.current ??= completeCommerceCallback(provider, window);
    void request.current.then((href) => { if (live) setDestination(href); }, (reason: unknown) => {
      if (live) setError(reason instanceof Error ? reason.message : "Connection was not confirmed. Check Connections before trying again.");
    });
    return () => { live = false; };
  }, [provider]);
  return <main className={`${styles.page} ${styles.callback}`}>
    <p className={styles.eyebrow}>FindEZ Connect</p>
    <h1>{destination ? `${providerLabel(provider)} connected` : `Connecting ${providerLabel(provider)}`}</h1>
    {error ? <p role="alert">{error}</p> : <p role="status">{destination ? "Your connection is ready. Choose what to sync on the Connections page." : "Checking your authorization..."}</p>}
    {(destination || error) && <Link href={destination || "/organizations"}>{destination ? "Open Connections" : "Return to FindEZ"}</Link>}
  </main>;
}
