"use client";
import Link from "next/link";
export function InteriorLoading({ page }: { page: string }) {
  return (
    <div className="interior-loading" role="status">
      <h1>Opening {page}…</h1>
      <p>Loading your account and workspace.</p>
    </div>
  );
}
export function InteriorError({ reset }: { reset: () => void }) {
  return (
    <div className="interior-loading" role="alert">
      <h1>This page could not be loaded</h1>
      <p>Try again to reload your workspace.</p>
      <button onClick={reset}>Try again</button> ·{" "}
      <Link href="/home">Go to Home</Link>
    </div>
  );
}
