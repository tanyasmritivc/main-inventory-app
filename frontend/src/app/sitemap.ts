import type { MetadataRoute } from "next";
import { PUBLIC_SITE_UPDATED_AT, PUBLIC_SITE_URL } from "@/lib/public-positioning";

const publicRoutes = [
  "",
  "/product",
  "/solutions",
  "/pricing",
  "/privacy",
  "/terms",
  "/docs/api",
];

export default function sitemap(): MetadataRoute.Sitemap {
  return publicRoutes.map((route) => ({
    url: `${PUBLIC_SITE_URL}${route}`,
    // Only advertise a date we know, rather than changing every URL on each crawl.
    ...(route === "" ? { lastModified: PUBLIC_SITE_UPDATED_AT } : {}),
  }));
}
