import { documentationMarkdown } from "@/lib/api-docs";

export const dynamic = "force-static";

export function GET() {
  return new Response(documentationMarkdown(), { headers: {
    "Content-Type": "text/markdown; charset=utf-8",
    "Content-Disposition": 'attachment; filename="findez-api-guide.md"',
    "X-Content-Type-Options": "nosniff",
  } });
}
