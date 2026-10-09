"use client";
import Link from "next/link";

export function InteriorLoading({ page }: { page?: string }) {
  return (
    <section className="workspace-page-loading" role="status" aria-busy="true">
      <span className="sr-only">Loading {page || "page"}.</span>
      <div className="workspace-loading-title" aria-hidden="true" />
      <div className="workspace-loading-line" aria-hidden="true" />
      <div className="workspace-loading-body" aria-hidden="true" />
    </section>
  );
}

export function InteriorError({ reset }: { reset: () => void }) {
  return (
    <section className="workspace-page-error" role="alert">
      <h1>This page could not be loaded</h1>
      <p>Try again to reload your workspace.</p>
      <button className="workspace-button" onClick={reset}>Try again</button>{" "}
      <Link href="/home">Go to Home</Link>
    </section>
  );
}
