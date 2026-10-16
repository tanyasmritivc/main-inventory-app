import { requireUser } from "@/lib/auth-guard";
import { OrganizationDirectory } from "@/components/site/organization-directory";
export const metadata = { title: "Organization", robots: { index: false, follow: false } };
export default async function OrganizationPage({ params }: { params: Promise<{ organizationId: string }> }) {
 const { organizationId } = await params;
 await requireUser(`/organizations/${encodeURIComponent(organizationId)}`);
 return <OrganizationDirectory organizationId={organizationId} />;
}
