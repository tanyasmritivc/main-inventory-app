"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

export function SiteNav(props: { variant: "marketing" | "app" }) {
  const router = useRouter();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);
  const [initial, setInitial] = useState<string>("?");

  useEffect(() => {
    if (props.variant !== "app") return;
    supabase.auth.getUser().then(({ data }) => {
      const email = data.user?.email ?? "";
      setInitial(email ? email[0].toUpperCase() : "?");
    }).catch(() => {});
  }, [props.variant, supabase]);

  async function onHomeClick(e: React.MouseEvent) {
    e.preventDefault();
    const { data } = await supabase.auth.getSession();
    const hasSession = Boolean(data.session);
    router.push(hasSession ? "/home" : "/");
  }

  return (
    <header className="w-full border-b border-white/[0.07] bg-black/70 backdrop-blur-xl sticky top-0 z-30">
      <div className="mx-auto flex h-14 w-full max-w-full items-center justify-between px-4 md:px-6">
        {props.variant === "app" ? (
          <Link
            href="/home"
            className="text-[17px] font-bold text-white tracking-tight md:hidden"
            onClick={onHomeClick}
          >
            FindEZ
          </Link>
        ) : (
          <Link href="/" className="text-[17px] font-bold text-white tracking-tight">
            FindEZ
          </Link>
        )}
        <div className="flex items-center gap-3">
          {props.variant === "marketing" ? (
            <>
              <Link href="/signin" className="text-sm text-white/60 hover:text-white transition-colors">
                Sign In
              </Link>
              <Button asChild className="text-sm">
                <Link href="/signup">Get Started</Link>
              </Button>
            </>
          ) : (
            <Link
              href="/settings"
              className="flex h-8 w-8 items-center justify-center rounded-full bg-white/10 border border-white/15 text-[13px] font-semibold text-white hover:bg-white/20 transition-colors"
              aria-label="Profile & Settings"
            >
              {initial}
            </Link>
          )}
        </div>
      </div>
    </header>
  );
}
