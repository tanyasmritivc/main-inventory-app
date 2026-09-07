"use client";

import { useEffect, useRef, useState } from "react";
import { BrowserMultiFormatReader } from "@zxing/browser";

function cameraErrorMessage(err: unknown): string {
  const name = err instanceof DOMException ? err.name : "";
  if (name === "NotAllowedError" || name === "SecurityError") {
    return "Camera access is off. Allow camera access in your browser settings, then try again.";
  }
  if (name === "NotFoundError" || name === "DevicesNotFoundError") {
    return "No camera was found on this device. You can enter the barcode manually.";
  }
  if (name === "NotReadableError" || name === "TrackStartError") {
    return "The camera is busy in another app. Close it there, then try again.";
  }
  return "The camera could not start. You can enter the barcode manually or try again.";
}

export function BarcodeScanner(props: { onDetected: (code: string) => void }) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const controlsRef = useRef<{ stop: () => void } | null>(null);
  const onDetectedRef = useRef(props.onDetected);
  const [error, setError] = useState<string | null>(null);
  const [running, setRunning] = useState(false);
  const [retryKey, setRetryKey] = useState(0);

  useEffect(() => {
    onDetectedRef.current = props.onDetected;
  }, [props.onDetected]);

  useEffect(() => {
    let reader: BrowserMultiFormatReader | null = null;
    let cancelled = false;

    async function start() {
      try {
        setError(null);
        setRunning(false);
        reader = new BrowserMultiFormatReader();

        if (!videoRef.current) throw new Error("Camera preview unavailable");

        const devices = await BrowserMultiFormatReader.listVideoInputDevices();
        const deviceId = devices?.[0]?.deviceId;
        if (!deviceId) throw new DOMException("No camera", "NotFoundError");

        const controls = await reader.decodeFromVideoDevice(deviceId, videoRef.current, (result) => {
          if (cancelled) return;
          if (result) {
            onDetectedRef.current(result.getText());
          }
        });

        controlsRef.current = controls;
        setRunning(true);
      } catch (e: unknown) {
        setError(cameraErrorMessage(e));
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
      controlsRef.current = null;
    };
  }, [retryKey]);

  return (
    <div className="space-y-3">
      <div className="overflow-hidden rounded-md border bg-black">
        <video ref={videoRef} className="h-72 w-full object-cover" muted playsInline />
      </div>
      {error ? <p className="text-sm text-destructive">{error}</p> : null}
      {!running ? (
        <button className="product-button" type="button" onClick={() => setRetryKey((key) => key + 1)}>
          Retry
        </button>
      ) : (
        <p className="text-sm text-muted-foreground">Point your camera at the barcode…</p>
      )}
    </div>
  );
}
