"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { accountRequest } from "@/lib/account-request";
import { useApiSession } from "@/lib/use-api-session";
import { worldHref } from "@/lib/world-navigation";
import { userFacingError } from "@/lib/user-facing-error";
export function LegacyWorkspaceRedirect({ workspaceId }: { workspaceId: string }) {
  const { accountId } = useApiSession();
  const router = useRouter();
  const [error, setError] = useState("");
  useEffect(() => {
    if (!accountId) return;
    let live = true;
    accountRequest<{ workspace: { organization_id?: string } }>(accountId,
      `/inventory-workspaces/${encodeURIComponent(workspaceId)}/overview`)
      .then(result => { if (live) router.replace(worldHref(result.workspace.organization_id || "personal", "spaces")); })
      .catch(reason => { if (live) setError(userFacingError(reason, "This organization is unavailable.")); });
    return () => { live = false; };
  }, [accountId, workspaceId, router]);
  return <p role={error ? "alert" : "status"}>{error || "Opening Spaces..."}</p>;
}
