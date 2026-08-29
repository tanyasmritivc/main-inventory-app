import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactCompiler: true,

  async redirects() {
    return [
      "/dashboard/:path*",
      "/home/:path*",
      "/inventory/:path*",
      "/documents/:path*",
      "/collections/:path*",
      "/shopping-list/:path*",
      "/checkout/:path*",
      "/onboarding/:path*",
    ].map((source) => ({
      source,
      destination: "/mobile-app",
      permanent: false,
    })).concat({
      source: "/sharing/:path*",
      destination: "/mobile-app?source=shared-space",
      permanent: false,
    });
  },

  typescript: {
    ignoreBuildErrors: true,
  },
};

export default nextConfig;
