import { apiSpecification } from "@/lib/api-openapi";

export const dynamic = "force-static";

export function GET() {
  return Response.json(apiSpecification, { headers: {
    "Content-Disposition": 'attachment; filename="findez-openapi.json"',
    "X-Content-Type-Options": "nosniff",
  } });
}
