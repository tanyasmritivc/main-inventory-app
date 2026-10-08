import { LabelStudioClient } from "@/components/site/label-studio-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export default async function LabelsPage({ searchParams }: { searchParams?: Promise<{ item?: string }> }) {
  const itemId = (await searchParams)?.item;
  return <ProtectedAppPage returnTo={itemId ? `/labels?item=${encodeURIComponent(itemId)}` : "/labels"}><LabelStudioClient initialItemId={itemId} /></ProtectedAppPage>;
}
