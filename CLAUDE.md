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
on Insane, `peeplet/peeplet_personas.gd`) and its menu card use it,
Teacups' friends and its card do too (the user, 2026-10-29), and the
day's pair (`core/cast.gd`) sits on Hidden Word's card and reveal, Streak's
Today card, the remove-ads sheet and the boot opening; nothing else does,
never the header. Never redraw a Peeplet by hand or bake it to an image.
(The chess sets made of models were a second exception until Versus left on
2026-11-03.)

**The baked Peeplets** (2026-10-27): `server/functions/assets/peeplet_sheet.png`,
the reference the night's painter and reviewer are given. It is rendered by
`tests/_shot_peeplet_sheet.gd`, never hand-edited, never on a phone
(`docs/art/peeplet-brand.md`). The website's eight (2026-10-30, the user's
call) are the same kind of thing: `tests/_shot_site_peeplets.gd` renders
them, `web/scripts/gen_games.py` cuts them, nobody draws or edits one
(`docs/agents/website.md`).

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

**Marigold moved to the Arcade tab the same day** and left the game with
Arcade on 2026-11-03 (below). `Registry.PUZZLES` is the grid and
`Registry.all()` returns it.

**Sand Sweep, Domino Patio, Gumdrop, Knight, Drumbeat and Trestle were removed
on 2026-11-02** (the user: "let's remove some games not so popular"): their
boards, cards, tutorials, sounds, shaders, banks, tools, tests, 492 locale rows
and notes. Git history has all of it. The ids were `train`, `patio`, `gumdrop`,
`knight`, `drumbeat` and `trestle`; saved progress under them is simply never
read. Kept because others use them: `ui/menu/cards/drumbeat.gd` (Birdsong's
card extends it), `ui/faces/drumbeat_parts.gd` (Birdsong); `chess_piece.gd` and
`domino_tile.gd` went with Versus on 2026-11-03. Paper Planes now
owns the colour `FAMILY` it borrowed from Sand Sweep. The server still accepts
Trestle's scores (`SCORED`, `server/functions/src/index.ts`) because store builds
still send them.

**Versus, Arcade, Factory, Friends and Marigold were removed on 2026-11-03**
(the user: "wipe multiplayer and arcade from this app, we gonna only keep the
daily puzzle ones"; Marigold went with Arcade by the user's call). The
state before is on the remote branch `archive/pre-daily-only-2026-11-03`
(9c7ca5d9). Gone: `versus/` (snooker, chess, checkers, air hockey, Toy Boats,
Penny Drop, Dominoes, Reversi, online play), `arcade/` (Firefly, Molehill,
Stackwood, Lucky Thirteen, Posy, Peapod, Nightlight, Beeline, Deckchair, Eddy,
Furrow, Griddle, Trivet, Tally, Bagatelle, Brittle, the boosters, Second
chance, the gold doubler), `factory/`, Marigold's board, `core/social.gd` and
`core/deep_link.gd` (friends and their links), the Versus/Arcade/Friends/shop
sheets and tabs, their cards, tutorial diagrams, sounds and `gen_sfx.py`
families, harnesses, 1,762 locale rows, notes and the website's cards.
`arcade/rewards.gd` moved to `ui/rewards.gd` (Paper Box and Untangle use it).
The categories row holds only Puzzles, the way back from Streak and Stats.
Gold is still earned on the boards and from the gifts (the calendar is gold
only now) but nothing spends it. The server was not touched: store builds
still send Versus turns, friends and Tally scores, so the rules and
functions stay until those builds are gone. Older notes still name all of
it as precedent.

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
| Gold, gifts and the shop | `docs/agents/gold-gifts-shop.md` |
| Sound | `docs/agents/sound.md` |
| Haptics: the kinds, the rules and the per-game list | `docs/agents/haptics.md` |
| Art, buttons, sheets, dialogs | `docs/agents/art-and-ui.md` |
| The website (`web/`) | `docs/agents/website.md` |
| Android build | `docs/agents/android.md` |
| Analytics events | `docs/agents/analytics.md` |
| Ads, age gate, remove-ads purchase | `docs/agents/ads-and-purchase.md` |
| Backend, Firestore, functions, locale | `docs/agents/turns-and-backend.md` |
| CI | `docs/agents/ci.md` |
| The day documents and the quality dashboard (`day_dict()`, `tools/export_days.gd`) | `docs/agents/days-dashboard.md` |
| The board checkup (perf, tutorial, ?, undo/reset) and where it stands | `docs/agents/checkup.md` |

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
  Bridges, Quilt, Paper Planes, Pinwheel, Caterpillar, Sunbeam,
  Hedgehogs, Marigold, Horse Pen, Firefly, Molehill,
  Stackwood, Lucky Thirteen, Posy, Peapod, Nightlight, Beeline, Deckchair, Eddy, Furrow, Griddle, Trivet, Tally, Bagatelle, Brittle, Grove, How Big?, Golden Acorn, Pearl Dive, Lattice, Toy Boats, Penny Drop, Jewel Box, Yarn Hoop, Glimpse, Birdsong, Teacups, Picket Sums, Market Sums, Who Ate the Pie?, Hosepipes, Honeycomb, Paper Box, Four Shelves, Five Clues, Cross Stitch, Padlock). The spec names the original once, to
  forbid it.
- **A game's world fills the screen** (the user, 2026-10-10, of Eddy: "the
  screen should fit everything, just like the factory does, it's gonna be a
  pattern from now on"): the field is laid full rect, edge to edge, and
  the top bar, plates and controls lie over it. No paper page with the game in a frame. A
  daily board asks the flat host for it with `"bleed": true` in the
  registry (`docs/agents/flat-screens.md`).
- **A game screen is laid as the daily boards** (the user, 2026-10-31: "wire
  UI layout properly, make it a rule, using daily ones"), every screen
  touched from now on: the world full rect (a
  mesh on a `_world` Control; `Scenery.planks` is the wooden floor), then on
  the 40 margin `FlatTopBar.new(title, motto, true, false, true)` and its tools
  row, Undo, the bin, a paper pill where the row's gap is (`_build_tools`:
  what the game counts) and the bulb, greyed where a game has none, then
  plates if any, then the field `SIZE_EXPAND_FILL`. The bin asks. No
  `Vistas.board_plate`, no paper page, no framed deck, and a game's own
  buttons stand above its board.
- **A new board** is a `Registry.PUZZLES` entry; the suite's parse guard walks
  the registry. `godot --headless --check-only --script puzzles/<board>2d.gd`
  before a harness. Text goes through locale keys (`locale/ui.csv`,
  `locale/boards.csv`); counts are `_ONE`/`_N` pairs; titles stay English.
- **Harness hygiene**: poke on one frame, `force_draw()` on the next; ;
  a harness puts back any `user://` save it touches on every exit path;
  mouse events are in window coordinates; send the release after a press.
- **`Analytics.start()`, `Backend`, `Ads.start()` run only from
  `world/main.gd`**, so tests and harnesses stay offline and ad-free.
- **The game rests** (`core/power.gd`, 2026-10-22): twenty seconds
  without a touch stop every face's idle and pause every forever-looping
  tween, cap the frame at 30 and skip unchanged draws; a minute was when the
  friends stream closed, before Friends left. A looping look that must run at rest is a `_process`,
  not a looping tween or a face idle. `Power.start` skips
  `--script` runs, so a harness never measures a resting game.
- **After merging a parallel branch**, diff the merge against both parents:
  git has merged boards into parse errors and dropped registry entries
  without a conflict.
- **Push to `main` runs CI** (`.github/workflows/android.yml`): tests, APK,
  Firebase App Distribution. Scripts that grant roles or deploy to
  production (`tools/*_identity.sh`, `tools/deploy_functions.sh`) are run by
  a person.
