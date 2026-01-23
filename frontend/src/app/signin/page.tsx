import Link from "next/link";

import { SiteNav } from "@/components/site/nav";
import { AuthForm } from "@/components/site/auth-form";
import { Button } from "@/components/ui/button";

export default function SignInPage() {
  return (
    <div className="min-h-screen">
      <SiteNav variant="marketing" />
      <main className="mx-auto flex w-full max-w-6xl flex-col items-center px-4 py-16">
        <AuthForm mode="signin" />
        <div className="mt-6 text-sm text-muted-foreground">
          Don&apos;t have an account?
          <Button asChild variant="link" className="px-2">
            <Link href="/signup">Sign up</Link>
          </Button>
        </div>
      </main>
    </div>
  );
}
