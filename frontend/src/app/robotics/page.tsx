export const dynamic = "force-dynamic";

import type { Metadata } from "next";

import { RoboticsClient } from "@/components/site/robotics-client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "FindEZ for Robotics Teams — Inventory Management for FTC, FRC, VEX & FLL",
  description: "Stop losing parts. FindEZ gives your robotics team one organized inventory — AI-scanned, barcode-tracked, and accessible from the pit or the shop.",
};

export default async function RoboticsPage() {
  let isAuthed = false;
  try {
    const supabase = await createSupabaseServerClient();
    const { data: { user } } = await supabase.auth.getUser();
    isAuthed = !!user;
  } catch (_) {}

  return <RoboticsClient isAuthed={isAuthed} />;
}
