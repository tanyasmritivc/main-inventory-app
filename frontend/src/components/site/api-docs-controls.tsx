"use client";

import { useRef, useState } from "react";
import { Check, Copy, Printer } from "lucide-react";
import styles from "./api-documentation.module.css";

export function CodeExample({ label, language, value }: { label: string; language: string; value: string }) {
  const [status, setStatus] = useState<"idle" | "copied" | "failed">("idle");
  const codeRef = useRef<HTMLElement>(null);

  async function copy() {
    try {
      await navigator.clipboard.writeText(value);
      setStatus("copied");
    } catch {
      setStatus("failed");
      codeRef.current?.focus();
      const selection = window.getSelection();
      if (selection && codeRef.current) {
        const range = document.createRange();
        range.selectNodeContents(codeRef.current);
        selection.removeAllRanges();
        selection.addRange(range);
      }
    }
  }

  return <figure className={styles.codeBlock}>
    <figcaption><span>{label}<small>{language}</small></span>
      <button type="button" onClick={() => void copy()} aria-label={`Copy ${label}`}>
        {status === "copied" ? <Check size={14} aria-hidden /> : <Copy size={14} aria-hidden />}
        {status === "copied" ? "Copied" : "Copy"}
      </button>
    </figcaption>
    <pre><code ref={codeRef} tabIndex={0} aria-label={label}>{value}</code></pre>
    <span role="status" className={status === "failed" ? styles.copyError : styles.srOnly}>
      {status === "failed" ? "Copy is unavailable. The example is selected; copy it manually." : status === "copied" ? `${label} copied.` : ""}
    </span>
  </figure>;
}

export function PrintDocumentation() {
  return <button className={styles.textButton} type="button" onClick={() => window.print()}><Printer size={15} aria-hidden />Print guide</button>;
}
