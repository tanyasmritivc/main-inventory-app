import Link from "next/link";
import { ListChecks } from "lucide-react";

import { ProtectedAppPage } from "@/components/site/protected-app-page";

export default function ReviewPage() {
  return (
    <ProtectedAppPage returnTo="/review">
      <section className="product-page review-page">
        <header className="product-page-header"><h1>Review</h1></header>
        <div className="review-empty">
          <ListChecks size={24} />
          <strong>No saved review queue yet</strong>
          <p>Photo results are reviewed in Capture before they are saved. Durable unresolved objects will appear here after capture storage is added.</p>
          <Link className="product-button primary" href="/scan">Open Capture</Link>
        </div>
      </section>
    </ProtectedAppPage>
  );
}
