import { SiteNav } from "@/components/site/nav";
import { AppSidebar } from "@/components/site/app-sidebar";

export function AppShell(props: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen">
      <SiteNav variant="app" />
      <div className="flex flex-col md:flex-row">
        <AppSidebar />
        <main className="w-full px-4 py-10">
          <div className="mx-auto w-full max-w-6xl">{props.children}</div>
        </main>
      </div>
    </div>
  );
}
