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

## Where the detail lives

This file holds the rules every change needs. Everything else -- each
screen's history, measurements and the reasons behind its decisions -- was
moved word for word into `docs/agents/` on 2026-09-29, when this file passed
Claude Code's 150k-character limit. **Read the matching file before touching
that area**, and add new history there rather than here.

| Area | File |
|---|---|
| Harness flags and what they measure | `docs/agents/harnesses.md` |
| First screen: menu, cards, pager, header, Stats/Streak, registry | `docs/agents/first-screen.md` |
| Flat boards: shared rules, motion, shell, trays, faces, meshes | `docs/agents/flat-screens.md` |
| One board's own notes | `docs/agents/boards/<board>.md` (Code Break: `code-break.md`) |
| Versus (snooker, chess, checkers) | `docs/agents/versus.md` |
| Friends: the link, codes, invites, a friend's game | `docs/agents/friends.md` |
| Arcade (Firefly, Molehill, Stackwood, Lucky Thirteen, Posy, Peapod) | `docs/agents/arcade.md` |
| Valley: the shared inventory (`Stock`) and the Grove | `docs/agents/valley.md` |
| Gold, gifts and the shop | `docs/agents/gold-gifts-shop.md` |
| Sound | `docs/agents/sound.md` |
| Haptics: the kinds, the rules and the per-game list | `docs/agents/haptics.md` |
| Art, buttons, sheets, dialogs | `docs/agents/art-and-ui.md` |
| Android build | `docs/agents/android.md` |
| Analytics events | `docs/agents/analytics.md` |
| Ads, age gate, remove-ads purchase | `docs/agents/ads-and-purchase.md` |
| Backend, Firestore, functions, locale | `docs/agents/turns-and-backend.md` |
| CI | `docs/agents/ci.md` |
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
- **Motion** comes from `core/motion.gd` and `docs/art/flat-motion.md`;
  rings, puffs and sparkles from `ui/fx2d.gd`. A board keeps only its own
  signature constants. Honour `Motion.reduce`.
- **Characters are code, never images** (`ui/faces/`). Check there before
  drawing a new one. A board whose pieces are marks gets no mascot.
- **On a board whose pieces are coloured by index, no state may be signalled
  by a shade of the piece's own colour** (halo, hatch or ring instead).
- **Renamed genres**: a board never uses the name of the game it follows, in
  code, comments, commits or on screen (Code Break, Hidden Word, Word Trail,
  Bridges, Quilt, Paper Planes, Pinwheel, Caterpillar, Sunbeam, Knight,
  Hedgehogs, Marigold, Drumbeat, Trestle, Firefly, Molehill, Stackwood, Lucky
  Thirteen, Posy, Peapod, Grove). The spec names the original once, to forbid it.
- **A new board** is a `Registry.PUZZLES` entry; the suite's parse guard walks
  the registry. `godot --headless --check-only --script puzzles/<board>2d.gd`
  before a harness. Text goes through locale keys (`locale/ui.csv`,
  `locale/boards.csv`); counts are `_ONE`/`_N` pairs; titles stay English.
- **Harness hygiene**: poke on one frame, `force_draw()` on the next; a
  harness puts `user://versus.cfg` / `arcade.cfg` back on every exit path;
  mouse events are in window coordinates; send the release after a press.
- **`Analytics.start()`, `Backend`, `Ads.start()` run only from
  `world/main.gd`**, so tests and harnesses stay offline and ad-free.
- **After merging a parallel branch**, diff the merge against both parents:
  git has merged boards into parse errors and dropped registry entries
  without a conflict.
- **Push to `main` runs CI** (`.github/workflows/android.yml`): tests, APK,
  Firebase App Distribution. Scripts that grant roles or deploy to
  production (`tools/*_identity.sh`, `tools/deploy_functions.sh`) are run by
  a person.
