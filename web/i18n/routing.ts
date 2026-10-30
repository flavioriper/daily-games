// i18n/routing.ts: single source of truth for locales + prefix strategy. The
// three the game itself speaks.
import { defineRouting } from "next-intl/routing";

export const routing = defineRouting({
  locales: ["en", "pt-BR", "es"],
  defaultLocale: "en",
  localePrefix: "always",
  alternateLinks: false,
});

export type Locale = (typeof routing.locales)[number];
