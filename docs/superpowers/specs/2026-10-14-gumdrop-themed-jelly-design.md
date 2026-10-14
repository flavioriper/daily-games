# Gumdrop follows the day's theme

2026-10-14. The user: "the gumdrop game should use the same picture themed
approach of the others picture games". It replaces the Gumdrop line of
`2026-10-13-daily-theme-design.md` ("the theme writer names moulds out of
the twenty-nine").

## Decided with the user

- **The night draws the jelly**, not the bead picture converted (the 10
  and 12 bead pictures came to 17 and 36 colour regions in nineteen beads,
  against six flavours and 16 chunks), and not a name out of the
  twenty-nine (a picnic day could only get a picnic jelly that was there).
- **Every mould is the theme's** (the user, of an Insane day whose first
  mould was the themed crab and the last a traffic light: "what this has to
  do with the theme?"). The first build themed only a band's first mould.

## How

- **Written as parts.** The twenty-nine are parts in code (`parts()`: a
  flavour and its ellipses, rounded boxes and soft polygons, the one
  underneath first). The night writes the theme's things in the same shapes
  as JSON, so a themed jelly is built and drawn by `build_parts`, the
  twenty-nine's own code: `server/functions/src/jelly.ts`, a text model
  (`DAILY_ROWS_MODEL`, Opus) shown four of the twenty-nine.
- **A jelly a mould**: Easy the theme's first two things, Medium three,
  Hard four, Insane five, each written to its band's row; so the same thing
  comes back on a harder band with more flavours and more chunks.
- **The rules, in code on both sides** (`jelly.ts` RULES,
  `gumdrop_mould.gd` THEMED, which change together):

  | Band | Flavours | Mixed among them | Chunks |
  |---|---|---|---|
  | Easy | 2 | 0 | 2-5 |
  | Medium | 3 | 0 | 3-7 |
  | Hard | 3-4 | 1 or more | 3-10 |
  | Insane | 4-6 | 2 or more | 4-14 |

  and for every band: one piece of jelly; every point inside 4-96 of the
  field's 100; every chunk shows 9 of the sim's 36 by 36 squares; the jelly
  covers 20-75% of them. Hard's left-out mixed pot and Insane's Three Pots
  need the mixed flavours.
- **The blind look** of the bead pictures (`lookThing`) is shown the jelly
  laid as 32 by 32 beads in its flavours' colours and must name the thing
  among the day's and a decoy. Two writes a jelly at the most, the second
  told why the first was turned down.
- **Delivery**: the `pictures` document gains `jellies: {"0": [...], ...}`,
  a list a band in the theme's order. Nothing new is fetched: `world/main.gd`
  already caches that document at boot. The phone (`ThemedPictures.jellies`)
  builds each, holds it to the band's row and drops one that fails; the
  day's moulds are the themed ones first, the twenty-nine fill the places
  left, never a picture of the same name twice.
- **Stage 4 is unchanged**: `publishDay` does not write `pictures` yet, so
  this reaches only this Mac (`tools/themed_play.sh`) until that deploy,
  which is the user's.

## Measured

- The rules on the twenty-nine: house, tree, butterfly, mushroom fail and
  pass where their flavour counts say they should.
- Tide Pool Morning (one jelly a band, the first build): 4 of 4 kept on the
  first write, the blind look named each (starfish, spiral shell, crab,
  crab). Picnic on the Hill, a jelly a mould: 9 of 14 kept; the five lost
  were OpenRouter's 402 (the account's credits ran out mid-run), not the
  rules or the look.
- `tests/_shot_gumdrop.gd -- 3` on the themed Insane crab (14 chunks, the
  twenty-nine stop at 6): poured and served at 89% by the bot, 118 draw
  calls; the day won.
- Cost: a jelly is an Opus write and a look, about US$0.03; a day of
  fourteen about US$0.45 and some minutes, one request at a time (four
  bands side by side ran into OpenRouter's in-flight budget).

## Not known yet

How often a day keeps all fourteen with credits to spare; a phone; the
user's eye on the jellies themselves.

- **Stage 4's time**: `publishDay` makes two days inside 1,800 seconds,
  and a pixel day's drawings already take minutes; fourteen Opus writes and
  their looks, one at a time, add several more a day. Timed when the deploy
  is planned.
- **The night counts chunks on a 100 by 100 raster, the phone with
  `merge_polygons`**: they agreed on all thirteen jellies made, but two
  shapes that only just touch could pass the night and fail the phone;
  that jelly's place is then dealt from the twenty-nine.

Seen through the real path (`tests/_shot_gumdrop.gd -- 0`, the 19th
installed as today's): Easy dealt the themed mushroom and then the mug,
served at 100% and 98%, the done day reopened on the mug.
