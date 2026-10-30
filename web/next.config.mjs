import createNextIntlPlugin from "next-intl/plugin";

const withNextIntl = createNextIntlPlugin("./i18n/request.ts");

// Static export: Firebase Hosting serves it next to /f, the privacy policy and
// app-ads.txt (scripts/assemble.mjs).
export default withNextIntl({
  output: "export",
  images: { unoptimized: true },
  reactStrictMode: true,
});
