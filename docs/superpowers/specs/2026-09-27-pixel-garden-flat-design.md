# Pixel Garden, flat: the twenty-seventh board

A pegboard in a wooden tray on the garden table, a little picture propped in
the corner of the card, and a kit of beads in the picture's colours. **Copy
the picture onto the pegboard, bead for bead.** Pick a colour, tap a peg to
seat a bead or drag across pegs to seat a run; the finished picture is
ironed.

The reference is the user's mock of 2026-09-27 (a "Pixel Garden" screen: a
thumbnail of a garden bird, five colour chips with counts, a 42 / 80 bar, a
pegboard half beaded, Recomeçar and Conferir under it, Undo and a hint with a
badge of 3 up top). The name is the mock's. Fuse-bead kits are sold under
trademarks this repo does not use; the game says "beads" and "pegboard" and
nothing else.

Built in one sitting while the user was away, from the mock alone, without a
concept tab in `docs/brainstorm/concepts.html` first -- Super Slider's and
Marigold's precedent, recorded so it is not read as an oversight.

---

## 1. What is built

| File | What it is |
| --- | --- |
| `content/pixel_garden.json` | The bank: forty hand-drawn pictures, ten a band, in a fixed bead palette. |
| `puzzles/pixel_garden_state.gd` | The rules: the picture, the beads seated, the kit, strokes, undo, hint, check, reset. Scene-free. |
| `puzzles/pixel_garden2d.gd` | The board: header (picture, name, chips, bar) and pegboard in one card, the stroke, the peek, the iron. |
| `ui/faces/bead.gd` | The drawing -- peg, bead, halo, thumbnail pixel -- shared by the board and its menu card. |
| `core/palette.gd` | The board's colours (`PG_*`) and the nineteen bead colours (`PG_BEADS`). |
| `ui/registry.gd`, `locale/boards.csv`, `ui/menu/vistas.gd`, `ui/menu/card_art.gd` | The card: entry, strings (en/pt-BR/es, every picture's name included), banner vista, picture. |
| `tools/gen_sfx.py`, `assets/sfx/pixelgarden/` | Thirteen cues, one take each. |
| `tests/_win.gd`, `tests/_shot_anim.gd` | The harness hooks (`solve` shoots the iron). |

## 2. The rules

- The day's picture is an n x n grid; every cell is bare or wants one of the
  day's colours. The board is the same n x n of pegs.
- A chip is a colour. Tap a peg: an empty peg takes a bead of the chosen
  colour; a bead of another colour is swapped for it (the old bead goes back
  to the kit); a bead of the chosen colour is lifted. A drag carries that one
  decision over every peg it crosses -- seat, or lift if the peg it began on
  already held the chosen colour -- and is one move, one undo (Nonogram's
  stroke).
- **The kit holds exactly the beads the picture needs.** The number under a
  chip is how many are left; a colour at nought seats no more until one of
  its beads is lifted. This is the one rule beyond "copy it", and it is what
  makes a misplaced bead findable without a checker: a colour that runs out
  before its shape is done has a bead in the wrong place. The refusal says
  exactly that.
- The bar counts beads seated, right or wrong. **Nothing answers each bead**:
  a counter of *correct* beads would give the picture away one peg at a time.
- Solved the moment every peg is as the picture has it (bare where it is
  bare). With every bead seated and the board still wrong, a toast says so
  and points at Check.
- **Check** rings every bead that is out of place in rose and shakes it; the
  rings hold until the next move (Bridges' paid-for answer). The bead keeps
  its colour: on a board coloured by index no state may be a shade of the
  piece (CLAUDE.md, Pinwheel).
- **Hint** (three): puts one peg right and fuses it for good -- a bead out of
  place is lifted or turned the right colour, else a missing bead drops in.
  If the kit's last bead of that colour sits on a wrong peg elsewhere, that
  one goes back to the kit first. A fused peg refuses a stroke, with a toast.
- **Reset** returns every bead to the kit but the ones a hint fused.
- **Hold the picture** and it grows over the board, peg dots and all, until
  let go: the thumbnail is 212 px and a 16 x 16 needs reading.

## 3. The bands

| Band | Size | Colours | Pictures |
| --- | --- | --- | --- |
| Easy | 10 x 10 | 3-4 | 30 |
| Medium | 12 x 12 | 4-5 | 30 |
| Hard | 14 x 14 | 5-6 | 30 |
| Insane | 16 x 16 | 6-7 | 30 |

The day's picture is the next of one fixed shuffle of the band
(`State.day_pick`, since 2026-10-09; it was `rng.randi() % 10` over ten
pictures), so a band goes thirty days before a picture returns; New deals
the one after. Harder bands are richer
pictures, not bigger easy ones: outlines, highlights, and **close shades side
by side** (green, forest and lime; orange, red and yellow), since telling
them apart on a 212 px thumbnail is where the difficulty is. Insane is a
band of the bank like the others, not a provisional generator row.

The pictures are hand-drawn, never generated: a generated picture is noise,
and the reward of this board is the picture.

## 4. The screen

Quilt's shape: the pieces live in the board card, so `"tray": "none"`; the
actions row carries Reset and Check (the mock's Recomeçar and Conferir);
Undo and Hint ride in the top bar with the hint's badge.

The card is a header and a board. The header is `HEAD` 212 tall: the picture
on a little pegboard of its own (each pixel a rounded square with a hole,
each bare cell a peg dot, so pegs can be counted off it), and beside it the
picture's name, the chips in a row (a paper tile, a bead, a count pill; the
chosen one stands `CHIP_RISE` up with an ink rim; a spent colour's bead is
drawn faint), and the bar with its "seated / total". The board is the
largest square the rest of the card holds, pegs `MARGIN` 0.35 of a cell in
from a wooden tray `RIM` 18 wide. At 1080 x 1920 a peg is about 88 px on
Easy and 55 on Insane -- under Paper Planes' 58, but a peg is a target the
finger sweeps across rather than aims at one at a time.

## 5. Motion

A bead pops in with the squash where it is seated (a hint's drops in), pops
out when lifted; a refusal shakes the peg and the chosen chip; the bar bumps
on every change; the chosen chip bumps. Every recipe is `core/motion.gd`'s.

**The iron is the signature.** On the solve the beads hop in the family's
wave along the diagonal; at `IRON_AT` 0.55 s a warm band crosses the board
from the top left, `IRON_STEP` 0.045 s a diagonal, and each bead fuses over
`IRON_TIME` 0.3 s -- its hole closes to a dimple, a gloss comes up and a glint
passes -- and the bare pegs fade over `PEGS_GONE` behind it, so the picture is
left standing as one ironed thing. The `iron` cue plays as the band sets off.

## 6. Drawing

Four meshes and some text: the table (card, tray, board, every peg; built
once a layout and while the pegs fade), the head (picture, chips, bar;
rebuilt when the kit or the chosen colour changes or a chip moves), the
still beads in bands of four rows (Hedgehogs' `_band_looks`, so a stroke
rebuilds its own rows), and a live mesh (moving pegs, leaving beads, halos,
the hint's ring, the iron's band). The picture's pixels are their own mesh,
so the peek grows it over the board by a transform alone.

## 7. Figures

Taken on this Mac (`--resolution 810x1440`, `--always-on-top`), 2026-09-27:

- `tests/_shot_anim.gd -- pixelgarden d=0..3` (a stroke along the longest run
  of the chosen colour): **77, 78, 78, 77** draw calls, idle 3.41, 3.56,
  3.39, 3.42 ms -- the size of the board costs nothing measurable, because
  the pegs are one still mesh and the beads are banded.
- `-- pixelgarden solve` (the iron): **101-103** draw calls at its peak,
  3.06-3.15 ms once it has settled.
- `--rendering-driver opengl3_angle`: the same 78, settled frame within 1/255
  of the default driver's. `rm`: the pair 1.5 s apart is pixel-identical.
- `tests/_win.gd -- pixelgarden`: PASS through real touches (hint, check, a
  wrong bead seated and lifted, every colour).
- The picture bank's validator (size, 3-7 colours by band, 30-70% filled,
  never touching all four edges) passes on all forty. Pale beads (cream,
  white) nearly vanish on the board in bulk, so they are kept to small or
  outlined areas; the bead's darker rim is what keeps them readable. The
  squirrel, caterpillar and sheep are the weakest pictures and the first to
  redraw.

## 8. Amendments

**Hollow beads (2026-09-27, the user's note).** A bead is a tube that fits
over its peg, and the drawing has to say so: the hole goes right through,
showing the board down it in the bead's shade, the far wall as a dark
crescent along its top, and the peg's lit top poking up through the middle.
A chip's or a loose bead's hole shows the paper or table under it, with no
peg. Ironing melts the tube shut round the peg to a dimple.
