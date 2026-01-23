"use client";

import { useEffect, useRef, useState } from "react";
import { BrowserMultiFormatReader } from "@zxing/browser";

import { Button } from "@/components/ui/button";

export function BarcodeScanner(props: { onDetected: (code: string) => void }) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const controlsRef = useRef<{ stop: () => void } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [running, setRunning] = useState(false);

  function errorMessage(err: unknown): string {
    if (err instanceof Error) return err.message;
    if (typeof err === "string") return err;
    return "Unable to start camera";
  }

  useEffect(() => {
    let reader: BrowserMultiFormatReader | null = null;
    let cancelled = false;

    async function start() {
      try {
        setError(null);
        setRunning(true);
        reader = new BrowserMultiFormatReader();

        if (!videoRef.current) return;

        const devices = await BrowserMultiFormatReader.listVideoInputDevices();
        const deviceId = devices?.[0]?.deviceId;

        const controls = await reader.decodeFromVideoDevice(deviceId, videoRef.current, (result) => {
          if (cancelled) return;
          if (result) {
            props.onDetected(result.getText());
          }
        });

        controlsRef.current = controls;
      } catch (e: unknown) {
        setError(errorMessage(e));
        setRunning(false);
      }
    }

    start();

    return () => {
      cancelled = true;
      try {
        controlsRef.current?.stop();
      } catch {
        // ignore
      }
    };
  }, [props]);

  return (
    <div className="space-y-3">
      <div className="overflow-hidden rounded-md border bg-black">
        <video ref={videoRef} className="h-72 w-full object-cover" muted playsInline />
      </div>
      {error ? <p className="text-sm text-destructive">{error}</p> : null}
      {!running ? (
        <Button variant="outline" onClick={() => window.location.reload()}>
          Retry
        </Button>
      ) : (
        <p className="text-sm text-muted-foreground">Point your camera at the barcode…</p>
      )}
    </div>
  );
}
