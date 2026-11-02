"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

// Legacy upgrade links open the planned Free, Plus and Team comparison.
export function UpgradeClient() {
  const router = useRouter();
  useEffect(() => { router.replace("/pricing"); }, [router]);
  return null;
}
