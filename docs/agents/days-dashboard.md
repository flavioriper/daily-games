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
  (`gumdrop_mould.gd`); an image cannot become one here. The themed days'
  are written as parts by the night instead (`server/functions/src/jelly.ts`,
  `node lib/cli.js jellies <day.json>...` for a day already made; drawn by
  `tests/_shot_gumdrop_bank.gd -- <out> themed`).

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

  The script names `gcloud auth print-access-token` as `VERTEX_TOKEN_COMMAND`,
  run for each drawing: handed one token at the start, a run of 2026-10-14
  was refused (401) twenty minutes in, gcloud's held token having expired.

Left in that project and used by nothing: the service account
`daily-pictures` with `roles/aiplatform.user`, an API key "Peeplet Daily
pictures (Gemini image)" (also in `~/.config/gemini/api_key`), and the
Gemini API enabled. **For the deployed function** (stage 4) the token has
to be its own: its service account granted `roles/aiplatform.user` on that
project, across projects. Not done.

## Pixel art, drawn as pixel art (2026-10-14)

The user, of the first way's pictures beside real pixel art (a kawaii ramen
bowl, bead kits): "i'm not happy about result ... isn't better and more
accurate to generate the images into pixel art already?" It is: pixel art
is drawn for its grid (a one-square outline, a face on whole squares), and
averaging a smooth drawing down loses exactly that. `DAILY_PICTURE_STYLE=pixel`
is the second way, beside the first, not over it:

- **Drawn as pixel art** on Vertex by `gemini-3-pro-image` (the only model
  of three that draws near the side it is asked; `gemini-2.5-flash-image`
  draws about three times finer than asked, and in two pitches at once:
  an outline in pairs of squares, a face in single ones). It is asked for a
  square image (`imageConfig.aspectRatio`; unasked it answers 1408 × 768).
- **Read at its own squares** by `Beads.snap` (tools/beads.js): the colour
  changes of each column and row, one pitch for both axes scored past
  chance, lines laid where the changes are with each square three quarters
  to five quarters of the pitch (the models' grids drift), each square the
  most common colour of its middle half. Of the best few pitches and the
  best one's multiples, the coarsest whose squares hold one colour about as
  well as any. `mixed` counts the squares that do not: over 5% of the
  drawing's and it is turned down, being either misread or drawn finer in
  places.
- **Kept only at its own size** by `Beads.fromSnap`: the background (the
  border's colour, joined to the border) bare, the drawing cut to what is
  drawn and centred in the band's square, never shrunk; a scene up to a
  quarter over is cut to its middle. A thing drawn too big is drawn again
  at the side that would have fitted (never under 0.6 of the band's: asked
  for 4, a model drew a literal 4 × 4 grid). **The image model holds no
  side** (the first made day: asked 6 to 8 squares for Easy, it drew 16,
  three times; a scene asked at 19 came back 67): a drawing seldom fits.
  Read smaller by each bead's most common colour, a 64-square scene at 24
  lost its basket and mug; that was tried and dropped.
- **Redrawn**: so the cleanest drawing of a size is shown to a text model
  that sees pictures (`DAILY_ROWS_MODEL`, Opus by default) and redrawn as
  rows of the band's side, keeping its layout. On the picnic scene at 24
  and 32 this was the best of every way tried: the basket, mug, sunflower
  and mushroom all in place, outlines one square wide.
- **Written**, things only: the same model draws the thing as rows from its
  words alone, every day, for the page to set beside the others. Opus's
  10 × 10 mushroom, 12 × 12 sunflower and 16 × 16 mug passed every rule at
  the first ask, US$0.02 to 0.04 each; GPT-6 Luna's were blobs, and Sonnet
  refused the mushroom (`content_filter`).
- The first route a size passes (rules, then the blind look) is kept:
  drawn, then redrawn, then written.
- **The same themes**: `tools/themed_days.sh` with the style set writes
  `tools/days/themed-pixel/` on the themes of `tools/days/themed/`, and
  Themed days shows the two ways one above the other. The Picture maker
  has "Read as: Pixel art", the same reader on any image.

The reader was tuned on eight drawings (`scratchpad`, not kept): four read
right, two turned down for `mixed`, two (flash) read at a finer pitch and
then turned down as too big. The rate: `gemini-3-pro-image` answers 429 to
a new project's second request in a minute; `draw()` waits 20, 40 and 80
seconds and asks again, so a drawing is one to four minutes, and the first
made day (three drawings a size) took 1,352 s. Two drawings a size now;
still too slow for the function's two days in 1,800 s unless the
project's quota for the model is raised.

**The first day made this way** (20261014, Garden Picnic, beside the first
way's): all five sizes kept, in 1,578 s and US$0.55 of OpenRouter (Opus)
plus ten drawings on Vertex's credits. Easy (mushroom) and Medium (mug)
were redrawn from Pro's drawings, Button Box's Hard (sunflower) written
from words (its two redraws were 71% filled, over the rule), and both
scenes redrawn; not one of Pro's drawings fitted its size as drawn. Next
to the first way's pictures every one has its outline and reads. The
project's image quota is 2 a minute a model, and an increase is refused
for now (`NOT_ENOUGH_USAGE_HISTORY`, a new project).


## One shaded thing a band, kept at its own squares (2026-10-14)

The user, of the pixel way's first day beside bead-art apps' pictures (a
croissant, a cat, a flower, 30 to 50 squares wide, one subject, two or
three tones a hue, bare board round it): "i still not happy about the
drawings ... this is what I wanted, something really amazing". Two drawings
asked that way (one shaded sprite on white, about 18 and 24 squares) came
back at 34 and 36 and read `mixed 0`: `gemini-3-pro-image` already draws
that quality. What lost it was after the drawing: the scene prompt and the
24/32 fill rule (85 to 100%) put four things and 600 beads of sky in 32
squares, the Opus redraw to the band's side flattened the outlines, and
the nineteen beads had no dark red, light red, light yellow, dark orange
or light grey, so a mushroom's maroon shadow read as brown and its grey
spots as sky. So, `feat/pixel-subjects`:

- **One thing a band**, five a theme (`theme.ts` THINGS; a theme written
  before, with three, lends its last to the bands past it). No scene.
- **Drawn shaded** (`PIXEL_OBJECT`: a one-pixel dark outline, each colour
  in two or three tones) and **kept at its own squares** by
  `Beads.cutOut`: the border's colour bare, the thing cut to what is drawn
  and centred in a square of its longer side plus one bare square each
  way, never under the band's side. A drawing over the band's range is
  asked for again, scaled by what came out (`FIRST_ASK` by band: 8, 9, 12,
  18, 24); no redraw. Bands up to 16 fall back to rows written from words.
- **A side range a band** (`Beads.RULES.side`, mirrored in
  `core/themed_pictures.gd`): 10 to 18, 12 to 22, 16 to 26, 24 to 34, 32
  to 40; colours 3 to 7 up to 8 to 14 (Easy and Medium the same seven, so a day is dealt again by side: `bySide`); fill 25 to 80% of the picture's own
  square; the largest colour under 60% of its beads (Button Box's rule);
  an edge bare. The day document is still keyed by the band's side and
  `v: 1`; an old phone's `valid()` turns a picture of another side down
  and the bank deals. Pixel Garden lays `rows.size()`, Button Box and Toy
  Cannons `w` and `h`: all three take any side.
- **Six shade beads**: maroon `a`, coral `h`, rust `q`, butter `j`, navy
  `v`, silver `x`, in `tools/beads.js`, `tools/check_pixel_garden.py`,
  `content/pixel_garden.json` and `core/palette.gd` (the four change
  together; Pixel Garden's chips stand in `PG_BEADS`' order, so each sits
  by its hue). The bank passes unchanged.
- The first way (`DAILY_PICTURE_STYLE` unset) is judged by the same rules
  now, so its 24 and 32 scenes fail fill: it is in effect Easy to Hard
  only. The Themed days page labels each picture by its own side.

Read with the new reader, the morning's two drawings: the mushroom 26 × 28
in a 30 square, 11 beads, 61% filled; the sunflower 16 × 31 in a 33 square,
11 beads, 35%; both passing every rule. The dashboard's own renderer puts
a highlight on each bead and the game a hole: Button Box looks dimmer than
the sheet, and the bead face is a separate call. Easy and Medium cannot
look like the references at 10 to 18 squares; the image model draws no
sprite under about 17.

The time: up to three drawings a band and five bands, one to four minutes
each at the project's two-a-minute quota, is 15 to 60 minutes a day, over
the function's 1,800 s for two days. The deployed function runs the first
way until `DAILY_PICTURE_STYLE=pixel` is set on it and its quota raised;
`tools/themed_days.sh` makes pixel days on this Mac meanwhile.

### Button Box's ladder: Hard is the 32, Insane a 48 (2026-10-14)

The user, on the first pixel day in the game: "hard and insane is way too
easy, insane should be a really big and detailed image, and hard should be
what is current insane". So Button Box's Hard deals the bank's 32 band and
asks the day for the 32 picture, and its Insane asks for a sixth band, key
48 (`Beads.RULES[48]`, side 44 to 64 (the first tray drawn came at 38 wide and was let in at 40; the floor is up so a drawing that size is asked for again bigger), colours 10 to 16), drawn with
"detailed, with texture and small features" in place of "big simple
shapes" (`DETAIL_FROM` 32) and asked for at 40 first. The gate before the
wiring: asked 36, the model drew a picnic basket at 32 × 32; asked 40, a
stone cottage at 64 × 61, both read clean. A drawing under the band's
range is now asked for again, scaled up, while a drawing is still to come
(the pad to the band's side is for the last one only). The 16 band is
nobody's now (only Button Box's Hard took it) and is gone from
`Beads.SIZES` and both rules tables; `content/buttons_hard.json` stays for
the dashboard's export but no board reads it. With no day held, Button
Box's Hard and Insane deal the same bank. Pixel Garden and Toy Cannons keep
24 and 32. A theme names six things (`THINGS`). The first day made so:
20261019.

## The daily theme, stage 3: the word boards and the quizzes (2026-10-14)

Gumdrop was stage 3's first (its jellies, above and in
`docs/agents/boards/gumdrop.md`); this is the rest, on local main, not
deployed (stage 4, `publishDay`, is the user's).

- **`server/functions/src/words.ts`** (`makeWords(theme)`): a language a
  request, Haiku shown the theme and the two boards' own lists (copied into
  `src/word_lists/` by `npm run build`, git-ignored, like the quiz banks)
  and asked for up to four of Hidden Word's answers and up to three Word
  Trail words a length that belong to the theme. A word is kept only if
  the list holds it exactly as spelt (accents and all); the theme's own
  eight words the lists hold are added after the model's. Rides in the
  pictures document as `words: {hiddenword: {en, pt, es}, wordtrail: {en:
  {"3": [...], ...}, ...}}`, `v` still 1. Why a pick and not the theme's
  words: those met Hidden Word's answers not once on two days of six in
  English. Eight days picked for US$0.03 in all, about 10 s a day:
  `node lib/cli.js words <day.json>...` (the step is also in `themed`).
  Some picks are loose (glass for a picnic, float for a harbour, monte).
- **The phone**: `ThemedPictures.words(date_key, board)` reads them in
  `Locale.current()` (the language the boards' lists follow). Hidden
  Word's Easy daily takes the first its list holds (`setup(..., themed)`);
  Word Trail's daily, every band, writes a path the first unused themed
  word of its length, drawn after the random one so the grid and the other
  words are the day's as without a theme. New deals, Medium to Insane of
  Hidden Word, and Insane's Snail Mail bank are untouched. Read headless
  with this Mac's cache (Picnic on the Hill): Easy deals "grass".
- **The quizzes**: `acorn.ts` and `pearl.ts` `makeDay(day, recent,
  theme)`. Golden Acorn's writer is told the theme and asked for exactly
  three of a band's drafts on it, flagged `theme` in the schema; Pearl
  Dive's kinds writer for two kinds of each level that keep every kind
  rule (a set, thirty members), the themed sorted first so a level keeps
  them. A themed item's id says so (`d…b0t3`, `d…l1k0t`): ids are opaque
  to the phone. `node lib/cli.js quizzes <day.json>...` writes both days
  into the file as `quizzes`, and Themed days lists the themed items. Not
  yet wired into `publishDay` (stage 4).
  Smoke run on 20261018 Campfire at Dusk with Haiku in both roles (to
  spare OpenRouter's last US$0.40; the night reviews with Opus): US$0.20,
  9.5 min; Golden Acorn kept 3/3/2/2 on the theme (embers, mycelium,
  evergreen, cones; granite barely), Pearl Dive 1/1/0/0 when it was asked
  three in all (a type of mushroom, a type of lamp), hence two a level now,
  not yet run.

The first real run (Anthropic's API, Haiku writes and Opus reviews, as the
night does), 2026-10-14, on 20261019 Picnic on the Hill and 20261018
Campfire at Dusk, about 10 min and US$1.95 a day for the two quizzes (by
cost()'s list prices), nothing from the bank: Golden Acorn themed 1/3/3/2
and 2/1/3/2 a band (thatch, fly agaric, the gourd family, spores, ember, a
lantern's mantle; loose: tungsten for a lantern, cacao for cocoa, raisins);
Pearl Dive 2/2/2/0 and 1/1/2/0 (a fruit, a kind of bread, a type of tree,
a type of mushroom, a type of tea, a kind of tent, a kind of pine; loose:
a room in a house for the cottage, a moon of Saturn for the dusk sky). In
the days' files as `quizzes`, on Themed days.

**Decided for the user, unconfirmed**: Hidden Word's Easy may deal any
answer of the list on a themed day, not only Easy's 217 (the theme gives
it away); Word Trail takes themed words on every band, Insane too, as many
as there are lengths (overruled 2026-10-15: no themed word on two bands of a
day, each band after the ones below it, `docs/agents/boards/word-trail.md`); the word picks have no second model reading them
(the lists are the board's own, already fit to deal); Golden Acorn three a
band asked, Pearl Dive two a level, One Breath seldom any; the theme's name
is still shown nowhere.

## Themed vistas (2026-10-17)

The day's own paintings for the day card and the difficulty rows: the theme's
place at morning, afternoon, dusk and night (`server/functions/src/vistas.ts`,
steps `vista0..3` in themeDay, published as `days/<day>/turns/vistas` only
when all four pass; `core/themed_vistas.gd` on the phone). Trial day 20261019
in `tools/days/themed-vistas/`, shown in Themed days. Spec and open calls:
`docs/superpowers/specs/2026-10-17-themed-vistas-design.md`.

**Peeplets in the vistas, the first dry run (2026-10-27).** `cli.js vistas`
on 20261019 (flash on Vertex, review on Anthropic direct, 21:9; pair 42 and
29, "a mint coat, a red spotted mushroom cap" and "a peach coat, a white
chef's hat"). Both morning tries were turned down, and the review itself
works (schema filled, `peeplets` 2 both times, the sheet and the painting
reach the model; the reviewer measures heights in px of the full painting).
- **Native size 1536 x 672**, not ~1024: a Peeplet at an eighth of the height
  is ~84 px, at a fifth ~134 px (56 px at an eighth on the phone's 448 px
  JPEG). The reviewer sees the full painting, 1.5x the phone's detail.
- **Try 0**: Peeplets ~170 and ~205 px tall (25-30%, over a fifth), right
  third, under a tree, a tea tray between them. Turned down for size.
- **Try 1**: ~125 and ~142 px (19-21%), right of centre. The reviewer said
  borderline on size and added that **both wear robes that hide the legs**.
- **The painter dressed them.** The sheet's body is coral (coat 0); the
  painter kept every body red and put the *named coat colour* on a jacket
  (mint, peach), with a mouth open in a smile, arms and legs mostly hidden.
  So "a mint coat" reads as clothing, not fur colour: the prompt's word for
  the pair (`describe`, "in a <coat> coat") needs the colour as the
  creature's own body ("a mint-green Peeplet", no jacket), and the sheet
  shows only red bodies as a reference. Not changed here (one day's
  evidence; the bench's call).
- Hats came through (mushroom cap, chef's hat); two Peeplets, right two
  thirds, same brushwork as the place.

**The second dry run, after the wording fix (2026-10-27).** `describe` now
says "a mint Peeplet (its whole round body is mint) wearing a red spotted
mushroom cap", `FIRST` says once that each body is one plain colour with no
clothes, robe or jacket and only the hat is worn, and asks for "each about
one seventh of the painting's height, small figures in a wide place, never
the main subject". Same day, pair and commands: morning try 0 turned down
for size (a hat-and-body of ~24% and ~31%; the reviewer counted body alone
~20%), **try 1 passed, then afternoon, dusk and night each passed at the
first try**: four vistas in five paintings, 1536 x 672 each, `peeplets` 2
every time, the same two Peeplets in the same spots and poses at all four
times (the edits kept them).
- **Body colour**: the clothes are gone. Peach reads peach; "mint" reads as
  a sage grey-green (the sheet's coat 6 is sage too), so the two are told
  apart but mint is not minty. Hats right (mushroom cap, chef's hat).
- **Size**: passing try 1 has the mushroom one ~125 px (19%) and the chef
  ~165 px with the hat (25%, its body ~100 px, 15%). The painter still lands
  a little over one seventh, bodies near it, hats over a fifth.
- **Limbs and faces**: two eyes, a small mouth, no fingers, no neck; they
  sit, so legs are mostly hidden and the mint body is more a frog-like
  blob than the sheet's round one. Try 0 (standing) has stubby arms and legs.
- Their place moved: the second run set them at x ~900-1130 of 1536
  (right of the middle), the first at ~1000-1300.
- The bench's cost line (`US$ so far`) read 0.15 for the five paintings
  and five reviews. `cost()` counts the direct Anthropic reviews too:
  `askAnthropic` adds to `spent` at `ANTHROPIC_PRICE`; only a Vertex
  drawing is uncounted (the answer carries no price).

## The day viewer shows what a port did (2026-10-21)

`tools/day_viewer` (a local React page, `npm run dev` there, built
2026-10-21 beside the dashboard: a day's theme, pictures and answers read
from Firestore as the phone reads them, one anonymous identity) gained the
picture ports' record (`docs/agents/turns-and-backend.md`, "Picture ports").
Spec goal 4: the user can judge the port itself, from the original
drawing, the render the reviewer saw, the verdict and the score. Built on `feat/picture-ports`; the viewer needs no
deploy.

- **`day.js` `readPorts(day)`** lists `days/{day}/ports?pageSize=50` and
  answers `{id: {game, band, thing, tries, source, render}}` (the tries
  parsed from their JSON string, `band` read as `integerValue` or
  `doubleValue`); a 403 or 404 answers `{}`, anything else throws. The
  page reads it beside `readDay` and **swallows a failure** (the page
  stays as it was; a `console.warn` would help, deferred).
- **`App.jsx` `PortRow`**, under each Yarn Hoop card (`hoop{band}_{id}`) and
  each Gumdrop jelly (`jelly{band}_{id}`): the kept try's source drawing
  and render as images, its score ("score 8 · try 2 of 2"), the reviewer's
  notes, and "fell back to the pixel reader" when the kept try's route is
  `reader`. A port with no kept try shows "nothing kept", the try count and
  the last try's error or why. A card with no port shows nothing.
- **Jelly cards wear the gummy finish**: one SVG filter (`GumDefs`, the
  spike's `GUM`: a specular highlight from a point light at (20, -10), a
  dark inner rim, a soft shadow) under the jellies heading, each jelly's
  polygons in one `<g filter="url(#gum)">`, strokes now the flavour's own
  colour (they were a brown outline). The game's version of the same finish
  is `gumdrop_art.gd` `picture()` (`docs/agents/boards/gumdrop.md`). The
  hoop cards are as they were: the spec's "fine facets" idea was dropped at
  approval, and the model's panels are the facets.
- **`hoopPorts` and `jellyPorts` in the day JSON** (`server/functions/src/
  cli.ts`): each a list of `Port`s without `source` and `render` (already
  in the document), written by `themedDays` as `[]` for the hoop and by
  the `jellies` and `hoops` commands, so a day made on this Mac keeps its
  tries beside its pictures.
- **Seen**: Chrome on a dev server, 20261021 live: 27 cards, 14 jellies
  with the filter and its glossy rim and highlight, **0 port rows** (the
  ports request answered 403 and was handled silently), no error text.
  With hand-made ports in component state (removed again): 12 port rows,
  two images, "score 8 · try 2 of 2" and the notes, "fell back to the pixel
  reader", "nothing kept · 1 try / refused by the checker" (after a
  "1 tries" plural was fixed). `vite build` passes.
- **Unconfirmed**: a real kept try's JPEGs (the rule is not deployed, so
  nothing is published; the fake images were solid squares); the viewer
  with a day's real ports. Small faults left: `readPorts` and `readDay` call
  `token()` concurrently on a first visit and sign up twice; `band` is
  parsed and unused; a port's unparsable score shows as 0.

## The Peeplet sheet (2026-10-27)

`server/functions/assets/peeplet_sheet.png` (2048 x 1024, flat `Pal.PAPER`
ground, one ink label under each cell) is the live Peeplet
(`ui/peeplet_view.gd`) in eight cells: front, three-quarter (`turn` 35),
side (90), back (180), sitting and "laughing (bounce)", all in coat 0
(coral); then a `sunhat` on coat 5 and `roundglasses` on coat 6. It is the
reference image the day's painter and the reviewer are given, so the Peeplets
painted into the vistas wear this one look. `server/` is `.gdignore`d, so
Godot never imports it; `npm run build` in `server/functions` copies it to
`lib/peeplet_sheet.png` beside `vista_style.png`.

Rebuild it after any change to the Peeplet's look (windowed, one at a time):

    ulimit -f 200000; caffeinate -d -i -u timeout 60 godot --path . --resolution 2048x1024 --always-on-top --script res://tests/_shot_peeplet_sheet.gd -- out=server/functions/assets/peeplet_sheet.png

`ink` was **off** (`PeepletFur.ink` is false in the repo): no line round the
coat. The harness (`tests/_shot_peeplet_sheet.gd`) takes `ink` as
`_shot_peeplet.gd` does; a sheet made with it must say so here. 17 draw
calls (the last run). The sheet is laid out on the first frame: in `_initialize` the window
has no size yet and every cell collapses into the corner.

Two poses are subtler than their names, and the sheet says so. The live
laugh (`peeplet_walker.gd`, `LAUGH_*`) is a body bounce, a squash and
stretch under a swell with a 14 degree rock back and a wag: it never opens
the mouth or changes the eyes. The cell is the walker frozen at its
`laugh_time` 0.80 (bounce at its tallest, taller and narrower than the
front, arms up, leaning back) and is labelled "laughing (bounce)" so the
painter is not told the face laughs. The live sit (`SIT_BODY_DROP` 0.072,
`SIT_LEAN` -13 degrees, the legs swung out under the belly) is genuinely
this subtle on a blob whose legs cannot reach past its belly: a lower,
slightly rocked body with the toes peeking out. The cell is the settled sit,
kept as it is.

The output is not bit-reproducible: the walkers' idle breathing and the
frame at which the laugh freezes (0.80 to 0.82 s) depend on wall-clock frame
timing, so a rebuild differs by a few pixels. The harness warns when the
window is not 2048 x 1024 and still saves.

## The cast (2026-10-27)

The day's two Peeplets (`server/functions/src/cast.ts`; the phone's twin is
`core/cast.gd`, built by the app plan). Eligible are the personas whose coat
is flat (`PeepletPalette.BODY` 0..7) and whose hat is one of `PLAIN_HATS`
(twenty-three of the fifty), in `PeepletPersonas.ALL` order. With `n` the
eligible count and `day` the yyyymmdd number: `a = fnv1a("cast-a-" + day) % n`,
`b = fnv1a("cast-b-" + day) % n`, `b = (a + 1) % n` when `b == a`, and the pair
is `eligible[a], eligible[b]`. When fewer than two personas are eligible, the pair is [0, 1], the first two of ALL. `describe(i)` is total: a coat index outside `COAT_WORDS` reads "coloured" and a hat outside `HAT_WORDS` "a plain hat", never `undefined`.
`fnv1a` is the 32-bit unsigned FNV-1a over the string's bytes (`core/daily.gd:47`,
`eye.ts`). The list reaches the server as `server/functions/src/cast_personas.json`,
written by `godot --headless --path . --script tools/export_personas.gd` (run it
whenever the persona list changes; `tests/_probe_cast_parity.gd` checks it).
Test vector, from `node lib/cli.js cast <day>` and confirmed in GDScript:
`20261027 = [14, 8]`, `20261028 = [11, 20]`, `20261029 = [42, 33]`.

## The reviewer's bench (2026-10-27)

`node lib/cli.js review-bench tools/days/peeplet-bench` (from
`server/functions`, on Anthropic's API: it refuses to start when the review
model would go to OpenRouter) runs `reviewPainting` over every JPEG in the
bench: a painting's or decoy's full PNG when on disk, the JPEG when not, the
day's morning that passed at paint time beside every non-morning file. It
prints a line a file and writes `report.json`: `pass`, `rubric` (sha1 of the
reviewer's prompts and schema: REVIEWER, REVIEW_FIRST, REVIEW_EDIT and
REVIEW_SCHEMA; the painter's FIRST, AGAIN and NEVER are not in it), `deformedPassed`, `goodRejected`,
`countErrors` (a pass-labelled painting not counted at 2 Peeplets),
`subtlePassed`, `passLabelled`, `errors`, tokens and `costUsd`, `verdicts` for
every file and `unlabelled` (the reviewer's word on the user's pile, never
scored). `--rescore` recomputes the scores from `report.json`'s verdicts
against the labels as they are now, with no API call. `--only <file.jpg>...`
reviews just the named files (a few new decoys, a few cents), merges their
verdicts into `report.json`'s and rescores; it refuses when the rubric hash
changed since the report. A decoy is labelled only after its defect is
confirmed by eye at full size; an edit that did not take is deleted. A file that errors
(429, network) is retried once after 20 s, then recorded `ERROR: ...` and
counted apart. Gate: `deformedPassed` empty and `goodRejected / passLabelled`
under 1/3; at most three passes, and no crop-and-enlarge before the user says.

| Pass | Prompt change | Deformed passed | Good rejected | Count errors | Subtle passed |
|---|---|---|---|---|---|
| 1 | none (the Task 3 rubric: sheet first, body-only size, 1..3 count) | 0 of 7 fail-labelled (fingers 2, human, neck, text 3) | 0 of 24 | 0 | 0 |
| 1, rescored on the user's 18 labels | none | 8 of 31 fail-labelled (4 long-arm, fused, missing-leg, the harbour's third Peeplet at dusk and night; the 1014 "neck") | 2 of 31 (size, 20261015 morning-0 and -1) | 0 | 0 |
| 2 | sheet named as the only truth, a `limbs` note a Peeplet before `wrong`, size ceiling a quarter, edit Peeplets must be the same | invalid: Opus stopped on `refusal` for 33 of 49 files (the "Before you decide anything, write ... in limbs" sentence trips it; US$2.27) | | | |
| 3 | the same, the refusal sentence gone, arms in body widths and "hunt for the flaw", feet counted, an added/gone/moved thing is a different place | 3 of 31: 20261014 morning-0 long-arm ("neck"), 20261018 night-1 long-arm, 20261202 morning-1 (third arm) | 7 of 31 (5 night/dusk files "lanterns added", 20261019 morning-0 fused decoy-6 [a labelled pass], 20261201 night-0 "arms fused") | 0 | 0 |
| 4, correction: lights | pass 3's place clause reverted to the pass-1 wording plus one sentence: windows, lanterns, the fire and their glow lit at dusk or night are the time of day, never a different place; limb wording untouched (the limb-wording cap of three passes was spent in pass 3) | 6 of 32: 20261018 night-1 long-arm, 20261019 morning-0 long-arm, 20261019 night-0 missing-leg, 20261101 dusk-0 and -1 (a lit window the user labelled fail), 20261201 afternoon-0 fused | 3 of 32 (20261015 morning-1, 20261018 afternoon-0 "arm runs into the other Peeplet", 20261019 morning-0 decoy-6-fused a labelled pass) | 0 | 0 |

Pass 3 gate FAILS (US$2.04, 302,705 tokens in and 41,564 out, no review errors).
The limb checks caught the 20261201 long-arm and fused, the 20261019 long-arm
and missing-leg (the missing-leg by a lantern string added at night, not the
leg), and the harbour's third Peeplet (the edit rule). The three misses write
"short round-tipped nub, about a quarter of the body's width" for arms the user
sees as long: the note comes out as the template, not as a measurement. The
good rejections are mostly the new "a thing added is a different place"
clause: night and dusk paintings show lanterns the reviewer calls new. The
three-pass cap is spent; the next step is the user's (a wording that does not
overreach on lanterns, or crop-and-enlarge, which needs their word).
Pass 4 (US$2.01, no review errors) is a production-safety correction, not a gate attempt: the lantern and glow rejections are gone (the five lit night/dusk paintings pass), but the lit window the user labelled fail (20261101 dusk-0 and -1) passes again, so it is on the deformed-passed list; the gate still FAILS. The user's label of 20261202 morning-1 decoy-1 as a pass arrived during the run (32 pass-labelled). Verdicts of the same file vary between runs.
`limbs` rides back from `reviewPainting` as a third field and is in each
`verdicts` entry of `report.json`. 20261202 morning-1 decoy-1 (unlabelled): turned down
in pass 3 for a flipper-like tip and a basket that hides the right foot.

Pass 1 read 49 files, 253,136 tokens in and 18,924 out; the gate held with no
change. Unlabelled files the reviewer **passed**: all of the third-arm,
fused, long-arm and missing-leg decoys (nine files) and 20261014 night-0,
20261017 dusk-0 and night-0 (the last two counted 3 Peeplets). It turned down
20261015 morning-0 and -1 and 20261202 morning-1 for size, and 20261101 dusk-0
and -1 for a lit window not in the morning. Only the fingers, human, neck and
text defects are labelled, so the gate says nothing yet about limb count,
fusing or length: label those decoys (open `index.html`) and `--rescore`.

## The dashboard shows the Peeplets (2026-10-27)

Themed days, under Vistas: each try's `peeplets` (the reviewer's count; days
made before it have none and show nothing) follows the difficulty row on a
kept painting and the reviewer's word on a turned-down one, and the line
links `days/peeplet-bench/index.html` (relative to `tools/dashboard.html`,
beside `days/themed-vistas/`). The page code is in `tools/dashboard.src.html`;
`tools/build_dashboard.py` already carries `vistaTries` whole. The Peeplet
rules and what the bench gate does not yet prove are in
`docs/art/peeplet-brand.md`.

## A 96 picture for Jewel Box's Insane (2026-10-27)

The user, of Jewel Box's Insane: "a way bigger image", sewn a quarter at a
time; 96 a side, so a quarter is about the 48's whole. `Beads.SIZES` gains
96 (`tools/beads.js` RULES: 80 to 112 a side, 12 to 16 colours, the same
fill, lead and bare edge; `core/themed_pictures.gd` holds the same row), so
the night has a `pic96` step drawing the theme's sixth thing (a theme of
five lends its fifth). The 48 stays: the build on phones asks for it.
`FIRST_ASK` is 80, three drawings.

**The reader had to change for it.** `Beads.snap` read no grid finer than
a 96th of the image, and a 96 sprite on its white board is always more, so a
band's RULES may name `finest` (the 96's is 160) and snap is handed it. A
pitch tried a quarter pixel off also drifts off its lines over a hundred
squares (a synthetic 100-square grid at 10.24 px scored under its double at
10.15), so with `finest` the pitches are tried closer where the squares are
many. Without it every band reads as before (the same synthetic 64-square
grid read 15.92 px before and after). On synthetic crisp grids of 80 to 124
squares at 1,024 px the 96 band read every square (`mixed 0`); a 140-square
canvas read too, its thing then 113 wide, over the range.

**Not tried on a real drawing**: the dry run on flash needed another
login's Vertex token on this Mac and was refused here. Owed: one 96 drawing
on `gemini-3-pro-image` (a square is 7 to 10 px at 1,024, and real output is
softer than the synthetic: if the night's 96s are turned down as "finer
drawing", ask Vertex for `imageConfig.imageSize: "2K"` on that band alone),
and `finest` raised to 192 if a sprite comes back on a canvas past 160.
