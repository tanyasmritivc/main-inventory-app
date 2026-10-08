import { ProtectedAppPage } from "@/components/site/protected-app-page";
import { ReviewQueueClient } from "@/components/site/review-queue-client";

export default function ReviewPage() {
  return (
    <ProtectedAppPage returnTo="/review">
      <ReviewQueueClient />
    </ProtectedAppPage>
  );
}
