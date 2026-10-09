import { HomeOverview } from "@/components/site/home-overview";
import { requireUser } from "@/lib/auth-guard";

export default async function HomePage() {
  await requireUser("/home");

  return (
      <HomeOverview />
  );
}
