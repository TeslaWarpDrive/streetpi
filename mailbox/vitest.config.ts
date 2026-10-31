import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: {
        bindings: {
          WRITE_TOKEN: "fixture-not-a-real-write-token",
          READ_TOKEN: "fixture-not-a-real-read-token",
        },
      },
    }),
  ],
});
