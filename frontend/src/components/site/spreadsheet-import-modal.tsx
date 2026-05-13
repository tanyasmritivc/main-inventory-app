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
    <div className="space-y-6">
      <div className="text-[22px] font-semibold tracking-[-0.01em] text-white">Import to {spaceName}</div>

      {step === "upload" ? (
        <div className="space-y-4">
          <label className="grid h-[120px] w-full cursor-pointer place-items-center rounded-[16px] border border-dashed border-white/[0.20] bg-white/[0.04] text-center text-white/55 transition-all duration-200 hover:border-white/[0.28]">
            <div className="space-y-2">
              <UploadCloud className="mx-auto" size={28} />
              <div className="text-sm font-medium text-white">Drop your spreadsheet here or click to browse</div>
              <div className="text-sm text-white/50">Supports Excel (.xlsx, .xls) and CSV</div>
            </div>
            <Input
              type="file"
              accept=".xlsx,.xls,.csv"
              className="hidden"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) {
                  void importFile(file);
                }
              }}
            />
          </label>
          <p className="text-[13px] text-white/55">Upload a spreadsheet and FindEZ will parse your data into inventory items in this space.</p>
          {error ? <p className="text-sm text-destructive">{error}</p> : null}
        </div>
      ) : step === "processing" ? (
        <div className="space-y-4 rounded-[16px] border border-white/[0.08] bg-white/[0.04] p-6 text-center">
          <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full border border-white/[0.12]">
            <Loader2 className="animate-spin" size={24} />
          </div>
          <div className="space-y-2">
            <p className="text-lg font-semibold text-white">Reading your file...</p>
            <p className="text-sm text-white/55">AI is organizing your data...</p>
          </div>
        </div>
      ) : (
        <div className="space-y-4 rounded-[16px] border border-white/[0.08] bg-white/[0.04] p-6 text-center">
          <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-300">
            <CheckCircle2 size={24} />
          </div>
          <div className="space-y-2">
            <p className="text-lg font-semibold text-white">Import complete!</p>
            <p className="text-sm text-white/55">{insertedCount ?? 0} items added to {spaceName}</p>
          </div>
          <div className="flex flex-col gap-2 sm:flex-row sm:justify-center">
            <DialogClose asChild>
              <Button>View Items</Button>
            </DialogClose>
            <Button
              variant="ghost"
              className="border border-white/[0.08]"
              onClick={() => {
                setError(null);
                setInsertedCount(null);
                setStep("upload");
              }}
            >
              Import another
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
