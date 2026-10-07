# Nightlight Universe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dead stars stay in the world as relics that pull and eat, a star ends one of three ways by its mass, the camera moves to the new star born in the old one's gas, the giant swells and engulfs, and the sky is never empty.

**Architecture:** The sim (`arcade/nightlight_sim.gd`) stays centred on the live star; relics are point masses in that frame, shifted at each birth. The sky (`arcade/nightlight_sky.gd`) draws relics, their nebulae, a far field and the camera's pan as pixel offsets on its existing `centre`/`zoom` mapping. The screen (`arcade/nightlight_screen.gd`) only learns the third end kind, the birth and new words.

**Tech Stack:** Godot 4 GDScript, gl_compatibility; the probe `tests/_probe_nightlight.gd` (headless) is the test; the shot harness `tests/_shot_nightlight.gd` (windowed) is the eye; `tests/run_tests.gd` is the suite.

**Spec:** `docs/superpowers/specs/2026-10-07-nightlight-universe-design.md`

## Global Constraints

- Branch `feat/nightlight-universe`, commits per task; nothing pushed (the user calls the push).
- The game is called Nightlight; the genre's original is never named in code, comments or commits.
- 855 draw calls budget; one `draw_mesh`/`draw_multimesh` per drawing; no `instance uniform`; cozy light has no shape (no rays, beams, lensing arcs).
- Harnesses: `godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_nightlight.gd -- <outdir> [reduce] [en|pt|es]`, one at a time, under `caffeinate -d -i -u`, logged to a file (never piped into `head`); both drivers (`--rendering-driver opengl3_angle` for the second).
- Probe: `godot --headless --path . --script res://tests/_probe_nightlight.gd` (and `-- pace [min] [seed] [first|second|random] [held]`). Parse guard: `godot --headless --check-only --script arcade/nightlight_sim.gd` etc.
- Text goes through `locale/ui.csv` (en, pt, es; `_ONE`/`_N` pairs for counts); titles stay English; after editing the csv run `godot --headless --path . --import` before a harness.
- Touch, not mouse: harnesses press with `InputEventScreenTouch`.
- Honour `Motion.reduce`. `Analytics.start()` never runs from a harness.
- Never read `power[...]` directly; use `on()`.
- The pour stays at the plain disc's rim (`main_r() * haze_wide()`), so the hand's pace does not move when the giant's disc widens (plan decision; add to the spec's amendments in Task 6).

## Review Focus

1. A `KEPT` 2 file (today's players) must load with no relics, `drift` zero, `far` seeded, `metal` 0, and no error; its bodies keep their 9 columns. (Task 1 test.)
2. A relic exactly at a body's position (d = 0) must not divide by zero: the body is eaten first. (Task 1 test.)
3. `end()` with no relics yet (a first death) must still pick a direction and place the relic; `away` from an empty list is a random unit vector, never NaN. (Task 2 test.)
4. The disc widening at the helium flash must not change where the pour comes in, or every kept star's pace jumps; `pour()` uses `main_r() * haze_wide()`. (Task 3 test.)
5. The camera's `shift`/`view` must be back to zero/one when the end finishes, under reduce motion too, or every later frame is off-centre; and the tutorial's END page (which builds its own sky and calls `begin_end`/`end()`) must still play. (Task 5 test by harness beats 8d/8e/16.)

---

### Task 1: Relics in the sim: data, pull, eating, the file

**Files:**
- Modify: `arcade/nightlight_sim.gd` (constants near line 320; `Body` class ~line 50; `tick` ~1016; `save`/`load_saved`/`kept` ~1155-1254)
- Test: `tests/_probe_nightlight.gd` (new `_check_relics()` called from `_initialize`)

**Interfaces:**
- Produces: `enum Relic { WD, NS, BH }`; `var relics: Array[Dictionary]` with keys `kind: int, m: float, pos: Vector2, layers: Array, age: float, novas: int`; `var far: Array[Vector2]`; `var drift: Vector2`; `Body.metal: float`; `func relic_r(rel: Dictionary) -> float`; `func relic_suns(rel: Dictionary) -> float`; `func add_relic(kind: int, m: float, pos: Vector2, layers: Array) -> Dictionary` (appends, drops the farthest past `RELICS_MOST`); event `{"kind": "lost", "at": Vector2, "m": float, "relic": int}`; `KEPT` 3; `kept()` adds `"relics": int`.

- [ ] **Step 1: Add the constants, the enum, the fields**

After `const KEPT := 2` (line ~340) change to `const KEPT := 3` and add:

```gdscript
# --- relics: what a dead star leaves, in the live star's frame ---
enum Relic { WD, NS, BH }
## A white dwarf's mass in Suns, and what each Sun of the dead star adds, up to a limit under Chandrasekhar.
const WD_M := 0.6
const WD_M_PER := 0.05
const WD_MOST := 1.3
## A black hole is this share of the star, and no less than BH_LEAST Suns; from COLLAPSE Suns a supernova leaves one.
const BH_SHARE := 0.2
const BH_LEAST := 3.0
const COLLAPSE := 20.0
## Where a body is lost to a relic, in the sim's pixels: a black hole grows by its Suns.
const WD_R := 8.0
const NS_R := 5.0
const BH_R := 10.0
const BH_R_M := 3.0
## How many relics are kept, and past what distance one pulls nothing.
const RELICS_MOST := 12
const RELIC_REACH := 6000.0
## Neighbour stars, decoration: how many and how far.
const NEIGHBOURS := 5
const FAR_NEAR := 2500.0
const FAR_FAR := 5000.0
```

In `class Body` add `var metal := 0.0` (the dust share of the gas a solid came from, 0..1) with a comment. Add state after `var bodies`:

```gdscript
var relics: Array[Dictionary] = []
var far: Array[Vector2] = []
var drift := Vector2.ZERO
```

In `_init` seed `far`: for `NEIGHBOURS`, `far.append(Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(FAR_NEAR, FAR_FAR))`.

- [ ] **Step 2: Helpers**

```gdscript
func relic_suns(rel: Dictionary) -> float:
	return float(rel.m) / START

## Inside this a body is the relic's: a point for a dwarf or a neutron star, a black hole's horizon by its Suns.
func relic_r(rel: Dictionary) -> float:
	match int(rel.kind):
		Relic.WD: return WD_R
		Relic.NS: return NS_R
	return BH_R + BH_R_M * relic_suns(rel)

## One more relic; past RELICS_MOST the farthest goes.
func add_relic(kind: int, m: float, pos: Vector2, layers: Array) -> Dictionary:
	var rel := {"kind": kind, "m": m, "pos": pos, "layers": layers.duplicate(), "age": 0.0, "novas": novas}
	relics.append(rel)
	while relics.size() > RELICS_MOST:
		var worst := 0
		for i in relics.size():
			if (relics[i].pos as Vector2).length_squared() > (relics[worst].pos as Vector2).length_squared():
				worst = i
		relics.remove_at(worst)
	return rel
```

- [ ] **Step 3: The pull and the eating in `tick`**

Before the body loop in `tick()` build the active list once: `var pulls: Array = []` of `[pos, G * m, r2 of relic_r]` for relics within `RELIC_REACH`. Inside the loop, right after the `r > far` removal and before the tear:

```gdscript
		var lost := false
		for k in pulls.size():
			var rel: Array = pulls[k]
			var to: Vector2 = (rel[0] as Vector2) - p
			var d2 := to.length_squared()
			if d2 <= float(rel[2]):
				var which: int = rel[3]
				if int(relics[which].kind) == Relic.BH:
					relics[which].m = float(relics[which].m) + b.m
				events.append({"kind": "lost", "at": p, "m": b.m, "relic": which})
				bodies.remove_at(i)
				lost = true
				break
			acc_rel += to * (float(rel[1]) / (d2 * sqrt(d2)))
		if lost:
			i -= 1
			continue
```

with `var acc_rel := Vector2.ZERO` declared before the relic loop and `acc += acc_rel` right after `var acc := p * (-pull / (r2 * r))`. Store the relic index as `rel[3]`. Age relics at the end of `tick`: `for rel in relics: rel.age = float(rel.age) + STEP`. Make sure the eaten-by-star branch (`r < eat`) still runs first.

- [ ] **Step 4: Save, load, kept**

In `save()`: write `metal` as a tenth column of each body row; `cfg.set_value("star", "relics", relics.map(func(r): return [int(r.kind), float(r.m), (r.pos as Vector2).x, (r.pos as Vector2).y, float(r.age), int(r.novas), Array(r.layers)]))`; `cfg.set_value("star", "far", far.map(func(p): return [p.x, p.y]))`; `cfg.set_value("star", "drift", [drift.x, drift.y])`.

In `load_saved()`: `old` is `kept < 3` for the bodies' tenth column (`b.metal = clampf(float(row[9]), 0.0, 1.0) if row.size() >= 10 else 0.0`); existing `kept < 2` handling stays (rename the local to `pre_gas`). Read relics only when `kept >= 3`: each row of 7 with finite numbers, `kind` clamped to the enum, `m > 0`, up to `RELICS_MOST`; `far` rows of 2 (if none valid, keep the fresh seeds); `drift` a pair. `kept()` returns `"relics": (cfg.get_value("star", "relics", []) as Array).size()`.

- [ ] **Step 5: Probe checks**

Add `_check_relics()` and call it from `_initialize`:

```gdscript
func _check_relics() -> void:
	var sim := _quiet()
	# a body at rest between the star and a relic of twice its mass falls toward the relic
	var rel: Dictionary = sim.add_relic(Sim.Relic.BH, sim.mass * 2.0, Vector2(2000.0, 0.0), sim.layers())
	var b: Sim.Body = sim.add(Sim.Kind.ROCK, 0.003, Vector2(1000.0, 0.0), Vector2.ZERO)
	_run(sim, 2.0)
	_ok("relic pulls", b.pos.x > 1000.0)
	# inside a black hole it is lost and the hole weighs more
	var was: float = rel.m
	var c: Sim.Body = sim.add(Sim.Kind.ROCK, 0.003, Vector2(2000.0, 0.0), Vector2.ZERO)
	sim.tick()
	_ok("black hole eats", not sim.bodies.has(c) and rel.m > was)
	_ok("lost event", sim.events.any(func(e): return e.kind == "lost"))
	# a white dwarf does not grow, and d = 0 is eaten, not divided by
	var wd: Dictionary = sim.add_relic(Sim.Relic.WD, 6.0, Vector2(-1500.0, 0.0), sim.layers())
	var d: Sim.Body = sim.add(Sim.Kind.GAS, Sim.PUFF, Vector2(-1500.0, 0.0), Vector2.ZERO)
	sim.tick()
	_ok("dwarf eats and stays", not sim.bodies.has(d) and is_equal_approx(float(wd.m), 6.0))
	# past the cap the farthest goes
	for k in Sim.RELICS_MOST:
		sim.add_relic(Sim.Relic.WD, 6.0, Vector2(100.0 + k, 0.0), sim.layers())
	_ok("relic cap", sim.relics.size() == Sim.RELICS_MOST and not sim.relics.has(rel))
	# the file: relics, far, drift and metal round-trip; a KEPT 2 file loads clean
	sim.drift = Vector2(300.0, -40.0)
	var g: Sim.Body = sim.add(Sim.Kind.ROCK, 0.003, Vector2(500.0, 0.0), Vector2.ZERO)
	g.metal = 0.3
	sim.save()
	var back: RefCounted = Sim.load_saved()
	_ok("relics kept", back.relics.size() == Sim.RELICS_MOST and back.far.size() == Sim.NEIGHBOURS and back.drift == sim.drift)
	_ok("metal kept", back.bodies.any(func(x): return is_equal_approx(x.metal, 0.3)))
	var cfg := ConfigFile.new()
	cfg.load(Sim.path)
	cfg.set_value("star", "kept", 2)
	cfg.erase_section_key("star", "relics")
	cfg.save(Sim.path)
	var older: RefCounted = Sim.load_saved()
	_ok("old file clean", older.relics.is_empty() and older.far.size() == Sim.NEIGHBOURS and older.drift == Vector2.ZERO and older.bodies.size() > 0)
```

- [ ] **Step 6: Run the probe and the parse guard**

Run: `godot --headless --path . --check-only --script arcade/nightlight_sim.gd && godot --headless --path . --script res://tests/_probe_nightlight.gd`
Expected: `probe_nightlight: N checks, 0 failed` (N = 46 + 9).

- [ ] **Step 7: Commit**

```bash
git add arcade/nightlight_sim.gd tests/_probe_nightlight.gd
git commit -m "feat(nightlight): relics -- dead stars as masses that pull and eat, kept in the file"
```

---

### Task 2: The three ends and the birth place

**Files:**
- Modify: `arcade/nightlight_sim.gd` (`ending` ~652, `dust_for`, `end` ~671, `_condense`/`_sweep` ~975-995 for `metal`, `_init`)
- Test: `tests/_probe_nightlight.gd` (new `_check_ends()`; `_pace` reports the end and remnant)

**Interfaces:**
- Consumes: Task 1's `Relic`, `add_relic`, `relics`, `far`, `drift`, `Body.metal`.
- Produces: `ending()` returns `"nova" | "nebula" | "fade" | ""`; `func remnant() -> int` (the Relic kind the current end would leave); `func remnant_mass() -> float`; `end()` returns the stardust and sets `var last_birth: Dictionary` `{"from": Vector2 (the relic's pos in the new frame), "d": float}` for the sky; `func born() -> void` lays the first cloud; constants `NEBULA_DUST`, `LOBE`, `METAL`, `IRONY`, `FIRST_CLOUD`.

- [ ] **Step 1: Constants**

```gdscript
## A planetary nebula pays this; the new disc sits inside the new star's lobe by LOBE.
const NEBULA_DUST := 2
const LOBE := 1.6
## The dead star's silicon, iron and rock become dust in the gas it leaves; a solid from gas this dusty is iron-dark.
const METAL := 2.5
const IRONY := 0.08
## A first star is born in this many puffs of gas.
const FIRST_CLOUD := 36
```

- [ ] **Step 2: `ending`, `remnant`, `remnant_mass`**

```gdscript
func ending() -> String:
	if made[5] >= IRON * START:
		return "nova"
	if ignited[1] and not ignited[2] and suns() < HEAVY and made[1] >= CARBON * START:
		return "nebula"
	if cold >= GRACE:
		return "fade"
	return ""

## What the end now due leaves: a black hole from COLLAPSE Suns, a neutron star for any other supernova, a white dwarf otherwise.
func remnant() -> int:
	if ending() == "nova":
		return Relic.BH if suns() >= COLLAPSE else Relic.NS
	return Relic.WD

func remnant_mass() -> float:
	match remnant():
		Relic.NS: return IRON * START
		Relic.BH: return maxf(BH_LEAST, BH_SHARE * suns()) * START
	return minf(WD_MOST, WD_M + WD_M_PER * (suns() - 1.0)) * START
```

`goal()` is unchanged (the `heavy: false` branch already exists); the screen's words change in Task 5.

- [ ] **Step 3: `end()`**

Rewrite the body of `end()`: compute `how`, `got` (`dust_for()` for nova, `NEBULA_DUST` for nebula, `FADE_DUST` for fade), `count` (nova as today, `FADE_ASHES` otherwise), the old star's `layers()` and `remnant()`/`remnant_mass()` **before** resetting anything. Then:

```gdscript
	# where the next star is born: away from the relics there are, far enough that its disc is its own
	var mean := Vector2.ZERO
	for rel in relics:
		mean += rel.pos as Vector2
	var away := Vector2.from_angle(_rng.randf() * TAU) if relics.is_empty() else (-mean).normalized().rotated(_rng.randf_range(-0.7, 0.7))
	if not away.is_finite() or away.length() < 0.5:
		away = Vector2.from_angle(_rng.randf() * TAU)
	var rm := remnant_mass()
	var kind := remnant()
	# ... the existing reset of mass, fuel, env, made, ignited, lv, power, bodies ...
	var d := LOBE * haze_r() * (1.0 + sqrt(rm / mass))
	for rel in relics:
		rel.pos = (rel.pos as Vector2) - away * d
	for i in far.size():
		far[i] -= away * d
	drift += away * d
	add_relic(kind, rm, -away * d, was_layers)
	last_birth = {"from": -away * d, "d": d}
```

`haze_r()` here is the **new** star's (mass already reset). Ashes: `b.dust = ASH_DUST + METAL * (was_layers[5] + was_layers[6] + was_layers[7])` clamped to 0.3 (layers are hydrogen, helium, carbon, neon, oxygen, silicon, iron, rock: indices 5, 6, 7). Note `mass` after reset for a fade/nebula must still honour `EMBER`.

- [ ] **Step 4: `metal` through condensing and merging**

In `_condense` (a grain from two puffs' dust) set the grain's `metal` to the dust share of the gas it came from: `grain.metal = clampf((a.dust * a.m + b.dust * b.m) / (a.m + b.m) / IRONY, 0.0, 1.0) * ...` — keep it simple and honest: `grain.metal = clampf(mean_dust / (2.0 * IRONY), 0.0, 1.0)` where `mean_dust` is the mass-weighted dust of the two puffs, so a 1% puff gives 0.06 and a 15% supernova puff gives 0.94. In `_sweep` (a solid taking a puff's dust) blend by mass: `s.metal = (s.metal * s.m + puff_metal * taken) / (s.m + taken)`. Wherever two solids merge in `_meet` blend `metal` by mass; in `_tear` the pieces keep `b.metal`.

- [ ] **Step 5: `born()` for a first game**

```gdscript
## A first star comes up in a cloud of its own: gas already falling in, no relic.
func born() -> void:
	var pull := gm()
	var rw := main_r()
	for i in FIRST_CLOUD:
		var near := (ASH_NEAR + _rng.randf() * ASH_REACH) * rw
		var far_r := near + 0.4 * rw + _rng.randf() * ((ASH_FAR - 0.4) * rw - near)
		var way := Vector2.from_angle(_rng.randf() * TAU)
		var v := sqrt(pull * (2.0 / far_r - 2.0 / (near + far_r)))
		var b := add(Kind.GAS, PUFF * ASH_M * _rng.randf_range(0.6, 1.4), way * far_r, way.orthogonal() * -v)
		b.h = STAR_H
		b.dust = 0.02
		b.age = COOL
```

Factor the ash-laying loop of `end()` into `_lay_gas(count, m_each, h, dust)` and call it from both. `load_saved` calls `sim.born()` when there is no file (the `cfg.load(path) != OK` return). The screen's `_on_reset` (Task 5) calls `born()` after `Sim.new()`.

- [ ] **Step 6: Probe checks and the pace report**

```gdscript
func _check_ends() -> void:
	# a 4-Sun star whose helium core reaches 1.06 Suns sheds a nebula and leaves a white dwarf
	var sim := _quiet()
	sim.mass = Sim.START * 4.0
	sim.fuel = sim.mass * 0.5
	sim.ignited[1] = true
	sim.made[0] = Sim.CARBON * Sim.START
	sim.made[1] = Sim.CARBON * Sim.START
	_ok("nebula end", sim.ending() == "nebula" and sim.remnant() == Sim.Relic.WD)
	_ok("dwarf mass", is_equal_approx(sim.remnant_mass(), (Sim.WD_M + Sim.WD_M_PER * 3.0) * Sim.START))
	var dust_was: int = sim.dust
	var layers: Array = sim.layers()
	var paid: int = sim.end()
	_ok("nebula pays", paid == Sim.NEBULA_DUST and sim.dust == dust_was + Sim.NEBULA_DUST)
	_ok("one relic", sim.relics.size() == 1 and int(sim.relics[0].kind) == Sim.Relic.WD)
	var d: float = sim.last_birth.d
	var from: Vector2 = sim.last_birth.from
	_ok("lobe rule", is_equal_approx(d, Sim.LOBE * sim.haze_r() * (1.0 + sqrt(float(sim.relics[0].m) / sim.mass))) and is_equal_approx(from.length(), d))
	_ok("disc inside lobe", d / (1.0 + sqrt(float(sim.relics[0].m) / sim.mass)) >= sim.haze_r() * Sim.LOBE * 0.999)
	_ok("drift moved", is_equal_approx(sim.drift.length(), d) and sim.far.size() == Sim.NEIGHBOURS)
	_ok("first end has a direction", from.is_finite() and from.length() > 1.0)
	# a 10-Sun supernova leaves a neutron star, a 25-Sun one a black hole of 5 Suns; the relics shift
	var big := _quiet(3)
	big.mass = Sim.START * 10.0
	big.made[5] = Sim.IRON * Sim.START
	_ok("neutron star", big.ending() == "nova" and big.remnant() == Sim.Relic.NS and is_equal_approx(big.remnant_mass(), Sim.IRON * Sim.START))
	big.end()
	var first: Vector2 = big.relics[0].pos
	big.mass = Sim.START * 25.0
	big.made[5] = Sim.IRON * Sim.START
	_ok("black hole", big.remnant() == Sim.Relic.BH and is_equal_approx(big.remnant_mass(), 5.0 * Sim.START))
	big.end()
	_ok("relics shift", big.relics.size() == 2 and big.relics[0].pos != first and (big.relics[1].pos as Vector2).length() > (big.relics[0].pos as Vector2).length() * 0.5)
	# a supernova's gas is dusty, and the grain it makes is iron-dark
	var dusty := 0.0
	for b: Sim.Body in big.bodies:
		dusty = maxf(dusty, b.dust)
	_ok("metal-rich ashes", dusty > 0.1)
	var grain := _quiet(5)
	var at := Vector2(grain.haze_r() * 0.9, 0.0)
	var p1: Sim.Body = grain.add(Sim.Kind.GAS, Sim.PUFF, at, grain.circle_vel(at))
	var p2: Sim.Body = grain.add(Sim.Kind.GAS, Sim.PUFF, at + Vector2(10.0, 0.0), grain.circle_vel(at))
	for p in [p1, p2]:
		p.dust = 0.15
		p.age = Sim.COOL + 1.0
	_run(grain, 1.0)
	_ok("iron grain", grain.bodies.any(func(x): return x.kind != Sim.Kind.GAS and x.metal > Sim.IRONY))
	# a first game is born in gas
	var fresh := _quiet(9)
	fresh.born()
	_ok("first cloud", fresh.gas_count() == Sim.FIRST_CLOUD and fresh.relics.is_empty())
```

In `_pace`, when the bot's life ends print `end: <how> remnant: <wd|ns|bh> at <min> min, <suns> Suns`, and at the end time 600 ticks with 300 bodies and 12 relics (`add_relic` in a ring at 2,000 px) and print the microseconds a tick.

- [ ] **Step 7: Run**

Run: `godot --headless --path . --script res://tests/_probe_nightlight.gd` then `godot --headless --path . --script res://tests/_probe_nightlight.gd -- pace 40 1 random 1.0`
Expected: 0 failed; the pace run reports a supernova and `ns` (the bot reaches 21 Suns) in about 27 min, and a tick under 100 us with relics. Then `-- pace 40 1 random 0.4`: a slower hand; report which end it got.

- [ ] **Step 8: Commit**

```bash
git add arcade/nightlight_sim.gd tests/_probe_nightlight.gd
git commit -m "feat(nightlight): three ends by mass, the next star born away from the relics, iron-dark worlds from a supernova's gas"
```

---

### Task 3: The giant

**Files:**
- Modify: `arcade/nightlight_sim.gd` (`GIANT`, `SEEN_LOG`, `star_r`, `haze_r`, `frost_r`, `temp`, `_burn`'s swell line ~1146, `pour` ~777, `tick`'s `eat`)
- Test: `tests/_probe_nightlight.gd` (new `_check_giant()`)

**Interfaces:**
- Produces: `swell` in 0..2; `haze_r()`, `frost_r()`, `wind_r()` and the eat radius on `star_r()`; `func pour_r() -> float` (the plain disc's rim, what `pour()` uses); `func giant() -> float` (= `minf(1.0, swell)` for colour and the sky).

- [ ] **Step 1: Numbers and radii**

`const GIANT := 1.2` (was 0.28), `const SEEN_LOG := 70.0` (was 40). `const SUPER := 2.0` (the supergiant's swell).

```gdscript
func star_r() -> float:
	return main_r() * (1.0 + GIANT * swell)

func haze_r() -> float:
	return star_r() * haze_wide()

func frost_r() -> float:
	return star_r() * FROST

## The plain disc's rim, where the hand's gas comes in: the giant's wider disc does not move the pour.
func pour_r() -> float:
	return main_r() * haze_wide()

func giant() -> float:
	return minf(1.0, swell)
```

`temp()`: `lerpf(k, GIANT_K, giant())`. In `pour()` use `pour_r()` for `rh`. `tick`'s `eat` already uses `star_r()`; check `roche_r()` stays on `main_r()`.

- [ ] **Step 2: When it swells**

In `_burn()` replace the swell line:

```gdscript
	var want := 0.0
	if awake and (ignited[1] or not h_on):
		want = SUPER if ignited[2] else 1.0
	swell = move_toward(swell, want, STEP / SWELL)
```

`load_saved` clamps `swell` to `0..SUPER`. `save` unchanged.

- [ ] **Step 3: Probe**

```gdscript
func _check_giant() -> void:
	var sim := _quiet()
	var plain: float = sim.haze_r()
	var pour_was: float = sim.pour_r()
	sim.swell = 1.0
	_ok("giant disc", is_equal_approx(sim.haze_r(), plain * (1.0 + Sim.GIANT)))
	_ok("pour stays", is_equal_approx(sim.pour_r(), pour_was))
	_ok("giant on screen", sim.seen_r() > 200.0 and sim.zoom() < 0.7)
	# a circle at 1.5 of the plain disc, parked for good on a plain star, spirals in once the star is a giant
	var parked := _quiet(2)
	var at := Vector2(parked.haze_r() * 1.5, 0.0)
	var b: Sim.Body = parked.add(Sim.Kind.ROCK, 0.003, at, parked.circle_vel(at))
	_run(parked, 60.0)
	var still: float = b.pos.length()
	parked.swell = 1.0
	_run(parked, 60.0)
	_ok("giant engulfs", not parked.bodies.has(b) or b.pos.length() < still * 0.9)
	# the swell comes with the helium flash, and goes to SUPER with carbon
	var lit := _quiet(4)
	lit.burning = true
	lit.ignited[1] = true
	_run(lit, Sim.SWELL * 1.2)
	_ok("flash swells", lit.swell > 0.95 and lit.swell <= 1.0)
	lit.ignited[2] = true
	_run(lit, Sim.SWELL * 1.2)
	_ok("carbon supergiant", lit.swell > 1.95)
	_ok("colour clamps", is_equal_approx(lit.giant(), 1.0))
```

- [ ] **Step 4: Run the probe and the pace**

Run: the probe, then `-- pace 40 1 random 1.0`. Expected: 0 failed; the supernova still between 24 and 32 min (the pour did not move). Quote both numbers in the commit.

- [ ] **Step 5: Commit**

```bash
git add arcade/nightlight_sim.gd tests/_probe_nightlight.gd
git commit -m "feat(nightlight): the giant -- from the helium flash, 2.2 times wide, its disc engulfing what was parked"
```

---

### Task 4: The sky draws the universe: relics, nebulae, far field, neighbours, iron paint

**Files:**
- Modify: `arcade/nightlight_art.gd` (colours ~line 25-55, `sky` ~214, `paint_of` ~82; new `far_field`, `disc` mesh)
- Modify: `arcade/nightlight_sky.gd` (`GAS_MOST` 480→1100; `_fill` ~337; `_draw_warm`, `_draw_bodies`; new `_fill_relics`, `_draw_far`)
- Test: `tests/_shot_nightlight.gd` (new beat `6c_relics`: `relics` step adds three relics by hand)

**Interfaces:**
- Consumes: `sim.relics`, `sim.far`, `sim.drift`, `sim.relic_r()`, `Body.metal`, `Sim.Relic`.
- Produces: `Art.WD`, `Art.NS`, `Art.PAINT_IRON`; `Art.far_field(seed: int) -> ArrayMesh` (a `FAR_WIDE` square centred on 0); `Art.disc() -> ArrayMesh` (a filled circle of radius R, white); `Art.paint_of(kind, ice, metal := 0.0)`; sky constants `NEBULA_PUFFS 48, NEBULA_R 500, NEBULA_FAR 3.5, NEBULA_LIFE 600, FAR_PARALLAX 0.25, FAR_WIDE 6000`; `sky.world(p: Vector2) -> Vector2` (= `px(p)` but honouring the camera `shift` Task 5 adds, so write it now as `centre + shift + p * (sim.zoom() * view * u)` with `shift`/`view` fields defaulting to 0/1).

- [ ] **Step 1: Art**

Add `const WD := Color("dfe8ff")`, `const NS := Color("cfc4ff")`, `const PAINT_IRON := Color("5c5a6e")`. `paint_of(kind, ice, metal := 0.0)`: `PAINT[kind].lerp(ICE, ice * 0.7).lerp(PAINT_IRON, clampf(metal, 0.0, 1.0) * 0.8)`. In `sky()` delete the `for i in mini(novas, 8)` cloud loop (keep the signature, ignore `novas`; remove `CLOUDS` if unused elsewhere: grep). Add:

```gdscript
## The stars far behind everything, over a FAR_WIDE square round the origin: one mesh, slid a little with the camera.
static func far_field(seed: int, wide: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tints := [Color("fff6e6"), Color("d6e0ff"), Color("ffd6dc")]
	for i in 90:
		var at := Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * wide
		var r := (1.6 + rng.randf() * rng.randf() * 5.0) * 2.4
		_radial(b, at, r, [[0.0, Color(tints[rng.randi() % 3], 0.2 + rng.randf() * 0.5)], [0.4, Color(tints[rng.randi() % 3], 0.3)], [1.0, Color(tints[0], 0.0)]])
	return b.mesh()

## A filled disc of radius R: a black hole's dark body, drawn scaled.
static func disc() -> ArrayMesh:
	var b := Face.Builder.new()
	b.circle(Vector2.ZERO, R, Color.WHITE, SIDES)
	return b.mesh()
```

(Use whatever `Face.Builder` offers for a filled circle; `lump` shows the fan pattern if there is no `circle`.)

- [ ] **Step 2: The sky's fields and fill**

Add `var shift := Vector2.ZERO`, `var view := 1.0`, `var _far: ArrayMesh`, `var _far_for := -1`, `var _holes: Batch` (`Batch.new(Art.disc(), 16)`), `func world(p)` as above, and make `px()` call `world()`. In `_fill()` compute `z` as `sim.zoom() * view * u` and `at = world(b.pos)`; pass `b.metal` to `paint_of`. Add `_fill_relics(z, seen)` called after the bodies:

```gdscript
func _fill_relics(z: float, seen: float) -> void:
	for i in sim.relics.size():
		var rel: Dictionary = sim.relics[i]
		var at := world(rel.pos as Vector2)
		if not Rect2(Vector2.ZERO, size).grow(NEBULA_R * NEBULA_FAR * z).has_point(at):
			continue
		# its nebula: a seeded ring of soft lights in its layers' colours, spreading and thinning over its age
		var rng := RandomNumberGenerator.new()
		rng.seed = 500 + int(rel.novas) * 7 + int(rel.kind)
		var age := minf(1.0, float(rel.age) / NEBULA_LIFE)
		var spread := lerpf(1.5, NEBULA_FAR, 1.0 - pow(1.0 - age, 2.0)) * NEBULA_R * z * 0.3
		var a := lerpf(0.22, 0.06, age) * seen
		var layers: Array = rel.layers
		for k in NEBULA_PUFFS:
			var li := k % maxi(1, layers.size() - 1)
			if float(layers[li]) < 0.01:
				continue
			var way := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.55, 1.0)
			var wide := rng.randf_range(0.5, 1.1) * (40.0 + 60.0 * age) * u / Art.R
			_gas.put(at + way * spread * (1.0 + 0.6 * li / 7.0), 0.0, wide, wide, Color(Art.MADE[li], a))
		# the relic itself
		var rr: float = sim.relic_r(rel) * z
		match int(rel.kind):
			Sim.Relic.WD:
				var r := maxf(4.0 * u, rr)
				_warms.put(at, 0.0, r * 5.0 / Art.R, r * 5.0 / Art.R, Color(Art.WD, 0.35 * seen))
				_warms.put(at, 0.0, r / Art.R, r / Art.R, Color(Color.WHITE, 0.95 * seen))
			Sim.Relic.NS:
				var r := maxf(3.0 * u, rr)
				var pulse := 1.0 if Motion.reduce else 1.0 + 0.12 * sin(_clock * 2.6)
				_warms.put(at, 0.0, r * 4.0 * pulse / Art.R, r * 4.0 * pulse / Art.R, Color(Art.NS, 0.4 * seen))
				_warms.put(at, 0.0, r / Art.R, r / Art.R, Color(Color.WHITE, 0.95 * seen))
			_:
				var r := maxf(10.0 * u, rr)
				_warms.put(at, 0.0, r * 1.6 / Art.R, r * 1.6 / Art.R, Color(Art.WARM, 0.5 * seen))
				_holes.put(at, 0.0, r / Art.R, r / Art.R, Color(Art.SHADE, seen))
	for p: Vector2 in sim.far:
		var at := world(p)
		if Rect2(Vector2.ZERO, size).grow(40.0).has_point(at):
			var r := 4.0 * u
			_warms.put(at, 0.0, r * 6.0 / Art.R, r * 6.0 / Art.R, Color(Art.COOL, 0.3 * seen))
			_warms.put(at, 0.0, r / Art.R, r / Art.R, Color(Color.WHITE, 0.9 * seen))
```

`_holes` is sent with the other batches and shown in `_draw_bodies` **before** the lumps (a dark disc under the bodies, over the gas). `_draw_light()` gets the far field first: `if _far == null: _far = Art.far_field(77, FAR_WIDE)`; draw it with `Transform2D(0, Vector2(s, s), 0, centre + shift * FAR_PARALLAX - sim.drift * FAR_PARALLAX * s)` where `s = u * FAR_PARALLAX * maxf(0.6, sim.zoom() * view)`, wrapping `drift` with `fposmod` over `FAR_WIDE` so it never runs out. One draw.

- [ ] **Step 3: Harness beat**

In `tests/_shot_nightlight.gd` add a step `"relics"` that does `_s.sim.add_relic(Sim.Relic.WD, 6.0, Vector2(-900, -700), _s.sim.layers())`, `NS` at `(1100, 300)` with `14.0`, `BH` at `(200, 1300)` with `50.0`, then `_s.sim.relics[2].age = 300.0`; insert `[23.55, "relics"], [23.58, "shot", "6c_relics"]` after `6_giant`. Run once windowed (`caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_nightlight.gd -- /tmp/nl_relics > /tmp/nl_relics.log 2>&1`), look at `6c_relics.png` and `6_giant.png`, and quote draw calls for `2_start` and `6c_relics` from the log.

- [ ] **Step 4: Parse guards and the probe**

Run: `godot --headless --path . --check-only --script arcade/nightlight_sky.gd`, same for `nightlight_art.gd`; the probe stays green.

- [ ] **Step 5: Commit**

```bash
git add arcade/nightlight_art.gd arcade/nightlight_sky.gd tests/_shot_nightlight.gd
git commit -m "feat(nightlight): the sky draws relics, their nebulae, a far field and neighbour stars; iron-dark worlds"
```

---

### Task 5: The camera, the nebula end, the birth, the words

**Files:**
- Modify: `arcade/nightlight_sky.gd` (`END` ~63, `begin_end` ~243, `_star_now` ~433, `_fill_end` ~403, `_draw_warm` ~459, new camera step in `refresh`)
- Modify: `arcade/nightlight_screen.gd` (`_step_end` ~1224, `_on_reset` ~1042, `_say` keys, `tutorial_pages` ~1078, Analytics at ~1254, the goal line's `NL_GOAL_C_WAIT` format, `_build` where the screen first opens)
- Modify: `ui/menu/arcade_tab.gd:205` (the card's line), `ui/hud/nightlight_tutorial_diagram.gd` (END lesson still plays a nova; add nothing but make sure `begin_end("nova", layers, Vector2.ZERO)` compiles)
- Modify: `locale/ui.csv`
- Test: `tests/_shot_nightlight.gd` beats `8d_pull_back`, `8e_pan`, `9a_nebula_leaving`, `9b_relic_wd`, `0_birth`, `17_tab_after`

**Interfaces:**
- Consumes: Task 2's `ending()` "nebula", `remnant()`, `last_birth`, `born()`; Task 4's `shift`, `view`, `world()`.
- Produces: `sky.begin_end(how: String, shares: Array, remnant: int)`; `sky.END.nebula`; `sky.swapped(birth: Dictionary)` taking `sim.last_birth`; `sky.begin_birth()` for a first game / Start over (the `close` part alone); `END[how].all` grown by `pull_back + pan + close`.

- [ ] **Step 1: The sky's camera and the nebula end**

`END` gets `"nebula": {"fall": 0.0, "swap": 4.2, "all": 0.0, "life": 6.5, "fly": 700.0, "veil": 0.0}` and every entry gets `"pull_back": 1.2, "pan": 3.0, "close": 4.0`; compute `all` as `swap + pull_back + pan + close` in `end_time()` (drop the literal `all`). In `begin_end(how, shares, remnant)`: for `"nebula"` build the shells with `LOBES_NEBULA` 3 lobes of `randf_range(0.75, 1.0)`, only `shares[0]` and `shares[1]`, counts `24 + 48 * sqrt(share)`, `v` 1.0 for hydrogen and 0.6 for helium, `wait` 0 and 0.4; `_end.remnant = remnant`. `_star_now()` for `"nebula"` is the fade's branch (thinning), no white core.

Camera: in `swapped(birth)` store `_end.birth = birth` and set `shift = world_offset(birth.from)`… concretely `shift = -(birth.from as Vector2) * sim.zoom() * u` (so the old star's place, now at `birth.from`, is still drawn at `centre`), `view = 1.0`. In `refresh()`, when `_end.swapped`: let `s = _end.t - END[how].swap`; phases: `s < pull_back`: `view` eases from 1 toward `fit`, where `fit = clampf(0.7 * size.y / (float(birth.d) * sim.zoom() * u), 0.3, 1.0)`, and `shift` stays at its start scaled by `view` (the old star stays under `centre`: `shift = -from * sim.zoom() * view * u`); `pull_back <= s < pull_back + pan`: `k = ease((s - pull_back) / pan, -1.8)`, `shift = -from * sim.zoom() * view * u * (1.0 - k)`; after: `shift = 0`, `view` eases from `fit` to 1 over `close` while `_rise` runs (set `RISE` to `close`). Under `Motion.reduce`: `shift = 0`, `view = 1` at once and `_rise` over 2 s. `finish_end()` sets `shift = Vector2.ZERO; view = 1.0`.

The birth: during `close`, the ash puffs nearest the star (`b.pos.length() < haze_r * 0.8`) are drawn at `b.pos * (1.0 + 0.5 * (1.0 - _rise))` (drifting in) in `_fill`; `_draw_star`'s `now.x` is `lerpf(0.3, 1.0, ease(_rise, 0.4))` as today. `begin_birth()`: `_end = {"how": "birth", "t": 0.0, "shells": [], "swapped": true, "col": ..., "r": star_px(), "birth": {"from": Vector2.ZERO, "d": 0.0}}`, `_rise = 0`, and `END.birth = {"swap": 0.0, "pull_back": 0.0, "pan": 0.0, "close": 4.0, "life": 0.0, "fly": 0.0, "veil": 0.0, "fall": 0.0}`; `ending()` must return true for it so the screen holds the sim (it already holds while `sky.ending()`), and `end_swap()` 0 so `_step_end` does not call `sim.end()` — guard `_step_end` with `_end_done = true` when `how == "birth"`. Simpler: give the screen a `_birth := true` flag set by `begin_birth()` and have `_step_end` skip `sim.end()`/`open_perks()` for it, calling `sky.finish_end()` at `end_time()`.

- [ ] **Step 2: The screen**

`_step_end`: `sky.begin_end(how, sim.layers(), sim.remnant())`; `_say` by how and remnant: `"NL_END_NEBULA"`, `"NL_END_FADE"`, `"NL_END_NOVA_NS"`, `"NL_END_NOVA_BH"`; cue `"fade"` for the nebula too; `Analytics.track("nightlight_nova", {..., "how": _end_how, "remnant": ["wd", "ns", "bh"][remnant]})`; `sky.swapped(sim.last_birth)`. In `_ready`/first open: if `sim.bodies` is a fresh cloud and no file existed (have `load_saved` set `sim.fresh = true` when it called `born()`), call `sky.begin_birth()` and cue `"born"`. `_on_reset`: `sim = Sim.new(); sim.born(); sky.started(); sky.begin_birth()`. The goal line: where `GOALS` maps `"c"` with `heavy == false`, format `NL_GOAL_C_WAIT` with `[Art.short(Sim.HEAVY, c), Art.short(Sim.CARBON, c), core temp]` (check the existing call's argument order and keep the core temperature). `tutorial_pages`: `TUT_NL_END_BODY % [Art.short(Sim.IRON, c), Art.short(Sim.HEAVY, c), Art.short(Sim.COLLAPSE, c)]`.

`ui/menu/arcade_tab.gd:205`: after the mass, if `star.relics > 0` append ` · ` + `tr("NL_CARD_RELICS_ONE")` or `tr("NL_CARD_RELICS_N") % relics`.

- [ ] **Step 3: Words** (`locale/ui.csv`, keep the file's quoting style; pt and es written with the same care as the rows round them)

```
NL_END_NEBULA,The star lets its layers go · a white dwarf is left,A estrela solta suas camadas · fica uma anã branca,La estrella suelta sus capas · queda una enana blanca
NL_END_NOVA_NS,Supernova · a neutron star is left,Supernova · fica uma estrela de nêutrons,Supernova · queda una estrella de neutrones
NL_END_NOVA_BH,Supernova · a black hole is left,Supernova · fica um buraco negro,Supernova · queda un agujero negro
NL_END_FADE,"Nothing left to burn · the star fades, a white dwarf is left","Nada mais a queimar · a estrela se apaga, fica uma anã branca","Nada que quemar · la estrella se apaga, queda una enana blanca"
NL_GOAL_C_WAIT,Carbon lights on a star of %s× · sheds at %s Suns of helium · core %s,O carbono acende numa estrela de %s× · solta as camadas com %s sóis de hélio · núcleo a %s,El carbono se enciende en una estrella de %s× · suelta sus capas con %s soles de helio · núcleo a %s
NL_CARD_RELICS_ONE,1 relic,1 relíquia,1 reliquia
NL_CARD_RELICS_N,%d relics,%d relíquias,%d reliquias
TUT_NL_END_BODY,"An iron core of %s Suns ends a star as a supernova: under %s× it sheds its layers as a nebula and leaves a white dwarf; from %s× a black hole, else a neutron star. The relic stays, pulls, and the next star is born in the gas.",...
```

Replace the old `NL_END_NOVA` uses (grep) and rewrite `TUT_NL_END_BODY`'s pt/es to match. Run `godot --headless --path . --import`.

- [ ] **Step 4: Harness beats**

Insert in `STEPS`: after `8c_shells`: `[29.3, "shot", "8d_pull_back"], [31.0, "shot", "8e_pan"], [34.0, "shot", "8f_rising"]` (retime the perks beats after by the added `pull_back + pan` seconds: +4.2 s to every later time). Add a step `"nebula"` that sets `_s.sim.mass = Sim.START * 4.0; _s.sim.ignited[1] = true; _s.sim.made[1] = Sim.CARBON * Sim.START` on the new star after `13_new`, with shots `9a_nebula_leaving` at +2.5 s and `9b_relic_wd` at `+ swap + pull_back + pan + close + 0.5`. Add a step `"fresh"` before `open` on a second run mode (`-- <outdir> fresh`) that deletes the cfg so the first open plays the birth, shot `0_birth` at 1.5 s into it. `17_tab_after` already exists; check the card's relics line.

Run both drivers, reduce motion, pt and es (one at a time, logged to files). Look at every new shot. Quote draw calls: `2_start`, `6_giant`, `6c_relics`, `8e_pan`, `9b_relic_wd`.

- [ ] **Step 5: Suite**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -3`
Expected: `... 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add arcade/nightlight_sky.gd arcade/nightlight_screen.gd ui/menu/arcade_tab.gd ui/hud/nightlight_tutorial_diagram.gd locale/ui.csv tests/_shot_nightlight.gd
git commit -m "feat(nightlight): the camera moves to the new star, a nebula end, a birth in gas, the words for three ends"
```

---

### Task 6: Notes

**Files:**
- Modify: `docs/agents/arcade.md` (a new bullet under Nightlight, after the sounds bullet), `docs/agents/analytics.md` (`nightlight_nova`'s `remnant`), `docs/agents/haptics.md` (row 42: the nebula end cues `fade`), `docs/superpowers/specs/2026-10-07-nightlight-universe-design.md` (an amendment: the pour stays at the plain disc; every number the build changed from the spec)

- [ ] **Step 1: Write the bullet** in the voice of the bullets above it: what replaces what (the clouds in `Art.sky`, the end's single kind, the star reborn in place), the names (`relics`, `add_relic`, `relic_r`, `remnant`, `last_birth`, `born`, `pour_r`, `giant`, `shift`/`view`/`world`, `begin_birth`, `END.nebula`), the measured numbers (draw calls per beat on both drivers, the pace runs with the end and remnant, a tick with relics), what is mine and what is not done (the spec's section 10, plus whatever the build left).
- [ ] **Step 2: Commit**

```bash
git add docs/agents/arcade.md docs/agents/analytics.md docs/agents/haptics.md docs/superpowers/specs/2026-10-07-nightlight-universe-design.md
git commit -m "docs(nightlight): the universe around the star -- notes, measurements, what is mine"
```
