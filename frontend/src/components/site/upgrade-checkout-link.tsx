"use client";

import { useMemo, useState } from "react";

import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

function apiBase() {
  return process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000";
}

export function UpgradeCheckoutLink(props: { className?: string }) {
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [loading, setLoading] = useState(false);

  return (
    <a
      href="#"
      className={props.className}
      onClick={async (e) => {
        e.preventDefault();
        if (loading) return;
        setLoading(true);
        try {
          const { data, error } = await supabase.auth.getSession();
          if (error) throw error;
          const token = data.session?.access_token;
          if (!token) return;

          const res = await fetch(`${apiBase()}/billing/create-checkout-session`, {
            method: "POST",
            headers: {
              Authorization: `Bearer ${token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ interval: "monthly" }),
          });

          if (!res.ok) return;
          const json = (await res.json()) as { url?: string };
          const url = (json.url || "").trim();
          if (!url) return;
          window.location.href = url;
        } finally {
          setLoading(false);
        }
      }}
    >
      Upgrade for unlimited access
    </a>
  );
}
