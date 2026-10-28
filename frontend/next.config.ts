import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactCompiler: true,

  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Content-Security-Policy", value: "frame-ancestors 'none'; base-uri 'self'; object-src 'none'" },
          { key: "Permissions-Policy", value: "camera=(self), microphone=(self), geolocation=(), browsing-topics=()" },
        ],
      },
      {
        source: "/.well-known/apple-app-site-association",
        headers: [{ key: "Content-Type", value: "application/json" }],
      },
    ];
  },

  async redirects() {
    return [
      { source: "/product/capture", destination: "/scan", permanent: true },
      { source: "/product/ask", destination: "/assist", permanent: true },
      { source: "/product/spaces-and-sharing", destination: "/spaces", permanent: true },
      { source: "/robotics", destination: "/teams", permanent: true },
    ];
  },

  // Authenticated application routes are first-class web surfaces. Keep the
  // public landing page at `/` independent from this product workspace.
};

export default nextConfig;
