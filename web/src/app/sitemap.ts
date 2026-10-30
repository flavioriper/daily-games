import type { MetadataRoute } from "next";
import { routing } from "@i18n/routing";
import { SITE_URL } from "@/lib/siteUrl";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  return routing.locales.map((locale) => ({
    url: `${SITE_URL}/${locale}`,
    changeFrequency: "weekly",
    alternates: {
      languages: Object.fromEntries(routing.locales.map((value) => [value, `${SITE_URL}/${value}`])),
    },
  }));
}
