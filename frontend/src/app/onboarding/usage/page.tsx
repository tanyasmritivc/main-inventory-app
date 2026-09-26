import { UsageOnboardingClient } from "@/components/site/usage-onboarding-client";
import { requireUser } from "@/lib/auth-guard";

export default async function UsageOnboardingPage() {
  await requireUser("/onboarding/usage");

  return (
    <div className="min-h-screen w-full bg-white text-foreground">
      <div className="min-h-screen w-full flex items-center justify-center px-4 py-10">
        <UsageOnboardingClient />
      </div>
    </div>
  );
}
