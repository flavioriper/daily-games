## The opening

**The game opens on an animation since 2026-10-06**, not on black (the user:
"create a cozy good looking animation for the game opening (instead of a
black screen)"). Three things made the black, and each has its own answer:

| What was black | Why | Now |
|---|---|---|
| The window behind the engine, on Android | `GodotAppMainTheme`'s `windowBackground` was `#000000` | `screen/background_color` in the Android preset, the icon's cream `#fcf5e9` |
| The engine's own first frames | `boot_splash/show_image=false` over the default dark `bg_color` | `boot_splash/bg_color` is the same cream |
| The wait for the first screen | `world/main.tscn` was the first scene, and nothing draws until every board it preloads is read: 1.6 s on this Mac, more on a phone | `world/boot.tscn` is the first scene; it draws the opening and loads `main.tscn` on a thread |

On iOS the launch storyboard took Godot's own logo (an empty
`boot_splash/image` falls back to it in the exporter): the iOS preset now
gives it `assets/icon/launch_blank.png`, a sheet of the same cream, scaled to
fill. Nothing iOS has been built or run since.

So the screen is one colour from the tap on the icon to the first tile: the
system's splash (the icon on its own cream), the window, the engine's clear,
the opening's ground. That cream is `Opening.GROUND`; change it in all four
places or not at all.

### What plays (`ui/opening.gd`)

**Since 2026-10-27 the grid, the sprout, the lettered word and the sun are
gone: the opening lays the twelve DAILY / PUZZLES tiles, see "The tiles"
below.** The two sections after this one keep the history of the nine-tile
opening (its order, puff, hop, 42 draw calls and the numbers measured under it).

The app icon coming together: the grid is built a tile at a time (since
2026-10-15, below), the sprout grows out of the middle one and its two leaves fall open, `Daily`
is lettered under it a letter at a time with the sun-dot last, and warm motes
drift up through it (round lights with no shape, never rays or sparkles).
Then it waits: the leaves sway and a ripple runs over the tiles every 2.6 s,
for as long as the load takes. Leaving, the tiles pop out in the run they
came in, the word lifts off and the ground thins over 0.5 s.

- One Control, one clock (`clock`), every beat read through `core/motion.gd`'s
  curve readers; every piece a mesh built once in `_init` and drawn under a
  transform. **42 draw calls** settled, on both drivers.
- The light on the paper is a shader (`shaders/opening_ground_2d.gdshader`)
  because a light that wide and that faint banded as a mesh; it carries a
  grain under one level. No instance uniform.
- `SETTLED` (1.7 s) is the soonest it is taken off unasked. A tap asks to be
  let through and is honoured once the game has loaded and 0.6 s have gone
  (a finger still down from the icon is not a skip).
- Reduce motion: it stands finished from the first frame, is held 0.8 s at
  least, and leaves in one plain fade of `Motion.REDUCED_TIME`.
- It had one sound from 2026-10-09: `ui`'s `opening`, tiles set down and
  two kalimba notes in one take from the first frame, synced to nothing.

### The tiles (2026-10-27)

The rebrand (Daily Puzzles, the Peeplet as its character) puts the app icon's
two words on the first screen's header (`ui/menu/word_tiles.gd`, `WordTiles`),
and the opening lays those same twelve tiles in place of the 3x3 grid, the
sprout, `Daily` and the sun. `Opening` has one `WordTiles` child (tile
`WORD_TILE` 108 at 1080, scaled by `u`, centred on the screen) and sets its
`shown`: a tile appears in reading order every `TILE_STEP` 0.085 s from
`TILE_AT`, when it is down (`touch_at`, 0.37 of `TILE_TIME`), with its puff
of light behind it, `landed(rank)` (ranks now 0..11) and a 1.2% settle of the
whole word. `WordTiles.shown` is whole tiles, so a tile *appears*; the drop,
the squash and the shadow of the nine-tile grid are gone with it.

- **The ripple** every 2.6 s (after `SETTLED`) is the puff's light run from
  tile to tile, 0.06 s apart, fainter; the tiles themselves do not hop.
- **Leaving**: `shown` falls one tile every `LEAVE_STEP` from the last, the
  run they came in reversed (the first screen takes the cream as before).
- **Reduce motion**: all twelve and the Peeplet from the first frame (the
  Peeplet on the second step), held `HELD`, one plain fade out.
- `SETTLED` is `TILE_AT + 12 * TILE_STEP + TILE_TIME + 0.4` = 1.84 s (was 2.05).
- **Sounds**: `world/boot.gd` is unchanged. `landed` now fires twelve times,
  so the pop's pitch climbs `11 * POP_STEP` = 5.5 semitones (was 4); the
  cozy rules' five at most is passed by half a tone and **no one has
  listened**: lower `POP_STEP` to 0.45 if it reads high. `bloomed` (the
  kalimba notes, `COZY_TUNE`) is now said as the Peeplet pops up
  (`peeplet_at()`, as the twelfth tile is down) since the leaves are gone.
- **The motes** stay, all behind the tiles now (the tiles are a child
  control and draw after the opening's own `_draw`).
- **The Peeplet** (`Cast.persona(0)`, `idle_fps 0`, `frame_height 0.88`,
  `aim_y 0.46`, a held portrait) is built when its cue passes, by a lazy
  `load` of `ui/peeplet_view.gd` and `core/cast.gd` (no new preload), and
  stands behind the tiles' top edge, feet 60 px under them: it pops up from
  its feet (`pop_in_scale`, rising 60 px with `Motion.drop_in_lift`) and
  shrinks back down as they leave. Measured on this Mac, opengl3_angle,
  second of two: `load` of the script 57 ms, `new` + dress 9 ms, the first
  `_rebuild` ~55 ms, so 121 ms to a built walker (under the 150 ms line) and
  67 ms more to its first draw (a 3D SubViewport's first render). It lands
  as one long frame (about 190 ms) just after the twelfth tile; the clock
  waits (`MAX_STEP`) so nothing jumps. It made the cut. **The phone's number
  is owed.**
- **Draw calls**: 27 settled (`tests/_shot_opening.gd`, second reading the
  same), the Peeplet one of them; the opening with the first screen under it
  reads 133 at most (`boot time`, was 148 with the nine-tile opening).
- **Boot cost, not paid yet.** `WordTiles` preloads the Hidden Word board
  (`puzzles/hidden_word2d.gd`, for four constants), and a cold `load` of that
  is 211 ms here. The opening references `WordTiles`, so `opening.gd` now
  takes ~190 ms longer to load before its first frame (`opening _init` at
  ~870 ms of engine time, was ~690) on this Mac, and every phone is slower.
  The load of the game under the opening is unchanged (3.07 s and 3.20 s,
  was 3.20 s and 3.22 s), the window is cream the whole while and the first
  tile comes that much later. The cure is in `word_tiles.gd` (the four board
  constants copied, or moved to a light script), not here; measure again
  after it.
- **Seen**: the shot harness (`tests/_shot_opening.gd`, stills and leaving)
  and one run of the game itself to the first screen (nothing in the log);
  the lay-down on screen, the pops with sound and the phone are unseen/unheard
  by the user.

### The grid built one by one (2026-10-15)

The user: "We need a better initial animation, some pop sounds with the
grid being build one by one". Where the nine came in along the diagonals
0.05 s apart (a blur, three at a time), they come round the edge clockwise
from the upper left, 0.085 s apart, and the cream middle one 0.06 s after
the eighth (`ORDER`, `TILE_STEP`, `MIDDLE_LAG`). Each pushes a puff of pale
light out from under it as it lands (`PUFF`, the `_soft` mesh grown and
thinned over 0.42 s, one draw while it lasts), and when the middle lands the
edge hops for it, the four beside it first and the corners 35 ms after
(`DONE_HOP`). The sprout, leaves, letters and sun moved 0.36 to 0.44 s later
with it; `SETTLED` is 2.05 s (was 1.7).

- **The sounds.** `ui/opening.gd` stays silent: it says `landed(rank)` as a
  tile first touches the paper (`touch_at`: `TOUCH` 0.37 of its drop, where
  the back ease first reaches zero) and `bloomed` as the right leaf starts
  to open, each from `step` on the frame the clock crosses the beat, never
  under reduce motion or once leaving. `world/boot.gd` plays `ui`'s `tile`
  on `landed` (a HUSH tock at -16, two players taken in turn, a half
  semitone higher each tile, four over the nine, with a 1.2% jitter) and
  `ui`'s `opening` on `bloomed`, now only its two kalimba notes
  (`COZY_TUNE`, `notes:0.3:0,5`, -13). The tune's first two takes were near
  silent at 320-350 Hz (rule 3); the second of three was kept. Measured:
  `tile` centroid 538 Hz, phone -15; `opening` 442 Hz, phone -14; nothing
  flagged. A tap before the leaves skips the tune; a tune already playing
  still rings out past the opening as before. No haptics: the opening is on
  the "screen opening" side of every board's nothing list.
- **Measured** (second of two `boot time` runs): the game under the
  opening at 3.08 s, and 3.08 s with the old opening too, so the load sets
  the handover and the longer build adds no wait on this Mac; a phone is
  slower still. Settled 42 draw calls; at most 134 with the first screen
  under it. The 1.95 s of 2026-10-06 is history: the game loads slower now.
- **Unheard by the user**, and the puff, the order and the hop are calls
  taken for them; nothing of it on a phone.

### The handover (`world/boot.gd`)

`boot.gd` preloads only what the opening draws with. When the threaded load
is done and the opening has settled, `main.tscn` is instantiated and added to
the root *under* the opening (the opening is on canvas layer 100), given
three frames to build and draw out of sight, and then `menu.rise()` replays
the first screen's entrance while the opening leaves. `main` becomes
`current_scene` and the boot node frees itself. Everything `world/main.gd`
does (settings, telemetry, backend, ads, the age screen, a friend link)
still happens in its own `_enter_tree` and `_ready`, later than before by the
length of the load and no differently.

- The frame the first screen is built in is long (135-150 ms here, one
  frame). The opening's clock moves 50 ms a frame at most, so it pauses
  through that frame rather than jumping.
- A failed threaded load falls back to a plain `load()` with the opening up.
- **Harnesses still load `world/main.tscn` themselves** and never see the
  boot scene. One that wants the real launch offline sets
  `boot.main_script` to `tests/_offline_main.gd` before adding it.
- Quitting before the load ends (`--quit-after 5`) prints a parse error for
  `main.tscn`: the abandoned load, not a broken scene.

### The harness

    godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_opening.gd -- [rm] [out=<dir>]
    godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_opening.gd -- boot [time] [tap] [rm] [out=<dir>]

The first sets the clock by hand and shoots the score and the leaving. `boot`
runs the real handover offline; add `time` to read it, because a shot is a
frame of 50 ms or more and the opening waits those out, so a run that shoots
reads a second late. Measured 2026-10-06 (second of two readings): the game
under the opening at 1.95 s, the opening leaving at 1.98 s, one frame over
34 ms; 360 draw calls at most with the first screen under the opening
(42 of them the opening). The load itself is what sets that 1.95: on a thread beside a
drawing game it takes about 1.9 s here, against 1.6 s alone.

### Not done

Nothing has run on a phone: the cream window, the system splash's exit into
it, the length of the load and the long frame there are all unseen. The
Android theme was read out of a local build (`windowBackground #fcf5e9`).
