"use client";

export function LegalPrintButton() {
  return <button type="button" onClick={() => window.print()}>Print / save a copy</button>;
}
