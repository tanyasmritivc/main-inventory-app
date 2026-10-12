export const dynamic = "force-dynamic";

import type { Metadata } from "next";

import { RoboticsClient } from "@/components/site/robotics-client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "Robotics inventory",
  description: "Organize robotics parts with photos, barcodes, Spaces, and shared team inventory.",
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
