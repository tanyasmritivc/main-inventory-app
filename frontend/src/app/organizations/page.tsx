import { requireUser } from "@/lib/auth-guard";
import { OrganizationDirectory } from "@/components/site/organization-directory";
export const metadata = { title: "Organizations", robots: { index: false, follow: false } };
export default async function OrganizationsPage({ searchParams }: { searchParams: Promise<{ new?: string }> }) {
 await requireUser("/organizations");
 const query = await searchParams;
 return <OrganizationDirectory startCreate={query.new === "1"} />;
}
