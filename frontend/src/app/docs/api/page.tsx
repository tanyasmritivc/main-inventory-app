import type { Metadata } from "next";
import { ApiDocs } from "@/components/site/api-docs";

export const metadata: Metadata = {
  title: "API documentation",
  description: "Complete FindEZ integration API reference: key verification, permissions, workspace inventory, organization management, structured queries, bulk sync, examples, limits, and errors.",
  alternates: { canonical: "/docs/api" },
  openGraph: { title: "FindEZ API documentation", description: "Connect workspace inventory and organization tools with scoped API keys.", url: "https://findez.ai/docs/api" },
};

export default function ApiDocumentationPage() {
  return <ApiDocs />;
}
