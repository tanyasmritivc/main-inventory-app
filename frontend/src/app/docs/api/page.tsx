import type { Metadata } from "next";
import { ApiDocs } from "@/components/site/api-docs";

export const metadata: Metadata = {
  title: "API documentation",
  description: "Complete FindEZ integration API reference: API keys, permissions, Team inventory, structured queries, bulk sync, examples, limits, and errors.",
  alternates: { canonical: "/docs/api" },
  openGraph: { title: "FindEZ API documentation", description: "Connect your Team inventory to reports, scripts, and external tools.", url: "https://findez.ai/docs/api" },
};

export default function ApiDocumentationPage() {
  return <ApiDocs />;
}
