# The website (web/)

The landing page, 2026-10-30: a Next.js app in `web/` built on the structure of
the old peeplet repo's site (`[locale]` routes, next-intl, `seo.ts`, sitemap,
robots), exported static.

**The look, second pass the same day** (the user: "way more elegant,
something targeting both kids and adults, keeping the cozy vibes, but
modern"). The first pass was an editorial page: thin rules, one picture, an
almanac list, Inter. Now the game's own screens do the colouring and the
chrome stays quiet:

- **The fan of phones** is the hero: five whole screens (`HERO_PHONES` in
  `src/lib/games.ts`, cut by the generator to `public/phones/`), leaning on
  each other, the middle one upright and in front. They are chosen for
  colour and for showing no Peeplet (below). Swap the list, rerun the
  generator.
- **Every game is a tile on a plate** tinted from its own screen: the
  generator averages the screen's vivid pixels and lays that thin over paper
  (`tint` in `games.json`). A grid on a desk, a shelf that scrolls sideways
  on a phone, so seventy games stay a short page.
- **Type**: Fraunces with its `SOFT` axis at 100 (rounded serif, the adult
  side) and Nunito, the game's own body font. The headline is sized to its
  column per language (`cqi`, `html[lang]` rules in `globals.css`): the
  Portuguese "Quebra-cabeças" would otherwise break at its hyphen, so the
  message carries a word joiner after it.
- **One radius family** (28 / 20 / 12 / pill), one accent (terracotta),
  three pale plates (butter, sage, sky) for the three reasons, a paper grain
  at 28%. No emoji, no confetti, no mascots.
- Reduced motion disables the fan's settle and every hover lift.

- **Data comes from the game.** `web/scripts/gen_games.py` writes
  `src/data/games.json` (with each tile's `tint`) from `ui/registry.gd`, the
  Arcade and Versus tabs and `locale/*.csv`, `public/games/*.webp` and the
  hero's `public/phones/*.webp` from `build/site_shots`, which
  `tests/_shot_site.gd` shoots. Run both after a new game or a new look.
  `public/og.png` is a 1440-wide Chrome shot of the English hero resized to
  1200 x 630.
- **Hosting.** `bun run build` assembles the export and `server/site` (the
  friend link's page, privacy, `.well-known`, app-ads.txt) into
  `server/public_site`, which `server/firebase.json` now serves.
  `tools/deploy_site.sh` builds and deploys and is run by a person. Before
  deploying by hand, build first: the folder is ignored by git.
- **The Peeplets on the page** (the user, 2026-10-30: "i'm missing some
  peeplets around the page", then "more natural on the page, like above
  elements, sitting somewhere, hiding"): eight renders of the live model by
  `tests/_shot_site_peeplets.gd` (windowed, `--resolution 1600x800`), each
  saved from its own transparent SubViewport to `build/site_peeplets/`;
  `gen_games.py` un-premultiplies, trims and writes `public/peeplets/*.webp`.
  Never hand-drawn, never hand-edited: this is the web's one exception to
  the no-baked-Peeplet rule, like the painter's sheet. `src/components/Peeplet.tsx`
  places one by class: perched on the middle phone (`reader`), watching from
  the floor half behind the left phone (`watcher`), hiding behind the right
  phone (`coral`, mirrored), peeking over a card's top edge from behind
  (`sunhat`, `party`; class `behind` = z-index -1, so the parent sets no
  z-index of its own), standing on a card (`mushroom`), sitting on the
  Puzzles shelf's rule (`flowers`), bouncing on the closing card's top edge
  (`laugh`), peeking from behind its left edge (`coral` again). Re-render
  after any change to the Peeplet's look.
- **Store links** live in `web/src/lib/siteUrl.ts` and the message files. Android
  links to the live Play listing; the iPhone link is TestFlight until the App
  Store page exists.
- `NEXT_PUBLIC_SITE_URL` sets the origin for canonical links and the sitemap
  once the site has its own domain.
- **Vercel**: `web/vercel.json` builds with plain `next build`, because the
  assemble step reaches outside `web/`. The site there has no `/f` or privacy
  page, so the footer's privacy link is absolute, to the Firebase page.
- **Live** on Vercel since 2026-10-30: project `peeplet-landing`, team hypertradeworx, https://peeplet-landing.vercel.app. Linked to the GitHub repo (the user, 2026-10-30: "it should have a link to git main"): every push to `main` builds and deploys production, so the site ships with the game. The project's Root Directory must be `web`; the first Git build failed while it was `.` (no `next` at the repo root). `NEXT_PUBLIC_SITE_URL` is set there; change it when a domain arrives.
- **Vercel Web Analytics and Speed Insights** (the user, 2026-10-30): `<Analytics />` and `<SpeedInsights />` in `src/app/[locale]/layout.tsx`, both already enabled in the project's dashboard (Hobby). They load same-origin scripts from `/_vercel/insights` and `/_vercel/speed-insights`, which exist only on Vercel, so the same export on Firebase Hosting 404s those two requests and counts nothing. `/_vercel/insights/script.js` still 404'd on the live site before the first deploy carrying this change.
