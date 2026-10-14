# The daily theme

2026-10-13. The user: "I want the daily process we run to pick a theme, and
we will pick some images around the theme so everything goes around it
between all games. So for example pixel garden show more and more details of
the image between difficulties instead of changing the whole picture, same
for button box, gumdrop, toy cannon". And, of a premade library: "daily
process will do exactly this, so we can just keep it running daily (and add
some supervisor to it so we can make sure the output is reliable)".

## What it is

Each UTC day has one theme, written by the night's process. The boards that
can take it deal around it; a board that cannot reach the day, or whose
piece of it was turned down, deals as it does today. Delivery is the
contract Golden Acorn set (`docs/agents/turns-and-backend.md`, "A day
written by a model"): `publishDay` makes today and tomorrow, a phone caches
the document, the shipped bank is the reserve. Nothing about that changes.

## Decided with the user

- **Live, not a library.** The process makes each day; the banks stay as the
  reserve and need not grow. A phone with no network gets an unthemed day.
- **Zoom out**, not the same picture sharper: a picture of a hundred squares
  cannot be a shrunken scene. Easy and Medium are single objects from the
  scene, Hard and Insane the scene itself.
- **Every board that can** follows the theme, built in the stages below.

## The theme document

`days/<day>/turns/theme`, made before any game's:

    {
      "v": 1,
      "id": "campfire",                      a slug
      "name": {"en": "...", "pt": "...", "es": "..."},
      "scene": "...",                        one paragraph, what the picture shows
      "objects": [{"id": "mug", "draw": "..."}, x3],
      "words": {"en": [...], "pt": [...], "es": [...]}
    }

The writer is told the themes of the days `recentDays` gives it (ten today;
stage 4 raises it for this document to sixty). The scene and the objects
are things a child knows and a flat drawing can show: one place, a few big
shapes, nothing written, nobody real.

## Pictures

`days/<day>/turns/pictures`, for Pixel Garden, Button Box and Toy Cannons,
which already share `content/pixel_garden.json`'s shape (`rows` of palette
letters):

| Size | Read by | Picture |
|---|---|---|
| 10 | Easy | object A |
| 12 | Medium | object B |
| 16 | Button Box's Hard | object C |
| 24 | Hard | the scene |
| 32 | Insane | the scene, finer |

A picture is `{"id", "name": {"en", "pt", "es"}, "rows"}`, under
`sizes["<size>"]`; a size not there is the bank's that day.

1. **Drawn** by an image model through OpenRouter, in one standing style:
   flat colours, a thick dark line, no shading, no text; an object alone on
   plain white, the scene filling a square. `generate.ts` gains a second
   caller, `draw()`, beside `ask()`: an image model is asked differently and
   answers elsewhere than `message.content`. Read off one real request on
   2026-10-13 (`google/gemini-3.1-flash-lite-image`, `modalities: ["image",
   "text"]`): the picture is `choices[0].message.images[0].image_url.url`, a
   `data:image/jpeg` of 1024 squared, `content` is null, and it cost
   US$0.034.
2. **Made into beads** by the dashboard's converter, which becomes one
   file, `tools/beads.js`: pure functions from RGBA bytes with a width and a
   height to `rows`, and the rules. No module syntax, a tail that exports
   where there is a `module`. `tools/build_dashboard.py` inlines it;
   `npm run build` copies it into `src/` as it does the banks, with
   `allowJs`. Each side brings its own bytes: the page a canvas, the server
   a decoder (`jpeg-js`, and `pngjs` for a model that answers in PNG: new
   dependencies, both pure JavaScript).
3. **Supervised**, three layers:
   - the bank's rules (`tools/check_pixel_garden.py`'s `check()`, in
     `beads.js`), in code. Button Box's Hard has no written rule: a 16 is
     held to what its thirty are, 6 to 7 colours and 34 to 66% filled;
   - a blind look: a model of another maker is shown the bead picture,
     enlarged, and never the drawing. Of a scene (24, 32) it says what it
     sees, and the picture is kept when that is the scene. Of an object
     (10, 12, 16) it is given the day's three objects and one that is not
     the day's, and picks: a mug of a hundred squares plays well and is
     named by nobody cold. Either way it also says if anything is wrong
     with it, and a picture it finds something in is not kept;
   - a reserve: three drafts a picture at the most (two days of four
     drawings must end inside the function's 1,800 seconds); a size whose
     drafts all fail is left out of the document, and the board deals that
     level from its bank.
4. `makeDay` never throws. No model: no document, and the day is the bank's.

## The other boards

- **Gumdrop**: replaced on 2026-10-14 by
  `2026-10-14-gumdrop-themed-jelly-design.md`: the night writes a jelly a
  mould from the theme's things, in the twenty-nine's own shapes. (It was:
  the theme writer names moulds out of `gumdrop_mould.gd`'s twenty-nine.)
- **Hidden Word, Word Trail**: the theme's words, kept only where the
  board's own dictionaries and lengths take them, in each language. Hidden
  Word takes one on Easy only: a known theme gives a harder answer away.
- **Golden Acorn, Pearl Dive**: two or three of a band's questions are on
  the theme; the spread of subjects stands.

## On the phone

A board that follows the theme reads `Backend.cached_day`, checks what it
reads by the same rules as the server, and otherwise deals as today. The
bead boards deal in `build()` now; they take Golden Acorn's deferred deal.
Where the theme's name is shown is not decided.

## Stages

1. **Theme, pictures and the supervisor, on this Mac, into the dashboard.**
   `node lib/cli.js themed <yyyymmdd> <days>` writes `tools/days/themed/`;
   the page shows each day's theme, the drawings, the beads and every
   verdict. No deploy, no game code. This is where the quality is judged,
   and what a day costs is read off it.
2. The bead boards read the day.
3. Gumdrop, the word boards, the quizzes.
4. `publishDay` gains `theme` and `pictures`; the deploy is the user's.
   Built 2026-10-14 as a second job, `themeDay` (themeday.ts), since the
   pixel pictures outrun one scheduled run; see
   `docs/agents/turns-and-backend.md`.

## Not known yet

Whether the drawings hold their style from day to day; how often the blind
look turns a good picture down, or passes a bad one; what a day costs.
Stage 1 answers all three before anything reaches a phone. A first sum of
the cost: four drawings a day at US$0.034, up to three drafts each, so
US$0.14 to 0.41 a day for the pictures, and cents for the text.
