import { Suspense } from "react";
import Link from "next/link";

import { SiteNav } from "@/components/site/nav";
import { AuthForm } from "@/components/site/auth-form";
import { Button } from "@/components/ui/button";

export default function SignUpPage() {
  return (
    <div className="min-h-screen flex flex-col">
      <SiteNav variant="marketing" />
      <main className="mx-auto flex w-full max-w-6xl flex-1 flex-col items-center px-4 py-16">
        <Suspense fallback={null}>
          <AuthForm mode="signup" />
        </Suspense>
        <div className="mt-6 text-sm text-muted-foreground">
          Already have an account?
          <Button asChild variant="link" className="px-2">
            <Link href="/signin">Sign in</Link>
          </Button>
        </div>
      </main>
    </div>
  );
}
