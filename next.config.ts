import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  agentRules: false,
  allowedDevOrigins: ["127.0.0.1"],
  experimental: {
    // The product accepts 5 MB source images; multipart overhead requires a
    // slightly larger transport ceiling before the 5 MB decoder check runs.
    serverActions: { bodySizeLimit: "6mb" },
  },
  poweredByHeader: false,
};

export default nextConfig;
