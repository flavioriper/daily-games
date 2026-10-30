import type { Metadata } from "next";
import { Fraunces, Nunito } from "next/font/google";
import Script from "next/script";
import { Analytics } from "@vercel/analytics/next";
import { SpeedInsights } from "@vercel/speed-insights/next";
import { notFound } from "next/navigation";
import { hasLocale } from "next-intl";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { routing } from "@i18n/routing";
import { SITE_URL } from "@/lib/siteUrl";
import { buildLocaleMetadata } from "@/lib/seo";

// Fraunces with its SOFT axis for the rounded, warmer cut; Nunito is the
// game's own body font (assets/fonts).
const serif = Fraunces({ subsets: ["latin", "latin-ext"], axes: ["opsz", "SOFT"], variable: "--font-serif" });
const sans = Nunito({ subsets: ["latin", "latin-ext"], variable: "--font-sans" });

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export async function generateMetadata(
  { params }: { params: Promise<{ locale: string }> },
): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "site" });
  return buildLocaleMetadata({
    locale,
    locales: routing.locales,
    title: t("metaTitle"),
    description: t("metaDescription"),
    siteUrl: SITE_URL,
  });
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!hasLocale(routing.locales, locale)) notFound();
  setRequestLocale(locale);

  return (
    <html lang={locale} className={`${serif.variable} ${sans.variable}`}>
      <body>
        {children}
        <Analytics />
        <SpeedInsights />
        {/* Ahrefs Web Analytics, the Peeplet project's key (public). */}
        <Script
          src="https://analytics.ahrefs.com/analytics.js"
          data-key="srxBBpGZIjhWpY7rFrasJg"
          strategy="lazyOnload"
        />
      </body>
    </html>
  );
}
