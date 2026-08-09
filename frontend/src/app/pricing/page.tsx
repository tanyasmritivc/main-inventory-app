export const dynamic = "force-dynamic";

import type { Metadata } from "next";

import { PricingClient } from "@/components/site/pricing-client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  title: "Pricing — FindEZ",
  description: "Simple, transparent pricing for FindEZ inventory management.",
};

export default async function PricingPage() {
  let isAuthed = false;
  try {
    const supabase = await createSupabaseServerClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    isAuthed = !!user;
  } catch (_) {}

  return <PricingClient isAuthed={isAuthed} />;
}
