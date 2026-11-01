import { redirect } from "next/navigation";
import { requireUser } from "@/lib/auth-guard";
export const metadata = {
  title: "Organizations",
  robots: { index: false, follow: false },
};
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ new?: string }>;
}) {
  await requireUser("/worlds");
  const query = await searchParams;
  redirect(query.new === "1" ? "/settings/organizations?new=1" : "/worlds");
}
