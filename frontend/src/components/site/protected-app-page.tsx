import { requireUser } from "@/lib/auth-guard";

export async function ProtectedAppPage({ children, returnTo }: { children: React.ReactNode; returnTo: string }) {
  await requireUser(returnTo);
  return children;
}
