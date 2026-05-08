"use client";

import Link from "next/link";
import { useMemo } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { createSupabaseBrowserClient } from "@/lib/supabase/browser";

export function SiteNav(props: { variant: "marketing" | "app" }) {
  const router = useRouter();
  const supabase = useMemo(() => createSupabaseBrowserClient(), []);

  async function onHomeClick(e: React.MouseEvent) {
    e.preventDefault();
    const { data } = await supabase.auth.getSession();
    const hasSession = Boolean(data.session);
    router.push(hasSession ? "/home" : "/");
  }

  return (
    <header className="w-full border-b border-white/[0.08] bg-black">
      <div className="mx-auto flex h-16 w-full max-w-6xl items-center justify-between px-4">
        <Link
          href={props.variant === "app" ? "/home" : "/"}
          className="text-lg font-semibold text-white tracking-tight"
          onClick={props.variant === "app" ? onHomeClick : undefined}
        >
          FindEZ
        </Link>
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
            <Button asChild variant="ghost" className="text-sm text-white/60 hover:text-white">
              <Link href="/home" onClick={onHomeClick}>
                Home
              </Link>
            </Button>
          )}
        </div>
      </div>
    </header>
  );
}
