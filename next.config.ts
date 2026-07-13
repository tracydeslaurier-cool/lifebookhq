import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // The dev-tools badge defaults to bottom-left, where it sits on top of the
  // wordmark. Development chrome must never obscure LifeBook's name — move it
  // to the opposite corner. (Production renders no badge at all.)
  devIndicators: {
    position: "bottom-right",
  },
};

export default nextConfig;
