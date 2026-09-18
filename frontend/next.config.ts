import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactCompiler: true,

  async headers() {
    return [
      {
        source: "/.well-known/apple-app-site-association",
        headers: [{ key: "Content-Type", value: "application/json" }],
      },
    ];
  },

  async redirects() {
    return [
      { source: "/product", destination: "/", permanent: true },
      { source: "/robotics", destination: "/", permanent: true },
    ];
  },

  // Authenticated application routes are first-class web surfaces. Keep the
  // public landing page at `/` independent from this product workspace.
};

export default nextConfig;
