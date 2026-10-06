import { ProtectedAppPage } from "@/components/site/protected-app-page";
import { ActivityFeedClient } from "@/components/site/activity-feed-client";
export default function Page() {
  return (
    <ProtectedAppPage returnTo="/activity">
      <ActivityFeedClient mode="activity" />
    </ProtectedAppPage>
  );
}
