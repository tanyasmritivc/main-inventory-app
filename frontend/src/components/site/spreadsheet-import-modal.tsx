"use client";

import { useState } from "react";
import { CheckCircle2, Loader2, UploadCloud } from "lucide-react";
import { Button } from "@/components/ui/button";
import { DialogClose } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";

function apiBase() {
  return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
}

type Props = {
  spaceName: string;
  token: string;
  onSuccess: (count: number) => void;
};

export function SpreadsheetImportModal({ spaceName, token, onSuccess }: Props) {
  const [step, setStep] = useState<"upload" | "processing" | "success">("upload");
  const [error, setError] = useState<string | null>(null);
  const [insertedCount, setInsertedCount] = useState<number | null>(null);

  function errorMessage(err: unknown, fallback: string): string {
    if (err instanceof Error) return err.message;
    if (typeof err === "string") return err;
    return fallback;
  }

  async function importFile(file: File) {
    setError(null);
    setStep("processing");

    const formData = new FormData();
    formData.append("file", file);
    formData.append("location", spaceName);

    try {
      const res = await fetch(`${apiBase()}/import/spreadsheet`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
        },
        body: formData,
      });

      if (!res.ok) {
        const text = await res.text();
        throw new Error(text || `Request failed: ${res.status}`);
      }

      const data = await res.json();
      const inserted = typeof data.inserted === "number" ? data.inserted : 0;
      setInsertedCount(inserted);
      onSuccess(inserted);
      setStep("success");
    } catch (err: unknown) {
      setError(errorMessage(err, "Failed to import spreadsheet"));
      setStep("upload");
    }
  }

  return (
    <div style={{ background: "#0d0d0d", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 20, padding: 28 }}>
      <div style={{ fontSize: 18, fontFamily: "var(--font-syne)", fontWeight: 600, color: "white", marginBottom: 24 }}>
        Import to {spaceName}
      </div>

      {step === "upload" ? (
        <div>
          <label
            style={{ display: "block", border: "1px dashed rgba(255,255,255,0.15)", borderRadius: 14, padding: "48px 24px", textAlign: "center", background: "rgba(255,255,255,0.02)", cursor: "pointer", transition: "border-color 150ms, background 150ms" }}
            onMouseEnter={(e) => { const el = e.currentTarget as HTMLElement; el.style.borderColor = "rgba(255,255,255,0.28)"; el.style.background = "rgba(255,255,255,0.04)"; }}
            onMouseLeave={(e) => { const el = e.currentTarget as HTMLElement; el.style.borderColor = "rgba(255,255,255,0.15)"; el.style.background = "rgba(255,255,255,0.02)"; }}
          >
            <div style={{ fontSize: 28, color: "rgba(255,255,255,0.28)", lineHeight: 1 }}>↑</div>
            <div style={{ fontSize: 14, color: "rgba(255,255,255,0.55)", marginTop: 12 }}>Drop spreadsheet here or click to browse</div>
            <div style={{ fontSize: 12, color: "rgba(255,255,255,0.28)", marginTop: 6 }}>Excel (.xlsx, .xls) or CSV</div>
            <input
              type="file"
              accept=".xlsx,.xls,.csv"
              style={{ display: "none" }}
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) void importFile(file);
              }}
            />
          </label>
          {error ? <p style={{ fontSize: 13, color: "#ef4444", marginTop: 12 }}>{error}</p> : null}
        </div>
      ) : step === "processing" ? (
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", padding: "40px 0" }}>
          <div style={{ width: 32, height: 32, borderRadius: "50%", border: "2px solid rgba(255,255,255,0.10)", borderTop: "2px solid white", animation: "spin 0.8s linear infinite" }} />
          <div style={{ fontSize: 14, color: "rgba(255,255,255,0.55)", marginTop: 16 }}>Reading your file...</div>
          <div style={{ fontSize: 12, color: "rgba(255,255,255,0.35)", marginTop: 6 }}>AI is organizing your data...</div>
        </div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", padding: "32px 0" }}>
          <div style={{ width: 56, height: 56, borderRadius: "50%", background: "rgba(34,197,94,0.12)", border: "1px solid rgba(34,197,94,0.25)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 24, color: "#22c55e" }}>
            ✓
          </div>
          <div style={{ fontSize: 18, fontFamily: "var(--font-syne)", fontWeight: 600, color: "white", marginTop: 16 }}>Import complete!</div>
          <div style={{ fontSize: 14, color: "rgba(255,255,255,0.45)", marginTop: 6 }}>{insertedCount ?? 0} items added to {spaceName}</div>
          <div style={{ display: "flex", gap: 10, marginTop: 24 }}>
            <DialogClose asChild>
              <button type="button" style={{ background: "white", color: "black", border: "none", borderRadius: 99, padding: "10px 22px", fontSize: 14, fontWeight: 600, cursor: "pointer" }}>
                View Items
              </button>
            </DialogClose>
            <button
              type="button"
              style={{ background: "rgba(255,255,255,0.05)", border: "1px solid rgba(255,255,255,0.10)", borderRadius: 99, padding: "10px 20px", fontSize: 14, color: "white", cursor: "pointer" }}
              onClick={() => { setError(null); setInsertedCount(null); setStep("upload"); }}
            >
              Import another
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
