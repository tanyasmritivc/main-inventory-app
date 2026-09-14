import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: ["/", "/robotics", "/privacy", "/terms", "/docs/api"],
      disallow: [
        "/signin", "/signup", "/reset-password", "/auth/", "/inventory", "/scan", "/assist",
        "/teams", "/documents", "/project-kits",
        "/notifications", "/labels", "/settings", "/sharing", "/billing",
        "/checkout", "/upgrade",
      ],
    },
    sitemap: "https://findez.ai/sitemap.xml",
  };
}
