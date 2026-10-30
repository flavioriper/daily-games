# Roadmap: the slight rebrand

Started 2026-10-30. The user showed two reference screens (a streak screen
with a mascot on a podium over a one-hue ground, and a home screen with
chunky pill buttons and a raised centre tab) and asked for "a slight
rebrand ... stay cozy, more minimalist and modern". The visual proposal is
a Design canvas, private to the user:
https://claude.ai/artifact/NPCp6i48U6WNUtHQpq7aVk. Its "today" boards are
crops of `build/store_shots/*.png`; its Peeplets are the website's rendered
ones (`web/public/peeplets/*.webp`), never drawn.

Nothing here is built or specced. The order is the house one: the calls
below, then a spec under `docs/superpowers/specs/`, then the build in
phases, each shot on the phone's driver and inside the 855 draw-call
budget. The two reference apps are never named, in code or on screen.

## What the rebrand is, in one breath

The same brand, with less on the screen at once: one tint ground with a
faint motif, one pressable colour (the sun), flat surface cards with a
bottom edge and no ink outline, a bottom bar with Puzzles raised in the
middle, and the day's Peeplet as the one hero where a hero belongs.

## What stays (decided, not up for the pass)

- The name on screen is the DAILY / PUZZLES tiles, never a font
  (`docs/art/peeplet-brand.md`); the icon is untouched.
- Paper `f6efe3`, surface `fffdf8`, ink `3b3028`, dim ink `8a7b6b`, the
  sun `f5a623` with its edge `d88a12` (`core/palette.gd`); Fredoka for
  titles, Nunito for body.
- The Peeplet is the live model view (`ui/peeplet_view.gd`), the day's pair
  from `core/cast.gd`, never in the header, never hand-drawn.
- The first screen is pages of cards two across, sliding, with a pager;
  scrolling stays rejected (`docs/agents/first-screen.md`).
- The nightly vistas keep running whatever the ground call is; they move
  rather than go.
- Board art and faces keep their outlines; only the chrome loses them.

## Left out of the references, on purpose

Hearts, timers under icons, discount badges, six stacked side buttons and a
scene with two characters fighting over it. They are the opposite of
minimalist and were not taken.

## Decide first (the user's calls, open)

- [ ] **1. The ground.** One tint with a faint motif, by time of day
      ("Home · calm tint"), or the painting kept at the top of the first
      screen under a scrim ("Home · painting kept, under a scrim")? The
      first moves the day's painting into the Today card and the Streak
      screen; the second keeps the nightly pipeline on the first screen.
- [ ] **2. The bottom bar.** Five sections (Versus, Arcade, Puzzles raised,
      Factory, Streak) replacing the segmented strip under the header, or
      keep the strip and only flatten it?
- [ ] **3. Cards.** The board's own art as the card picture (shown on the
      canvas), or the painted card faces (`ui/menu/cards/`) with their
      outlines removed?
- [ ] **4. Streak as a hero screen.** The podium, the bubble, the count in
      sun and the week strip: right for the brand, or too close to the
      reference's voice? The month calendar stays one tap away either way.
- [ ] **5. How far into the boards.** Chrome only (top bar, stat row,
      tools, as on the Posy board), or the win screen and the sheets in the
      same pass?

## Phases (after the calls)

- [ ] **A. Tokens.** `ui/theme.gd` and `core/palette.gd`: the tint grounds
      (morning, afternoon, dusk, night), the surface card with a 3 px
      bottom edge and no outline, the tool tile with a 4 px edge, the round
      icon button, the primary pill with a 6 px edge and ink text. No drop
      shadows anywhere in the chrome. Every later phase reads these; none
      defines its own.
- [ ] **B. First screen.** `ui/menu.gd`, `ui/menu/menu_header.gd`,
      `ui/menu/day_row.gd`, `ui/menu/puzzle_card_2d.gd`,
      `ui/menu/pager_pill.gd`: the ground per call 1, tiles small in the
      header with the gold pill and settings beside them (gift, friends and
      shop move inside settings or the Today card), the Today card with the
      painting or the Peeplet per call 1, flat cards per call 3, the bottom
      bar per call 2. Re-fit the height budget in `_fit_grid`; the bar's
      height comes out of the pictures, as always. Measure draw calls at
      810x1440 before and after.
- [ ] **C. Streak.** `ui/menu/streak_tab.gd`: the hero per call 4, the week
      strip (done, today, rest-day leaf, the week's gift), best / days /
      rest under it, one pill. Stats stay where they are.
- [ ] **D. Board chrome.** The flat host (`ui/puzzle_host.gd`,
      `docs/agents/flat-screens.md`): the top bar as a title with a tracked
      caption, round back and help, the stat row as one surface with
      dividers, tool tiles, the field bleeding to the edges with its own
      world tint. One board first (Posy), then the rest by the shared
      shell, never board by board.
- [ ] **E. Win screen and sheets** (only if call 5 says so): the win
      report, the difficulty sheet, the remove-ads sheet, the options
      sheets, in the same tokens.
- [ ] **F. Opening and store.** The boot opening on the new ground; new
      store shots (`build/store_shots/`) and the website's phone shots
      (`docs/agents/website.md`) after the app is shot on a phone.

## Checks every phase owes

- `--resolution 810x1440 --always-on-top` harness shots on
  `--rendering-driver opengl3_angle`, draw-call counts quoted, two readings.
- Text through locale keys; pt and es rows for anything new.
- `Motion.reduce` honoured; the rest rules (`core/power.gd`) untouched.
- A phone look before the next phase starts; this Mac's shots decide
  nothing about feel.
