import { requireUser } from "@/lib/auth-guard";
import { PlansUsageClient } from "@/components/site/plans-usage-client";

export const metadata = { title: "Plans & usage" };
export default async function PlansPage() {
  await requireUser("/settings/plans");
  return <PlansUsageClient/>;
}
