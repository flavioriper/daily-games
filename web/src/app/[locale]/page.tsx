import Image from "next/image";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { routing } from "@i18n/routing";
import { GameList } from "@/components/GameList";
import { StoreButtons } from "@/components/StoreButtons";
import { GAMES, langOf, type Group } from "@/lib/games";
import { appJsonLd } from "@/lib/seo";
import { CONTACT, SITE_URL } from "@/lib/siteUrl";

const GROUPS: Group[] = ["puzzles", "arcade", "versus"];
const LOCALE_NAMES: Record<string, string> = { en: "English", "pt-BR": "Português", es: "Español" };

export default async function Page({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations({ locale, namespace: "site" });
  const lang = langOf(locale);
  const jsonLd = appJsonLd({
    locale,
    description: t("metaDescription"),
    siteUrl: SITE_URL,
    games: GAMES.map((game) => ({ name: game.title, description: game.text[lang] })),
  });

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd).replace(/</g, "\\u003c") }}
      />
      <header className="bar">
        <a className="mark" href={`/${locale}`}>Peeplet</a>
        <nav aria-label={t("navLabel")}>
          {GROUPS.map((group) => (
            <a key={group} href={`#${group}`}>{t(`${group}Title`)}</a>
          ))}
        </nav>
      </header>

      <main>
        <section className="hero">
          <div>
            <p className="eyebrow">{t("eyebrow")}</p>
            <h1>{t("headlineOne")}<br /><em>{t("headlineTwo")}</em></h1>
            <p className="lede">{t("lede", { count: GAMES.length })}</p>
            <StoreButtons />
          </div>
          <figure>
            <Image src="/games/hero.webp" alt={t("heroAlt")} width={1000} height={1000} priority />
            <figcaption><span>Jewel Box</span><span>{t("heroCaption")}</span></figcaption>
          </figure>
        </section>

        {GROUPS.map((group) => (
          <GameList
            key={group}
            id={group}
            title={t(`${group}Title`)}
            intro={t(`${group}Intro`)}
            games={GAMES.filter((game) => game.group === group)}
            lang={lang}
            shotOf={(name) => t("shotAlt", { name })}
          />
        ))}

        <section className="close">
          <h2>{t("closeTitle")}</h2>
          <StoreButtons />
        </section>
      </main>

      <footer>
        <p>{t("madeBy")}</p>
        <p>
          <a href={t("privacyHref")}>{t("privacy")}</a>
          <a href={`mailto:${CONTACT}`}>{CONTACT}</a>
        </p>
        <p>
          {routing.locales.map((value) => (
            <a key={value} href={`/${value}`} hrefLang={value} lang={value}>{LOCALE_NAMES[value]}</a>
          ))}
        </p>
      </footer>
    </>
  );
}
