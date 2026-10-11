# Gumdrop as a daily board

2026-10-11. The user: "i want you to convert gumdrop into a daily game not
arcade". Two calls made in chat the same morning: a day is **a set of moulds
per band**, and the board is **the full-screen table with the daily chrome
over it**. Then "all good, build it" over the design below. No concept tab:
the look and the pour are the built screen's, unchanged.

The pour, the fluid, the colour maths, the judge and the hidden match are
`2026-10-10-arcade-gumdrop-design.md`, sections 9 and 10, and stay as they
are. This spec is what changes around them.

## 1. The day

Gumdrop is the thirty-sixth card on the Puzzles grid (`Registry.PUZZLES`,
id `gumdrop`, `pick_difficulty`), each band its own daily with its own done
mark. A band's moulds are dealt from the day's seed by
`Mould.day(band, rng)`, the same for everyone, easiest first.

| Band | Moulds | Designs (rows of `DESIGNS`) | Flavours | Mark |
|---|---|---|---|---|
| Easy | 2 | 0 to 5 (2 or 3 cells) | 2, none mixed | 60 |
| Medium | 3 | 3 to 10 (3 to 5 cells) | 3, none mixed | 65 |
| Hard | 4 | 8 to 16 (4 to 6 cells) | 3 or 4, one mixed from two pots | 70 |
| Insane, Three Pots | 5 | 13 to 23 (5 to 9 cells) | up to 5; only cherry, lemon and blueberry stand by the tray | 75 |

- A mould served at or over the mark is taken away and the next is set
  down; the last one served is the day solved.
- **Easy to Hard cannot be lost**: a mould under the mark shows its number,
  is emptied and poured again. Reset empties the mould on the tray.
- **Insane counts serves** (`docs/agents/flat-screens.md`, "Insane counts
  moves"): the budget is the moulds and one more (`Sim.SLACK`). A serve
  costs one whatever it scores. Under the mark with fewer serves left than
  moulds is the day lost: the out-of-moves card, whose video buys one more
  serve, once. Reset is the day from its first mould with the serves back.
  The user picked "under the mark loses the day"; one spare serve was put
  to them in the design ("say zero and it is zero") and stood.
- No Undo, Hint or Check on any band: Serve is the check, and the match is
  a `?` until it is pressed.
- The arcade run is gone: no level ramp, no rising mark, no score, no
  perfect bonus, no best, no Second chance, no gold doubler. The win's
  line reads the time and the serves (as moves).

## 2. The host's full-bleed mode

`"bleed": true` on a registry entry (with `tray: "none"`, `actions: false`),
for any board whose world fills the screen (CLAUDE.md, the 2026-10-10
rule):

- The board is laid full rect under the host's rows, not in the card slot.
  No backdrop plate and no board card; the paper page stays under it.
- The host's margins and its column ignore the pointer, so the board takes
  every touch its rows do not.
- The host tells the board what its rows cover: `set_clear(top, bottom,
  won)`, in the board's own pixels, at the spawn, when the insets change and
  once at the win with the win's slots. The board is never frozen and
  scaled for the win's slide; it moves itself into the span.
- Everything else is the flat host's as it is: the top bar, the day card,
  the tutorial, the win screen, the done mark, the streak, the gold, the
  analytics.

## 3. Files

- `arcade/gumdrop_{sim,mould,art,fluid}.gd` move to `puzzles/`. Shaders stay.
- `puzzles/gumdrop_table.gd`: the table as a Control (field, syrup, top,
  the fluid's drive, the fingers, the stickers), from the arcade screen.
  The board and the tutorial's `Bench` both use it.
- `puzzles/gumdrop2d.gd` (`core/puzzle_base.gd`): the day, the serves, the
  out-of-moves card, the done day, the tutorial's pages.
- `puzzles/gumdrop_sim.gd` keeps the tip, the pots, the colour maths and
  `judge()`; its run is the day's list of moulds.
- `arcade/gumdrop_screen.gd` is deleted.

## 4. The win and the done day

On the win the pots, the buttons, the dropper and the card fade and the
tray slides to the middle of the span the host leaves, under one
transform (no mesh is rebuilt). The record is each mould's match
(`{"pct": [...]}`). The fluid cannot be saved, so a finished day reopened
shows its last mould filled flat in the card's colours (the tutorial's
prefill) with the day's numbers under it.

## 5. Leaving Arcade

The Arcade tab is ten cards again. Softer jelly and Kinder marks are
removed; held ones (and the older two) come back as gold when the board
opens. The best-moulds record is dropped.

## 6. Checks

No new tests. `tests/_probe_gumdrop.gd` follows the sim to the day (a
hand-answered judge); the suite's parse guard walks the registry;
`tests/_shot_gumdrop.gd` plays a band through the host on `opengl3_angle`
at 810x1440 with real touches, for the draw calls, the win and the done
day.
