import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: ["/", "/pricing", "/robotics", "/privacy", "/terms"],
      disallow: [
        "/signin", "/signup", "/dashboard", "/inventory", "/scan", "/assist",
        "/teams", "/documents", "/project-kits", "/shopping-list", "/activity",
        "/notifications", "/labels", "/settings", "/sharing", "/billing",
        "/checkout", "/upgrade",
      ],
    },
    sitemap: "https://findez.ai/sitemap.xml",
  };
}
