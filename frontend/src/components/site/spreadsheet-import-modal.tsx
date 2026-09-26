"use client";

import { useState } from "react";
import { CheckCircle2, Loader2, UploadCloud } from "lucide-react";
import { Button } from "@/components/ui/button";
import { DialogClose } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { importSpreadsheet } from "@/lib/api";
import { userFacingError } from "@/lib/user-facing-error";

type Props = {
  spaceName: string;
  token: string;
  onSuccess: (count: number) => void;
};

export function SpreadsheetImportModal({ spaceName, token, onSuccess }: Props) {
  const [step, setStep] = useState<"upload" | "processing" | "success">("upload");
  const [error, setError] = useState<string | null>(null);
  const [insertedCount, setInsertedCount] = useState<number | null>(null);

  async function importFile(file: File) {
    setError(null);
    setStep("processing");

    try {
      const data = await importSpreadsheet({ token, file, location: spaceName });
      const inserted = typeof data.inserted === "number" ? data.inserted : 0;
      setInsertedCount(inserted);
      onSuccess(inserted);
      setStep("success");
    } catch (err: unknown) {
      setError(userFacingError(err, "The spreadsheet could not be imported. Check the file and try again."));
      setStep("upload");
    }
  }

  return (
    <div style={{ background: "var(--light-panel)", border: "1px solid rgba(0,0,0,0.10)", borderRadius: 20, padding: 28 }}>
      <div style={{ fontSize: 18, fontFamily: "var(--font-syne)", fontWeight: 600, color: "var(--ink)", marginBottom: 24 }}>
        Import to {spaceName}
      </div>

      {step === "upload" ? (
        <div>
          <label
            style={{ display: "block", border: "1px dashed rgba(0,0,0,0.15)", borderRadius: 14, padding: "48px 24px", textAlign: "center", background: "rgba(0,0,0,0.02)", cursor: "pointer", transition: "border-color 150ms, background 150ms" }}
            onMouseEnter={(e) => { const el = e.currentTarget as HTMLElement; el.style.borderColor = "rgba(0,0,0,0.28)"; el.style.background = "rgba(0,0,0,0.04)"; }}
            onMouseLeave={(e) => { const el = e.currentTarget as HTMLElement; el.style.borderColor = "rgba(0,0,0,0.15)"; el.style.background = "rgba(0,0,0,0.02)"; }}
          >
            <div style={{ fontSize: 28, color: "var(--light-muted)", lineHeight: 1 }}>↑</div>
            <div style={{ fontSize: 14, color: "var(--light-muted)", marginTop: 12 }}>Drop spreadsheet here or click to browse</div>
            <div style={{ fontSize: 12, color: "var(--light-muted)", marginTop: 6 }}>Excel (.xlsx, .xls) or CSV</div>
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
          {error ? <p style={{ fontSize: 13, color: "var(--danger-ink)", marginTop: 12 }}>{error}</p> : null}
        </div>
      ) : step === "processing" ? (
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", padding: "40px 0" }}>
          <div style={{ width: 32, height: 32, borderRadius: "50%", border: "2px solid rgba(0,0,0,0.10)", borderTop: "2px solid var(--clay)", animation: "spin 0.8s linear infinite" }} />
          <div style={{ fontSize: 14, color: "var(--light-muted)", marginTop: 16 }}>Reading your file...</div>
          <div style={{ fontSize: 12, color: "var(--light-muted)", marginTop: 6 }}>AI is organizing your data...</div>
        </div>
      ) : (
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", padding: "32px 0" }}>
          <div style={{ width: 56, height: 56, borderRadius: "50%", background: "rgba(34,197,94,0.12)", border: "1px solid rgba(34,197,94,0.25)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 24, color: "#22c55e" }}>
            ✓
          </div>
          <div style={{ fontSize: 18, fontFamily: "var(--font-syne)", fontWeight: 600, color: "var(--ink)", marginTop: 16 }}>Import complete!</div>
          <div style={{ fontSize: 14, color: "var(--light-muted)", marginTop: 6 }}>{insertedCount ?? 0} items added to {spaceName}</div>
          <div style={{ display: "flex", gap: 10, marginTop: 24 }}>
            <DialogClose asChild>
              <button type="button" style={{ background: "var(--control-primary)", color: "var(--ink)", border: "none", borderRadius: 7, padding: "10px 22px", fontSize: 13, fontWeight: 600, cursor: "pointer" }}>
                View Items
              </button>
            </DialogClose>
            <button
              type="button"
              style={{ background: "var(--light-raised)", border: "1px solid var(--light-line)", borderRadius: 7, padding: "10px 20px", fontSize: 13, fontWeight: 600, color: "var(--ink)", cursor: "pointer" }}
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
