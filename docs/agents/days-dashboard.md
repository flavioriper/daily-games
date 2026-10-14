# The day documents and the quality dashboard

2026-10-13, the user: "we need some simple dashboard (but elegant) where I
can easily see games data, solution, so I can measure quality of daily
challenges one by one". The spec is
`docs/superpowers/specs/2026-10-13-day-documents-dashboard-design.md`.

    godot --headless --path . --script res://tools/export_days.gd -- from=2026-10-13 days=30 [boards=a,b] [levels=0,1]
    python3 tools/build_dashboard.py --open

The first deals every board's day as the host does (`seed_for(seed_as or
id, level, date)`, the board's own `start`) and writes what the board's
`day_dict()` says into `tools/days/<board>.json`; thirty days of the
thirty-three boards are 3,960 documents and about four minutes. The second
inlines them into `tools/dashboard.html`. Both outputs are git-ignored, and
`tools/*` is left out of the APK. `#board=sudoku&level=2&date=20261020` on
the page's address opens that day.

**A new board writes `day_dict()`** (`core/puzzle_base.gd` has the empty
one and the shape): what `build` dealt, its answer, the figures it already
knows, and a `view` when it is a grid (the spec has the cell format). It
only reads; nothing in the game calls it. Twenty-four boards are grids;
Untangle, Hidden Word, Drumbeat, Trestle, Mini Golf, How Big?, Golden
Acorn, Pearl Dive, Gumdrop and Marigold are text.

**`InsaneBank.day_override`** is the one thing the exporter sets in the
game's code: a banked level picks by the clock's UTC day, not by the seed,
so another day's pick needs the day handed in. -1 in the game.

What the first export showed (thirty days from 2026-10-13, per level):

- Repeats inside the month: Drumbeat 27 of 30 on every level (three
  songs), Trestle 18/14/15/7, Pixel Garden 12 on Hard and on Insane, Gumdrop
  11 on Easy and 5 on Medium, Button Box 7 and 2, Horse Pen 3/3/4, Lattice
  2/3, Hidden Word 3/1, Knight 1, Slider 1.
- Marigold keeps no answer on Easy to Hard (the hint searches live), so
  its solution side is empty there.
- Toy Cannons' solved rug is bare: its answer is the line of cannons, as
  text.
- Golden Acorn and Pearl Dive export the server's day only for a date this
  Mac has cached (`user://backend_cache`); every other date is the bank's.
- The word and quiz boards are exported in English.

The clock audit, read off every generator: only Sudoku's live dig stops on
a wall clock (`sudoku_gen.gd:186-200`, 300 ms; Easy and Medium, and Hard
and Insane only when their bank has nothing), so only there can a slow
phone deal another grid than a fast one. Every other budget is a count of
attempts or nodes. What else moves a day between players: the app's
version (a changed generator, or a bank that grew: Horse Pen, Lattice,
Pixel Garden and the Insane banks pick by pool size), the language (the
word boards), the network (Golden Acorn, Pearl Dive), and, unmeasured, the
last bit of a float on another CPU (Paper Planes' `pow`, Marigold's
garden).

**The Gallery** (the user, the same day, of Pixel Garden, Gumdrop and
Button Box: "can you add on the dashboard the pictures somewhere? like a
gallery tab"): the exporter also writes `tools/days/gallery.json`, every
picture those boards and Toy Cannons deal from -- the bead bank's four
bands, Button Box's own Hard band, Gumdrop's twenty-nine moulds -- in the
game's colours (`Palette.PG_BEADS`, `Sim.FLAVOURS`), and the page's Picture
gallery shows them a set at a time. A set's chips are the boards and levels
that read it; under a picture, the exported days that board and level dealt
it (a click opens the day) and a faded card for one that never came up.
No picture is made on the day: the bead pictures are typed (10 and 12
square, 16 for Button Box's Hard) or painted by
`tools/paint_pixel_garden.py` (24 and 32), Gumdrop's are code in
`gumdrop_mould.gd`. Pixel Garden walks one shuffle of a band a day; Button
Box, Toy Cannons and Gumdrop draw by the day's seed with no memory, which
is where their repeats come from.

Not built: the db and the game reading a stored day (the user, the same
day: "we can keep the seed if it works to render the exactly same board"),
drawings for the text boards, any new solver or difficulty estimate.
Checked: the suite 249565/0, every touched script `--check-only`, two
exports of the thirty days identical but for `gen_ms`, twelve boards looked
at in headless Chrome. Not checked: the page in Safari or Firefox, the
light theme, a phone-width window.

## The picture maker (2026-10-13)

The user: "given any image, I want us to be able to convert it to a pixel
image, and map it to fit into the picture games. Do it somewhere on the
dashboard for now so we can test". A try-out, all of it in
`tools/dashboard.src.html` (`#view=convert`): nothing writes the bank, and no
game code was touched.

- An image is dropped, chosen or pasted, and read in the browser. A size is
  picked: 10, 12, 24, 32 (the bead bank's bands) or 16 (Button Box's Hard).
- **Frame**: the subject alone with bare squares round it (the default where
  the band's pictures are cut-outs), a square cropped from it, or the whole
  image. **Background**: what joins the border in the border's colour is left
  bare, or that colour anywhere, or only what is transparent.
- A square takes the mean of what it covers and then the nearest of the
  nineteen beads in OKLab; the band's colour count is kept by dropping, one
  at a time, the bead whose loss costs least. No dithering. `Vivid` scales
  chroma before the match, for photos that come out tan and grey.
- A picked bead paints squares by hand; moving a control starts over.
- The checks are a port of `tools/check_pixel_garden.py`'s `check()`, which
  stays the judge. Button Box's Hard has no written rule, so a 16 is held
  beside the ranges of the thirty it has, and the page says so.
- The foot is the bank entry as text. Pasting one in also wants its
  `PG_PIC_*` row in the locale files.
- Gumdrop's jellies are polygons built from named parts
  (`gumdrop_mould.gd`); an image cannot become one here.

Checked in headless Chrome, dark theme: two emoji drawings and two photos
converted at 10, 12, 16, 24 and 32; four of them appended to a scratch copy
of the bank pass `check_pixel_garden.py --bank`, and a fifth fails it for the
reason the page gave. Not driven: the file chooser, drop, paste and the
painting (the test fed images to `convLoad` directly).

## The daily theme, stage 1 (2026-10-13)

Spec: `docs/superpowers/specs/2026-10-13-daily-theme-design.md`. Stage 1 is
the theme, the pictures and their supervisor made on this Mac and shown in
the dashboard; nothing is published, no game code reads any of it, and
`publishDay` does not know about it yet (stage 4).

- **`tools/beads.js`** is the converter and the bank's rules, taken out of
  the page: pure functions on RGBA bytes. `build_dashboard.py` inlines it
  where `/*BEADS*/` stands; `npm run build` copies it to
  `server/functions/lib/beads.js`, typed by `src/beads.d.ts`. One file, so
  the Picture maker tries what the night runs. It shrinks the image itself
  (a box mean to 240 a side), so the page and the server see the same bytes.
- **`generate.ts`**: `draw(prompt)` asks an image model (`DAILY_IMAGE_MODEL`,
  default `google/gemini-3.1-flash-lite-image`) and reads
  `message.images[0].image_url.url`; `ask()` takes `images`; `cost()` sums
  OpenRouter's `usage.cost`. `jpeg-js` and `pngjs` are new dependencies.
- **`theme.ts`**: `makeTheme(day, recent)`; a second model turns down a
  theme that does not belong in the game and names words to leave out. A
  wrong word no longer costs the day its theme (it did, the first run).
- **`pictures.ts`**: `makeDay(day, theme, keep?)`. Three things at 10, 12
  and 16, the scene at 24 and 32; three drawings of each at the most. A
  thing is laid with a bare square round it, then edge to edge if the rules
  want it bigger. The blind look: a thing is picked out of the day's three
  and a decoy; a scene is described and a second question asks whether that
  is the scene.
- **`tools/themed_days.sh [yyyymmdd] [days]`** runs `cli.js themed` into
  `tools/days/themed/` (git-ignored) and rebuilds the page. A day already
  made is kept: delete its files to make it again.
- **The page's Themed days** (`#view=themed`): a day's theme, the five
  sizes (a dashed one is the bank's), and under a fold every drawing with
  what the rules and the look said.

**The first four days** (14 to 17 Oct 2026, after three fixes to the
prompts): 17 of 20 pictures kept; US$0.14 to 0.24 and 70 to 90 seconds a
day. The drawings are in the style asked for every time. What was seen:

- Things at 10 to 16 mostly read (apple, cupcake, crab, lantern, teapot);
  some do not (a spiral shell, a loaf, and a mug that is a red box).
- **The look for a thing is weak**: one of four names is easy, and it kept
  the red-box mug on its third drawing. It did turn down a starfish three
  times (seen as a crab), rightly.
- **Scenes are the soft spot.** At 24 and 32 they keep the rules but are
  muddy; one of four days lost both (a dusk porch: one colour 60% of it,
  then seen as a shore). The scene judge was too strict at first (a teapot
  taken for a duck cost a good picture) and was told so.
- A theme's things repeated two days apart (a teapot); the writer is now
  told the recent days' things as well as their names. Not run since.

Not done: stages 2 to 4. Not checked: a run long enough to say how the
style and the themes hold over weeks; the light theme.

## The daily theme, stage 2 (2026-10-13)

The user: "do stage 2". Pixel Garden, Button Box and Toy Cannons deal the
day's themed picture when this phone holds it.

- **`core/themed_pictures.gd`** (`ThemedPictures.picture(date_key, size)`)
  reads `Backend.cached_day("pictures", key)` and answers the picture in
  the bank's shape, or `{}`: no key (a board not a daily), an unstarted
  backend (the suite, every harness, `export_days.gd`), no document, or a
  picture that fails `valid()` -- the rules of `tools/beads.js` a third
  time, in GDScript. It never waits: `world/main.gd` asks for the day
  behind the menu at boot, beside Golden Acorn's.
- **The host sets `daily_key` before `start()` now** (`puzzle_host._spawn`
  through `_daily_key()`, which the flat host answers), as well as after:
  these boards deal inside `build()`. Golden Acorn and Pearl Dive still
  defer their deal and are not changed by it.
- **Each board's `State.setup` takes the key** and asks for its band's
  size (the side of the band's first bank picture: 10/12/24/32 for Pixel
  Garden, 10/12/16/32 for Button Box, 10/24/32/32 for Toy Cannons). New
  (`bank_step` > 0) is always the bank's.
- **The name**: the document carries each picture's name in en, pt and es
  (the thing's; the theme's for the scene). The board is handed the one in
  the player's language as its `name`, and `tr()` gives back a string it
  has no row for, so no board's naming code changed.
- **Button Box turns a picture down for itself**: its scramble trades whole
  colours, so a picture over half one colour opens part sewn, and past a
  quarter sewn it deals the bank's. The first made days lost Easy and
  Medium to this (a red apple, a blue teapot, a red mug). So
  `tools/beads.js` has a rule that is Button Box's and not the bank's
  (`lead`: the biggest colour under 60% of a small picture's beads), and
  the theme and drawing prompts ask for things not mostly one colour.
- **Toy Cannons' Hard and Insane read one band**, so on a themed day they
  are the same picture (in the bank they are two draws of one band).
- **Known and left**: a daily finished from the bank before the day's
  document arrived, and reopened after, shows the themed picture on its
  finished screen. Only a phone that was offline at boot can meet it.
- **`tools/themed_play.sh <yyyymmdd>|off`** copies a made day into this
  Mac's game as today's pictures, to play it; nothing else writes there.

Checked headless with a throwaway probe over the four made days (a
stand-in backend node, the cache file written and removed): for each board
and level, the daily is the themed picture at the band's size and New and a
plain board are the bank's; a document with a bad row is refused; 55 to 61
checks a day, 0 failed after the Button Box rule. Suite 249565/0. Thirty
days re-exported: 3,960 documents, 0 errors. **Not run**: the game itself
with a themed day on screen (that is `themed_play.sh` and the user's eye),
and the fetch against the real server, where no `pictures` document exists
until stage 4.

## Drawing on Vertex AI, on a project's credits (2026-10-13)

The user has Google Cloud credits (a startup programme's, on the billing
account of `production-506015`, the `andressa.t@navlio.io` login) and asked
for the pictures to be drawn on them. What was found, in the order it cost:

- **The plain Gemini API does not spend Cloud credits**: a key for
  `generativelanguage.googleapis.com` listed the models and then answered
  402, "Your prepayment credits are depleted". AI Studio shows "R$ 0
  qualifying GCP credits" on every billing account looked at.
- **Vertex AI takes no bare API key** ("API keys are not supported by this
  API"), and a key bound to a service account is refused by that
  organisation's policy (`iam.managed.disableServiceAccountApiKeyCreation`).
- **Vertex AI with a login's own token works** and is billed to the project:
  `generate.ts`'s `draw()` asks Vertex when `VERTEX_PROJECT` is set
  (`VERTEX_ACCESS_TOKEN`, or the process's own Google identity through
  `google-auth-library`), and OpenRouter otherwise. `cost()` does not count
  a Vertex drawing: the answer carries no price.

      VERTEX_PROJECT=production-506015 VERTEX_ACCOUNT=andressa.t@navlio.io tools/themed_days.sh

Left in that project and used by nothing: the service account
`daily-pictures` with `roles/aiplatform.user`, an API key "Peeplet Daily
pictures (Gemini image)" (also in `~/.config/gemini/api_key`), and the
Gemini API enabled. **For the deployed function** (stage 4) the token has
to be its own: its service account granted `roles/aiplatform.user` on that
project, across projects. Not done.
