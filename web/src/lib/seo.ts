import type { Metadata } from "next";

type LocaleMetadataInput = {
  locale: string;
  locales: readonly string[];
  title: string;
  description: string;
  siteUrl: string;
};

export const APP_NAME = "Peeplet: Daily Puzzles";

export function buildLocaleMetadata({
  locale,
  locales,
  title,
  description,
  siteUrl,
}: LocaleMetadataInput): Metadata {
  const canonical = `/${locale}`;
  const image = { url: "/og.png", width: 1200, height: 630, alt: APP_NAME, type: "image/png" };

  return {
    metadataBase: new URL(siteUrl),
    title,
    description,
    alternates: {
      canonical,
      languages: {
        ...Object.fromEntries(locales.map((value) => [value, `/${value}`])),
        "x-default": "/",
      },
    },
    openGraph: {
      type: "website",
      url: canonical,
      siteName: APP_NAME,
      title,
      description,
      locale: locale.replace("-", "_"),
      images: [image],
    },
    twitter: { card: "summary_large_image", title, description, images: [image] },
    icons: { icon: "/icon.png", apple: "/apple-icon.png" },
    robots: { index: true, follow: true },
    other: {
      "ahrefs-site-verification": "3da426c0ee2cdd80a18bde6f5ec444bb3c9953427128da3860bbc1d3b530fe05",
    },
  };
}

// The structured data of the home page: the app, and its games as a list.
export function appJsonLd(input: {
  locale: string;
  description: string;
  siteUrl: string;
  games: { name: string; description: string }[];
}) {
  return {
    "@context": "https://schema.org",
    "@type": "MobileApplication",
    name: APP_NAME,
    url: `${input.siteUrl}/${input.locale}`,
    description: input.description,
    inLanguage: input.locale,
    applicationCategory: "GameApplication",
    operatingSystem: "iOS, Android",
    image: `${input.siteUrl}/og.png`,
    offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
    hasPart: {
      "@type": "ItemList",
      numberOfItems: input.games.length,
      itemListElement: input.games.map((game, index) => ({
        "@type": "ListItem",
        position: index + 1,
        name: game.name,
        description: game.description,
      })),
    },
  };
}
