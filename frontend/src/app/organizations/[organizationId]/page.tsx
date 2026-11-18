import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth-guard";
import { OrganizationDirectory } from "@/components/site/organization-directory";
export const metadata = { title: "Organization", robots: { index: false, follow: false } };
export default async function OrganizationPage({ params, searchParams }: { params: Promise<{ organizationId: string }>; searchParams: Promise<{ view?: string }> }) {
 const { organizationId } = await params;
 const { view } = await searchParams;
 if (view !== "people" && view !== "settings") redirect(`/worlds/${encodeURIComponent(organizationId)}`);
 const selectedView = view === "people" ? "people" : "settings";
 await requireUser(`/organizations/${encodeURIComponent(organizationId)}?view=${selectedView}`);
 return <OrganizationDirectory organizationId={organizationId} view={selectedView} />;
}
