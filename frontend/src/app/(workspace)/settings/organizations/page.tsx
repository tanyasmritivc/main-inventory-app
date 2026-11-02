import { requireUser } from "@/lib/auth-guard";
import { OrganizationDirectory } from "@/components/site/organization-directory";
export const metadata = { title: "Organizations | Settings" };
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ new?: string }>;
}) {
  const query = await searchParams;
  await requireUser(
    `/settings/organizations${query.new === "1" ? "?new=1" : ""}`,
  );
  return <OrganizationDirectory embedded startCreate={query.new === "1"} />;
}
