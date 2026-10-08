import { ActivityFeedClient } from "@/components/site/activity-feed-client";
import { ProtectedAppPage } from "@/components/site/protected-app-page";
export default function NotificationsPage() { return <ProtectedAppPage returnTo="/notifications"><ActivityFeedClient mode="notifications" /></ProtectedAppPage>; }
