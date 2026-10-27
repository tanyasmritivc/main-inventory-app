import { requireUser } from "@/lib/auth-guard";
import { OrganizationDirectory } from "@/components/site/organization-directory";
export const metadata = { title: "Organizations", robots: { index: false, follow: false } };
export default async function OrganizationsPage() {
 await requireUser("/organizations");
 return <OrganizationDirectory />;
}
