# Picture ports: a reviewed path a game, for sharp pictures every night

2026-10-21. The user, with the day viewer open on 20261021: the pixel
pictures (Jewel Box) "are amazing, love them"; Yarn Hoop "is terrible",
Gumdrop "is even worse"; beside them two references of what was expected,
the same viewer cards with the pictures swapped: a Yarn Hoop of a few
hundred small muted facets, softly lit (a rain boot, a snail with its
spiral, a frog with its green body, a kettle without a face), and a
Gumdrop of glossy, shaded gummy things. Then: "We can use the llm to make
sure high quality outcome, check how can we use them to make sure we have
a specific port for each game to have a high quality sharp picture game
on each."

## Intent

Every picture game gets its own **port**: a path through the night
(`themeWork`, `server/functions/src/themeday.ts`) that draws the thing in
that game's own style, reads it into that game's geometry, renders the
geometry **as the player will see it**, and has a reviewer model look at
that render before it is kept. The eye is on the output, not the source.
What the pixel path already does (`pictures.ts`: Opus writes rows, a
reviewer must name the thing among decoys) is why Jewel Box is loved; Yarn
Hoop and Gumdrop ship a flash drawing read by geometry with no eye on it,
and that is why the frog has no body and the kettle has fangs.

## Goals

1. **An eye on every picture.** A picture is kept only when a reviewer,
   shown the game's own render, names the thing and scores it above the
   game's floor. The reviewer's complaint feeds the next drawing.
2. **Yarn Hoop looks like the reference on every band**: a fine picture of
   a few hundred muted, lit facets, while the play (pins, counts, panels
   by band, 2026-10-15's "difficulty from the picture, not the crowding")
   stays as it is.
3. **Gumdrop's silhouettes are sharp** and the viewer and the game show a
   jelly as a glossy gummy, not a flat blob.
4. **The day viewer shows what the port did**: the original drawing, the
   render the reviewer saw, the verdict and score, so the user can judge
   the port itself.
5. Jewel Box stays as it is (goal 1 adds a score to its existing look, no
   change to what it draws).

## Non-goals

- No change to any game's rules, counts or spacing: Yarn Hoop's 35/55/85/
  150 panels and its pin spacing, Gumdrop's flavours and chunks a band
  (`jelly.ts` RULES), Jewel Box's sizes.
- No new image model. Drawings stay on `DAILY_SHAPES_MODEL` (flash on
  Vertex; pro's quota is production's and shared, never run locally).
- Not the bank pictures (`content/pixel_garden.json`): the bank is cut as
  before when a day has no drawn picture.

## Anti-goals

- A night that runs out of its half-hour step: every port is bounded in
  drawings and reviews a band.
- A reviewer that passes anything: the pick-among-decoys test stays the
  gate, the score only ranks what passed.
- Density bought by crowding pins. The reference's density comes from the
  **picture**, never from the panels.

## The shared eye (`server/functions/src/eye.ts`, new)

One function every port calls:

```
judge(day, theme, thing, game, render: Drawing, source?: Drawing)
  -> {pick, score, wrong, notes}
```

- `render` is a PNG of the game's own geometry, drawn in node with
  `pngjs` **as polygons, with the panel outlines drawn as the board's
  ropes are** (the pixel path keeps `shown()`). The spike showed the eye
  a 256-pixel raster scaled up, and a third of its complaints were
  "jagged", "stair-stepped", "pixelated" edges the player never sees; a
  cream handle also "vanished into the cream background" that a rope
  would outline. A score against the wrong render is worth nothing.
  `source` is the model's drawing when there is one, shrunk as the
  vistas are.
- The reviewer (`role: "review"`, Opus via the Anthropic key as today)
  is shown the render first and, when there is one, the source beside
  it, and answers one JSON: `pick` among the day's things and one decoy
  (as `lookThing`, the choices shuffled by the day), `wrong` (empty, or
  what does not belong in a children's game), `score` 0-10, `notes` one
  sentence on what to fix. The score's rubric is the port's
  (`game`): the eye is told what a good picture of that game looks like
  (hoop: the whole thing present with every part a child expects, its
  true colours, facets reading as light and shade, no face on an object,
  nothing but the thing; jelly: a silhouette a child names at once, parts
  big and clean, no stray blobs or slivers; pixel: as today) and, when a
  source is shown, whether the render still shows what the source shows
  (this is the check the frog failed: the source had a body, the read
  took it).
- A port keeps the **best scoring** of its tries that was named, not
  wrong and scored at least the port's floor: **the score gates, the
  pick alone does not** (the spike's eye named every broken read, an
  umbrella with no middle at 3 and a frog with no head at 2; the pick
  catches only a thing that is not there). The floor is a constant a
  port (hoop 7; jelly set once its reader handles white and outlines,
  see below). A try that fails the pick or is wrong is dropped; its `notes`
  are folded into the next drawing's prompt ("the last drawing was
  turned down because: ...").
- Everything a try produced (name, pick, score, wrong, notes) and the
  kept source and render (JPEG, shrunk as the vistas are) are published
  **a document a picture** under `days/{day}/ports/{game}{band}_{thing}`
  when the day is published (a jelly band has up to five things, and
  five sources and renders would pass a document's 1 MiB). The night
  keeps no `tries` log today (`runStep` hands `pixelBand` an empty
  drafts list and drops `makeJellies`' tries), so this log is built, not
  extended: each port returns its tries and `themeday.ts` stages them
  beside the picture. `server/firestore.rules` opens `days/{day}/ports/**`
  to read as `days/{day}/turns/**` is (the `themes/**` staging stays
  server only, so the day after tomorrow's theme is never readable), and
  `tools/day_viewer/src/day.js` lists it as it lists the turns. The
  phone never reads it. The rules deploy and the functions deploy are the
  user's, as every deploy is.

## The Yarn Hoop port (`hoop.ts`)

- **Prompt** rewritten to the reference: a low-poly illustration of
  about 150-250 flat facets **on every band**, each facet one colour, a
  soft harmonious palette (muted, slightly desaturated, the reference's),
  light from the top left with light, mid and shadow tones, crisp edges,
  no outlines, no gradient inside a facet, no cast shadow (the game draws
  its own under the hoop), nothing else. "Cute cozy style" goes; the
  prompt says a face only when the thing is a creature (the theme writer
  adds `creature: boolean` to `Thing`; until a theme has it, the port
  asks the write model once a thing).
- **The key colour is chosen a thing**: the port asks the write model,
  from `thing.draw` (the thing with its colours), which of green, magenta
  and cyan is farthest from the thing, and `KEY_WORDS` takes that colour.
  The reader's board flood works from the edge's median already, so it
  needs no change for the colour; `readHoop` gains a floor on the thing's
  share of the picture (under 12% of the raster, or a thing split into
  parts of which the biggest is under half, is `why`-refused before the
  eye sees it).
- **The picture is finer than the panels.** `readHoop` keeps the fine
  regions it has before `join` brings them to the band's `most`, and
  ships them: `facets: [{k: [pin indices or own points], c, p: panel}]`,
  each fine facet tagged with the panel it ended in. The pins, the
  panels and their counts are exactly today's. The fine facets' corners
  are their own points in the square of 100 (they need not be pins), and
  **the night clips each facet to its panel's outline** before shipping,
  so a panel's facets tile the panel exactly. The phone's weld
  (`HoopState.adopt_drawn` `weld`) moves a pin a few units at most on a
  new day, since the night welds at the same spacing; a facet's spill of
  under a unit past the welded outline lies under the panel's rope and
  is accepted. A panel the weld drops hands its facets to the panel that
  took its area.
  Budget: about 250 facets a picture, the document stays well under
  Firestore's limit (today's Insane hoop is ~6 KB; 250 facets of ~6
  points at 2 decimals is ~12 KB).
- **The render the eye sees** is the fine facets filled in their colours
  over bare linen, pins not drawn.
- **The phone**: `ThemedPictures.hoop()` checks `facets` (each `p` a
  panel, points inside the square, 3+ corners) and `HoopState.adopt_drawn`
  keeps them; `hoop2d.gd` `_knit_part(k)` builds a panel's knit from its
  facets (each a fan of vertices in its own colour, the tile UVs as
  today) instead of one flat colour, so Easy knits in as the reference
  looks. A panel with no facets (a bank cut, or an old day) knits as
  today. Draw calls do not change (the chunk mesh holds more vertices,
  not more draws). The facet shade (`FACET`) stays off for drawn
  pictures, as now.
- **The viewer** draws `facets` when a hoop has them, panels otherwise.
- **A style reference goes with the prompt**: a crop of the user's
  reference picture (the low-poly snail of 2026-10-21, kept in the
  functions as `vista_style.png` is) handed to `draw()` as `images`, as
  the vistas do. In the spike the snail drawn with it matched the
  reference and read at 7; the same prompt in words alone drew a
  textured, near-photographic snail the reader shredded (5).
- **What the fine facets buy, honestly**: Easy and Medium animals (the
  snail drew 109 fine regions over 40 panels, the frog 208 over 55). A
  simple object draws few facets however many are asked (the umbrella
  20 on Hard), and on Insane the cut splits big regions into more
  convex panels than there are facets (the kettle 65 fine, 121 panels),
  so there the knit is the panels either way.
- Tries: up to 3 drawings a band, each reviewed once; the best kept.
  The spike measured about 42 s a drawing, read and review, so three a
  band fits the half-hour step with room.

## The Gumdrop port (`jelly.ts`)

- **Rules untouched**: flavours, mixed and chunks a band stay. (Easy in
  two flavours cannot be the reference's glossy snail; the user decides
  whether Easy's counts rise. Not in this design.)
- **Sharper silhouettes**: the grown outline falls from 0.9 to 0.5 and
  `SWELL` from 5 to 3 pixels; the sticker prompt asks for "a clean,
  sharp, well-drawn silhouette with its true proportions" instead of
  "chunky". **The 16-point outline cap stays** (`MOST_POINTS`, and
  `gumdrop_mould.gd` `from_doc` refuses a shape over it): raising it
  would have an unpatched phone refuse every new jelly and deal from the
  bank until the APK is on the stores, so the day the functions deploy
  Gumdrop would get worse. Raising it on both sides is offered to the
  user with the counts question below.
- **The render the eye sees** is the parts as soft shapes in the flavour
  inks on the board's cream, drawn as the viewer draws them.
- **The gummy finish goes on the card's picture** (`Art.picture`, the
  flat flavour polygons that match the viewer's blob) and on the viewer
  (an SVG filter: a highlight along the top-left edge, a darker rim, a
  soft inner glow). Not on the tint: the user turned lighting on the
  syrup down on 2026-10-11 and 2026-10-14 ("every fold a crease of
  foil", "no light outline anywhere"), and the mould's gel is glossy
  already (`Art.gloss_of`). The finish is still, so `Motion.reduce` has
  nothing new to honour.
- **The reader must handle what flash draws however it is asked**: a
  white sticker border, dark outlines, white eyes and cream bodies. In
  the spike the second run's prompt forbade all of them and flash drew
  them anyway on three of four; the reader mapped the white to lemon
  (a kettle's handle a yellow blob) or dropped pale parts with the
  border (a frog's head). The eye scored those 4 to 6 and would have
  refused them all at 7, which is right, but a floor is meaningful only
  once a clean sticker can reach it: white and near-white pixels inside
  the thing become the flavour round them, a dark outline is dissolved
  into its neighbour, and only then is the jelly's floor set.
- Tries: `DRAWINGS` as today (3, 3, 2, 2), each reviewed. **The written
  fallback stays** (`makeJellies.one`'s Opus-written parts, up to
  `TRIES` 2) and goes through the eye with no source, competing on score
  with the drawings; it runs only when every drawing failed, as today, so
  the step's budget is today's plus a review a try.

## The Jewel Box port (`pictures.ts`)

- `lookThing` becomes a call to the shared eye with `game: "pixel"`,
  keeping its pick-among-decoys and adding the score and notes to
  `Tried`. The drafts and sizes it keeps are chosen as today (the first
  that passes), so nothing the user loves changes. Its source is the rows
  themselves; no drawing is saved.

## The day viewer (`tools/day_viewer`)

- Each hoop and jelly card gains, below the game's render, the kept
  source drawing (from `themes/{day}/pictures/...`), the score and the
  reviewer's notes; a card whose picture fell back to the bank says so.
- Hoop cards draw the fine facets.
- Jelly cards wear the gummy finish.

## Constraints

- The night's steps are bounded: a hoop band is at most 3 drawings and
  3 reviews, a jelly band at most `DRAWINGS[band]` x the band's things.
  A review is a few seconds; a flash drawing ten to twenty. A step stays
  inside its half hour.
- Nothing night-side reaches a phone until the user deploys the
  functions (`tools/deploy_functions.sh`, run by a person). The functions
  were last deployed before the 2026-10-20 pin weld.
- Local runs of the port use flash only, serially (`cli.ts`), with the
  drawings kept in the scratchpad or `build/`.
- The phone must keep reading old days and bank cuts: `facets` is
  optional in the document.
- No board name of the game each follows, anywhere.

## Decided by me (the user may overturn)

- The score floor 7 and "best of the tries" (rather than the first
  that passes): quality over the night's minutes.
- The key colour chosen among green, magenta and cyan by the write model.
- The fine facets are shipped with their own corner points, not snapped
  to pins.
- Gumdrop's grow 0.5 and swell 3; the 16-point cap kept.
- The gummy finish on the card's picture, not the tint.
- The written jelly fallback kept and reviewed.
- The port's tries, source and render published a document a picture
  under `days/{day}/ports/`, readable as the turns are; the phone never
  reads it.

## Left to the builder

- The exact rubric wording a port; the render size (448 px square as
  `shown()`); the scan-fill.
- How the shader estimates a normal for the gummy highlight.
- Whether `creature` is asked of the theme writer's schema or inferred
  a thing at port time (either is fine; the port must work for a theme
  written before the field).
- Test shape: the suite's parse guard and the existing hoop and jelly
  probes (`tests/_probe_hoop.gd`) must pass with a `facets` document and
  without one; a throwaway node check renders a known hoop document.

## What the spike showed (2026-10-21, 15:25-15:47)

Two runs of a throwaway (`scratchpad/spike/spike_ports.js`, flash on
Vertex, the reviewer Opus, one drawing a card): Yarn Hoop on every band
twice (with and without the style reference), Gumdrop once a band.

- **The mechanism works.** The eye's complaints named the real fault
  every time ("the pale cream body nearly vanishes", "restore the frog's
  green body silhouette", "the handle as a clear arched loop instead of
  a big blob").
- **The green key was the hoop's fault, and it is fixed by the key a
  thing.** Flash paints the key as a muted sage, and the board flood ate
  every pale part near it: the snail's cream body, the umbrella's yellow
  middle, and in the jelly a lime frog whole. On magenta and cyan in run
  2 the umbrella read at 8 and 8, the frog 8 and 6, the snail 7.
- **Run 2's scores**: hoop snail 7/5, frog 6/8, umbrella 8/8, kettle
  6/4 (ref/words); jelly boot 5, snail 6, frog 4, kettle 4. Against the
  cruder render, so the hoop's are low by some.
- **Neither of the user's two open calls is informed by it.** The Medium
  snail jelly at 3 parts in today's counts did read as a snail when the
  read worked, mild evidence the counts can stay.

## The map written by a model (2026-10-21, 16:03)

The user, with run 2's snail beside its shredded cut: "can we send the
image, some mapping field, and ask a model to generate the yarn hoop
map?" A third throwaway (`spike_map.js`) tried it on run 2's drawings:
each drawing with a numbered grid over it (20, 24, 30, 40 cells a side
by band, about the band's pin spacing) went to Opus, which wrote pins and
panels in grid coordinates; the mesh was snapped, checked as the phone
checks a map, coloured by the drawing's mean over each panel, rendered
and scored by the eye, beside the pixel reader's playable cut of the
same drawing scored the same way.

| Card | Model's map | Reader's cut |
|---|---|---|
| snail, Easy | 30 panels, 45 pins, score 6 | 40 panels, score 5 |
| frog, Medium | 56 panels, 78 pins, score 7 | 55 panels, score 6 |
| umbrella, Hard | 25 panels, 47 pins, score 5 | 29 panels, score 5 |
| kettle, Insane | 75 panels, 114 pins, score 7 | 121 panels, score 5 |

- **The model's meshes are clean and valid**: 0 overlaps on all four,
  one T-junction and two sides shared by three panels in all, no panel
  over 7 corners; silhouettes faithful and whole, panels coherent, the
  look the reference has. The reader's cuts are jagged, hole-ridden and
  drop parts (eye stalks, a knob, a shaft).
- **What it misses**: fine features the drawing has but the panel
  budget does not (the shell's spiral folded into a dome at 30 panels,
  the umbrella's thin shaft, 1 panel, dropped). The counts came under
  the band's most (30 of 40, 75 of 170): the model simplifies.
- **Cost and time**: 45-175 s and $0.11-0.42 a map on Opus; a band's
  three tries fit the half-hour step.

So the hoop port's reader becomes **the model writing the map**, with
the pixel reader as the fallback: the drawing on its key, the grid laid
over it, the mesh checked and repaired (snap, drop a panel under 3, a
T-junction's pin inserted into the side it lies on, a concave panel
ear-clipped as the night does now), coloured off the drawing, the eye
scoring the render, the complaint folded into the next ask ("the shaft
is missing; the shell's spiral is missing: keep every facet of the
drawing, use the whole panel budget"). This replaces "the picture finer
than the panels" as the way to the reference look: the panels
themselves are the drawing's facets, whole and placed where the drawing
has them. The user decides.

## The jelly written by a model (2026-10-21, 16:13)

The user: "let's try to do something similar for the other games and
the gumdrop". The other boards that take a drawn picture are the bead
boards, already on the model-written, model-reviewed pixel path; so a
fourth throwaway (`spike_jelly_map.js`) did it for Gumdrop: run 2's
sticker drawing with a 0-100 grid went to Opus, which wrote the parts
(flavour + soft polygons) under the band's rules as the prompt stated
them; the night's own `why()` judged them, one refusal folded into one
retry; the eye scored the render beside the pixel reader's parts.

| Card | Model's jelly | Checker | Reader's parts |
|---|---|---|---|
| rain boot, Easy | 2 parts, score 6 | refused twice, "covers 18%" | score 5 |
| snail, Medium | 3 parts, score 7 | passed | score 6 |
| frog, Hard | 4 parts, score 7 | refused, "a soft's numbers" then "a chunk too small to pour in" | score 4 (refused) |
| kettle, Insane | 5 parts, score 6 | the same two refusals | score 4 (refused) |

- **The silhouettes are what the reference asks**: whole, clean, true
  to the sticker, the eyes and cheeks placed as drawn; 7-20 s and
  $0.02-0.04 a try. The reader's parts of the same drawings are lumpy
  blobs with the head or sole lost.
- **Every refusal was a rule the prompt had not stated**: the jelly
  must cover 20-75% of the field (`COVER`), a chunk must show at least
  `LEAST_SQUARES` 9 of the sim's 36-grid (a frog's eye dot cannot be a
  chunk of its own), a soft polygon has 6-16 points. Stated in the ask
  and folded into the retry as the hoop's are, these pass; the spike's
  second try repeated "covers 18%" because the ask never said the
  floor.
- So **the Gumdrop port's reader is also the model writing the map**,
  with the pixel reader as the fallback, the band's rules stated in
  full in the ask (counts, mixed, cover, chunk size, points), `why()`
  as the checker, and the eye over the render. The sticker drawing
  stays the source. The rules themselves stay (open question 1).

The four spike scripts are kept beside this document in
`2026-10-21-picture-ports-spike/` as the record of the prompts, grids,
checks and renders; their pages and drawings were in the session's
scratchpad only.

## Open for the user

1. Should Gumdrop's Easy and Medium colour and shape counts rise, and
   the 16-point outline cap with them, so the jelly can carry more of the
   thing? Both change the phone (`RULES`/`THEMED`, `from_doc`), so the
   functions must deploy only once that APK is on the stores.
2. Should the hoop's fine facets also be drawn under the **unfilled**
   panels, faintly, as a hint of the picture, or stay hidden until a
   panel knits in (as today)?
