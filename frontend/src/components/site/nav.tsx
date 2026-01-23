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
    <header className={"w-full border-b " + (props.variant === "marketing" ? "bg-transparent" : "bg-background")}>
      <div className="mx-auto flex h-16 w-full max-w-6xl items-center justify-between px-4">
        <Link
          href={props.variant === "app" ? "/home" : "/"}
          className="font-semibold tracking-tight"
          onClick={props.variant === "app" ? onHomeClick : undefined}
        >
          main-ai-inventory
        </Link>
        <div className="flex items-center gap-2">
          {props.variant === "marketing" ? (
            <>
              <Button asChild variant="ghost">
                <Link href="/signin">Sign In</Link>
              </Button>
              <Button asChild>
                <Link href="/signup">Get Started</Link>
              </Button>
            </>
          ) : (
            <Button asChild variant="outline">
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
