import { AssistClient } from "@/components/site/assist-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export const metadata = { title: "Ask" };

export default async function AssistPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const params = await searchParams;
  return (
    <ProtectedAppPage returnTo={typeof params.q === "string" ? `/assist?${new URLSearchParams({ q: params.q.slice(0, 4000) })}` : "/assist"}>
      <AssistClient
        initialQuery={
          typeof params.q === "string" ? params.q.slice(0, 4000) : ""
        }
      />
    </ProtectedAppPage>
  );
}
