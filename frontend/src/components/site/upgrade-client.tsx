"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

// Individual web Pro checkout is retired — payments moved to team season plans.
// Redirect any visitor to the new pricing page.
export function UpgradeClient() {
  const router = useRouter();
  useEffect(() => { router.replace("/pricing"); }, [router]);
  return null;
}
