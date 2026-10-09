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

The app icon coming together: nine soft tiles drop in along the diagonals,
the sprout grows out of the middle one and its two leaves fall open, `Daily`
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
- It has one sound since 2026-10-09, asked for by the user: `ui`'s
  `opening` (`assets/sfx/ui/opening.ogg`, 1.7 s at -13, `HEARTH_TUNE`: tiles
  set down, then two low kalimba notes), played by `world/boot.gd` from the
  first frame, so `ui/opening.gd` alone stays silent in a harness. Boot
  loads the sound switch before it plays; under reduce motion it is not
  played. A tapped opening leaves before the tune ends: boot frees the
  opening's layer and waits for the last note before freeing itself.
  Unheard by the user, and not synced to a beat of the animation.

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
