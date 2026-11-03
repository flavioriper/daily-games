import { PHASE_DEVELOPMENT_SERVER } from "next/constants.js";
import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin("./i18n/request.ts");

// Static export: Firebase Hosting serves it next to /f, the privacy policy and
// app-ads.txt (scripts/assemble.mjs).
// Files named *.dev.tsx / *.dev.ts are pages and routes only `next dev` sees:
// the admin page (src/app/admin) reads the game straight from the repo, and
// no build, Vercel or Firebase, ever carries it.
const DEV_ONLY = ["dev.tsx", "dev.ts"];
const BASE = ["tsx", "ts", "jsx", "js"];

// `next dev` runs as a plain server so /admin can read the repo on each load.
export default (phase) => withNextIntl({
  output: phase === PHASE_DEVELOPMENT_SERVER ? undefined : "export",
  pageExtensions: phase === PHASE_DEVELOPMENT_SERVER ? [...DEV_ONLY, ...BASE] : BASE,
  images: { unoptimized: true },
  reactStrictMode: true,
});
