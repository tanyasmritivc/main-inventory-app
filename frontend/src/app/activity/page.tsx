import { ActivityFeedClient } from "@/components/site/activity-feed-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export default function ActivityPage() { return <ProtectedAppPage returnTo="/activity"><ActivityFeedClient mode="activity" /></ProtectedAppPage>; }
