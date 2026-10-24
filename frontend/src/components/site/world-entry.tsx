"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useApiSession } from "@/lib/use-api-session";
import { accountRequest } from "@/lib/account-request";
import { chooseWorld, worldPreferenceKey } from "@/lib/world-entry";
import { worldHref } from "@/lib/world-navigation";
import {
  requireInventoryContext,
  selectInventory,
} from "@/lib/inventory-selection";
import { userFacingError } from "@/lib/user-facing-error";
export function WorldEntry({ query = "" }: { query?: string }) {
  const session = useApiSession();
  return (
    <AccountEntry
      key={session.accountId || "signed-out"}
      accountId={session.accountId}
      sessionError={session.error}
      query={query}
    />
  );
}
function AccountEntry({
  accountId,
  sessionError,
  query,
}: {
  accountId: string | null;
  sessionError?: string | null;
  query: string;
}) {
  const router = useRouter();
  const [error, setError] = useState("");
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    if (!accountId) return;
    let live = true;
    requireInventoryContext(false);
    selectInventory(null);
    void accountRequest<{ organizations: { organization_id: string }[] }>(
      accountId,
      "/organizations",
    )
      .then((result) => {
        if (!live) return;
        if (
          !Array.isArray(result.organizations) ||
          result.organizations.some(
            (o) => typeof o.organization_id !== "string",
          )
        )
          throw new Error("Your organizations could not be verified.");
        let remembered = null;
        try {
          remembered = localStorage.getItem(worldPreferenceKey(accountId));
        } catch {}
        const href = worldHref(chooseWorld(result.organizations, remembered));
        router.replace(
          href +
            (query
              ? `?${new URLSearchParams({ q: query.slice(0, 4000) })}`
              : ""),
        );
      })
      .catch((reason) => {
        if (live)
          setError(userFacingError(reason, "Could not open your workspace."));
      });
    return () => {
      live = false;
    };
  }, [accountId, router, query, attempt]);
  return (
    <main className="interior-loading" aria-live="polite">
      <p role={error || sessionError ? "alert" : "status"}>
        {error || sessionError || "Opening your world..."}
      </p>
      {error && (
        <button
          className="workspace-button"
          onClick={() => {
            setError("");
            setAttempt((v) => v + 1);
          }}
        >
          Try again
        </button>
      )}
    </main>
  );
}
