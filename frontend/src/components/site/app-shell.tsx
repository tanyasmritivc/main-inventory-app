import { SiteNav } from "@/components/site/nav";
import { AppSidebar } from "@/components/site/app-sidebar";
import Link from "next/link";

export function AppShell(props: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen">
      <SiteNav variant="app" />
      <div className="flex flex-col md:flex-row">
        <AppSidebar />
        <main className="w-full px-4 py-10">
          <div className="mx-auto w-full max-w-6xl">{props.children}</div>

          <footer className="mt-20 border-t py-10 text-center text-xs text-muted-foreground">
            <div className="flex flex-col items-center gap-3">
              <div className="flex flex-wrap items-center justify-center gap-3">
                <Link href="/privacy" className="hover:underline">
                  Privacy Policy
                </Link>
                <span aria-hidden="true">·</span>
                <Link href="/terms" className="hover:underline">
                  Terms & Conditions
                </Link>
              </div>
            </div>
          </footer>
        </main>
      </div>
    </div>
  );
}
