# The Peeplet is the brand

The user, 2026-10-27: "make the peeplet chars the new brand character, also
make a pattern game being called daily puzzles not just daily, and on store it
will be peeplet: daily puzzles"; "instead of general moon and sun, we could find
a way to add funny peeplets around. And for example the day image of windmill
hill, we could ask the model to include the peeplets in the composition"; "the
daily generated images should contains peeplets (we must make sure to properly
calibrate the reviewer to catch peeplet deformed limbs)". The sprout goes
completely ("yes, you get it").

## Intent

One character fronts the game everywhere a player meets it: the store, the
icon (already the user's painted Peeplet), the opening, the first screen, the
day's painting. The game is **Daily Puzzles**; on the stores it
is **Peeplet: Daily Puzzles**. The sun, the moon and the sprout stop being the
greeting, and the Peeplet takes their place: live, funny, a little different
every day.

Three parts, buildable one at a time, in this order: **B** (the Peeplet in the
app), **C** (the Peeplets in the paintings and the reviewer), **A** (the name).
A goes last because it is a release step and touches the stores.

## Goals, non-goals, anti-goals

Goals: the Peeplet is the face of the game on every brand surface; the day's
painting has Peeplets in it that read at card size; no painting with a
malformed Peeplet reaches a phone; the name reads "Daily Puzzles" in the app.

Non-goals: new Peeplet animations (the walker's set is the set); a new icon
(the painted one stays); pixel-art sprites with Peeplets in them (a Peeplet is
a blob at 10-18 squares; the Insane 48 band is a possible follow-on); the
sun and the moon where they are a board's pieces or a tray's marks.

Anti-goals: a hand-drawn or baked Peeplet on any screen (the 2D port was
rejected 2026-10-23); a painting where a human is drawn instead of a Peeplet
or a Peeplet has three arms; days that silently fall back to the bundled vistas
because a stricter reviewer rejects everything; a save folder that moves
because the app was renamed.

## Constraints

- The Peeplet on a screen is the model through `ui/peeplet_view.gd` (one
  SubViewport each, its own World3D): held views cost one draw a frame, a
  redrawing one 14-16. Budget 855 draw calls. `set_idle` is honoured at rest.
- The image side runs in `server/functions/src/vistas.ts`: flash on Vertex
  (`gemini-2.5-flash-image`), the morning painted off `vista_meadow.png` as a
  style reference, the other three as edits of the morning, Opus reviewing
  (OpenRouter). `themeDay` gives a vista step one try a run, `TRIES` 2; a day
  publishes vistas only with all four.
- The vista's left third is kept calm for the day card's words.
- Deploying functions and editing the store consoles are the user's to run.
- Calibration costs Vertex and OpenRouter money: the bench below is sized and
  priced so the user approves it once.

## Part B: the Peeplet in the app

### The header (`ui/menu/menu_header.gd`)

- The wordmark is **the icon's letter tiles** (the user, 2026-10-27: "keep
  the same daily puzzle look from the icon instead of doing a plain daily
  puzzle font"): DAILY over PUZZLES, one tile a letter, in the icon's
  colours (paper, butter, leaf, sky blue, coral), each tile a touch askew,
  with a sunk bottom edge. The tiles are drawn in code with Hidden Word's
  own tile drawing (`ui/menu/cards/hiddenword.gd`, the same component, fed
  twelve letters), never an image of the icon. It fits the 380 vertical
  budget the header has (today 100 air, a 140 wordmark on a 182 line, two 38
  motto lines); sizes are settled on a concept tab in
  `docs/brainstorm/concepts.html` before the Godot build, as the user prefers
  for a reworked screen; the tab lays the live-look Peeplet renders over the
  real header art for layout only. My call pending the tab: tiles near 60,
  the motto one line. The Label wordmark and its sun-dot go with the sprig
  (the sun-dot stays the dot of every i in titles and card names).
- The entrance: the tiles are laid a tile at a time, as the opening does.
- **The picture behind the header is the day's** (the user, 2026-10-27:
  "the hero image should also be daily changed by the daily theme"): on a
  themed day `Vistas.header_plate` takes `ThemedVistas.texture("dusk")`
  under the same crop (zoom 1.1 at 0.88, 0.70) and scrim as the bundled
  dusk, which stays the fallback; the header joins the `themed_vistas` group
  so a vista arriving behind the menu changes it in place, as the day card
  does. That crop keeps the right 91% of the painting's width and the band
  from 18% to 92% of its height, so the painting's Peeplets (right two
  thirds, see C) are what shows in the header. Dusk is my call: it is the
  bundled vista the header wears today, so its palette holds.
- The sun and moon faces go, and **no Peeplet takes their seat** (the user,
  2026-10-27: "remove the peeplets from the main screen header, keep only the
  daily puzzles"): the header is the tiles, the motto and the buttons over
  the vista. The entrance keeps the buttons' scale-in; the sun and moon's
  rise is simply gone.
- **The day's pair** still exists: two personas from
  `peeplet/peeplet_personas.gd` picked by the day number, the same two the
  night's painting is asked to paint (see C, `cast`). It shows on Streak,
  Hidden Word and the remove-ads sheet (table below). With
  no published cast the phone picks by its own seed. What a shown pair does,
  from the walker's set only: breathe at idle_fps 15, laugh on a tap
  (`trigger_laugh`), once in a while pick or snack, seeded so two never act
  at once. No time-of-day state (my call).
- Cost: the menu loses the sun and moon's draws and gains none. The menu is
  measured before and after (`_shot_menu.gd`, two readings, opengl3_angle).

### The opening (`ui/opening.gd`, `docs/agents/opening.md`)

The opening still animates the first icon: a 3x3 grid, the sprout, `Daıly`.
It becomes the current icon coming together: the DAILY / PUZZLES tiles laid a
tile at a time, the word lettered under as **Daily Puzzles**, the motes as
today. The Peeplet: a live view that hops in behind the tiles once the glb is
loaded, if loading it costs under 150 ms on the phone's path; otherwise the
opening has no character and the tiles alone are the icon. The same tiles
then stay as the header's wordmark, so the opening hands over to the first
screen without a change of lettering. The builder measures and records the
number in opening.md.

### Every sprout face goes (`ui/faces/sprout_face.gd` is deleted)

| Where | Today | Becomes |
|---|---|---|
| Hidden Word card (`ui/menu/cards/hiddenword.gd`) | sprout | the day's first Peeplet, held, frame as Pie's card |
| Hidden Word board (`puzzles/hidden_word2d.gd`) | sprout rises on the reveal | the day's first Peeplet rises in the same spot: laughs on the win, sits on a loss (`grieve` is the walker's sad); the hat and glasses the sprout wore on a win become the persona's own hat and eyewear, none on a persona without (my call) |
| Word Trail card (`ui/menu/card_art.gd`) | sprout | no character (its pieces are marks) |
| Streak Today card (`ui/menu/streak_tab.gd`) | sprout on a rock | the day's first Peeplet, sitting on the rock |
| Remove-ads sheet (`ui/hud/remove_ads_sheet.gd`) | sprout | the day's second Peeplet |
| Stats cells | reuse card faces | follow the cards |
| Win screen (`ui/flat/well_done.gd`) | sun and moon | unchanged for now; a later per-board pass |

The **drawn plant ornaments stay**, my call: the sheet title sprout and
divider (`ui/hud/sheet_parts.gd`), the difficulty plaques' sprout, sun, cloud
and crescent, and the Streak calendar's sprout, bud and flower are the garden
language of the sheets, not the mascot.

### The sun and moon faces

They stay where they are pieces or marks: Binairo's board, card and tutorial,
`symbol_tray.gd`, `friends.gd`, `teacup.gd`, the friends sheet's moon, Peapod's
sun. They go from the header. **The win screen keeps them for now** (the
user, 2026-10-27: "let's not change the ingame win look for now, it need to
be done one by one later, let's keep it more general"): this pass touches the
general surfaces (the header, the opening, the sprout's seats, the paintings,
the name), and in-game looks are a later board-by-board pass. The one
in-game change here is Hidden Word's board, because the sprout file goes
(table above).

### The difficulty sheet comes back (ui/menu.gd, ui/menu/difficulty_sheet.gd)

The user, 2026-10-27: "move back the difficulties sheet when clicking on the
game". A puzzle card with `pick_difficulty` asks on the sheet again (the
four rows on the day's four paintings, Easy to Insane, the done rows
checked), as before 93105bbd retired it on 2026-10-22; the sheet's `chose`
opens the board. `Progress.last_level` stays: the board's level card and the
win's "Try Hard" still save it, and the sheet marks the row last played (my
call, a small ring on its go). `_shot_menu.gd` gets its `diff` shot back.
With Peeplets in the vistas, the sheet is where all four painted times show
on a themed day, so it is measured with a themed day adopted.

### Docs and rules

- `CLAUDE.md`'s Peeplet exception widens: the Peeplet is the brand character
  and appears, always through `ui/peeplet_view.gd`, on the opening,
  Hidden Word, Streak, the remove-ads sheet and Pie.
  Boards whose pieces are marks still get no mascot. The "never bake it to an
  image" rule gains its one carve-out (C: the painter's reference sheet).
- A new `docs/art/peeplet-brand.md`: what the Peeplet is (blob, two short
  arms, two leg stubs, a tail, two eyes, coat from the 12-colour palette, hat
  and eyewear from the wardrobe), the personas, where it appears, where it
  never does, and the reference sheet rule.
- `docs/agents/first-screen.md`, `opening.md` and `boards/hidden_word.md`
  get the history.

## Part C: Peeplets in the day's paintings

### The reference sheet

A harness (`tests/_shot_peeplet_sheet.gd`, after `_shot_peeplet.gd`) renders
the live look at 2048 wide on a flat cream: a front view, a three-quarter, a
side, a back, a sitting one and a laughing one, in two coats, one wearing a
hat and eyewear. It is written to `server/functions/assets/peeplet_sheet.png`
(outside the game tree, so Godot never imports or ships it) and the
`package.json` build copies it to `lib/peeplet_sheet.png` beside
`vista_style.png`. **Rule:** the sheet is rebuilt by its harness whenever the
Peeplet's look changes (ink, shade, eyes); it is never edited by hand. This is
the one baked Peeplet image allowed, and it never reaches a phone.

### The painter (`vistas.ts`)

- `FIRST` attaches two references: the style (as today) and the sheet, and
  asks for the day's **cast**: "two Peeplets, the small round creatures of
  the attached sheet, exactly as drawn there: a round body, two short arms,
  two stubby legs, two eyes, no fingers, no neck; one in a <colour> coat
  with <hat>, the other in a <colour> coat with <hat>, <doing something the
  theme suggests>, in the right two thirds of the painting, each between an
  eighth and a fifth of the painting's height, painted in the same brushwork
  as the place". How close the painted pair must be to the day's pair is
  the user's call (see "Open"); the default written here is coat colour and
  hat in words, eyewear never asked, and the day's cast drawn only from
  personas with a plain (unpatterned) coat and a hat that has a plain name,
  so flash is never asked to invent a propeller cap from a word. The theme step writes the
  doing (`theme.cast`: a one-line scene for the pair, e.g. "rolling a hay
  bale toward the mill"), the night fills the coats and hats from the day's
  two personas (same seed rule as the phone, in a shared place:
  `server/functions/src/cast.ts` mirrors `peeplet_personas.gd`'s list and
  seed; a test checks the two lists match).
- `NEVER` becomes "No humans, no human faces, ..." and says "the Peeplets are
  the only creatures with faces".
- `AGAIN` keeps the Peeplets where they are ("the same two creatures in the
  same spots and poses") so the four times are one place with one cast.
- `publishVistas` writes `cast: [i, j]` (persona indices) into the vistas
  document; the phone's Streak, Hidden Word and remove-ads sheet
  read it, else seed.

### The reviewer

`REVIEWER` is shown the sheet with every painting and gains a Peeplet rubric,
applied to all four times (an edit can bend a limb the morning had right):

- Turned down: any human or human-shaped figure; any Peeplet with more or
  fewer than two arms or two legs, a limb that is fused, melted, doubled,
  bent the wrong way or longer than the body, hands with fingers, a neck, a
  second head or face, more than two eyes, a body that is not one round blob;
  a Peeplet in the left third; a Peeplet larger than a fifth of the height or
  smaller than a twentieth (unreadable on the card); zero Peeplets; more than
  three.
- The reviewer judges the **full painting** as drawn, before `shrunk()`
  (today it sees the 1024x448 JPEG, where a Peeplet is ~45 px tall and a
  bent limb is invisible); `makeVista` reviews first and shrinks after (my
  call; about a cent more a review).
- One to three Peeplets pass; two are asked. Hats and coats are not judged
  (the painter's fidelity is not a safety matter; the bench reports it).
- The answer gains a count: `{wrong, peeplets: n}` so the bench can score it.
- `makeVista` gets two tries a run on the morning (the step that changes the
  most), one on the edits as today; `TRIES` goes to 3. A day's vistas still
  publish only with all four. The functions' logs count turned-down reasons
  so the first week tells us the real rejection rate.

### Calibration: the bench

What the user asked for in so many words. Built before the prompt ships:

1. `node lib/cli.js vistas` runs on eight made days from `tools/days/`
   (varied places: a mill, a harbour, a market, a snowy one, a night-first
   one), two morning tries each and the three edits of each accepted morning:
   about 50 paintings. Flash on Vertex at ~US$0.04 each, about US$2.
2. **Decoys**, after `eye.ts`'s decoy pattern: for eight of the accepted
   paintings, flash is asked to edit in a defect (a third arm, a missing leg,
   fingers, a human child, a Peeplet with a neck), and for four more a subtle
   one (an arm slightly too long, a leg fused to the body). Sixteen decoys.
3. Every painting is labelled by hand on a review page (an artifact with the
   images in a grid, pass/fail/limb-defect per image; the user judges the
   subtle ones) into `tools/days/peeplet-bench/labels.json`.
4. `node lib/cli.js review-bench` runs the reviewer over the set and reports
   deformed-passed, good-rejected, and the count error. Opus via OpenRouter,
   ~US$0.05 a review, about US$4 a pass. Exit criterion: **zero deformed
   passed** over the bench, including the subtle decoys, with good-rejected
   under a third. The rubric is iterated until it meets that; each pass is a
   row in `docs/agents/days-dashboard.md`.
   **The gate is the obvious defects** (limb count, fused or melted limbs,
   fingers, a neck, a human): zero of those pass. The subtle decoys (an arm a
   little long, a leg half swallowed) are a tracked rate, not a gate. If the
   gate is not met after three reviewer passes, the work stops and the user
   is asked before the next lever: a second look where the reviewer names
   each Peeplet's box, the box is cropped and enlarged, and the crop is
   judged on its own (new spend, new code).
5. The bench, its labels and the last report are committed, so the next
   prompt change reruns it.

Total approved spend for the bench: under US$15. OpenRouter is topped up
first (its balance has run to zero before).

## Part A: the name

- `menu_header.gd`'s Label wordmark and `opening.gd`'s `WORD` give way to the
  DAILY / PUZZLES tiles (B above).
- Stores, by the user by hand: Play Console title **Peeplet: Daily Puzzles**
  (22 of 30 characters), App Store Connect name the same. Subtitle, short and
  long descriptions, feature graphic and the six phone shots are refreshed
  after B ships, since they show the old header: a follow-on, listed in
  `docs/roadmap-to-release.md` with the trademark line.
- The device label under the icon (Android `package/name`, iOS display
  name): **Peeplet**, my call pending the user: it fits every launcher without
  truncation, the icon's tiles already say DAILY PUZZLES, and it matches the
  store prefix.
- `project.godot`'s `config/name` stays "Peeplet Daily" (amended 2026-10-27
  at planning): it is only the desktop window title, and either renaming it
  or pinning a custom user dir would move this Mac's `user://` out of
  `app_userdata/Peeplet Daily`, breaking `tools/themed_play.sh` and the
  checkout trap. The launcher labels are set where they are read: Android
  `package/name` in the preset, iOS `INFOPLIST_KEY_CFBundleDisplayName`
  patched by `tools/export_ios.sh` after the export (the exporter writes it
  from `config/name`). The bundle and package id `com.peeplet.daily`, the
  Firebase project and App Distribution ids never change.
- `locale/ui.csv` `FRIENDS_INVITE_TEXT` says "Peeplet: Daily Puzzles" in en,
  pt and es. The three site pages under `server/site/` and `generate.ts`'s
  `X-Title` say the same. `export_presets.cfg`, `tools/export_ios.sh`,
  `upload_ios.sh`, the release scripts and the workflow keep their file names
  (`peeplet-daily.apk`, the scheme, the profile): they are ids, not names.

## Open (the user's)

- How recognisable the painting's pair must be as the day's pair in the app: coat
  colour and hat in words (the default above), or coat colour only, or
  faithful (the wardrobe on the sheet, a hat-to-words table, the reviewer
  checking the hat; more work and more rejections).

## Left to the builder

- Exact header tile sizes (the concept tab settles them).
- The seed rule for the day's pair, shared by `cast.ts` and the phone.
- Which walker actions a shown pair uses and their cadence.
- The bench's eight days and the decoy edit prompts.
- The opening's timing if the Peeplet makes it in.

## Done means

Part B: suite green, `_shot_menu.gd` two readings within budget, the sprout
face file gone, docs updated, committed locally. Part C: the bench meets its
exit criterion, the trial day in `tools/days/themed-vistas/` shows Peeplets
in all four times, the dashboard shows the bench, committed locally; the
deploy is the user's. Part A: the app builds and runs under the new name with
the old save folder, committed locally; the store renames are the user's.
