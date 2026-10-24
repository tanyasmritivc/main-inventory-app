import { requireUser } from "@/lib/auth-guard";
import { OrganizationDirectory } from "@/components/site/organization-directory";
export const metadata = { title: "Organization", robots: { index: false, follow: false } };
export default async function OrganizationPage({ params, searchParams }: { params: Promise<{ organizationId: string }>; searchParams: Promise<{ view?: string }> }) {
 const { organizationId } = await params;
 const { view } = await searchParams;
 const selectedView = view === "people" || view === "settings" ? view : "workspaces";
 await requireUser(`/organizations/${encodeURIComponent(organizationId)}${selectedView === "workspaces" ? "" : `?view=${selectedView}`}`);
 return <OrganizationDirectory organizationId={organizationId} view={selectedView} />;
}
