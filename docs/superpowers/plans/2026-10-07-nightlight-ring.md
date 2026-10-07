# Nightlight Ring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The player presses the sky to brake what circles the star; a star is born with a ring of gas, worlds pull, and what falls in pays by what it is.

**Architecture:** The sim (`arcade/nightlight_sim.gd`) gains the ring, `brake`, the trickle, worlds as extra pullers in the relics' table, and `rank`/`paid` on a body; it loses the pour. The sky (`arcade/nightlight_sky.gd`) draws three lights a puff, the press's glow and the flush. The screen (`arcade/nightlight_screen.gd`) reads touches on the sky, drops the Gas button, guards the pick card and shows the system's readout.

**Tech Stack:** Godot 4 GDScript, gl_compatibility; the probe `tests/_probe_nightlight.gd` (headless) is the test; the shot harness `tests/_shot_nightlight.gd` (windowed) is the eye; `tests/run_tests.gd` is the suite.

**Spec:** `docs/superpowers/specs/2026-10-07-nightlight-ring-design.md` (read it whole before a task; section numbers below are its own).

## Global Constraints

- Branch `feat/nightlight-ring`, one or more commits a task; nothing pushed, nothing merged (the user calls both).
- The game is called Nightlight; the genre's original is never named in code, comments or commits.
- Read `docs/agents/arcade.md` from "Nightlight is the seventh" to the end of "An eighth time" before touching the game; `docs/agents/harnesses.md` before a harness; `docs/agents/haptics.md` row 42 and `docs/agents/analytics.md` before the screen.
- 855 draw calls budget; one `draw_mesh`/`draw_multimesh` per drawing; no `instance uniform`; cozy light has no shape (soft round glows from `Art.glow`: no ring outline, ray, beam or arc).
- Harness: `caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_nightlight.gd -- <outdir> [reduce] [en|pt|es] > <log> 2>&1` (flags before `--script`, never piped into `head`), one windowed run at a time, then again with `--rendering-driver opengl3_angle`. Commit `project.godot` state before a windowed run and revert any header Godot re-saves into it.
- Probe: `godot --headless --path . --script res://tests/_probe_nightlight.gd` (and `-- pace ...`). Parse guard: `godot --headless --path . --check-only --script arcade/nightlight_sim.gd` (same for each file touched). Suite: `godot --headless --path . --script res://tests/run_tests.gd`.
- Text goes through `locale/ui.csv` (en, pt, es; `_ONE`/`_N` pairs for counts); titles stay English; after editing the csv run `godot --headless --path . --import` before a harness.
- Touch is not mouse here (`emulate_mouse_from_touch` is off): hand-written input takes `InputEventScreenTouch` and `InputEventScreenDrag`, and a harness presses with them.
- Honour `Motion.reduce`. `Analytics.start()`, `Backend`, `Ads.start()` never run from a harness.
- Never read `power[...]` directly; use `on()`.
- Every number is the spec's starting value; only Task 6 retunes, and it lists what it moved.
- A subagent keeps at most one background shell, kills what it starts, and a long job prints a line per item.
- No new test files: the probe keeps and extends its checks; anything else is a throwaway check that is not committed.

## Review Focus

1. A `KEPT` 3 file (every tester's, since 2026-10-07) must load with its star, relics and bodies, its tile levels carried to the new keys, a ring laid, and no error. (Task 1 test.)
2. `ring.y == 0` (a sim whose ring was cleared, as a tutorial page does) must not divide by zero in `zoom()`, `press_r()`, `_trickle()` or the lobe rule. (Task 1 test.)
3. A press with nothing under it, a press at the star's centre, and a press while a card is up must each do nothing and throw nothing; a finger still down when a card opens must stop braking. (Task 3: probe for the first two, a harness beat for the last.)
4. A world exactly on a body (`d == 0`, itself or a merged neighbour) must not divide by zero in the pull; a world eaten or merged mid-tick must not be read after it is gone. (Task 2 test.)
5. A torn planet's pieces, a merged pair and a body loaded from an old file must each have a sane `rank` and `paid`, so no body pays twice or a negative amount when eaten. (Task 2 test.)

---

### Task 1: The ring, the brake, the trickle, the camera and the file

**Files:**
- Modify: `arcade/nightlight_sim.gd` (constants ~80-377, `Body` ~50, `zoom`/`seen_r` ~467, `frost_r` ~602, `end` ~775-840, `born`/`_lay_gas` ~845-865, `pour` ~922, `tick` ~1172, `save`/`load_saved` ~1352-1460)
- Modify: `arcade/nightlight_screen.gd` (`TILE_NAMES` ~99, `_effect` ~1459) and `locale/ui.csv` (the tiles' words) so the shop still opens
- Test: `tests/_probe_nightlight.gd` (new `_check_ring()`, `_pace` rewritten, the pour's checks replaced)

**Interfaces:**
- Produces: `ring: Vector2`, `frost: float`, `dusty: float`; `brake(at: Vector2, r: float) -> int`; `press_r() -> float`; `flow_gap() -> float`; `trickle_rate() -> float`; `Body.sink: float`; `TILES == ["reach", "flow", "rich", "pure"]`; `zoom()` framed on the ring; `KEPT == 4`.
- Kept until Task 3 so the screen still runs: `pour()` (one puff of `RING_M / RING`, no volley) and `stream_gap()` (returns `flow_gap()`).

- [ ] **Step 1: Write the failing checks.** In `tests/_probe_nightlight.gd` add `_check_ring()` to `_initialize` after `_check_giant()`, and a helper that stands in for the pour wherever the older checks used `sim.pour()` (lines ~117, 256-261, 525):

```gdscript
## A puff set on a circle just inside the disc's rim, as the old button did:
## the older checks' way of putting gas in.
func _puff(sim: RefCounted, m := Sim.PUFF) -> Sim.Body:
	var pos := Vector2.from_angle(sim._rng.randf() * TAU) * sim.haze_r() * sim._rng.randf_range(0.7, 0.97)
	var b: Sim.Body = sim.add(Sim.Kind.GAS, m, pos, sim.circle_vel(pos) * sim._rng.randf_range(0.97, 1.0))
	b.h = sim.puff_h()
	b.dust = Sim.DUSTY * Sim.PUFF / m
	return b

func _check_ring() -> void:
	var sim := _quiet(11)
	sim.born()
	var rh: float = sim.haze_r()
	_ok("the ring is laid from 1.15 to 1.75 of the newborn disc", is_equal_approx(sim.ring.x, rh * Sim.RING_IN) and is_equal_approx(sim.ring.y, rh * Sim.RING_OUT))
	_ok("the frost line is the ring's middle", is_equal_approx(sim.frost_r(), (sim.ring.x + sim.ring.y) * 0.5))
	_ok("it is RING puffs", sim.bodies.size() == Sim.RING)
	var ids := {}
	var one_way := true
	var mass := 0.0
	for b: Sim.Body in sim.bodies:
		mass += b.m
		one_way = one_way and b.pos.cross(b.vel) * sim.bodies[0].pos.cross(sim.bodies[0].vel) > 0.0
		if b.pos.length() >= sim.ring.x * 0.999:
			ids[b.id] = true
	_ok("all turning one way", one_way)
	# the falling few start at their far point, which may be past the ring's inner edge
	_ok("all but the falling few are in the ring", ids.size() >= Sim.RING - Sim.RING_FALLING)
	_ok("it weighs RING_M", absf(mass - Sim.RING_M) < Sim.RING_M * 0.1)
	_run(sim, 300.0)
	var held := 0
	for b: Sim.Body in sim.bodies:
		if ids.has(b.id) and b.kind == Sim.Kind.GAS and b.pos.length() > rh:
			held += 1
	_ok("left alone, the ring does not come down", held >= Sim.RING - Sim.RING_FALLING)
	_ok("the view shows the ring's edge at FRAME", is_equal_approx(sim.zoom() * sim.ring.y, Sim.FRAME))
	sim.mass = Sim.START * 20.0
	var wide: float = sim.press_r() * sim.zoom()
	sim.mass = Sim.START
	_ok("the press is the same under the finger at 1 and 20 Suns", is_equal_approx(wide, sim.press_r() * sim.zoom()) and is_equal_approx(wide, Sim.PRESS_R))
	# the brake: a body at R slowed by f comes down to R f^2 / (2 - f^2)
	var one := _quiet(3)
	var at := Vector2(655.0, 0.0)
	var b: Sim.Body = one.add(Sim.Kind.GAS, 0.05, at, one.circle_vel(at))
	var v0: float = b.vel.length()
	_ok("a press brakes what is under it", one.brake(at + Vector2(75.0, 0.0), 100.0) == 1 and is_equal_approx(b.vel.length(), v0 * 0.95) and b.sink == 1.0)
	_ok("and nothing past its edge", one.brake(at + Vector2(0.0, 5000.0), 100.0) == 0)
	_ok("a press on the star itself throws nothing", one.brake(Vector2.ZERO, 100.0) == 0)
	var near := 655.0
	for i in int(200.0 / Sim.STEP):
		one.tick()
		near = minf(near, b.pos.length())
	_ok("its nearest point is R f^2 / (2 - f^2)", absf(near - 655.0 * 0.9025 / 1.0975) < 655.0 * 0.02)
	# once, it winds in and pays; three times, it drops in and pays little
	var paid := []
	for presses: int in [1, 3]:
		var s := _quiet(5)
		var g: Sim.Body = s.add(Sim.Kind.GAS, 0.05, at, s.circle_vel(at))
		g.dust = 0.0
		for k in presses:
			s.brake(at, 100.0)
		var t := 0.0
		while s.bodies.size() > 0 and t < 600.0:
			s.tick()
			t += Sim.STEP
		_ok("pressed %d times it is eaten" % presses, s.bodies.is_empty())
		paid.append(s.light)
	_ok("a gentle brake pays light", paid[0] > 0.0)
	_ok("a long hold pays under a third of it", paid[1] < paid[0] / 3.0)
	# the trickle
	var far := _quiet(9)
	far.passing = true
	far._pass_gap = 1e9
	var was: float = far.trickle_rate()
	far.mass = Sim.START * 4.0
	_ok("the trickle grows with the star", is_equal_approx(far.trickle_rate(), was * pow(4.0, Sim.TRICKLE_UP)))
	far.mass = Sim.START
	_run(far, 120.0)
	var got := _sky_mass(far)
	_ok("two minutes of it is two tenths of a Sun", absf(got - Sim.TRICKLE * 120.0) < Sim.RING_M / Sim.RING * 1.5)
	var outer := true
	for p: Sim.Body in far.bodies:
		outer = outer and p.pos.length() > far.ring.y * 0.85
	_ok("it arrives at the ring's outer edge", outer)
	# a sim whose ring was cleared (a tutorial page) still works
	var bare := _quiet(2)
	bare.ring = Vector2.ZERO
	bare.passing = true
	_run(bare, 5.0)
	_ok("no ring: the old view, and no trickle", is_equal_approx(bare.zoom(), 1.0) and is_finite(bare.press_r()) and bare.bodies.is_empty())
	# a new star is born clear of its ring
	for case: Array in [[1.2, false], [25.0, true]]:
		var dead := _quiet(4)
		dead.mass = Sim.START * float(case[0])
		if case[1]:
			dead.made[5] = Sim.IRON * Sim.START
		else:
			dead.cold = Sim.GRACE
		dead.end()
		var rel: Dictionary = dead.relics[0]
		var d: float = (rel.pos as Vector2).length()
		var lobe: float = d * pow(dead.mass / (3.0 * float(rel.m)), 1.0 / 3.0)
		_ok("the ring is inside half the new star's lobe (%s Suns)" % case[0], dead.ring.y < lobe * 0.5 + 1.0)
		_ok("and the new star has a ring", dead.gas_count() == Sim.RING)
	# the file
	var keep := _quiet(6)
	keep.born()
	keep.lv.reach = 2
	keep.dusty = 0.2
	keep.save()
	var back: RefCounted = Sim.load_saved(1)
	_ok("a star saved and read back keeps its ring", back.ring.is_equal_approx(keep.ring) and is_equal_approx(back.frost, keep.frost) and is_equal_approx(back.dusty, 0.2) and int(back.lv.reach) == 2 and back.bodies.size() == keep.bodies.size())
	var old := ConfigFile.new()
	old.load(Sim.path)
	old.set_value("star", "kept", 3)
	for key in ["ring", "frost", "dusty"]:
		old.erase_section_key("star", key)
	old.erase_section("lv")
	old.set_value("lv", "puff", 3)
	old.set_value("lv", "volley", 9)
	old.set_value("lv", "stream", 4)
	old.set_value("lv", "pure", 2)
	old.set_value("star", "mass", Sim.START * 3.0)
	old.set_value("star", "bodies", [])
	old.save(Sim.path)
	var kept3: RefCounted = Sim.load_saved(1)
	_ok("a KEPT 3 star's tiles carry over", int(kept3.lv.rich) == 3 and int(kept3.lv.reach) == 6 and int(kept3.lv.flow) == 4 and int(kept3.lv.pure) == 2)
	_ok("and it is given a newborn's ring", is_equal_approx(kept3.ring.y, Sim.STAR_R * Sim.HAZE * Sim.RING_OUT) and kept3.gas_count() == Sim.RING)
```

Replace every `sim.pour()` / `one.pour()` in the older checks with `_puff(sim)` / `_puff(one)`; delete the checks on `puff_mass`, `volley`, `stream_gap() == Sim.STREAM` and `pour_r()` (lines ~251-252, ~512 and the giant's pour block); change `int(old.lv.puff) == 5` to `int(old.lv.rich) == 5`. In `_quiet` nothing changes (`passing = false` stops the trickle too).

- [ ] **Step 2: Run it and see it fail.** `godot --headless --path . --script res://tests/_probe_nightlight.gd` — expected: a script error on `sim.ring` (nothing is defined yet).

- [ ] **Step 3: The sim.** In `arcade/nightlight_sim.gd`:

Constants (beside `HAZE`; delete `FROST`, the `IN_*` block, `PUFF_STEP`, `STREAM*`; set `WIND := 0.0003`, `MOST := 260`, `FULL := 400`, `SOLIDS := 40`, `KEPT := 4`; delete `ASHES`, `ASHES_LOG`, `ASHES_MOST`, `FADE_ASHES`, `FIRST_CLOUD` once nothing reads them — grep first):

```gdscript
## The ring a star is born with: its inner and outer edge in the newborn's
## plain disc, how many puffs, what they weigh together, and how many of
## them are already falling so a new star has something winding in.
const RING_IN := 1.15
const RING_OUT := 1.75
const RING := 180
const RING_M := 15.0
const RING_FALLING := 6
## The ring's outer edge is this far from the star on the screen, of the
## design's 1080 across.
const FRAME := 500.0
## A press: the share of its speed a body under the finger's middle loses,
## the finger's reach in the design's pixels and what a level of Reach adds,
## the seconds between brakes while it is held, and how long what it braked
## is drawn warm.
const BRAKE := 0.2
const PRESS_R := 95.0
const REACH_STEP := 0.25
const FLOW := 0.6
const FLOW_STEP := 0.88
const FLOW_LEAST := 0.15
const FLUSH := 6.0
## Gas from the far sky: mass a second at one Sun (a tenth of a Sun a
## minute), the power of the star's Suns it grows by (Bondi's is 2, which
## runs away), and what a level of Rich adds.
const TRICKLE := 0.017
const TRICKLE_UP := 1.0
const RICH_STEP := 0.5

const TILES := ["reach", "flow", "rich", "pure"]
const TILE := {
	"reach": [40.0, 2.2, 6],
	"flow": [30.0, 2.0, 0],
	"rich": [12.0, 1.8, 0],
	"pure": [20.0, 1.9, 6],
}
```

State (`lv` becomes `{"reach": 0, "flow": 0, "rich": 0, "pure": 0}`; `_inlet` goes):

```gdscript
## The ring's inner and outer edge, fixed when the star is born; the frost
## line, at its middle; and the dust share of the gas this star was born in,
## which what drifts in later shares.
var ring := Vector2.ZERO
var frost := 0.0
var dusty := 0.02
var _owed_gas := 0.0
```

`Body` gains `var sink := 0.0` ("1 when a press has just braked it, 0 again `FLUSH` seconds on; drawn, not saved").

Functions:

```gdscript
## The ring and the frost line a newborn of `m` has. Powers are none on a
## newborn, so its disc is the plain one.
func _set_ring(m := mass) -> void:
	var disc := STAR_R * pow(m / START, 1.0 / 3.0) * HAZE
	ring = Vector2(RING_IN, RING_OUT) * disc
	frost = (ring.x + ring.y) * 0.5

## The dust a puff of `m` carries at `share`: what a puff of PUFF * ASH_M
## would, whatever it weighs, or heavy puffs made a giant of every pair.
static func dust_of(share: float, m: float) -> float:
	return minf(0.5, share * PUFF * ASH_M / m)

## `count` puffs weighing `total` between the ring's edges, on circles, all
## turning the disc's way; the first few on the old falling paths.
func _lay_ring(count: int, total: float, h: float, dust_share: float) -> void:
	dusty = dust_share
	var each := total / count
	var falling := mini(RING_FALLING, count)
	_lay_gas(falling, each, h, dust_share)
	for i in count - falling:
		var pos := Vector2.from_angle(_rng.randf() * TAU) * sqrt(lerpf(ring.x * ring.x, ring.y * ring.y, _rng.randf()))
		var b := add(Kind.GAS, each * _rng.randf_range(0.6, 1.4), pos, circle_vel(pos) * _rng.randf_range(0.98, 1.02))
		b.h = h
		b.dust = dust_of(dust_share, b.m)
		b.age = COOL

## The finger: everything within `r` of `at` loses a share of its speed,
## most under the middle, none at the edge. What follows is the orbit's own.
## Returns how many it braked.
func brake(at: Vector2, r: float) -> int:
	var n := 0
	if r <= 0.0:
		return n
	for b in bodies:
		var d := b.pos.distance_to(at)
		if d >= r:
			continue
		b.vel *= 1.0 - BRAKE * (1.0 - d / r)
		b.sink = 1.0
		n += 1
	if n > 0:
		events.append({"kind": "brake", "at": at, "n": n})
	return n

## How far the finger reaches, in the sim's pixels: the same on the screen
## whatever the star weighs.
func press_r() -> float:
	return PRESS_R * (1.0 + REACH_STEP * int(lv.reach)) / zoom()

## Seconds between brakes while a finger is held.
func flow_gap() -> float:
	return maxf(FLOW_LEAST, FLOW * pow(FLOW_STEP, int(lv.flow)))

## Mass a second drifting in from the far sky.
func trickle_rate() -> float:
	return TRICKLE * pow(suns(), TRICKLE_UP) * (1.0 + RICH_STEP * int(lv.rich)) * (1.0 + HAND * int(perk.hand))

## A puff's worth of what has drifted in is set on a circle at the ring's
## outer edge; with the sky full it goes into the last puff there is.
func _trickle() -> void:
	if ring.y <= 0.0:
		return
	var each := RING_M / RING
	_owed_gas = minf(_owed_gas + trickle_rate() * STEP, each * 4.0)
	if _owed_gas < each:
		return
	if gas_count() >= MOST or bodies.size() >= FULL:
		for i in range(bodies.size() - 1, -1, -1):
			var last := bodies[i]
			if last.kind == Kind.GAS:
				last.h = (last.h * last.m + puff_h() * each) / (last.m + each)
				last.dust = (last.dust * last.m + dust_of(dusty, each) * each) / (last.m + each)
				last.m += each
				_owed_gas -= each
				return
		return
	_owed_gas -= each
	var pos := Vector2.from_angle(_rng.randf() * TAU) * ring.y * _rng.randf_range(0.9, 1.0)
	var b := add(Kind.GAS, each, pos, circle_vel(pos))
	b.h = puff_h()
	b.dust = dust_of(dusty, each)
```

Changed functions:

```gdscript
func seen_r() -> float:
	return star_r() * zoom()

## Screen pixels to one of the world's: the star's own log rule, or less
## where the ring would not fit.
func zoom() -> float:
	var r := star_r()
	var plain := 1.0 if r < SEEN else (SEEN + SEEN_LOG * log(r / SEEN)) / r
	return minf(plain, FRAME / ring.y) if ring.y > 0.0 else plain

func frost_r() -> float:
	return frost * (1.0 + GIANT * swell) if frost > 0.0 else star_r() * 2.2
```

- `_init`: call `_set_ring()` after the seed is set.
- `_lay_gas`: `b.dust = dust_of(dust_share, b.m)`.
- `born()`: `_set_ring()`, `_lay_ring(RING, RING_M, STAR_H, 0.02)`, `fresh = true`.
- `end()`: drop `count`; after the tiles and powers are reset call `_set_ring()`; replace the `_lay_gas(count, ...)` line with `_lay_ring(RING, RING_M * (1.0 + RICHER * novas), ASH_H, ash_dust)`; the distance becomes `var d := LOBE * ring.y * (1.0 + sqrt(rm / mass))`.
- `tick()`: delete the `_inlet` line; inside `if passing:` add `_trickle()`; in the body loop, before the velocity is stepped, `if b.sink > 0.0: b.sink = maxf(0.0, b.sink - STEP / FLUSH)`.
- `pour()`, until Task 3: `var m := RING_M / RING`, one puff, the inlet angle replaced by `_rng.randf() * TAU` and `IN_NEAR`/`IN_FAR`/`IN_WIDE` by the literals 0.7 and 0.97; `puff_mass()` and `volley()` deleted; `stream_gap()` returns `flow_gap()`; `pour_r()` deleted (inline `haze_r()`).
- `save()`: `cfg.set_value("star", "ring", [ring.x, ring.y])`, `"frost"`, `"dusty"`.
- `load_saved()`: the tiles' loop becomes

```gdscript
	var was_tile := {"reach": "volley", "flow": "stream", "rich": "puff", "pure": "pure"}
	for tile: String in TILES:
		var key: String = tile
		if ver < 4:
			key = was_tile[tile]
			if pre_gas:
				key = "meteor" if key == "puff" else ("ice" if key == "pure" else key)
		var level := maxi(0, int(cfg.get_value("lv", key, 0)))
		sim.lv[tile] = level if sim.last_level(tile) == 0 else mini(level, sim.last_level(tile))
```

  and, after the perks are read, `sim._set_ring(START * pow(EMBER, int(sim.perk.ember)))`; then at the end (after the bodies and `_load_sky`), for a file that is not `pre_gas`:

```gdscript
	if ver >= 4:
		var edges = cfg.get_value("star", "ring", [])
		if edges is Array and (edges as Array).size() == 2 and is_finite(float(edges[0])) and float(edges[0]) > 0.0 and float(edges[1]) > float(edges[0]):
			sim.ring = Vector2(float(edges[0]), float(edges[1]))
			sim.frost = clampf(float(cfg.get_value("star", "frost", sim.frost)), sim.ring.x, sim.ring.y)
		sim.dusty = clampf(float(cfg.get_value("star", "dusty", 0.02)), 0.0, 0.3)
	else:
		# a star kept before the ring is given one: inside a heavy star's disc it simply falls
		sim._lay_ring(RING, RING_M, ASH_H, ASH_DUST)
```

- [ ] **Step 4: The shop still opens.** `arcade/nightlight_screen.gd`: `TILE_NAMES := {"reach": "NL_REACH", "flow": "NL_STREAM", "rich": "NL_RICH", "pure": "NL_PURE"}`; `_effect`:

```gdscript
func _effect(tile: String) -> String:
	var c := _comma()
	match tile:
		"reach":
			var level := int(sim.lv.reach)
			return tr("NL_FX_REACH") % [Art.short(1.0 + Sim.REACH_STEP * level, c), Art.short(1.0 + Sim.REACH_STEP * (level + 1), c)]
		"flow":
			var gap: float = sim.flow_gap()
			return tr("NL_FX_STREAM") % [_hundredths(gap), _hundredths(maxf(Sim.FLOW_LEAST, gap * Sim.FLOW_STEP))]
		"rich":
			var level := int(sim.lv.rich)
			return tr("NL_FX_RICH") % [Art.short(1.0 + Sim.RICH_STEP * level, c), Art.short(1.0 + Sim.RICH_STEP * (level + 1), c)]
	var h: float = sim.puff_h()
	return tr("NL_FX_PURE") % [int(round(h * 100.0)), int(round(minf(0.95, h + Sim.PURE_STEP) * 100.0))]
```

  Find where a tile's icon is chosen by its name (`_tile`, `Art`) and give `reach` the old volley's picture, `flow` the stream's, `rich` the puff's. `locale/ui.csv`: add `NL_REACH,Reach,Alcance,Alcance`; `NL_RICH,Rich sky,Céu farto,Cielo rico`; `NL_FX_REACH,"reach ×%s, then ×%s","alcance ×%s, depois ×%s","alcance ×%s, luego ×%s"`; `NL_FX_RICH,"gas ×%s, then ×%s","gás ×%s, depois ×%s","gas ×%s, luego ×%s"`; reword `NL_FX_STREAM` to `"slows every %s s, then %s s","freia a cada %s s, depois %s s","frena cada %s s, luego %s s"`; `NL_PERK_HAND_FX` to `30% more gas drifts in,chega 30% mais gás,llega 30% más gas`. Leave `NL_PUFF`, `NL_VOLLEY`, `NL_GAS` and their `FX` for Task 3. Run `godot --headless --path . --import`.

- [ ] **Step 5: The bot presses.** Rewrite `_pace` (`-- pace [minutes] [seed] [first|second|random] [held] [gas|worlds]`): where it poured, every `sim.flow_gap()` seconds inside the held share of each ten seconds it calls `sim.brake(spot, sim.press_r())`, `spot` chosen every 3 s:

```gdscript
## Where the bot presses: the heaviest solid outside the disc if it sends
## worlds, else the middle of the fullest of 24 slices of the ring outside it.
func _spot(sim: RefCounted, worlds: bool) -> Vector2:
	var rh: float = sim.haze_r()
	var best: Sim.Body = null
	var slices := PackedFloat32Array()
	slices.resize(24)
	var sum: Array[Vector2] = []
	sum.resize(24)
	sum.fill(Vector2.ZERO)
	for b: Sim.Body in sim.bodies:
		if b.pos.length() <= rh:
			continue
		if b.kind != Sim.Kind.GAS and (best == null or b.m > best.m):
			best = b
		var k := int(fposmod(b.pos.angle(), TAU) / TAU * 24.0) % 24
		slices[k] += b.m
		sum[k] += b.pos * b.m
	if worlds and best != null and best.m >= Sim.GRAIN_M:
		return best.pos
	var top := 0
	for k in 24:
		if slices[k] > slices[top]:
			top = k
	return sum[top] / slices[top] if slices[top] > 0.0 else Vector2.ZERO
```

  It keeps buying the cheapest tile, picking powers and calling `end()`; each report line adds the gas left outside the disc (count and Suns) and seconds since the last press that braked anything. `_sky(sim)` stays.

- [ ] **Step 6: Run.** The probe: every check passes, `0 failed`. The parse guard on the sim, the screen and the probe. The suite: `249790/0` or its current count with 0 failed. `-- pace 12 1 random 1.0 gas`: print it into the commit message (it is the untuned pace; Task 6 tunes).

- [ ] **Step 7: Commit.** `git add -A arcade/nightlight_sim.gd arcade/nightlight_screen.gd locale tests/_probe_nightlight.gd && git commit -m "feat(nightlight): a ring to be born with, a brake, gas drifting in, the view on the ring"`

---

### Task 2: What a thing pays, worlds that pull, the system's count

**Files:**
- Modify: `arcade/nightlight_sim.gd` (`Body`, `_sort`, `_tear`, `_meet`'s merge, `_condense`'s grain, `_sweep`, `_gulp`, `tick`, `save`/`load_saved`, `kept`)
- Test: `tests/_probe_nightlight.gd` (new `_check_pay()` and `_check_worlds()`)

**Interfaces:**
- Consumes: Task 1's sim.
- Produces: `Body.rank: float`, `Body.paid: float`; `pay(rank: float) -> float`; `hill_r(b: Body) -> float`; `system() -> Dictionary` (`{planets, giants, comets, rocks}`, ints); `kept()` gains `"worlds": int`; a body's saved row has twelve columns.

- [ ] **Step 1: Write the failing checks.**

```gdscript
func _check_pay() -> void:
	_ok("gas pays 1, a grain 4, a rock 10, a world 25", Sim.pay(0.0) == Sim.PAY_GAS and Sim.pay(Sim.GRAIN_M * 0.5) == Sim.PAY_GRAIN and Sim.pay(Sim.PLANET_M * 0.5) == Sim.PAY_ROCK and Sim.pay(Sim.PLANET_M) == Sim.PAY_WORLD)
	# a solid pays in full when eaten, whatever its path
	for way: Array in [["dropped straight in", 0.0], ["on a grazing path", 0.55]]:
		var sim := _quiet(12)
		var at := Vector2(300.0, 0.0)
		var p: Sim.Body = sim.add(Sim.Kind.ROCK, 0.01, at, sim.circle_vel(at) * float(way[1]))
		sim._sort(p)
		var owed: float = p.m * sim.spiral_light() * Sim.PAY_WORLD
		_ok("a planet's rank is its mass", is_equal_approx(p.rank, 0.01))
		var t := 0.0
		while sim.mass < Sim.START + 0.0099 and t < 900.0:
			sim.tick()
			t += Sim.STEP
		var got: float = sim.light
		for b: Sim.Body in sim.bodies:
			got += b.e
		_ok("a planet %s is eaten" % way[0], sim.mass >= Sim.START + 0.0099)
		_ok("and pays 25 times its mass of spiral light (%s)" % way[0], absf(got - owed) < owed * 0.05)
	# gas dropped straight in still pays almost nothing
	var gas := _quiet(12)
	var g: Sim.Body = gas.add(Sim.Kind.GAS, 0.05, Vector2(300.0, 0.0), Vector2.ZERO)
	g.dust = 0.0
	_run(gas, 60.0)
	_ok("gas dropped straight in pays under a tenth of a spiral", gas.bodies.is_empty() and gas.light < 0.05 * gas.spiral_light() * 0.1)
	# torn pieces keep the whole body's rank, and what it had paid is shared out
	var torn := _quiet(13)
	var q: Sim.Body = torn.add(Sim.Kind.ROCK, 0.02, Vector2(torn.roche_r() * 0.9, 0.0), Vector2.ZERO)
	torn._sort(q)
	q.paid = 0.3
	torn._tear(0)
	var ranks := true
	var shared := 0.0
	for piece: Sim.Body in torn.bodies:
		ranks = ranks and is_equal_approx(piece.rank, 0.02)
		shared += piece.paid
	_ok("a torn planet's pieces keep its rank", ranks and torn.bodies.size() >= 2)
	_ok("and share what it had paid", is_equal_approx(shared, 0.3))
	# nothing pays a negative amount: a body that has already paid more than it owes
	var over := _quiet(14)
	var o: Sim.Body = over.add(Sim.Kind.ROCK, 0.001, Vector2(145.0, 0.0), Vector2.ZERO)
	over._sort(o)
	o.paid = 99.0
	_run(over, 5.0)
	_ok("a body that has paid its worth pays no more", over.bodies.is_empty() and over.light >= 0.0 and over.light < 0.001)
	# the file keeps rank and paid; an old row is its own mass
	var keep := _quiet(15)
	var k: Sim.Body = keep.add(Sim.Kind.ROCK, 0.004, Vector2(700.0, 0.0), keep.circle_vel(Vector2(700.0, 0.0)))
	keep._sort(k)
	k.rank = 0.02
	k.paid = 0.11
	keep.save()
	var back: RefCounted = Sim.load_saved(1)
	_ok("a body read back keeps its rank and what it paid", back.bodies.size() == 1 and is_equal_approx(back.bodies[0].rank, 0.02) and is_equal_approx(back.bodies[0].paid, 0.11))
	var cfg := ConfigFile.new()
	cfg.load(Sim.path)
	var rows: Array = cfg.get_value("star", "bodies", [])
	rows[0] = (rows[0] as Array).slice(0, 10)
	cfg.set_value("star", "bodies", rows)
	cfg.save(Sim.path)
	var old: RefCounted = Sim.load_saved(1)
	_ok("a ten-column row's rank is its mass", is_equal_approx(old.bodies[0].rank, 0.004) and old.bodies[0].paid == 0.0)

func _check_worlds() -> void:
	var sim := _quiet(16)
	var at := Vector2(655.0, 0.0)
	var w: Sim.Body = sim.add(Sim.Kind.ROCK, 0.02, at, sim.circle_vel(at))
	sim._sort(w)
	var hill: float = sim.hill_r(w)
	_ok("a world of 0.02 at 655 px has a Hill radius of about 57 px", absf(hill - 655.0 * pow(0.02 / 30.0, 1.0 / 3.0)) < 0.5)
	# a grain beside it is turned by it; one past the reach is not
	var near_at := at + Vector2(0.0, hill * 0.5)
	var far_at := Vector2(-655.0, 0.0)
	var a: Sim.Body = sim.add(Sim.Kind.GRAIN, 0.0005, near_at, sim.circle_vel(near_at))
	var b: Sim.Body = sim.add(Sim.Kind.GRAIN, 0.0005, far_at, sim.circle_vel(far_at))
	var alone := _quiet(16)
	var a0: Sim.Body = alone.add(Sim.Kind.GRAIN, 0.0005, near_at, alone.circle_vel(near_at))
	var b0: Sim.Body = alone.add(Sim.Kind.GRAIN, 0.0005, far_at, alone.circle_vel(far_at))
	_run(sim, 20.0)
	_run(alone, 20.0)
	_ok("a world turns what is near it", a.pos.distance_to(a0.pos) > 1.0)
	_ok("and not what is past its reach", b.pos.distance_to(b0.pos) < 0.01)
	_ok("a world on top of a body divides by nothing", is_finite(w.pos.x) and is_finite(a.pos.x))
	# only the heaviest WORLDS pull, and a planet under PLANET_M does not
	var small := _quiet(17)
	var s: Sim.Body = small.add(Sim.Kind.ROCK, Sim.PLANET_M * 0.5, at, small.circle_vel(at))
	small._sort(s)
	var c: Sim.Body = small.add(Sim.Kind.GRAIN, 0.0005, near_at, small.circle_vel(near_at))
	_run(small, 20.0)
	_ok("a rock pulls nothing", c.pos.distance_to(a0.pos) < 0.01)
	# gas inside half a Hill radius of a core stays with it; a planet under CORE_M holds none
	for case: Array in [[Sim.CORE_M * 1.5, true], [Sim.PLANET_M * 1.1, false]]:
		var held := _quiet(18)
		var core: Sim.Body = held.add(Sim.Kind.ROCK, float(case[0]), at, held.circle_vel(at))
		core.h = 0.5 if case[1] else 0.0
		held._sort(core)
		var puff_at := at + Vector2(held.hill_r(core) * 0.3, 0.0)
		var puff: Sim.Body = held.add(Sim.Kind.GAS, 0.02, puff_at, held.circle_vel(puff_at))
		puff.dust = 0.0
		puff.age = 0.0
		_run(held, held.turn_time(655.0) * 2.0)
		var with_it: bool = puff.m <= 0.0 or not held.bodies.has(puff) or puff.pos.distance_to(core.pos) < held.hill_r(core)
		_ok("gas inside half a Hill radius %s" % ("stays with a core" if case[1] else "does not stay with a small planet"), with_it == bool(case[1]))
	# a ring beside a relic at its birth distance keeps its puffs
	for case: Array in [[1.2, false, "a dwarf"], [25.0, true, "a hole"]]:
		var dead := _quiet(19)
		dead.mass = Sim.START * float(case[0])
		if case[1]:
			dead.made[5] = Sim.IRON * Sim.START
		else:
			dead.cold = Sim.GRACE
		dead.end()
		var before: int = dead.gas_count()
		_run(dead, 600.0)
		var left := 0
		for p: Sim.Body in dead.bodies:
			if p.pos.length() < dead.ring.y * 1.3:
				left += 1
		_ok("a ring beside %s keeps nine in ten for ten minutes" % case[2], left >= int(before * 0.9) - Sim.RING_FALLING)
	# Wind leans the ring in; it does not empty it
	var wind := _quiet(20)
	wind.power.wind = 1
	var wp: Sim.Body = wind.add(Sim.Kind.GAS, 0.05, at, wind.circle_vel(at))
	wp.dust = 0.0
	_run(wind, 300.0)
	_ok("with Wind a ring circle is still 0.8 of its radius after five minutes", wp.pos.length() > 655.0 * 0.8 and wp.pos.length() < 655.0)
	# the count
	var sys := _quiet(21)
	for row: Array in [[0.02, 0.0, 0.0], [0.02, 0.0, 0.6], [0.004, 0.0, 0.0], [0.004, 0.5, 0.0], [0.0005, 0.0, 0.0]]:
		var body: Sim.Body = sys.add(Sim.Kind.ROCK, row[0], Vector2(700.0, 0.0), Vector2.ZERO)
		body.ice = row[1]
		body.h = row[2]
		sys._sort(body)
	var count: Dictionary = sys.system()
	_ok("the system counts planets, giants, rocks and comets, not grains", int(count.planets) == 1 and int(count.giants) == 1 and int(count.rocks) == 1 and int(count.comets) == 1)
```

- [ ] **Step 2: Run it and see it fail** (`Sim.pay` is not defined).

- [ ] **Step 3: The pay.** In the sim:

```gdscript
## What a thing's mass pays against gas, by the biggest solid it is or was
## part of.
const PAY_GAS := 1.0
const PAY_GRAIN := 4.0
const PAY_ROCK := 10.0
const PAY_WORLD := 25.0

static func pay(rank: float) -> float:
	if rank <= 0.0:
		return PAY_GAS
	if rank < GRAIN_M:
		return PAY_GRAIN
	return PAY_ROCK if rank < PLANET_M else PAY_WORLD
```

`Body` gains `rank` ("the mass of the biggest solid it is or has been part of; 0 for gas") and `paid` ("the light it has let go so far"). `_sort`: for a solid, `b.rank = maxf(b.rank, b.m)` before the kind is chosen (gas returns first, rank untouched at 0). `_tear`: `piece.rank = b.rank` and `piece.paid = b.paid * share`, set before `_sort(piece)`. The solid merge in `_meet`: `b.rank = maxf(a.rank, b.rank)` and `b.paid += a.paid` before `b.m = m`. `_gulp`: `s.paid += g.paid * take / g.m` and `g.paid -= ...` beside the `e` lines. In `tick`:

- the drag's light line gains `* pay(b.rank)`: `b.e += k * b.vel.length_squared() * STEP / bind * b.m * LIGHT * gl * pay(b.rank)`; where a mote is let go (`b.e -= q; light += q`) add `b.paid += q`;
- where the star eats: after `light += b.e`,

```gdscript
			if not gas:
				# a solid pays in full, whatever its path: what a perfect spiral
				# would have, by its rank, less what it has let go already
				var rest := b.m * spiral_light() * pay(b.rank) - b.paid - b.e
				if rest > 0.0:
					light += rest
					events.append({"kind": "shed", "at": p, "e": rest})
```

`save()`: a body's row gains `b.rank, b.paid`. `load_saved()`: `b.rank = maxf(0.0, float(row[10])) if row.size() >= 12 else 0.0`, `b.paid = maxf(0.0, float(row[11])) if row.size() >= 12 else 0.0`, before `sim._sort(b)` (which lifts a solid's rank to its mass).

- [ ] **Step 4: Worlds pull.** Constants `WORLDS := 8`, `PULL_REACH := 6.0`, `HILL_HOLD := 0.5`, `MOON_DRAG := 0.05`.

```gdscript
## How far a world's own pull beats the star's tide, where it is now.
func hill_r(b: Body) -> float:
	return b.pos.length() * pow(b.m / (3.0 * mass), 1.0 / 3.0)
```

In `tick`, after the relics' table is built, gather the `WORLDS` heaviest bodies with `m >= PLANET_M` and `kind != Kind.GAS` (one pass keeping a small sorted list; no sort of the whole sky) into parallel packed arrays: `w_at` (position at the tick's start), `w_vel`, `w_gm` (`G * m`), `w_soft` (`body_r(m)` squared), `w_reach` (`(PULL_REACH * hill_r)` squared), `w_hold` (`(HILL_HOLD * hill_r)` squared if `m >= CORE_M and m < GIANT_MOST and kind == Kind.GIANT or it can gulp by `_meet`'s own test`, else -1), `w_id`. In the body loop, after the relics' pull:

```gdscript
		for k in w_at.size():
			if w_id[k] == b.id:
				continue
			var to := w_at[k] - p
			var d2 := to.length_squared()
			if d2 >= w_reach[k]:
				continue
			acc_rel += to * (w_gm[k] / pow(d2 + w_soft[k], 1.5))
			if gas and d2 < w_hold[k]:
				b.vel += (w_vel[k] - b.vel) * (MOON_DRAG * STEP)
```

The hold's test is exactly the condition under which `_meet` calls `_gulp` (`s.m >= CORE_M and s.m < GIANT_MOST`); read `_meet` and copy it, not the kind.

- [ ] **Step 5: The count.**

```gdscript
## What circles the star, for the screen and the Arcade card: grains are dust
## and are not counted.
func system() -> Dictionary:
	var n := {"planets": 0, "giants": 0, "comets": 0, "rocks": 0}
	for b in bodies:
		match b.kind:
			Kind.PLANET: n.planets += 1
			Kind.GIANT: n.giants += 1
			Kind.COMET: n.comets += 1
			Kind.ROCK: n.rocks += 1
	return n
```

`save()` writes `cfg.set_value("star", "worlds", n.planets + n.giants)`; `kept()` returns `"worlds": int(cfg.get_value("star", "worlds", 0))` (and 0 with no file).

- [ ] **Step 6: Run.** The probe, `0 failed`. Then time a tick: a throwaway headless script (not committed) that builds 400 bodies (8 of them worlds of 0.02 in the ring) and 12 relics inside `RELIC_REACH` and prints the mean microseconds of 2,000 ticks; the spec's line is 1,200 us on this Mac's debug build. Over it: bring `WORLDS` down first, and say so in the commit. Parse guard, suite.

- [ ] **Step 7: Commit.** `feat(nightlight): a thing pays by what it is, worlds pull, the system is counted`

---

### Task 3: The press on the screen; the Gas button and the pour go

**Files:**
- Modify: `arcade/nightlight_screen.gd` (`_build` ~236-380, `_gas_button` ~448, `_process` ~1131, `_stream` ~1156, `_offer` ~1166, `_play_events`, `_on_gas_input`..`_pour` ~1505-1550, `open_pick`, `_tutor_hold`, the top bar's settings handler)
- Modify: `arcade/nightlight_sky.gd` (`unworld`, `set_down`, the press's glow in `_fill`)
- Modify: `arcade/nightlight_sim.gd` (delete `pour` and `stream_gap`)
- Modify: `ui/hud/nightlight_tutorial_diagram.gd` (the GAS lesson, `_feed`), `locale/ui.csv`
- Modify: `tests/_shot_nightlight.gd` (presses), `docs/agents/haptics.md` row 42
- Test: the probe (unchanged, must still pass) and the harness

**Interfaces:**
- Consumes: `sim.brake(at, r) -> int`, `sim.press_r()`, `sim.flow_gap()`, `Body.sink`.
- Produces: `sky.unworld(px: Vector2) -> Vector2` (this control's pixels to the sim's); `sky.set_down(at: Vector2, r: float)` (both in the sim's units); the screen's `_fingers: Dictionary` (finger index, -1 the mouse, to `{at: Vector2, t: float}`), `_press_at(finger: int, px: Vector2)`, `_lift(finger: int)`, `_drop_fingers()`.

- [ ] **Step 1: The sky.** `unworld` is `world`'s inverse:

```gdscript
## This control's pixels back to the sim's.
func unworld(at: Vector2) -> Vector2:
	var k: float = sim.zoom() * view * u
	return (at - centre - shift) / k if k > 0.0 else Vector2.ZERO
```

`set_down(at, r)` appends `{"at": at, "t": 0.0, "r": r}` to a new `_downs` array (at most 12; cleared where `_puffs` is cleared); `refresh` ages them by `delta` and drops those past `DOWN` 0.5 s; `_fill` puts each in `_warms` at `world(at)` as one `Art.glow` of the press's radius on the screen (`r * z / Art.R`, times `lerpf(0.7, 1.0, t / DOWN)` unless `Motion.reduce`), colour `Color(1.0, 0.89, 0.75, 0.35 * (1.0 - t / DOWN))`. No outline.

- [ ] **Step 2: The screen reads the sky.** In `_build`, where the sky is made: `sky.mouse_filter = Control.MOUSE_FILTER_STOP`, `sky.gui_input.connect(_on_sky_input)`, and rewrite the comment above it (the 2026-10-06 ruling, its reversal on 2026-10-07, and that the guard is `_deaf()` and `_offer`). Everything the screen adds to the sky that is not a button (`_note`, the hint, `_fx`, `_quiet`) already ignores the mouse; check `_chips` stays a button over it. Replace `_holding`, `_finger`, `_stream_t`, `_pressed_at` with:

```gdscript
## Fingers down on the sky: index (-1 the mouse) to where it is, in the sky's
## pixels, and the seconds since it last braked.
var _fingers := {}
var _lifted_at := -100000

## No press is read under a card, while the tutorial holds the screen, or
## while a star ends or is born.
func _deaf() -> bool:
	return _held_back or settings_sheet.is_open() or _pick.visible or _shop.visible or _perks.visible or _powers.visible or _reset.visible or sky.ending() or sim.ending() != ""

func _on_sky_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_press_at(t.index, t.position)
		else:
			_lift(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _fingers.has(d.index):
			_fingers[d.index].at = d.position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_press_at(-1, (event as InputEventMouseButton).position)
		else:
			_lift(-1)
	elif event is InputEventMouseMotion and _fingers.has(-1):
		_fingers[-1].at = (event as InputEventMouseMotion).position

func _press_at(finger: int, px: Vector2) -> void:
	if _deaf() or _fingers.has(finger):
		return
	_fingers[finger] = {"at": px, "t": 0.0}
	_brake(px)

func _lift(finger: int) -> void:
	if _fingers.erase(finger):
		_lifted_at = Time.get_ticks_msec()

func _drop_fingers() -> void:
	if not _fingers.is_empty():
		_fingers.clear()
		_lifted_at = Time.get_ticks_msec()

## One brake where a finger is. Heard and felt when it caught something,
## though not every one of a held finger's.
func _brake(px: Vector2) -> void:
	var at: Vector2 = sky.unworld(px)
	var r: float = sim.press_r()
	sky.set_down(at, r)
	if sim.brake(at, r) == 0:
		return
	var now := Time.get_ticks_msec()
	if now - _felt_at >= int(FELT * 1000.0):
		_felt_at = now
		_fx.cue("pour", randf_range(0.94, 1.08))
	_dirty = true

## Held, a finger brakes again where it is now, as often as Flow lets it.
func _hold(delta: float) -> void:
	if _deaf():
		_drop_fingers()
		return
	var gap: float = sim.flow_gap()
	for finger in _fingers:
		var f: Dictionary = _fingers[finger]
		f.t += delta
		if f.t >= gap:
			f.t = 0.0
			_brake(f.at)
```

`_process` calls `_hold(delta)` every frame before the `if not waits:` block (`_stream` goes); `_tutor_hold`, the settings handler, `open_pick`, `open_shop`, `open_perks`, `open_powers`, `open_reset` each call `_drop_fingers()` where they set `_holding = false` or first thing. A touch that also arrives as a mouse press must not brake twice: if the project emulates mouse from touch the screen saw it before as `_pressed_at`'s 60 ms guard; keep that guard in `_press_at` across the two kinds (a mouse press within 60 ms of a touch press is dropped).

- [ ] **Step 3: The card guard.** `_offer` gains, before `_pick_wait += delta`: `if not _fingers.is_empty() or Time.get_ticks_msec() - _lifted_at < int(OFFER_CALM * 1000.0): _pick_wait = 0.0; return` with `const OFFER_CALM := 0.6`. `open_pick` records `_pick_shown_at = Time.get_ticks_msec()` and `_on_pick` returns at once while `Time.get_ticks_msec() - _pick_shown_at < int(PICK_DEAF * 1000.0)` with `const PICK_DEAF := 0.5`; the card's own scrim or close, if it has one, takes the same guard.

- [ ] **Step 4: The button goes.** Delete `_gas_b`, `_gas_button`, `_on_gas_input`, `_press`, `_let_go`, `_pour`, `GAS_W`, the `info.add_child(_gas_button())` line and the `_gas_b` branch in `_notification`; `HAPTICS`'s `"pour"` key stays (it is the press's cue). In the sim delete `pour()` and `stream_gap()`. `locale/ui.csv`: delete `NL_GAS`, `NL_PUFF`, `NL_VOLLEY`, `NL_FX_PUFF`, `NL_FX_VOLLEY` after grepping that nothing reads them; `NL_HINT` becomes `Press the gas to slow it,Toque no gás para freá-lo,Toca el gas para frenarlo`; `TUT_NL_GAS` `Slow the gas,Freie o gás,Frena el gas`; `TUT_NL_GAS_BODY` `"Gas circles the star and never falls by itself. Press it to slow it: it drops into the disc, winds in and feeds the star. Hold to keep slowing it.","O gás gira em volta da estrela e nunca cai sozinho. Toque nele para freá-lo: ele desce até o disco, entra girando e alimenta a estrela. Segure para continuar freando.","El gas gira alrededor de la estrella y nunca cae solo. Tócalo para frenarlo: baja hasta el disco, entra girando y alimenta la estrella. Mantén para seguir frenando."`; `NL_MOTTO` stays. Run the import.

- [ ] **Step 5: The tutorial's GAS page.** In `ui/hud/nightlight_tutorial_diagram.gd`: every page's sim sets `_sim.ring = Vector2.ZERO` in `_ready` after `Sim.new` (the pages keep the old view and no trickle). `_feed` no longer pours. The GAS lesson's `_set_up` lays 28 puffs of 0.05 on circles from 1.02 to 1.25 of `haze_r()` (dust 0, age `COOL`), and its step presses on a loop of `LOOP[Lesson.GAS]` seconds: at 0.8 s and 1.6 s `_sim.brake(spot, _sim.haze_r() * 0.45)` and `_sky.set_down(spot, _sim.haze_r() * 0.45)` with `spot` a fixed point on the ring at 1.13 of the haze, upper right; `_set_up` again at the loop's end. Under `Motion.reduce` the page is warmed until the braked gas is half way in, as the other lessons are. The WORLDS lesson must still get gas: where it relied on `_feed`'s pour, lay its puffs in `_set_up` (the same 28, inside the disc at 0.7 to 0.97 of the haze) and top them up to 28 every 4 s. Read the file whole first; keep `LOOP`, `WARM` and `TALL` unless a page overflows.

- [ ] **Step 6: The harness presses the sky.** In `tests/_shot_nightlight.gd`: `_touch(down, finger)` sends a `InputEventScreenTouch` to the sky (`_s.sky`) at a point given in the sim's units (`_s.sky.world(spot)`, converted to the viewport with the sky's global transform), and a `"drag"` step sends `InputEventScreenDrag`s along an arc of the ring; while it presses, `_s.sky.mouse_filter` is set to IGNORE and the events go straight to `_s._on_sky_input` with positions in the sky's own pixels (a real pointer over the window would brake too). Where `_run` poured to grow the sky (lines ~131-140, ~211) it now brakes at the fullest slice every `flow_gap()` (copy `_spot` from the probe) or, where a beat needs a heavy star fast, sets the mass as it already does elsewhere. Rename the beats: `3_pour` → `3_press` (shot 0.2 s after a press, so the glow shows), add `3b_falling` (20 s after three presses on one arc), and a beat that opens the pick card with a finger held (`5e_card_drops_finger`: assert in the log that `_s._fingers.is_empty()` once `_s._pick.visible`, and that a press sent to the sky while the card is up leaves `sim.events` without a `brake`). Update the header comment's list of beats.

- [ ] **Step 7: Run.** Parse guard on every file touched; the probe `0 failed`; the suite; the harness on the default driver and on `opengl3_angle`, then with `reduce`, then `pt` and `es` on the default driver. Read `2_start`, `3_press`, `3b_falling`, the pick card and the GAS tutorial shot yourself (crop with PIL from the repo dir): the ring is whole inside the field, the glow is a soft round light with no edge, the hint reads, nothing overlaps. Report every beat's draw calls beside the notes' numbers (94 new, 138-146 heavy, 211 shop).

- [ ] **Step 8: Notes and commit.** `docs/agents/haptics.md` row 42: the tap is the press that braked something. Commit: `feat(nightlight): the hand presses the sky -- a tap brakes, a hold keeps braking, the Gas button goes`

---

### Task 4: The sky's ring, the flush, the readout

**Files:**
- Modify: `arcade/nightlight_sky.gd` (`GAS_MOST`, `_fill`'s gas branch, the birth's drift)
- Modify: `arcade/nightlight_screen.gd` (the readout label, `_refresh_hud`), `ui/menu/arcade_tab.gd` (~203), `locale/ui.csv`
- Modify: `tests/_shot_nightlight.gd` (beats)

**Interfaces:**
- Consumes: `Body.sink`, `sim.system()`, `Sim.kept().worlds`, `sim.ring`.

- [ ] **Step 1: Three lights a puff, and the flush.** `GAS_MOST := 2000`. In `_fill`'s gas branch, after the puff's own light, two more at offsets seeded by the body's id (no RNG a frame):

```gdscript
				var warm := maxf(sqrt(b.heat), b.sink * 0.7)
				var tint := Color(Art.GAS.lerp(Art.WARM, warm), a * (1.0 + 0.6 * b.heat + 0.5 * b.sink))
				_gas.put(at, 0.0, wide, wide, tint)
				# two more lights beside it, so the ring reads as a cloud and
				# not as beads: seeded by the puff, turning slowly with it
				var spread: float = sim.gas_r() * 0.6 * z
				for k in 2:
					var turn := float((b.id * 7919 + k * 104729) % 628) * 0.01 + b.spin * 0.2
					var off := Vector2.from_angle(turn) * spread * (0.6 + 0.4 * float((b.id + k * 3) % 5) / 4.0)
					_gas.put(at + off, 0.0, wide * 0.8, wide * 0.8, Color(tint, tint.a * 0.7))
```

  (replacing the single `_gas.put`). The tutorial's pages (`small` set) keep one light a puff: gate the two extra on `sim.ring.y > 0.0`. The birth's drift (`drawn_in`, `BIRTH_NEAR`) now applies to every puff (`far < rh * BIRTH_NEAR` removed): the whole ring gathers as the star comes up.

- [ ] **Step 2: The readout.** A `Label` named `System` on the sky, `CardBlurb`, `Art.VEIL` at 0.8, top-left, below the powers' chips (`_chips` sits at (22, 22); put the line under it and move it up when there are no chips), `mouse_filter` IGNORE. `_refresh_hud` rebuilds its text only when the four counts change:

```gdscript
func _system_line() -> String:
	var n: Dictionary = sim.system()
	var parts: PackedStringArray = []
	for row: Array in [["planets", "NL_SYS_PLANETS"], ["giants", "NL_SYS_GIANTS"], ["rocks", "NL_SYS_ROCKS"], ["comets", "NL_SYS_COMETS"]]:
		if int(n[row[0]]) > 0:
			parts.append(_count(row[1], int(n[row[0]])))
	return " · ".join(parts)
```

  (`_count(key, n)` is the screen's own `_ONE`/`_N` helper.) Hidden while `sky.ending()` and when the line is empty. `locale/ui.csv`: `NL_SYS_PLANETS_ONE,1 planet,1 planeta,1 planeta` / `_N,%d planets,%d planetas,%d planetas`; `NL_SYS_GIANTS_ONE,1 giant,1 gigante,1 gigante` / `_N,%d giants,%d gigantes,%d gigantes`; `NL_SYS_ROCKS_ONE,1 rock,1 rocha,1 roca` / `_N,%d rocks,%d rochas,%d rocas`; `NL_SYS_COMETS_ONE,1 comet,1 cometa,1 cometa` / `_N,%d comets,%d cometas,%d cometas`; `NL_CARD_WORLDS_ONE,1 world,1 mundo,1 mundo` / `_N,%d worlds,%d mundos,%d mundos`. `TUT_NL_WORLDS_BODY` gains, in each language, the sentence "A world pays far more light than the gas it was made from. Gas left in the ring makes them." / "Um mundo rende muito mais luz do que o gás de que foi feito. O gás deixado no anel é que os faz." / "Un mundo da mucha más luz que el gas del que se hizo. El gas que queda en el anillo los forma." Import.

- [ ] **Step 3: The card.** `ui/menu/arcade_tab.gd` near line 203: between the mass (and supernovas) and the relics append ` · ` and `NL_CARD_WORLDS_ONE/_N` when `kept.worlds > 0`. Check the line still fits the card in pt (the longest) on the tab's shot.

- [ ] **Step 4: Beats.** The harness gains `2b_ring` (a new star, 2 s after the birth has finished), `6d_system` (a third-generation star: set `novas` 2, lay an iron-rich ring with `_lay_ring(Sim.RING, Sim.RING_M, Sim.ASH_H, 0.25)`, run 240 s of sim in the harness's fast-forward so worlds form, then shoot: the readout shows, worlds wear their swirls) and `6e_half_eaten` (a 3-Sun star, 300 s on). Run on both drivers, with `reduce`, and in pt and es; look at each new shot; report draw calls for every beat against Task 3's.

- [ ] **Step 5: Commit.** `feat(nightlight): the ring reads as a cloud, braked gas flushes warm, the system is named`

---

### Task 5: The pace

**Files:**
- Modify: `arcade/nightlight_sim.gd` (numbers only), `tests/_probe_nightlight.gd` (checks whose expected numbers moved)

- [ ] **Step 1: Measure before touching anything.** `-- pace 40 <seed> random 1.0 gas` and `... worlds` for seeds 1, 2, 3 (one at a time, each to its own log); then `-- pace 40 1 random 0.4 gas` and `-- pace 30 1 random 0.0 gas` (nobody touches it). Write the table: minutes to 2 Suns, light a minute over the first ten, first end (minute, Suns, remnant), the system's counts at 10 and 20 min, the second and third stars' light a minute.

- [ ] **Step 2: Tune toward the spec's section 18**, in this order, one lever at a time, re-running seed 1 after each and all three seeds at the end: `RING_M` and `TRICKLE` for 1 to 2 Suns in about five minutes with the button held; `TRICKLE_UP` for a first end at 25 to 30 minutes; `LIGHT` (and only then the tiles' first prices) for a first star's light a minute within 15% of the last build's (take that number from `git stash`-free means: run the pace bot on `main`'s probe in a second checkout made with `git worktree add /tmp/... main`, removed afterwards, or read the eighth pass's figures in `docs/agents/arcade.md`); the `PAY_*` steps for a third star earning about twice a first star's light a minute when the bot sends worlds, and a gas-only hand under half of the worlds hand there. `BRAKE`, `RING_IN` and `RING_OUT` only if a centre press takes more than 120 s to be eaten. `G`, `DRAG` and the chain's real numbers (0.45, 1.06, 8, 1.4, 20) are not touched.

- [ ] **Step 3: Say what an untouched star does.** From the `0.0` run: when it dims, when it fades, what the next star is. If it never ends (the trickle alone feeds it once Wind or the disc reaches the ring), say so; that is the user's "mostly itself" and not a bug.

- [ ] **Step 4: Fix the probe's numbers that moved, run it, the suite, and one harness pass on the default driver.** Commit with the table in the message: `tune(nightlight): the ring's pace`

---

### Task 6: Notes

**Files:**
- Modify: `docs/agents/arcade.md` (a "A ninth time (2026-10-07): a ring to tend" bullet after the eighth, in the file's own voice: what replaces what, the rules, the measured numbers, "Mine, not asked for", "Not done"), `docs/agents/haptics.md`, `docs/agents/analytics.md` if an event's meaning moved, `docs/superpowers/specs/2026-10-07-nightlight-ring-design.md` (an "As built" section at the end: every number Task 5 moved, every ruling made during the build with what it costs if wrong)

- [ ] **Step 1:** Write them from the commits and the logs, not from memory: every figure quoted is one a command printed on this branch. The first line of the arcade bullet says which earlier bullets it replaces (the Gas button, the pour, the stream at the rim, the pour riding a giant's rim, "the sky takes no press").
- [ ] **Step 2:** Commit: `docs(nightlight): the ring -- notes, measurements, the spec as built`
