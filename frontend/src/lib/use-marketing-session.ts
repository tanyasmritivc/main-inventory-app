"use client";

import { useEffect, useState } from "react";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

/** Link presentation only; workspace pages still verify the user on the server. */
export function useMarketingSession(initialSignedIn = false) {
  const [signedIn, setSignedIn] = useState(initialSignedIn);

  useEffect(() => {
    const supabase = createSupabaseBrowserClient();
    // Supabase emits INITIAL_SESSION after reading browser storage, then keeps
    // this link current when the visitor signs in or out in another tab.
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      setSignedIn(Boolean(session));
    });
    return () => data.subscription.unsubscribe();
  }, []);

  return signedIn;
}
