import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactCompiler: true,

  // Authenticated application routes are first-class web surfaces. Keep the
  // public landing page at `/` independent from this product workspace.
};

export default nextConfig;
