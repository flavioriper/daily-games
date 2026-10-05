## Valley

**A sixth tab since 2026-10-05**, between Arcade and Stats: slow places
that share one inventory and have no finish (spec
`2026-10-05-valley-grove-design.md`; the concept and its four passes are
`docs/brainstorm/concepts.html#valley`). Like Versus and Arcade it is not a
registry entry: `ui/menu/valley_tab.gd` holds a card a place, `ui/menu.gd`'s
`_open_valley` mounts the place's own screen and closes back to the tab, and
the screen joins the `versus_host` group so Android's back reaches it.
**Leaving a place calls no `Ads.leaving_game()`**: a place is looked in on
many times a day for a minute.

**The pace is the design** (the user: "really slow, not something the user
will nail in 2 hours", "infinite"). Do not make a number faster to make a
shot or a demo easier: change the harness's preset instead.

- **`Stock`** (`core/stock.gd`, autoload, `user://stock.cfg`) is the shared
  inventory: `count`, `add`, `can_pay`, `pay`, `changed`. A place talks to
  Stock and never to another place. **A place never spends a shared
  resource on itself** (the user's rule): its upgrade currency is its own,
  in its own save. Point `Stock.path` elsewhere and `reload()` in a harness.
  It writes at most every two seconds and when the app is left; `flush()`
  writes now.
- **The Grove is the only place.** No card, chip or line on the tab names a
  second one: the user took the Sawmill and the rest out ("we still gonna
  plan the future").

### The Grove

A piece of land in a pond; trees come up at random spots; a circle follows
the finger and chops what is inside it; nothing chops by itself. A felled
tree gives wood (to Stock) and the same energy (the Grove's own), and energy
buys six tiles. **It is called the Grove and nothing else**: the game it
follows is named once, in the spec.

- **The game is pure data** (`valley/grove_sim.gd`): land units (810 by
  800), `step(dt, holding, at)`, `events` for the screen to drain, `buy`,
  and its own keeping (`save(now)`, `load_saved(now)`, `Sim.path`). It never
  touches Stock: the screen hands each felled tree's wood over.
  `tests/_probe_grove.gd` checks the arithmetic (33 checks) and
  `-- pace [visits] [seconds] [days]` or `-- marathon [hours]` plays it with
  a bot; **run `pace` after touching any number** and put the table in the
  spec's section 4.
- **Every tree starts at 4** (`Sim.HP`; the user: "each tree start as 4hp").
  Axe and Seeds have no last level; Reach, Swing, Sprout and Room stop.
- **Away is worked out, never run**: `load_saved` adds the trees that came
  up since `seen`, up to the room. The tab keeps its own sim from the file
  and steps it for the card's picture; **Play saves that sim first**, so the
  screen opens on the same trees.
- **One mesh a tree** (`valley/grove_art.gd`, cached per look), one for the
  whole pond and land (`Art.ground`, rebuilt on resize only), a draw a
  number. 92 draw calls on a new grove, 246-286 on a land of thirty with a
  circle over a dozen trees and their numbers, about 230 under the tutorial
  card (810x1440, 2026-10-05; the same on `opengl3_angle`, 92 and 275).
  Frames came 8 to 10 ms apart through the whole harness run on both.
- **The fonts have no arrow and no star.** A tile says "chop 1, then 2" and
  a tree past the fifth tier is "Birch II" (`tree_name`).
- **Sounds** (`assets/sfx/grove/`, `tools/gen_sfx.py grove`): `chop` is a 90
  ms click, the quietest of the set, since it repeats for as long as the
  finger is held; `fell`, `buy`, `no`. Unheard by the user.
- **Haptics** (`docs/agents/haptics.md` row 40): fell taps, a tile bought
  bumps, one refused warns; a chop that hits is felt only as its sound's
  echo.
- **Analytics**: `valley_enter` (place, trees, room), `valley_leave` (place,
  seconds, felled), `grove_upgrade` (tile, level, energy).
- `tests/_shot_grove.gd` shoots the tab, a new grove, a chop, a fell, a
  middle and a late grove, a tile bought, the tutorial's three pages and the
  tab again, on throwaway files. It prints frames and their mean gap between
  shots; `Performance.TIME_PROCESS` read 100 ms on frames 9 ms apart under
  `--script` and is not printed.
- **Not built**: automation, chests, critical hits, timed days, a skill
  tree, ads, a growing land, a second place. Nothing run on a phone.
