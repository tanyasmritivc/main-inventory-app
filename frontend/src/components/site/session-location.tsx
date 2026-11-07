"use client";
import { useEffect } from "react";
import { usePathname, useSearchParams } from "next/navigation";
import { rememberPage } from "@/lib/app-resume";

export function SessionLocation({ accountId }: { accountId: string | null }) {
  const pathname = usePathname();
  const search = useSearchParams().toString();
  useEffect(() => {
    if (accountId) rememberPage(accountId, pathname + (search ? `?${search}` : ""));
  }, [accountId, pathname, search]);
  return null;
}
