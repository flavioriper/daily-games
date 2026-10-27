# Agent guidelines

## The game is 2D only

**The 3D game was removed on 2026-09-24** (`feat/remove-3d`): `legacy/` (the
thirteen island boards, the campsite, How Big?, the stage, the toon and model
pipeline, the island HUD), `assets/models/`, the 3D shaders, every `art/*.blend`
and the Blender export tools, and the More tab that reached them. Git history
has all of it. Nothing in the game loads a model or a `World3D` now, and a new
board is drawn in 2D like the other twenty. The Blender rules that used to open
this file went with it; if a model ever comes back, recover them from history
(`docs/art/blender-contract.md` is still in the tree).

**One exception, the Peeplet** (the user, 2026-10-23 and 2026-10-27): the
real Peeplet is a 3D model shown flat through `ui/peeplet_view.gd`, each a
SubViewport with its own `World3D`. Who Ate the Pie?'s bakers (up to twenty
on Insane, `peeplet/peeplet_personas.gd`) and its menu card use it; nothing
else does. Never redraw a Peeplet by hand or bake it to an image.

## Boards that left

**Balance, Code Break, Tents, One Line and Mushroom Patch were removed on
2026-10-13** (the user: "we need to remove some games not so good"): their
boards, worlds, generators, cards, tutorials, sounds, Insane banks, tests,
locale rows and notes. Git history has all of it; older notes and comments
still name them as precedents, and nothing loads them. The ids were
`balance`, `mastermind`, `tents`, `oneline` and `mushroom`; a player's saved
progress under them is simply never read. `ui/hud/out_of_rows.gd` and the
`HTP_TN_HINT*` / `HTP_TN_HEARTS` tutorial captions were theirs first and are
still used by other boards, under their old key names.

**Marigold moved to the Arcade tab the same day** (`Registry.ARCADE`): the
same daily board with its levels, its card in the Arcade list
(`docs/agents/boards/marigold.md`). `Registry.PUZZLES` is the grid's
thirty-two; `Registry.all()` is every board.

## Where the detail lives

This file holds the rules every change needs. Everything else -- each
screen's history, measurements and the reasons behind its decisions -- was
moved word for word into `docs/agents/` on 2026-09-29, when this file passed
Claude Code's 150k-character limit. **Read the matching file before touching
that area**, and add new history there rather than here.

| Area | File |
|---|---|
| Harness flags and what they measure | `docs/agents/harnesses.md` |
| The opening: the boot scene, the launch colours, the handover to the first screen | `docs/agents/opening.md` |
| First screen: menu, cards, pager, header, Stats/Streak, registry | `docs/agents/first-screen.md` |
| Flat boards: shared rules, motion, shell, trays, faces, meshes | `docs/agents/flat-screens.md` |
| One board's own notes | `docs/agents/boards/<board>.md` |
| Versus (snooker, chess, checkers, air hockey, Toy Boats, Penny Drop, Dominoes, Reversi) | `docs/agents/versus.md` |
| Friends: the link, codes, invites, a friend's game | `docs/agents/friends.md` |
| Arcade (Firefly, Molehill, Stackwood, Lucky Thirteen, Posy, Peapod, Nightlight, Beeline, Deckchair, Eddy, Furrow, Griddle, Trivet, Tally, Bagatelle; Factory and Marigold have cards there too) | `docs/agents/arcade.md` |
| Factory: the land, the sim, the one-sim rule (and the dropped Valley and Grove, as history) | `docs/agents/factory.md` |
| Gold, gifts and the shop | `docs/agents/gold-gifts-shop.md` |
| Sound | `docs/agents/sound.md` |
| Haptics: the kinds, the rules and the per-game list | `docs/agents/haptics.md` |
| Art, buttons, sheets, dialogs | `docs/agents/art-and-ui.md` |
| Android build | `docs/agents/android.md` |
| Analytics events | `docs/agents/analytics.md` |
| Ads, age gate, remove-ads purchase | `docs/agents/ads-and-purchase.md` |
| Backend, Firestore, functions, locale | `docs/agents/turns-and-backend.md` |
| CI | `docs/agents/ci.md` |
| The day documents and the quality dashboard (`day_dict()`, `tools/export_days.gd`) | `docs/agents/days-dashboard.md` |
| The board checkup (perf, tutorial, ?, undo/reset), the Versus and Arcade tutorials, and where it stands | `docs/agents/checkup.md` |

## Rules that apply everywhere

- **Harnesses**: `--resolution 810x1440` (never `1080x1920`), written
  *before* `--script`, and `--always-on-top`. A menu card measuring ~372
  wide means the flag landed after `--script`. Run windowed harnesses one at
  a time and quote the second of two readings; a single ms reading off this
  Mac is worth nothing, draw-call counts are.
- **Budget: 855 draw calls.** gl_compatibility pays per `draw_*` command:
  bake a drawing into one `ArrayMesh` and issue it as one `draw_mesh`. Keep
  the mesh a `_draw` handed over (`_shown`) until the next replaces it. A
  look that only moves is a cached mesh under a transform, not a rebuild.
- **Check the phone's driver**: `--rendering-driver opengl3_angle`; no
  `instance uniform` anywhere (garbage on Android past 16 instances).
- **Sound** (the user, 2026-10-15: "amazing sounds"): an action is a pop
  from `tools/sfx_bank/`, named in a cue's row with `bank:<name>`. The
  token is a button or a thing set down, the wrap anything repeated, the
  pebble a select, the lip a thing taken off, the tongue a refusal, and
  the jar coin money. Never the old mouse-wheel tick. A run of pops rides
  the motion it sounds. Swipes stay breezes and moments stay muffled
  notes. Read "The house sound" at the top of `docs/agents/sound.md`
  first.
- **Motion** comes from `core/motion.gd` and `docs/art/flat-motion.md`;
  rings, puffs and sparkles from `ui/fx2d.gd`. A board keeps only its own
  signature constants. Honour `Motion.reduce`.
- **Characters are code, never images** (`ui/faces/`). Check there before
  drawing a new one. A board whose pieces are marks gets no mascot.
- **On a board whose pieces are coloured by index, no state may be signalled
  by a shade of the piece's own colour** (halo, hatch or ring instead).
- **Renamed genres**: a board never uses the name of the game it follows, in
  code, comments, commits or on screen (Hidden Word, Word Trail,
  Bridges, Quilt, Paper Planes, Pinwheel, Caterpillar, Sunbeam, Knight,
  Hedgehogs, Marigold, Drumbeat, Trestle, Horse Pen, Firefly, Molehill,
  Stackwood, Lucky Thirteen, Posy, Peapod, Nightlight, Beeline, Deckchair, Eddy, Furrow, Griddle, Trivet, Tally, Bagatelle, Gumdrop, Grove, How Big?, Golden Acorn, Pearl Dive, Lattice, Sand Sweep, Toy Boats, Penny Drop, Jewel Box, Toy Cannons, Yarn Hoop, Glimpse, Birdsong, Domino Patio, Teacups, Picket Sums, Market Sums, Who Ate the Pie?, Hosepipes, Honeycomb, Paper Box, Four Shelves, Five Clues). The spec names the original once, to
  forbid it.
- **A game's world fills the screen** (the user, 2026-10-10, of Eddy: "the
  screen should fit everything, just like the factory does, it's gonna be a
  pattern from now on"): the field is laid full rect, edge to edge, and
  the top bar, plates and controls lie over it, as `factory/screen.gd` and
  `arcade/eddy_screen.gd` do. No paper page with the game in a frame. A
  daily board asks the flat host for it with `"bleed": true` in the
  registry (Gumdrop, Jewel Box, Toy Cannons; `docs/agents/flat-screens.md`).
- **A new board** is a `Registry.PUZZLES` entry; the suite's parse guard walks
  the registry. `godot --headless --check-only --script puzzles/<board>2d.gd`
  before a harness. Text goes through locale keys (`locale/ui.csv`,
  `locale/boards.csv`); counts are `_ONE`/`_N` pairs; titles stay English.
- **Harness hygiene**: poke on one frame, `force_draw()` on the next; a
  harness puts `user://versus.cfg` / `arcade.cfg` back on every exit path;
  mouse events are in window coordinates; send the release after a press.
- **`Analytics.start()`, `Backend`, `Ads.start()` run only from
  `world/main.gd`**, so tests and harnesses stay offline and ad-free.
- **The game rests** (`core/power.gd`, 2026-10-22): twenty seconds
  without a touch stop every face's idle and pause every forever-looping
  tween, cap the frame at 30 and skip unchanged draws; a minute closes the
  friends stream. A looping look that must run at rest is a `_process`,
  not a looping tween or a face idle. `Power.start` skips
  `--script` runs, so a harness never measures a resting game.
- **After merging a parallel branch**, diff the merge against both parents:
  git has merged boards into parse errors and dropped registry entries
  without a conflict.
- **Push to `main` runs CI** (`.github/workflows/android.yml`): tests, APK,
  Firebase App Distribution. Scripts that grant roles or deploy to
  production (`tools/*_identity.sh`, `tools/deploy_functions.sh`) are run by
  a person.
