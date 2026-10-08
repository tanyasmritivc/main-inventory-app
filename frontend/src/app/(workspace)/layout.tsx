import { AppShell } from "@/components/site/app-shell";

// Keep navigation, identity and appearance mounted while page segments load.
// Authentication remains in each page so it is verified on every navigation.
export default function WorkspaceLayout({ children }: { children: React.ReactNode }) {
  return <AppShell>{children}</AppShell>;
}
