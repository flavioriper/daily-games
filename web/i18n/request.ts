// i18n/request.ts: server-side message loading.
import { getRequestConfig } from "next-intl/server";
import { hasLocale } from "next-intl";
import { routing } from "./routing";

export default getRequestConfig(async ({ requestLocale }) => {
  const requested = await requestLocale;
  const locale = hasLocale(routing.locales, requested) ? requested : routing.defaultLocale;
  const site = (await import(`../messages/${locale}/site.json`)).default;
  return { locale, messages: { site } };
});
