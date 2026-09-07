"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type { ReactNode } from "react";

type DialogOptions = {
  title: string;
  message?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
};

type PromptOptions = DialogOptions & {
  label?: string;
  placeholder?: string;
  initialValue?: string;
  inputType?: "text" | "email" | "number" | "date";
  requiredValue?: string;
};

type ActiveDialog =
  | ({ kind: "confirm" } & DialogOptions)
  | ({ kind: "prompt" } & PromptOptions)
  | ({ kind: "notice" } & DialogOptions);

type DialogApi = {
  confirmAction: (options: DialogOptions) => Promise<boolean>;
  promptValue: (options: PromptOptions) => Promise<string | null>;
  showNotice: (options: DialogOptions) => Promise<void>;
};

const DialogContext = createContext<DialogApi | null>(null);

export function AppDialogProvider({ children }: { children: ReactNode }) {
  const [active, setActive] = useState<ActiveDialog | null>(null);
  const [value, setValue] = useState("");
  const resolver = useRef<((result: boolean | string | null) => void) | null>(null);

  const open = useCallback(<T extends boolean | string | null>(dialog: ActiveDialog, initialValue = "") => {
    resolver.current?.(null);
    setValue(initialValue);
    setActive(dialog);
    return new Promise<T>((resolve) => {
      resolver.current = resolve as (result: boolean | string | null) => void;
    });
  }, []);

  const close = useCallback((result: boolean | string | null) => {
    const resolve = resolver.current;
    resolver.current = null;
    setActive(null);
    resolve?.(result);
  }, []);

  useEffect(() => {
    if (!active) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") close(active.kind === "notice" ? true : null);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [active, close]);

  const api = useMemo<DialogApi>(() => ({
    confirmAction: (options) => open<boolean>({ kind: "confirm", ...options }),
    promptValue: (options) => open<string | null>({ kind: "prompt", ...options }, options.initialValue ?? ""),
    showNotice: async (options) => { await open<boolean>({ kind: "notice", ...options }); },
  }), [open]);

  const promptValid = active?.kind !== "prompt" || (
    value.trim().length > 0 &&
    (!active.requiredValue || value === active.requiredValue)
  );

  return (
    <DialogContext.Provider value={api}>
      {children}
      {active && (
        <div className="app-dialog-backdrop" role="presentation" onMouseDown={() => close(active.kind === "notice" ? true : null)}>
          <section className="app-dialog" role="dialog" aria-modal="true" aria-labelledby="app-dialog-title" onMouseDown={(event) => event.stopPropagation()}>
            <div className="app-dialog-copy">
              <h2 id="app-dialog-title">{active.title}</h2>
              {active.message && <p>{active.message}</p>}
            </div>
            {active.kind === "prompt" && (
              <label className="app-dialog-field">
                {active.label && <span>{active.label}</span>}
                <input
                  autoFocus
                  type={active.inputType ?? "text"}
                  value={value}
                  placeholder={active.placeholder}
                  onChange={(event) => setValue(event.target.value)}
                  onKeyDown={(event) => {
                    if (event.key === "Enter" && promptValid) close(value.trim());
                  }}
                />
                {active.requiredValue && <small>Type {active.requiredValue} exactly to continue.</small>}
              </label>
            )}
            <div className="app-dialog-actions">
              {active.kind !== "notice" && <button type="button" onClick={() => close(null)}>{active.cancelLabel ?? "Cancel"}</button>}
              <button
                autoFocus={active.kind !== "prompt"}
                type="button"
                className={active.danger ? "danger" : "primary"}
                disabled={!promptValid}
                onClick={() => close(active.kind === "prompt" ? value.trim() : true)}
              >
                {active.confirmLabel ?? (active.kind === "notice" ? "Done" : "Confirm")}
              </button>
            </div>
          </section>
        </div>
      )}
    </DialogContext.Provider>
  );
}

export function useAppDialog(): DialogApi {
  const context = useContext(DialogContext);
  if (!context) throw new Error("useAppDialog must be used within AppDialogProvider");
  return context;
}
