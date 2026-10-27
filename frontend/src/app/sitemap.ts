import type { MetadataRoute } from "next";

const publicRoutes = [
  "",
  "/privacy",
  "/terms",
  "/docs/api",
];

export default function sitemap(): MetadataRoute.Sitemap {
  return publicRoutes.map((route) => ({
    url: `https://findez.ai${route}`,
    lastModified: new Date(),
  }));
}
