import type { Metadata } from "next";
import { ApiDocumentation } from "@/components/site/api-documentation";

export const metadata: Metadata = {
  title: "API documentation",
  description: "Integrate FindEZ inventory with your software. API-key setup, endpoint reference, queries, bulk imports, permissions, security, and company integration guidance.",
  alternates: { canonical: "/docs/api" },
  openGraph: { title: "FindEZ API documentation", description: "The integration guide for FindEZ Team inventory.", url: "https://findez.ai/docs/api" },
};

export default function ApiDocsPage() {
  return <ApiDocumentation />;
}
