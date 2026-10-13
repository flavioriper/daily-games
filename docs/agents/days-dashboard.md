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
