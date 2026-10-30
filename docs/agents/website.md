# The website (web/)

The landing page, 2026-10-30: a Next.js app in `web/` built on the structure of
the old peeplet repo's site (`[locale]` routes, next-intl, `seo.ts`, sitemap,
robots), exported static. Warm paper, a serif, thin rules: the user asked for
elegance rather than the game's cards, and picked the almanac list on no
stated preference, so that list is the builder's call.

- **Data comes from the game.** `web/scripts/gen_games.py` writes
  `src/data/games.json` from `ui/registry.gd`, the Arcade and Versus tabs and
  `locale/*.csv`, and `public/games/*.webp` from `build/site_shots`, which
  `tests/_shot_site.gd` shoots. Run both after a new game or a new look.
  `hero.webp` and `public/og.png` are cut by hand.
- **Hosting.** `bun run build` assembles the export and `server/site` (the
  friend link's page, privacy, `.well-known`, app-ads.txt) into
  `server/public_site`, which `server/firebase.json` now serves.
  `tools/deploy_site.sh` builds and deploys and is run by a person. Before
  deploying by hand, build first: the folder is ignored by git.
- **The Peeplet is not on the page**: the rule against baking one to an image
  has no web exception yet, so that is the user's call.
- **Store links** live in `web/src/lib/siteUrl.ts` and the message files. Android
  links to the live Play listing; the iPhone link is TestFlight until the App
  Store page exists.
- `NEXT_PUBLIC_SITE_URL` sets the origin for canonical links and the sitemap
  once the site has its own domain.
- **Vercel**: `web/vercel.json` builds with plain `next build`, because the
  assemble step reaches outside `web/`. The site there has no `/f` or privacy
  page, so the footer's privacy link is absolute, to the Firebase page.
- **Live** on Vercel since 2026-10-30: project `peeplet-landing`, team hypertradeworx, https://peeplet-landing.vercel.app. Deployed by CLI from `web/` (`vercel deploy --prod`), no Git connection. `NEXT_PUBLIC_SITE_URL` is set there; change it when a domain arrives.
