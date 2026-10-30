import Image from "next/image";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { routing } from "@i18n/routing";
import { GameList } from "@/components/GameList";
import { StoreButtons } from "@/components/StoreButtons";
import { GAMES, HERO_PHONES, langOf, type Group } from "@/lib/games";
import { appJsonLd } from "@/lib/seo";
import { CONTACT, SITE_URL } from "@/lib/siteUrl";

const GROUPS: Group[] = ["puzzles", "arcade", "versus"];
const LOCALE_NAMES: Record<string, string> = { en: "English", "pt-BR": "Português", es: "Español" };

// The three reasons, each with a small line drawing: a sun, four steps, two
// rings.
const PILLARS = [
  {
    key: "Morning",
    tone: "butter",
    glyph: (
      <svg viewBox="0 0 32 32" aria-hidden="true">
        <circle cx="16" cy="18" r="6.5" />
        <path d="M16 4v4M6 9l2.8 2.8M26 9l-2.8 2.8M3 22h4M25 22h4" />
        <path d="M2 28h28" />
      </svg>
    ),
  },
  {
    key: "Levels",
    tone: "sage",
    glyph: (
      <svg viewBox="0 0 32 32" aria-hidden="true">
        <path d="M3 27h7v-6h7v-6h7V9h5" />
        <path d="M3 27h26" />
      </svg>
    ),
  },
  {
    key: "Together",
    tone: "sky",
    glyph: (
      <svg viewBox="0 0 32 32" aria-hidden="true">
        <circle cx="12" cy="16" r="7.5" />
        <circle cx="21" cy="16" r="7.5" />
      </svg>
    ),
  },
] as const;

export default async function Page({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations({ locale, namespace: "site" });
  const lang = langOf(locale);
  const titleOf = Object.fromEntries(GAMES.map((game) => [game.id, game.title]));
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
          <a className="pill" href="#get">{t("navGet")}</a>
        </nav>
      </header>

      <main>
        <section className="hero">
          <div className="hero-copy">
            <p className="eyebrow"><i aria-hidden="true" />{t("eyebrow")}</p>
            <h1>{t("headlineOne")}<br /><em>{t("headlineTwo")}</em></h1>
            <p className="lede">{t("lede", { count: GAMES.length })}</p>
            <StoreButtons />
            <ul className="facts">
              <li>{t("factGames", { count: GAMES.length })}</li>
              <li>{t("factLevels")}</li>
              <li>{t("factFree")}</li>
            </ul>
          </div>
          <div className="fan" aria-hidden="false">
            {HERO_PHONES.map((id, index) => (
              <figure key={id} className="phone" style={{ "--i": index } as React.CSSProperties}>
                <Image
                  src={`/phones/${id}.webp`}
                  alt={t("phoneAlt", { name: titleOf[id] })}
                  width={405}
                  height={720}
                  priority
                />
              </figure>
            ))}
          </div>
        </section>

        <section className="pillars" aria-label={t("navLabel")}>
          {PILLARS.map((pillar) => (
            <article key={pillar.key} className={`pillar ${pillar.tone}`}>
              <span className="glyph">{pillar.glyph}</span>
              <h2>{t(`pillar${pillar.key}Title`)}</h2>
              <p>{t(`pillar${pillar.key}Text`)}</p>
            </article>
          ))}
        </section>

        {GROUPS.map((group) => {
          const games = GAMES.filter((game) => game.group === group);
          return (
            <GameList
              key={group}
              id={group}
              title={t(`${group}Title`)}
              intro={t(`${group}Intro`)}
              count={t("countChip", { count: games.length })}
              games={games}
              lang={lang}
              shotOf={(name) => t("shotAlt", { name })}
            />
          );
        })}

        <section className="close" id="get">
          <div className="close-card">
            <h2>{t("closeTitle")}</h2>
            <p>{t("closeText")}</p>
            <StoreButtons />
          </div>
        </section>
      </main>

      <footer>
        <p>{t("madeBy")}</p>
        <p>
          <a href={t("privacyHref")}>{t("privacy")}</a>
          <a href={`mailto:${CONTACT}`}>{CONTACT}</a>
        </p>
        <p className="langs">
          {routing.locales.map((value) => (
            <a
              key={value}
              href={`/${value}`}
              hrefLang={value}
              lang={value}
              aria-current={value === locale ? "page" : undefined}
            >
              {LOCALE_NAMES[value]}
            </a>
          ))}
        </p>
      </footer>
    </>
  );
}
