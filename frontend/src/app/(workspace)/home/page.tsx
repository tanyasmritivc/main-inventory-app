import { HomeOverview } from "@/components/site/home-overview";
import { requireUser } from "@/lib/auth-guard";

export const metadata = { title: "Home" };

export default async function HomePage() {
  await requireUser("/home");

  return (
      <HomeOverview />
  );
}
