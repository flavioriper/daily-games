// page.tsx: the bare root. A static export has no middleware to negotiate the
// locale, so the root picks one in the browser and points crawlers at /en.
import { routing } from "@i18n/routing";
import { SITE_URL } from "@/lib/siteUrl";

const PICK = `(function(){var l=(navigator.language||"en").toLowerCase();location.replace(l.indexOf("pt")===0?"/pt-BR":l.indexOf("es")===0?"/es":"/en")})()`;

export default function Root() {
  return (
    <html lang="en">
      <head>
        <title>Peeplet: Daily Puzzles</title>
        <link rel="canonical" href={`${SITE_URL}/en`} />
        {routing.locales.map((locale) => (
          <link key={locale} rel="alternate" hrefLang={locale} href={`${SITE_URL}/${locale}`} />
        ))}
        <noscript>
          <meta httpEquiv="refresh" content="0; url=/en" />
        </noscript>
        <script dangerouslySetInnerHTML={{ __html: PICK }} />
      </head>
      <body>
        <a href="/en">Peeplet: Daily Puzzles</a>
      </body>
    </html>
  );
}
