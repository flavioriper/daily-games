# Binairo Motion (polish sub-project 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Binairo board and its island world cozy motion: a tween library with a reduce-motion switch, nine board effects, shader ambience (grass sway, toon water, pollen, camera breath) and the harness that measures it.

**Architecture:** A static `core/motion.gd` holds every tween recipe and the `reduce` flag; boards call it and get `Tween`s back that tests step with `custom_step`. Continuous motion lives in shaders driven by one global shader parameter `motion_scale`, owned by a new `world/ambient.gd` node on the stage. One-shot particles are pooled in `world/fx.gd`, a child of the board. `puzzles/binairo3d.gd` wires the effects to taps, reset, build and solve.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility renderer, Godot spatial shaders with `#include`, `CPUParticles3D`, Blender 5.1 via `tools/build_models.sh` (only to regenerate the rim pieces).

**Spec:** `docs/superpowers/specs/2026-09-13-binairo-polish-design.md`, section "Sub-project 1". Read it first; every number below comes from it.

## Global Constraints

- Renderer is `gl_compatibility` on every platform. Nothing may read depth or screen textures. `CPUParticles3D` only, never `GPUParticles3D`.
- Every recipe returns the `Tween` it made, or `null` when reduce-motion skipped it. Callers guard `if tw != null`.
- Every colour comes from `core/palette.gd`. New constants: `FOCUS` `7fd1ff`, `WATER_HI` `5fb0e8`.
- Blush blends are quantised to 16 steps, so `BAD_BLEND` becomes `0.375` (6/16) and the heartbeat adds `0.125` (2/16).
- Material-name conventions: `_flat` (no outline, existing), `_sway` (wind shader, new). A `_sway` material must also end in `_flat`.
- Under reduce-motion: decorative recipes finish instantly and return `null`; essential ones (rolls) run 0.15 s linear; `motion_scale` is 0; pollen, puffs, sparkles, splash and camera breath are off.
- Tests: headless runner `godot --headless --path . --script res://tests/run_tests.gd` must print `failed=0`. The win harness `godot --path . --resolution 540x960 --script res://tests/_win.gd` must print `winnable=10/10`.
- Tabs for indentation in GDScript, as the repo does. Doc comments with `##` above every class and non-trivial function, as the repo does.
- Commit after every task with a message in the repo's style (`feat:`, `fix:`, `docs:`, `test:`; lower-case, present tense, one line).
- Do not touch the uncommitted mascot files on the branch (`art/mascot_pom.blend`, `assets/models/mascot_pom.glb*`, `CLAUDE.md`, `tests/_shot_model.gd*`). `docs/art/blender-contract.md`, `assets/models/README.md` and the emblem/mark `.glb` files also carry uncommitted mascot-session edits; when a task commits one of them it commits the whole file, which is acceptable and is noted in that task.

## File structure

| File | Responsibility |
|---|---|
| `core/motion.gd` (new) | Tween recipes, `reduce` flag, settings persistence. No scene knowledge. |
| `core/palette.gd` | Adds `FOCUS`, `WATER_HI`. |
| `core/placeholders.gd` | Adds the `focus_ring` placeholder mesh and its translucent material. |
| `core/models.gd` | Adds `focus_ring` to `SLOTS`; `_dress()` gives the `water` and `focus_ring` slots their special materials. |
| `core/toon.gd` | `wind_material()`, `water()`, `_sway` routing in `apply_to`. |
| `shaders/toon_lit.gdshaderinc` (new) | Shared uniforms, `fragment()`, `light()` of the toon look. |
| `shaders/toon.gdshader` | Becomes `shader_type` + `render_mode` + `#include`. |
| `shaders/toon_wind.gdshader` (new) | Toon plus a swaying `vertex()`. |
| `shaders/water.gdshader` (new) | Toon-lit water with stripes, sparkles, splash ring. |
| `world/ambient.gd` (new) | `motion_scale` global, pollen, splash clock, `refresh()`, `fit_to()`. |
| `world/fx.gd` (new) | Pooled puff and sparkle emitters, `cue()` audio hook. |
| `world/stage.gd` | Creates `Ambient`, loads settings, forwards `fit_camera` and `splash`. |
| `world/camera_rig.gd` | Camera breath offset. |
| `puzzles/binairo3d.gd` | Roll settle and lift, neighbour bob, dust, focus ring, blush pulse, entrance, reset wave, solved wave. |
| `tools/build_pieces.py` | Rim materials renamed to `_sway_flat`. |
| `project.godot` | `[shader_globals] motion_scale`. |
| `tests/test_motion.gd`, `tests/test_ambient.gd`, `tests/test_fx.gd` (new) | Unit suites for the three new units. |
| `tests/test_binairo3d.gd`, `tests/test_toon.gd`, `tests/test_models.gd`, `tests/test_palette.gd` | Extended. |
| `tests/run_tests.gd` | Registers the three new suites. |
| `tests/_shot.gd` | Longer slot so the screenshot lands after the entrance. |
| `tests/_shot_anim.gd` (new) | Frame strip plus draw calls and frame time. |
| `docs/art/blender-contract.md`, `assets/models/README.md`, `README.md` | Rule 11, `focus_ring` row, harness docs. |

---

### Task 1: Motion library

**Files:**
- Create: `core/motion.gd`
- Create: `tests/test_motion.gd`
- Modify: `tests/run_tests.gd` (the `suites` dictionary)

**Interfaces:**
- Produces (used by every later task):
  - `Motion.reduce: bool` (static), `Motion.settings_path: String` (static, default `user://settings.cfg`)
  - `Motion.load_settings() -> void`, `Motion.save_settings() -> void`
  - `Motion.settle(node: Node3D, property: String, target, time: float, delay := 0.0, essential := false) -> Tween`
  - `Motion.hop(node: Node3D, height: float, time: float, delay := 0.0, base := NAN) -> Tween`
  - `Motion.squash(node: Node3D, amount := 0.12, time := 0.18, delay := 0.0) -> Tween`
  - `Motion.wobble(node: Node3D, angle := 0.12, time := 0.45) -> Tween`
  - `Motion.fade(node: Node, setter: Callable, from: float, to: float, time: float, steps := 16, delay := 0.0) -> Tween`
  - `Motion.stagger(index: int, per: float, cap := 0.6) -> float`
  - `Motion.stop(tw: Tween) -> void` (kills a tween if it is valid; null-safe)
  - `Motion.running(tw: Tween) -> bool`

- [ ] **Step 1: Write the failing test**

Create `tests/test_motion.gd`:

```gdscript
extends RefCounted

## The motion library: every recipe returns a tween that lands exactly on its
## final value when stepped to the end, and reduce-motion collapses the
## decorative ones to an instant final state. Node-bound tweens need a live
## tree, so this runs from run_in_tree.

const Motion = preload("res://core/motion.gd")

const THIRD := TAU / 3.0

static func run_in_tree(t) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var node := Node3D.new()
	root.add_child(node)
	Motion.reduce = false
	_test_settle(t, node)
	_test_hop(t, node)
	_test_squash(t, node)
	_test_wobble(t, node)
	_test_fade(t, node)
	_test_stagger(t)
	_test_stop_and_running(t, node)
	_test_reduce(t, node)
	_test_settings(t)
	Motion.reduce = false
	root.remove_child(node)
	node.free()

static func _test_settle(t, node: Node3D) -> void:
	node.rotation.x = 0.0
	var tw: Tween = Motion.settle(node, "rotation:x", -THIRD, 0.34)
	t.check(tw != null and tw.is_running(), "settle returns a running tween")
	tw.custom_step(0.34 * 0.25)
	t.check(node.rotation.x < -0.1 and node.rotation.x > -THIRD, "a quarter in, settle is between start and target (%.3f)" % node.rotation.x)
	tw.custom_step(0.34 * 0.25)
	t.check(node.rotation.x < -THIRD, "halfway, settle has overshot the target (%.3f)" % node.rotation.x)
	tw.custom_step(1.0)
	t.check(is_equal_approx(node.rotation.x, -THIRD), "settle lands exactly on the target (%.4f)" % node.rotation.x)
	t.check(not tw.is_running(), "settle tween finished")
	var d: Tween = Motion.settle(node, "position:y", 1.0, 0.3, 0.2)
	d.custom_step(0.1)
	t.check(is_zero_approx(node.position.y), "a delayed settle has not moved during its delay")
	d.custom_step(1.0)
	t.check(is_equal_approx(node.position.y, 1.0), "delayed settle still lands exactly")
	node.position.y = 0.0

static func _test_hop(t, node: Node3D) -> void:
	node.position.y = 0.5
	var tw: Tween = Motion.hop(node, 0.08, 0.4)
	t.check(tw != null and tw.is_running(), "hop returns a running tween")
	tw.custom_step(0.2)
	t.check(node.position.y > 0.55, "at the top of the hop the node is up (%.3f)" % node.position.y)
	tw.custom_step(0.3)
	t.check(is_equal_approx(node.position.y, 0.5), "hop lands back on its base (%.4f)" % node.position.y)
	var dip: Tween = Motion.hop(node, -0.02, 0.35)
	dip.custom_step(0.175)
	t.check(node.position.y < 0.49, "a negative hop dips (%.3f)" % node.position.y)
	dip.custom_step(1.0)
	t.check(is_equal_approx(node.position.y, 0.5), "dip returns to base")
	# An explicit base wins over the node's current height (a cell mid-bob).
	node.position.y = 0.53
	var based: Tween = Motion.hop(node, 0.1, 0.2, 0.0, 0.5)
	based.custom_step(1.0)
	t.check(is_equal_approx(node.position.y, 0.5), "hop with an explicit base lands on that base (%.3f)" % node.position.y)

static func _test_squash(t, node: Node3D) -> void:
	node.scale = Vector3.ONE
	var tw: Tween = Motion.squash(node)
	t.check(tw != null and tw.is_running(), "squash returns a running tween")
	tw.custom_step(0.18 * 0.4)
	t.check(node.scale.y < 0.95 and node.scale.x > 1.0, "squash flattens y and widens x (%s)" % node.scale)
	tw.custom_step(1.0)
	t.check(node.scale.is_equal_approx(Vector3.ONE), "squash returns to the original scale")

static func _test_wobble(t, node: Node3D) -> void:
	node.rotation.z = 0.2
	var tw: Tween = Motion.wobble(node)
	t.check(tw != null and tw.is_running(), "wobble returns a running tween")
	tw.custom_step(0.45 / 12.0)
	t.check(not is_equal_approx(node.rotation.z, 0.2), "wobble moves the node early on (%.3f)" % node.rotation.z)
	tw.custom_step(1.0)
	t.check(is_equal_approx(node.rotation.z, 0.2), "wobble ends on its starting angle (%.4f)" % node.rotation.z)
	node.rotation.z = 0.0

static func _test_fade(t, node: Node3D) -> void:
	var got: Array = []
	var tw: Tween = Motion.fade(node, func(v: float): got.append(v), 0.0, 0.375, 0.25, 16, 0.1)
	t.check(tw != null and tw.is_running(), "fade returns a running tween")
	tw.custom_step(0.05)
	t.check(got.is_empty(), "fade calls nothing during its delay")
	for i in 60:
		tw.custom_step(0.01)
	t.check(got.size() <= 17, "fade produces at most steps + 1 levels (got %d)" % got.size())
	t.check(got.size() >= 8, "fade produces a ramp, not a jump (got %d levels)" % got.size())
	t.check(is_equal_approx(got[got.size() - 1], 0.375), "fade's last level is exactly `to` (%.4f)" % got[got.size() - 1])
	var on_grid := true
	for v in got:
		if not is_equal_approx(roundf(v / 0.375 * 16.0) / 16.0 * 0.375, v):
			on_grid = false
	t.check(on_grid, "every fade level sits on the 16-step grid")
	var distinct := true
	for i in range(1, got.size()):
		if is_equal_approx(got[i], got[i - 1]):
			distinct = false
	t.check(distinct, "fade never repeats a level")

static func _test_stagger(t) -> void:
	t.check(is_zero_approx(Motion.stagger(0, 0.03)), "first element has no delay")
	t.check(is_equal_approx(Motion.stagger(5, 0.03), 0.15), "delay grows linearly")
	t.check(is_equal_approx(Motion.stagger(100, 0.03), 0.6), "delay is capped")
	t.check(is_equal_approx(Motion.stagger(100, 0.03, 0.2), 0.2), "cap is a parameter")

static func _test_stop_and_running(t, node: Node3D) -> void:
	t.check(not Motion.running(null), "running(null) is false")
	Motion.stop(null)
	var tw: Tween = Motion.hop(node, 0.1, 0.3)
	t.check(Motion.running(tw), "running(tw) is true for a live tween")
	Motion.stop(tw)
	t.check(not Motion.running(tw), "stop kills a live tween")
	node.position.y = 0.5

static func _test_reduce(t, node: Node3D) -> void:
	Motion.reduce = true
	node.rotation.x = 0.0
	var dec: Tween = Motion.settle(node, "rotation:x", -THIRD, 0.34)
	t.check(dec == null, "reduce: decorative settle returns null")
	t.check(is_equal_approx(node.rotation.x, -THIRD), "reduce: decorative settle sets the final state at once")
	node.rotation.x = 0.0
	var ess: Tween = Motion.settle(node, "rotation:x", -THIRD, 0.34, 0.0, true)
	t.check(ess != null and ess.is_running(), "reduce: essential settle still returns a tween")
	ess.custom_step(0.075)
	t.check(is_equal_approx(node.rotation.x, -THIRD * 0.5), "reduce: essential motion is linear over 0.15 s (%.3f)" % node.rotation.x)
	ess.custom_step(0.075)
	t.check(is_equal_approx(node.rotation.x, -THIRD) and not ess.is_running(), "reduce: essential settle is done at 0.15 s")
	node.position.y = 0.5
	t.check(Motion.hop(node, 0.1, 0.3) == null and is_equal_approx(node.position.y, 0.5), "reduce: hop is skipped")
	node.scale = Vector3.ONE
	t.check(Motion.squash(node) == null and node.scale.is_equal_approx(Vector3.ONE), "reduce: squash is skipped")
	t.check(Motion.wobble(node) == null, "reduce: wobble is skipped")
	var got: Array = []
	t.check(Motion.fade(node, func(v: float): got.append(v), 0.0, 1.0, 0.3) == null, "reduce: fade returns null")
	t.eq(got, [1.0], "reduce: fade calls the setter once with `to`")
	Motion.reduce = false

static func _test_settings(t) -> void:
	Motion.settings_path = "user://_test_settings.cfg"
	Motion.reduce = true
	Motion.save_settings()
	Motion.reduce = false
	Motion.load_settings()
	t.check(Motion.reduce, "reduce round-trips through the settings file")
	Motion.reduce = false
	Motion.save_settings()
	Motion.reduce = true
	Motion.load_settings()
	t.check(not Motion.reduce, "a saved false loads as false")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_test_settings.cfg"))
	Motion.settings_path = "user://settings.cfg"
	Motion.reduce = false
	Motion.load_settings()
	Motion.reduce = false
```

Register the suite in `tests/run_tests.gd`: add `"motion": "res://tests/test_motion.gd",` to the `suites` dictionary right after the `"toon"` line.

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: `FAIL [motion] could not load suite` (the preload of `core/motion.gd` fails) and `failed=1`.

- [ ] **Step 3: Write the implementation**

Create `core/motion.gd`:

```gdscript
extends RefCounted

## Tween recipes every board and widget uses, so motion has one voice and one
## switch. Each recipe builds its tween on the target node and returns it, or
## null when reduce-motion skipped it, so callers can chain `finished` and
## headless tests can drive it with custom_step (see tests/test_motion.gd).
## Spec: docs/superpowers/specs/2026-09-13-binairo-polish-design.md, section 1.

## Essential motion under reduce-motion: this long, linear, no overshoot.
const REDUCED_TIME := 0.15

## When true, decorative recipes set their final state at once and return
## null; essential ones (the roll) shorten to REDUCED_TIME. Persisted in
## settings_path under [motion] reduce; the settings sheet toggles it.
static var reduce: bool = false
static var settings_path: String = "user://settings.cfg"

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	reduce = false
	if cfg.load(settings_path) == OK:
		reduce = bool(cfg.get_value("motion", "reduce", false))

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)  # keeps other sections; a missing file is fine
	cfg.set_value("motion", "reduce", reduce)
	cfg.save(settings_path)

## Tweens `property` (a NodePath like "rotation:x" or "scale") to `target`
## with a back ease: it overshoots by about a tenth of the distance and
## springs home. `essential` motion is the state change itself and survives
## reduce-motion, shortened and linear.
static func settle(node: Node3D, property: String, target, time: float, delay := 0.0, essential := false) -> Tween:
	if reduce and not essential:
		node.set_indexed(property, target)
		return null
	var tw := node.create_tween()
	if reduce:
		tw.tween_property(node, property, target, REDUCED_TIME).set_delay(delay).set_trans(Tween.TRANS_LINEAR)
	else:
		tw.tween_property(node, property, target, time).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw

## Lifts position.y by `height` and comes back down; a negative height dips.
## `base` is the resting height; it defaults to the node's current height,
## so pass it explicitly for a node that may already be mid-hop.
static func hop(node: Node3D, height: float, time: float, delay := 0.0, base := NAN) -> Tween:
	if reduce:
		return null
	if is_nan(base):
		base = node.position.y
	var tw := node.create_tween()
	tw.tween_property(node, "position:y", base + height, time * 0.5).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position:y", base, time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tw

## Flattens y by `amount` and widens x and z by half of it, then springs back.
static func squash(node: Node3D, amount := 0.12, time := 0.18, delay := 0.0) -> Tween:
	if reduce:
		return null
	var base := node.scale
	var squashed := Vector3(base.x * (1.0 + amount * 0.5), base.y * (1.0 - amount), base.z * (1.0 + amount * 0.5))
	var tw := node.create_tween()
	tw.tween_property(node, "scale", squashed, time * 0.4).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, time * 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw

## A damped side-to-side shake on rotation.z: three swings that die out,
## ending exactly where it started.
static func wobble(node: Node3D, angle := 0.12, time := 0.45) -> Tween:
	if reduce:
		return null
	var base := node.rotation.z
	var shake := func(t: float) -> void:
		node.rotation.z = base + angle * sin(t * 6.0 * PI) * (1.0 - t) * (1.0 - t)
	var tw := node.create_tween()
	tw.tween_method(shake, 0.0, 1.0, time)
	return tw

## Calls `setter(value)` along a ramp from `from` to `to`, quantised to
## `steps` equal levels and never repeating one, so a colour fade built on it
## yields a bounded set of colours for the toon material cache. Under
## reduce-motion the setter is called once with `to`.
static func fade(node: Node, setter: Callable, from: float, to: float, time: float, steps := 16, delay := 0.0) -> Tween:
	if reduce:
		setter.call(to)
		return null
	var last := [-INF]
	var step := func(t: float) -> void:
		var q := roundf(t * steps) / float(steps)
		var v := lerpf(from, to, q)
		if last[0] != v:
			last[0] = v
			setter.call(v)
	var tw := node.create_tween()
	tw.tween_method(step, 0.0, 1.0, time).set_delay(delay)
	return tw

## Delay for the i-th element of a wave: `per` seconds apart, never past `cap`.
static func stagger(index: int, per: float, cap := 0.6) -> float:
	return minf(index * per, cap)

## Kills `tw` if it is still alive. Null-safe.
static func stop(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()

static func running(tw: Tween) -> bool:
	return tw != null and tw.is_valid() and tw.is_running()
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: no `FAIL` lines, `failed=0`, and `passed=` at least 40 higher than before (the count before this task is 987).

- [ ] **Step 5: Commit**

```bash
git add core/motion.gd tests/test_motion.gd tests/run_tests.gd
git commit -m "feat: motion library with reduce-motion switch and steppable tween recipes"
```

---

### Task 2: Palette colours and the focus ring slot

**Files:**
- Modify: `core/palette.gd` (island block)
- Modify: `core/placeholders.gd` (`make()` match, new helpers)
- Modify: `core/models.gd` (`SLOTS`, `instance()`, new `_dress()`)
- Modify: `tests/test_palette.gd`, `tests/test_models.gd`
- Modify: `assets/models/README.md`, `docs/art/blender-contract.md` (slot tables)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `Pal.FOCUS: Color`, `Pal.WATER_HI: Color`
  - `Placeholders.FOCUS_OUTER := 0.46`, `FOCUS_INNER := 0.40`, `Placeholders.focus_material() -> StandardMaterial3D` (a fresh, unshaded, alpha-blended, cull-disabled material in `FOCUS` at alpha 0.9)
  - `Models.instance("focus_ring") -> Node3D` whose single mesh has `material_override` set to a focus material (its own instance, so alpha can be tweened per ring)
  - `Models._dress(slot: String, node: Node3D) -> void`, called at the end of `instance()` for every slot

- [ ] **Step 1: Write the failing tests**

In `tests/test_palette.gd`, in `_test_island_colours`, extend the constants list and add two checks at the end of the function:

```gdscript
	for name in ["STONE", "STONE_GIVEN", "SLATE", "SLATE_GIVEN", "SUN", "MOON", "MARK", "MOSS", "ROCK", "WATER", "FOCUS", "WATER_HI"]:
		t.check(constants.has(name), "palette defines %s" % name)
```

```gdscript
	t.check(Pal.contrast(Pal.WATER_HI, Pal.WATER) >= 1.3, "water stripes read on the water, got %.2f" % Pal.contrast(Pal.WATER_HI, Pal.WATER))
	t.check(Pal.FOCUS != Pal.WATER_HI and Pal.FOCUS != Pal.CAT[5], "focus blue is its own colour")
```

In `tests/test_models.gd`:

Change the slot list assertion in `_test_slots` to:

```gdscript
	t.eq(Models.SLOTS, ["tile", "emblem_sun", "emblem_moon", "empty_mark", "rim_edge", "rim_corner", "platform", "water", "focus_ring"], "slot list matches the polish spec")
```

Add a new test function and call it from `run` after `_test_tint_and_height(t)`:

```gdscript
## The focus ring is a flat translucent frame around one cell (polish spec,
## section 6): it sits on y = 0, fits the cell, gets no outline and carries
## its own material instance so one ring's alpha tween never touches another.
static func _test_focus_ring(t) -> void:
	var a = Models.instance("focus_ring")
	var b = Models.instance("focus_ring")
	var ms := Models.meshes(a)
	t.eq(ms.size(), 1, "focus ring is one mesh")
	var bounds := _bounds(a)
	t.check(is_zero_approx(bounds[0].y) and bounds[1].y <= 0.02, "focus ring is flat on y=0 (%.3f .. %.3f)" % [bounds[0].y, bounds[1].y])
	t.check(bounds[1].x <= Placeholders.FOCUS_OUTER + 0.001 and bounds[0].x >= -Placeholders.FOCUS_OUTER - 0.001, "focus ring spans the cell (%.3f)" % bounds[1].x)
	var mat = ms[0].material_override
	t.check(mat is StandardMaterial3D, "focus ring carries a StandardMaterial3D override")
	if mat is StandardMaterial3D:
		t.check(mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "focus ring is unshaded")
		t.check(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "focus ring is alpha blended")
		t.check(Color(mat.albedo_color.r, mat.albedo_color.g, mat.albedo_color.b).is_equal_approx(Pal.FOCUS), "focus ring is FOCUS blue")
	t.check(Models.meshes(b)[0].material_override != mat, "each ring has its own material instance")
	t.check(ms[0].get_node_or_null("Outline") == null, "focus ring has no outline")
	a.free()
	b.free()
```

Add `const Pal = preload("res://core/palette.gd")` to the top of `tests/test_models.gd`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: `FAIL [palette] palette defines FOCUS`, `FAIL [models] slot list matches the polish spec`, focus ring failures, `failed=` greater than 0.

- [ ] **Step 3: Write the implementation**

`core/palette.gd`, after the `WATER` line:

```gdscript
const WATER_HI    := Color("5fb0e8")   # water stripes and splash ring
const FOCUS       := Color("7fd1ff")   # focus ring on the last tapped cell
```

`core/placeholders.gd`: add constants after `RIM_H`:

```gdscript
## The focus ring: a flat square frame around one cell (polish spec, section 6).
const FOCUS_OUTER := 0.46
const FOCUS_INNER := 0.40
```

Add a new match arm in `make()` before the `_:` arm:

```gdscript
		"focus_ring":
			# Flat frame of four top-facing quads, one draw call, no thickness:
			# it is light on the stone, not a piece. Unshaded, translucent,
			# no outline, never tinted. Models._dress gives it its material.
			mi.mesh = _ring_mesh(FOCUS_OUTER, FOCUS_INNER)
			root.add_child(mi)
			return root
```

Add two static functions at the end of the file:

```gdscript
## Translucent unshaded material for the focus ring. A fresh instance each
## call, so a ring can tween its alpha without touching another ring.
static func focus_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(Pal.FOCUS, 0.9)
	return m

## Four bars of a square frame as top-facing quads on y = 0. Godot front
## faces wind clockwise seen from the front, so seen from above (x right,
## z down) each quad goes x0z0, x1z0, x1z1, x0z1.
static func _ring_mesh(outer: float, inner: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bars := [
		[-outer, outer, -outer, -inner],   # far bar
		[-outer, outer, inner, outer],     # near bar
		[-outer, -inner, -inner, inner],   # left bar
		[inner, outer, -inner, inner],     # right bar
	]
	for b in bars:
		var p := [Vector3(b[0], 0.0, b[2]), Vector3(b[1], 0.0, b[2]), Vector3(b[1], 0.0, b[3]), Vector3(b[0], 0.0, b[3])]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for i in tri:
				st.set_normal(Vector3.UP)
				st.add_vertex(p[i])
	return st.commit()
```

`core/models.gd`: change `SLOTS` and `instance()`, add `_dress()`:

```gdscript
const SLOTS := ["tile", "emblem_sun", "emblem_moon", "empty_mark", "rim_edge", "rim_corner", "platform", "water", "focus_ring"]
```

```gdscript
static func instance(slot: String) -> Node3D:
	var node: Node3D
	if has_model(slot):
		var scene: PackedScene = _scenes.get(slot)
		if scene == null:
			scene = load(path_for(slot))
			if scene == null:
				push_warning("Models: %s exists but did not load (not imported?); using placeholder" % path_for(slot))
		if scene != null:
			_scenes[slot] = scene
			node = scene.instantiate() as Node3D
			node.name = slot
			Toon.apply_to(node)
	if node == null:
		node = Placeholders.make(slot)
	_dress(slot, node)
	return node

## Slot-specific materials the toon step cannot infer from a colour, applied
## to the export and the placeholder alike so the two never look different.
static func _dress(slot: String, node: Node3D) -> void:
	match slot:
		"focus_ring":
			for mi in meshes(node):
				mi.material_override = Placeholders.focus_material()
```

(The `"water"` arm of `_dress` arrives in Task 5.)

Docs: in `assets/models/README.md` add a table row after `water`:

```
| `focus_ring` | flat translucent frame the board slides onto the last tapped cell; unshaded, no outline, never tinted |
```

In `docs/art/blender-contract.md`, in the slot table after the `water` row:

```
| `focus_ring` | inside 0.92 x 0.92 | 0.02 | flat square frame around one cell; the game gives it a translucent unshaded material, so its Blender material is only a placeholder |
```

Note: `docs/art/blender-contract.md` and `assets/models/README.md` carry uncommitted edits from the mascot session. Committing them here commits those edits too; that is expected.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: no `FAIL`, `failed=0`.

- [ ] **Step 5: Commit**

```bash
git add core/palette.gd core/placeholders.gd core/models.gd tests/test_palette.gd tests/test_models.gd assets/models/README.md docs/art/blender-contract.md
git commit -m "feat: focus ring slot and the two polish palette colours"
```

---

### Task 3: Toon include, wind shader, `_sway` routing

**Files:**
- Create: `shaders/toon_lit.gdshaderinc`, `shaders/toon_wind.gdshader`
- Modify: `shaders/toon.gdshader` (whole file), `core/toon.gd`, `project.godot`
- Modify: `tests/test_toon.gd`

**Interfaces:**
- Produces:
  - `Toon.WIND_SHADER: Shader` (preloaded `toon_wind.gdshader`), `Toon.SWAY_MARK := "_sway"`
  - `Toon.wind_material(albedo: Color) -> ShaderMaterial` (cached per colour, separate cache from `material()`)
  - `Toon.sways(name: String) -> bool`
  - `apply_to` routes any `StandardMaterial3D` surface whose `resource_name` contains `_sway` to `wind_material`
  - global shader parameter `motion_scale` (float, default 1.0) declared in `project.godot`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_toon.gd`: two new functions, called from `run` after `_test_apply_twice_is_idempotent(t)`:

```gdscript
## A `_sway` material bends in the wind (polish spec, section 4): it gets the
## wind shader, everything else the plain toon shader, and since a swaying
## mesh must also be `_flat` it gets no outline.
static func _test_sway_gets_wind(t) -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("a3c95e")
	grass.resource_name = "Grass_sway_flat"
	var mi := _mesh_with(grass)
	Toon.apply_to(mi)
	var over = mi.get_surface_override_material(0)
	t.check(over is ShaderMaterial and over.shader == Toon.WIND_SHADER, "_sway surface gets the wind shader")
	t.check(over != null and Color(over.get_shader_parameter("albedo")).is_equal_approx(Color("a3c95e")), "wind material keeps the base colour")
	t.check(over != null and over.get_shader_parameter("ramp") is GradientTexture1D, "wind material shares the toon ramp")
	t.check(mi.get_node_or_null("Outline") == null, "_sway_flat mesh gets no outline")
	mi.free()
	var moss := StandardMaterial3D.new()
	moss.resource_name = "Moss_flat"
	var still := _mesh_with(moss)
	Toon.apply_to(still)
	t.check(still.get_surface_override_material(0).shader == Toon.TOON_SHADER, "a plain _flat surface keeps the toon shader")
	still.free()
	t.check(Toon.sways("Petal_sway_flat") and not Toon.sways("Petal_flat"), "sways() reads the _sway mark")

static func _test_wind_cache(t) -> void:
	var a = Toon.wind_material(Color("a3c95e"))
	var b = Toon.wind_material(Color("a3c95e"))
	var c = Toon.material(Color("a3c95e"))
	t.check(a == b, "same colour returns the cached wind material")
	t.check(a != c, "wind and plain toon materials of one colour are different objects")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: `FAIL [toon] could not load suite` (the suite references `Toon.WIND_SHADER`, which does not exist), `failed=1`.

- [ ] **Step 3: Write the shaders**

Create `shaders/toon_lit.gdshaderinc` (the body moved out of `toon.gdshader`, unchanged in behaviour):

```glsl
// Shared body of the cozy cel shader: toon.gdshader and toon_wind.gdshader
// #include this so the lighting has one source. Spec: 3d-toon-pipeline design
// section 2. Runs on gl_compatibility: nothing here reads depth or screen.

uniform vec4 albedo : source_color = vec4(1.0);
// Red channel = lit factor across NdotL remapped to 0..1. Nearest filtering
// keeps the bands hard. core/toon.gd ramp() builds the default.
uniform sampler2D ramp : filter_nearest, repeat_disable, hint_default_white;
// Shadow is a hue shift toward this tint, never a multiply toward black.
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
uniform float rim_width : hint_range(0.0, 1.0) = 0.30;
uniform vec4 rim_color : source_color = vec4(1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = step(1.0 - rim_width, 1.0 - facing);
	EMISSION = rim_color.rgb * albedo.rgb * rim * rim_strength;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float t = clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * clamp(ATTENUATION, 0.0, 1.0);
	float band = texture(ramp, vec2(t, 0.5)).r;
	// LIGHT_COLOR is colour * energy * PI, and the pipeline multiplies this
	// result by ALBEDO afterwards (scene.glsl: diffuse_light *= albedo), so
	// neither factor belongs here.
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint.rgb, vec3(1.0), band);
}
```

Replace `shaders/toon.gdshader` with:

```glsl
shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Cozy cel shading. The body lives in toon_lit.gdshaderinc so the wind
// variant (toon_wind.gdshader) shares it.
#include "res://shaders/toon_lit.gdshaderinc"
```

Create `shaders/toon_wind.gdshader`:

```glsl
shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Toon shading plus wind: vertices above sway_base lean sideways by a slow
// sine of world position and time, more the higher they are, so tufts wave
// and roots stay planted. Materials named with `_sway` get this (core/toon.gd).
// motion_scale is the project-wide global that reduce-motion sets to 0.
// Spec: docs/superpowers/specs/2026-09-13-binairo-polish-design.md, section 4.
#include "res://shaders/toon_lit.gdshaderinc"

global uniform float motion_scale;
uniform float sway_base = 0.03;    // local y of the moss top; below it nothing moves
uniform float sway_height = 0.07;  // local y span over which sway reaches full
uniform float sway_amount = 0.02;  // world units at the tip
uniform float sway_speed = 1.6;

void vertex() {
	float h = clamp((VERTEX.y - sway_base) / sway_height, 0.0, 1.0);
	h *= h;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = TIME * sway_speed + wp.x * 0.9 + wp.z * 0.7;
	VERTEX.x += sin(ph) * sway_amount * h * motion_scale;
	VERTEX.z += cos(ph * 0.8) * sway_amount * 0.6 * h * motion_scale;
}
```

Add to `project.godot` at the end of the file:

```
[shader_globals]

motion_scale={
"type": "float",
"value": 1.0
}
```

- [ ] **Step 4: Write the GDScript**

In `core/toon.gd`, after the `OUTLINE_SHADER` preload:

```gdscript
const WIND_SHADER := preload("res://shaders/toon_wind.gdshader")
```

After `FLAT_SUFFIX`:

```gdscript
## A Blender material whose name contains this bends in the wind
## (toon_wind.gdshader). It must also end in FLAT_SUFFIX, since the outline
## shell would not follow the sway.
const SWAY_MARK := "_sway"
```

After `static var _cache: Dictionary = {}`:

```gdscript
static var _wind_cache: Dictionary = {}
```

After `material()`:

```gdscript
## Toon material that sways in the wind; same ramp and tint, its own cache.
static func wind_material(albedo: Color) -> ShaderMaterial:
	var key := albedo.to_html()
	if _wind_cache.has(key):
		return _wind_cache[key]
	var m := ShaderMaterial.new()
	m.shader = WIND_SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("ramp", ramp())
	m.set_shader_parameter("shadow_tint", Pal.SHADOW_TINT)
	_wind_cache[key] = m
	return m

static func sways(name: String) -> bool:
	return name.contains(SWAY_MARK)
```

In `_apply_mesh`, replace the `if src is StandardMaterial3D:` block body:

```gdscript
		if src is StandardMaterial3D:
			var toon := wind_material(src.albedo_color) if sways(src.resource_name) else material(src.albedo_color)
			mi.set_surface_override_material(i, toon)
```

- [ ] **Step 5: Run the tests and the shader compile check**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: no `FAIL`, `failed=0`.

Run: `godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | grep -iE "shader|error|saved /tmp/shot_binairo" | head`

Expected: `saved /tmp/shot_binairo.png` and no line containing `SHADER ERROR` or `Global uniform`. Open `/tmp/shot_binairo.png` and confirm the board looks exactly as before this task (the include moved code; nothing should change).

- [ ] **Step 6: Commit**

```bash
git add shaders/toon_lit.gdshaderinc shaders/toon.gdshader shaders/toon_wind.gdshader core/toon.gd project.godot tests/test_toon.gd
git commit -m "feat: toon body shared through an include; wind variant for _sway materials; motion_scale global"
```

---

### Task 4: Rim pieces sway (material renames, contract rule 11, regeneration)

**Files:**
- Modify: `tools/build_pieces.py` (`rim_materials()` and the docstring)
- Modify: `docs/art/blender-contract.md` (rules list, slot table rim rows)
- Modify: `assets/models/README.md` (rim rows)
- Regenerate: `assets/models/rim_edge.glb`, `assets/models/rim_corner.glb`

**Interfaces:**
- Consumes: `Toon.SWAY_MARK`, `Toon.sways()` from Task 3.
- Produces: rim pieces whose grass, petal and pollen surfaces are named `Grass_sway_flat`, `Petal_sway_flat`, `Pollen_sway_flat`.

- [ ] **Step 1: Write the failing test**

Add to `tests/test_models.gd`, called from `run` after `_test_focus_ring(t)`:

```gdscript
## The rim's tufts, petals and pollen sway (polish spec, section 4); the moss
## slab stays still. Checked on the export, since that is what the game shows.
static func _test_rim_sways(t) -> void:
	if not Models.has_model("rim_edge"):
		return
	for slot in ["rim_edge", "rim_corner"]:
		var piece = Models.instance(slot)
		var names := Models.surface_names(piece)
		t.check(names.has("Moss_flat"), "%s keeps a still Moss_flat surface" % slot)
		for mat in ["Grass_sway_flat", "Petal_sway_flat", "Pollen_sway_flat"]:
			t.check(names.has(mat), "%s carries %s" % [slot, mat])
		var wind := 0
		for mi in Models.meshes(piece):
			for i in mi.mesh.get_surface_count():
				var over = mi.get_surface_override_material(i)
				if over != null and over.shader == Toon.WIND_SHADER:
					wind += 1
		t.eq(wind, 3, "%s has three swaying surfaces" % slot)
		piece.free()
```

Add `const Toon = preload("res://core/toon.gd")` at the top of `tests/test_models.gd`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: `FAIL [models] rim_edge carries Grass_sway_flat` and similar, `failed=` at least 8.

- [ ] **Step 3: Rename the materials in the builder**

In `tools/build_pieces.py`, replace `rim_materials()`:

```python
def rim_materials():
    # The tufts, petals and pollen sway in the game's wind (a `_sway` name,
    # contract rule 11); the moss slab stays still.
    return [material("Moss_flat", MOSS), material("Grass_sway_flat", GRASS),
            material("Petal_sway_flat", PETAL), material("Pollen_sway_flat", POLLEN)]
```

In the module docstring, change the line

```
plain-colour Principled materials, `_flat` names on surfaces that must not get
an outline. Pieces are built with bmesh so the script is the source of truth;
```

to

```
plain-colour Principled materials, `_flat` names on surfaces that must not get
an outline and `_sway` on the ones that wave in the wind. Pieces are built
with bmesh so the script is the source of truth;
```

- [ ] **Step 4: Regenerate and re-import**

Run: `tools/build_models.sh 2>&1 | tail -12`

Expected: six `OK` lines from the exporter and the `ls` of `assets/models/*.glb`. If Blender prints `SKIP`, read the rule it names and fix the builder; do not hand-edit a `.glb`.

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: no `FAIL`, `failed=0`.

- [ ] **Step 5: Document the rule**

In `docs/art/blender-contract.md`, after rule 10 in the `## Rules` list, add:

```
11. **`_sway` marker.** A material whose name contains `_sway` bends in the
    game's wind (`shaders/toon_wind.gdshader`): vertices above local Z 0.03
    lean sideways, more the higher they are, so keep the planted part of a
    tuft below that height. Use it for grass, petals, leaves. Until the
    outline follows the wind, a `_sway` material must also end in `_flat`
    (`Grass_sway_flat`), and `core/toon.gd` reads the mark anywhere in the
    name. The rim pieces carry `Grass_sway_flat`, `Petal_sway_flat` and
    `Pollen_sway_flat` beside a still `Moss_flat`.
```

In the slot table, change the `rim_edge` note to end with `; materials Moss_flat plus Grass_sway_flat, Petal_sway_flat, Pollen_sway_flat` and the `rim_corner` note likewise.

In `assets/models/README.md`, in the paragraph starting `The platform, water, empty_mark, rim_edge and rim_corner materials`, append the sentence: `The rim's grass, petals and pollen also carry `_sway` so they wave in the wind; the moss does not.`

- [ ] **Step 6: Visual check and commit**

Run: `godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | grep -iE "shader error|saved /tmp/shot_binairo"`

Expected: `saved /tmp/shot_binairo.png`, no shader error. Look at the image: the rim reads as before (a single still frame cannot show sway; Task 11's strip does).

```bash
git add tools/build_pieces.py assets/models/rim_edge.glb assets/models/rim_corner.glb docs/art/blender-contract.md assets/models/README.md tests/test_models.gd
git commit -m "feat: rim grass, petals and pollen sway in the wind (_sway materials, contract rule 11)"
```

The regenerated `emblem_*.glb` and `empty_mark.glb` also change on disk (the build script rebuilds all six). Leave them uncommitted; they belong to the mascot session's exporter work already in the working tree.

---

### Task 5: Ambient node, toon water, stage wiring

**Files:**
- Create: `shaders/water.gdshader`, `world/ambient.gd`, `tests/test_ambient.gd`
- Modify: `core/toon.gd` (water material), `core/models.gd` (`_dress` water arm), `world/stage.gd`, `tests/test_models.gd`, `tests/run_tests.gd`

**Interfaces:**
- Consumes: `Motion.reduce`, `Motion.load_settings()` (Task 1); `Pal.WATER_HI` (Task 2); `Models._dress` (Task 2).
- Produces:
  - `Toon.WATER_SHADER: Shader`, `Toon.water() -> ShaderMaterial` (one shared instance; uniforms `base_color`, `band_color`, `sparkle_color`, `shadow_tint`, `splash_origin: Vector3`, `splash_age: float`)
  - `Ambient` (`world/ambient.gd`, `extends Node3D`): `pollen: CPUParticles3D`, `static func motion_scale() -> float`, `refresh() -> void`, `fit_to(aabb: AABB) -> void`, `splash(origin: Vector3) -> void`, `splash_age() -> float`; constants `GLOBAL := "motion_scale"`, `SPLASH_TIME := 2.0`, `POLLEN_AMOUNT := 24`, `POLLEN_LIFETIME := 6.0`
  - `Stage.ambient: Node3D`, `Stage.splash(origin: Vector3) -> void`; `Stage.fit_camera` also calls `ambient.fit_to(aabb)`; `Stage._ready` calls `Motion.load_settings()` first

- [ ] **Step 1: Write the failing tests**

Create `tests/test_ambient.gd`:

```gdscript
extends RefCounted

## The world's continuous motion and its one switch (polish spec, section 4):
## the Ambient node the stage creates, its pollen, the splash clock on the
## water material, and the motion_scale value reduce-motion drives to zero.
## Needs a live tree (the stage builds in _ready), so this runs from run_in_tree.

const Stage = preload("res://world/stage.gd")
const Ambient = preload("res://world/ambient.gd")
const Motion = preload("res://core/motion.gd")
const Toon = preload("res://core/toon.gd")

static func run_in_tree(t) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	Motion.reduce = false
	var stage: Node3D = Stage.new()
	root.add_child(stage)
	_test_stage_owns_ambient(t, stage)
	_test_pollen(t, stage.ambient)
	_test_refresh(t, stage.ambient)
	_test_splash(t, stage.ambient)
	_test_fit_to(t, stage.ambient)
	Motion.reduce = false
	root.remove_child(stage)
	stage.free()

static func _test_stage_owns_ambient(t, stage) -> void:
	t.check(stage.ambient != null and stage.ambient.get_parent() == stage, "stage creates an Ambient child")
	t.check(stage.get_node_or_null("Ambient") == stage.ambient, "the Ambient node is named Ambient")
	t.check(is_equal_approx(Ambient.motion_scale(), 1.0), "motion_scale is 1 when the world moves")

static func _test_pollen(t, ambient) -> void:
	var p: CPUParticles3D = ambient.pollen
	t.check(p != null and p.get_parent() == ambient, "ambient owns a pollen emitter")
	t.eq(p.amount, Ambient.POLLEN_AMOUNT, "two dozen specks")
	t.check(is_equal_approx(p.lifetime, Ambient.POLLEN_LIFETIME) and is_equal_approx(p.preprocess, Ambient.POLLEN_LIFETIME), "six-second lives, pre-rolled so the air is full on frame one")
	t.check(p.emitting and p.visible, "pollen drifts by default")
	t.check(p.emission_shape == CPUParticles3D.EMISSION_SHAPE_BOX, "pollen spawns in a box")
	t.check(p.gravity.is_zero_approx(), "pollen has no gravity; it sinks by its direction")
	t.check(p.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "specks cast no shadow")

static func _test_refresh(t, ambient) -> void:
	Motion.reduce = true
	ambient.refresh()
	t.check(is_zero_approx(Ambient.motion_scale()), "motion_scale is 0 under reduce-motion")
	t.check(not ambient.pollen.emitting and not ambient.pollen.visible, "reduce-motion stops and hides the pollen")
	Motion.reduce = false
	ambient.refresh()
	t.check(ambient.pollen.emitting and ambient.pollen.visible, "clearing reduce-motion restarts the pollen")

static func _test_splash(t, ambient) -> void:
	var water: ShaderMaterial = Toon.water()
	t.check(ambient.splash_age() < 0.0, "no splash at rest")
	ambient.splash(Vector3(1.0, -4.0, 2.0))
	t.check(is_zero_approx(ambient.splash_age()), "splash starts its clock at zero")
	t.check(Vector3(water.get_shader_parameter("splash_origin")).is_equal_approx(Vector3(1.0, -4.0, 2.0)), "splash origin reaches the water material")
	ambient._process(0.5)
	t.check(is_equal_approx(ambient.splash_age(), 0.5), "the clock advances with process time")
	t.check(is_equal_approx(float(water.get_shader_parameter("splash_age")), 0.5), "the water material sees the age")
	ambient._process(Ambient.SPLASH_TIME)
	t.check(ambient.splash_age() < 0.0, "the splash ends after SPLASH_TIME")
	t.check(float(water.get_shader_parameter("splash_age")) < 0.0, "the water material sees the end")
	Motion.reduce = true
	ambient.splash(Vector3.ZERO)
	t.check(ambient.splash_age() < 0.0, "reduce-motion skips the splash")
	Motion.reduce = false

static func _test_fit_to(t, ambient) -> void:
	ambient.fit_to(AABB(Vector3(-3.0, -0.6, -3.0), Vector3(6.0, 1.1, 6.0)))
	var p: CPUParticles3D = ambient.pollen
	t.check(p.position.is_equal_approx(Vector3(0.0, 1.5, 0.0)), "pollen floats one cell above the board's top (%s)" % p.position)
	t.check(p.emission_box_extents.is_equal_approx(Vector3(4.0, 0.2, 4.0)), "pollen volume is the board plus a one-cell margin, 0.4 tall (%s)" % p.emission_box_extents)
```

Register it in `tests/run_tests.gd`: add `"ambient": "res://tests/test_ambient.gd",` after the `"motion"` line.

In `tests/test_models.gd`, add a function called from `run` after `_test_rim_sways(t)`:

```gdscript
## The water slot always wears the water shader (polish spec, section 4),
## placeholder or export, so the stage never shows a plain toon plane.
static func _test_water_material(t) -> void:
	var water = Models.instance("water")
	var over = Models.meshes(water)[0].get_surface_override_material(0)
	t.check(over is ShaderMaterial and over.shader == Toon.WATER_SHADER, "water slot carries the water shader")
	t.check(over == Toon.water(), "the water material is the shared instance Ambient drives")
	water.free()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: `FAIL [ambient] could not load suite`, `FAIL [models] could not load suite` (both reference `Toon.WATER_SHADER`), `failed=2`.

- [ ] **Step 3: Write the water shader**

Create `shaders/water.gdshader`:

```glsl
shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_disabled;

// Toon water: hard drifting highlight stripes, a scatter of sparkle dots and
// one splash ring the stage triggers when a board lands. Lit with the same
// two-band step as the toon shader so the platform's shadow still falls on
// it. Every time term is scaled by the motion_scale global so reduce-motion
// stills it. Spec: docs/superpowers/specs/2026-09-13-binairo-polish-design.md,
// section 4. Runs on gl_compatibility: nothing here reads depth or screen.

global uniform float motion_scale;
uniform vec4 base_color : source_color = vec4(0.18, 0.56, 0.84, 1.0);
uniform vec4 band_color : source_color = vec4(0.37, 0.69, 0.91, 1.0);
uniform vec4 sparkle_color : source_color = vec4(0.96, 0.95, 0.90, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.72, 0.65, 0.77, 1.0);
uniform vec3 splash_origin = vec3(0.0);
// Seconds since the splash began; negative means no splash. Driven by
// world/ambient.gd from its own clock so the ring is deterministic.
uniform float splash_age = -1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * motion_scale;
	vec2 p = world_pos.xz;
	float b = sin(dot(p, vec2(0.80, 0.45)) * 0.9 + t * 0.35)
			+ 0.5 * sin(dot(p, vec2(-0.35, 0.90)) * 1.7 - t * 0.5);
	float band = step(1.1, b);
	float s = sin(p.x * 7.3 + t * 1.3) * sin(p.y * 6.1 - t * 0.9);
	float spark = step(0.985, s);
	vec3 col = mix(base_color.rgb, band_color.rgb, band);
	col = mix(col, sparkle_color.rgb, spark);
	if (splash_age >= 0.0 && splash_age < 2.0) {
		float d = distance(p, splash_origin.xz);
		float ring = step(abs(d - splash_age * 3.0), 0.15) * (1.0 - splash_age / 2.0);
		col = mix(col, band_color.rgb, ring);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(normalize(NORMAL), normalize(LIGHT));
	float t = clamp(ndl * 0.5 + 0.5, 0.0, 1.0) * clamp(ATTENUATION, 0.0, 1.0);
	float band = step(0.5, t);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint.rgb, vec3(1.0), band);
}
```

- [ ] **Step 4: Write the GDScript**

`core/toon.gd`: after `WIND_SHADER`:

```gdscript
const WATER_SHADER := preload("res://shaders/water.gdshader")
```

After `static var _wind_cache`:

```gdscript
static var _water: ShaderMaterial
```

After `wind_material()`:

```gdscript
## The one water material. Shared so Ambient can drive its splash uniforms
## and every water surface shows the same ring.
static func water() -> ShaderMaterial:
	if _water == null:
		_water = ShaderMaterial.new()
		_water.shader = WATER_SHADER
		_water.set_shader_parameter("base_color", Pal.WATER)
		_water.set_shader_parameter("band_color", Pal.WATER_HI)
		_water.set_shader_parameter("sparkle_color", Pal.MOON)
		_water.set_shader_parameter("shadow_tint", Pal.SHADOW_TINT)
		_water.set_shader_parameter("splash_origin", Vector3.ZERO)
		_water.set_shader_parameter("splash_age", -1.0)
	return _water
```

`core/models.gd`, in `_dress()`, add an arm:

```gdscript
		"water":
			for mi in meshes(node):
				for i in mi.mesh.get_surface_count():
					mi.set_surface_override_material(i, Toon.water())
```

Create `world/ambient.gd`:

```gdscript
extends Node3D

## The world's continuous motion and the one switch that stills it: the
## motion_scale global every ambient shader reads, the pollen drifting over
## the board, and the splash ring on the water. The stage creates one of
## these as "Ambient". Spec: docs/superpowers/specs/2026-09-13-binairo-polish-design.md,
## section 4.

const Motion = preload("res://core/motion.gd")
const Toon = preload("res://core/toon.gd")
const Pal = preload("res://core/palette.gd")

## Global shader parameter, declared in project.godot [shader_globals].
const GLOBAL := "motion_scale"
const SPLASH_TIME := 2.0
const SPLASH_SPEED := 3.0
const POLLEN_AMOUNT := 24
const POLLEN_LIFETIME := 6.0

var pollen: CPUParticles3D
var _splash_age := -1.0

func _ready() -> void:
	_ensure_global()
	pollen = _make_pollen()
	add_child(pollen)
	refresh()
	set_process(false)

## Declares the global if project.godot has not (a stripped test project),
## never twice: RenderingServer errors on a duplicate.
static func _ensure_global() -> void:
	if not RenderingServer.global_shader_parameter_get_list().has(GLOBAL):
		RenderingServer.global_shader_parameter_add(GLOBAL, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)

## 1 when the world moves, 0 under reduce-motion.
static func motion_scale() -> float:
	return 0.0 if Motion.reduce else 1.0

## Re-reads Motion.reduce: sets the shader global and starts or stills the
## pollen. Call after the flag changes.
func refresh() -> void:
	RenderingServer.global_shader_parameter_set(GLOBAL, motion_scale())
	var on := not Motion.reduce
	if on and not pollen.emitting:
		pollen.restart()
	pollen.emitting = on
	pollen.visible = on

## Sizes the pollen volume to a board: its footprint plus a one-cell margin,
## one cell above its top, 0.4 tall. The stage calls this from fit_camera.
func fit_to(aabb: AABB) -> void:
	var c := aabb.get_center()
	pollen.position = Vector3(c.x, aabb.end.y + 1.0, c.z)
	pollen.emission_box_extents = Vector3(aabb.size.x * 0.5 + 1.0, 0.2, aabb.size.z * 0.5 + 1.0)

## Rings the water around `origin` (only its x and z matter). Nothing under
## reduce-motion.
func splash(origin: Vector3) -> void:
	if Motion.reduce:
		return
	Toon.water().set_shader_parameter("splash_origin", origin)
	_splash_age = 0.0
	Toon.water().set_shader_parameter("splash_age", _splash_age)
	set_process(true)

func splash_age() -> float:
	return _splash_age

func _process(delta: float) -> void:
	if _splash_age < 0.0:
		set_process(false)
		return
	_splash_age += delta
	if _splash_age >= SPLASH_TIME:
		_splash_age = -1.0
		set_process(false)
	Toon.water().set_shader_parameter("splash_age", _splash_age)

func _make_pollen() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Pollen"
	p.amount = POLLEN_AMOUNT
	p.lifetime = POLLEN_LIFETIME
	p.preprocess = POLLEN_LIFETIME
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(4.0, 0.2, 4.0)
	p.direction = Vector3(1.0, -0.15, 0.2)
	p.spread = 20.0
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.16
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.025
	p.scale_amount_max = 0.04
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	ramp.colors = PackedColorArray([Color(Pal.MOON, 0.0), Color(Pal.MOON, 0.85), Color(Pal.MOON, 0.85), Color(Pal.MOON, 0.0)])
	p.color_ramp = ramp
	p.mesh = speck_mesh()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## A unit billboard quad that takes the particle's colour, for pollen and
## for the one-shot effects in world/fx.gd.
static func speck_mesh(texture: Texture2D = null) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	if texture != null:
		m.albedo_texture = texture
	q.material = m
	return q
```

`world/stage.gd`: add preloads after `CameraRig`:

```gdscript
const Ambient = preload("res://world/ambient.gd")
const Motion = preload("res://core/motion.gd")
```

Add `var ambient: Node3D` after `var water: Node3D`. At the top of `_ready()`, before `add_to_group("stage")`:

```gdscript
	Motion.load_settings()
```

After the `anchor` block at the end of `_ready()`:

```gdscript
	ambient = Ambient.new()
	ambient.name = "Ambient"
	add_child(ambient)
```

Replace `fit_camera` and add `splash`:

```gdscript
func fit_camera(aabb: AABB, rect: Rect2) -> void:
	rig.fit(aabb, rect)
	ambient.fit_to(aabb)

## Rings the water under a board that has just landed.
func splash(origin: Vector3) -> void:
	ambient.splash(origin)
```

Update the class doc comment of `stage.gd` to mention the ambient node: replace `## water far below.` with `## water far below, and the Ambient node that keeps the world moving.`

- [ ] **Step 5: Run the tests and the shader compile check**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: no `FAIL`, `failed=0`.

Run: `godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | grep -iE "shader error|global uniform|saved /tmp/shot_binairo"`

Expected: `saved /tmp/shot_binairo.png`, no shader error. Open the image: the water shows lighter stripes and a few cream dots, the platform's shadow still falls on it, and small cream specks float over the board.

- [ ] **Step 6: Commit**

```bash
git add shaders/water.gdshader world/ambient.gd world/stage.gd core/toon.gd core/models.gd tests/test_ambient.gd tests/test_models.gd tests/run_tests.gd
git commit -m "feat: ambient node with motion_scale global, pollen and splash; toon water shader"
```

---

### Task 6: Camera breath

**Files:**
- Modify: `world/camera_rig.gd`
- Modify: `tests/test_ambient.gd`

**Interfaces:**
- Consumes: `Motion.reduce`.
- Produces: `CameraRig.BREATH := 0.002`, `CameraRig.breathing: bool` (default true), `CameraRig.breath_offset() -> Vector3` (the current additive offset).

- [ ] **Step 1: Write the failing test**

Add to `tests/test_ambient.gd` a function, and call it as `_test_camera_breath(t, stage)` from `run_in_tree` right after `_test_fit_to(t, stage.ambient)`:

```gdscript
## Camera breath (polish spec, section 4): a slow, tiny drift of camera and
## target together, a fraction of the fitted distance, off under reduce-motion.
static func _test_camera_breath(t, stage) -> void:
	var rig = stage.rig
	var cam: Camera3D = rig.camera
	rig._distance = 10.0
	rig._target = Vector3.ZERO
	rig._place()
	var still := cam.global_position
	rig._process(2.0)
	var moved := cam.global_position
	var shift := (moved - still).length()
	t.check(shift > 0.001, "the camera has drifted after two seconds (%.4f)" % shift)
	t.check(shift <= 10.0 * rig.BREATH * 1.7, "the drift is a fraction of the distance (%.4f)" % shift)
	t.check(rig.breath_offset().length() > 0.0, "breath_offset reports the drift")
	# The target moves with the camera, so the view direction is unchanged.
	var dir_still := rig.view_offset_dir()
	var dir_now := (cam.global_position - (rig._target + rig.breath_offset())).normalized()
	t.check(dir_now.is_equal_approx(dir_still), "camera and target drift together; the view direction holds")
	Motion.reduce = true
	rig._process(0.1)
	t.check(rig.breath_offset().is_zero_approx(), "reduce-motion zeroes the breath")
	t.check(cam.global_position.is_equal_approx(still), "reduce-motion puts the camera back on its fitted spot")
	Motion.reduce = false
	rig.breathing = false
	rig._process(1.0)
	t.check(rig.breath_offset().is_zero_approx(), "breathing=false also stills the camera")
	rig.breathing = true
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: `FAIL [ambient]` lines about the drift (`rig.BREATH` and `breath_offset` do not exist, so the suite may fail to load instead: `FAIL [ambient] could not load suite`). `failed=` greater than 0.

- [ ] **Step 3: Write the implementation**

In `world/camera_rig.gd`, after the `@export var margin` line:

```gdscript
const Motion = preload("res://core/motion.gd")

## Camera breath: camera and target drift together by this fraction of the
## fitted distance on two slow sine loops (8 s across, 11 s up), for a
## handheld-diorama calm. Off under reduce-motion or when breathing is false.
## Try-and-keep per the polish spec: drop it if the strip reads as wobble.
const BREATH := 0.002
var breathing := true
var _breath := Vector3.ZERO
var _breath_t := 0.0
```

Replace `_place()`:

```gdscript
func _place() -> void:
	camera.global_position = _target + _breath + view_offset_dir() * _distance
	camera.look_at(_target + _breath, Vector3.UP)

## The breath offset applied on top of the fitted position.
func breath_offset() -> Vector3:
	return _breath

func _process(delta: float) -> void:
	if not breathing or Motion.reduce:
		if not _breath.is_zero_approx():
			_breath = Vector3.ZERO
			_place()
		return
	_breath_t += delta
	var dir := view_offset_dir()
	var right := Vector3.UP.cross(dir).normalized()
	var up := dir.cross(right)
	var a := _distance * BREATH
	_breath = right * (sin(_breath_t * TAU / 8.0) * a) + up * (0.6 * sin(_breath_t * TAU / 11.0) * a)
	_place()
```

Update the class doc comment: after `## direction and slides its target so a given AABB fills a given screen rect.` add `## Between fits a tiny breath drifts camera and target together (see BREATH).`

- [ ] **Step 4: Run the tests and look at it**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: no `FAIL`, `failed=0`.

Run: `godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | grep -E "winnable|FAIL"`

Expected: `winnable=10/10` (the drift is a couple of pixels, well inside the cell the harness taps).

- [ ] **Step 5: Commit**

```bash
git add world/camera_rig.gd tests/test_ambient.gd
git commit -m "feat: camera breath, a slow drift of camera and target together"
```

---

### Task 7: Fx pools (puff, sparkle, cue)

**Files:**
- Create: `world/fx.gd`, `tests/test_fx.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `Motion.reduce`; `Ambient.speck_mesh(texture)` (Task 5); `Pal.STONE`, `Pal.SUN`.
- Produces: `Fx` (`world/fx.gd`, `extends Node3D`, names itself `"Fx"`): `puff(at: Vector3, colour: Color = Pal.STONE) -> void`, `sparkle(at: Vector3, colour: Color = Pal.SUN) -> void`, `cue(name: String) -> void`, `last_cue: String`, `puffs: Array[CPUParticles3D]`, `sparkles: Array[CPUParticles3D]`; constants `PUFF_POOL := 4`, `SPARKLE_POOL := 2`; `static func star_texture() -> ImageTexture`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_fx.gd`:

```gdscript
extends RefCounted

## One-shot particle pools a board fires at a point (polish spec, section 3):
## puffs and sparkles are picked round-robin, land where asked, take the
## colour given, and do nothing under reduce-motion. cue() is the audio hook.
## CPUParticles3D want a tree, so this runs from run_in_tree.

const Fx = preload("res://world/fx.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

static func run_in_tree(t) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	Motion.reduce = false
	var fx: Node3D = Fx.new()
	root.add_child(fx)
	_test_pools(t, fx)
	_test_puff(t, fx)
	_test_sparkle(t, fx)
	_test_cue(t, fx)
	_test_reduce(t, fx)
	_test_star(t)
	Motion.reduce = false
	root.remove_child(fx)
	fx.free()

static func _test_pools(t, fx) -> void:
	t.eq(String(fx.name), "Fx", "the node names itself Fx")
	t.eq(fx.puffs.size(), Fx.PUFF_POOL, "four puff emitters")
	t.eq(fx.sparkles.size(), Fx.SPARKLE_POOL, "two sparkle emitters")
	var idle := true
	for p in fx.puffs + fx.sparkles:
		if p.emitting or not p.one_shot or p.get_parent() != fx:
			idle = false
	t.check(idle, "every emitter is a one-shot child, idle at start")
	t.check(fx.puffs[0].amount == 8 and is_equal_approx(fx.puffs[0].lifetime, 0.4), "a puff is 8 specks over 0.4 s")
	t.check(fx.sparkles[0].amount == 10 and is_equal_approx(fx.sparkles[0].lifetime, 0.6), "a sparkle is 10 stars over 0.6 s")
	t.check(fx.puffs[0].gravity.y < 0.0 and fx.sparkles[0].gravity.is_zero_approx(), "puffs arc down, sparkles float")

static func _test_puff(t, fx) -> void:
	fx.puff(Vector3(1.0, 0.12, 2.0))
	var first: CPUParticles3D = fx.puffs[0]
	t.check(first.emitting, "the first puff fires the first emitter")
	t.check(first.position.is_equal_approx(Vector3(1.0, 0.12, 2.0)), "the emitter moves to the point")
	t.check(first.color.is_equal_approx(Pal.STONE), "puffs default to stone dust")
	fx.puff(Vector3(2.0, 0.12, 2.0), Pal.SUN)
	t.check(fx.puffs[1].emitting and fx.puffs[1].color.is_equal_approx(Pal.SUN), "the second puff takes the next emitter and its colour")
	fx.puff(Vector3.ZERO)
	fx.puff(Vector3.ZERO)
	fx.puff(Vector3(5.0, 0.0, 5.0))
	t.check(first.position.is_equal_approx(Vector3(5.0, 0.0, 5.0)), "the fifth puff wraps round to the first emitter")

static func _test_sparkle(t, fx) -> void:
	fx.sparkle(Vector3(0.5, 0.2, 0.5))
	t.check(fx.sparkles[0].emitting and fx.sparkles[0].position.is_equal_approx(Vector3(0.5, 0.2, 0.5)), "sparkle fires at the point")
	t.check(fx.sparkles[0].color.is_equal_approx(Pal.SUN), "sparkles default to sun gold")
	fx.sparkle(Vector3.ZERO)
	fx.sparkle(Vector3(3.0, 0.0, 3.0))
	t.check(fx.sparkles[0].position.is_equal_approx(Vector3(3.0, 0.0, 3.0)), "the third sparkle wraps round")

static func _test_cue(t, fx) -> void:
	fx.cue("roll")
	t.eq(fx.last_cue, "roll", "cue records the last name for the audio layer to come")

static func _test_reduce(t, fx) -> void:
	Motion.reduce = true
	for p in fx.puffs + fx.sparkles:
		p.emitting = false
		p.position = Vector3.ZERO
	fx.puff(Vector3(9.0, 9.0, 9.0))
	fx.sparkle(Vector3(9.0, 9.0, 9.0))
	var quiet := true
	for p in fx.puffs + fx.sparkles:
		if p.emitting or not p.position.is_zero_approx():
			quiet = false
	t.check(quiet, "reduce-motion fires nothing")
	Motion.reduce = false

static func _test_star(t) -> void:
	var tex: ImageTexture = Fx.star_texture()
	t.check(tex != null and tex.get_width() == 32 and tex.get_height() == 32, "the star is a 32 x 32 texture")
	var img := tex.get_image()
	t.check(img.get_pixel(16, 16).a > 0.9, "the star is solid at its centre")
	t.check(img.get_pixel(2, 2).a < 0.1, "the star is clear at its corners")
	t.check(img.get_pixel(16, 3).a > 0.9, "the star reaches up along its axis")
	t.check(Fx.star_texture() == tex, "the star texture is built once")
```

Register it in `tests/run_tests.gd`: add `"fx": "res://tests/test_fx.gd",` after the `"ambient"` line.

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: `FAIL [fx] could not load suite`, `failed=1`.

- [ ] **Step 3: Write the implementation**

Create `world/fx.gd`:

```gdscript
extends Node3D

## One-shot particle effects a board fires at a point: a dust puff when a
## prism lands, a sparkle for a hint. Emitters are pooled and picked
## round-robin, so taps in quick succession never steal each other's puff.
## Board-local: the board adds this as its own child. cue() is the audio
## hook; it only records the name until sounds exist. Spec:
## docs/superpowers/specs/2026-09-13-binairo-polish-design.md, section 3.

const Motion = preload("res://core/motion.gd")
const Ambient = preload("res://world/ambient.gd")
const Pal = preload("res://core/palette.gd")

const PUFF_POOL := 4
const SPARKLE_POOL := 2
const STAR_SIZE := 32

var puffs: Array[CPUParticles3D] = []
var sparkles: Array[CPUParticles3D] = []
## The most recent audio cue name. A later audio layer plays these.
var last_cue := ""
var _next_puff := 0
var _next_sparkle := 0
static var _star: ImageTexture

func _ready() -> void:
	name = "Fx"
	for i in PUFF_POOL:
		var p := _emitter("Puff_%d" % i, 8, 0.4, 60.0, 0.5, 0.9, Vector3(0.0, -1.5, 0.0), 0.05)
		p.mesh = Ambient.speck_mesh()
		add_child(p)
		puffs.append(p)
	for i in SPARKLE_POOL:
		var s := _emitter("Sparkle_%d" % i, 10, 0.6, 40.0, 0.3, 0.6, Vector3.ZERO, 0.04)
		s.mesh = Ambient.speck_mesh(star_texture())
		add_child(s)
		sparkles.append(s)

## Stone dust rising from `at` and shrinking away.
func puff(at: Vector3, colour: Color = Pal.STONE) -> void:
	if Motion.reduce:
		return
	_fire(puffs[_next_puff], at, colour)
	_next_puff = (_next_puff + 1) % PUFF_POOL

## Small stars floating up from `at`.
func sparkle(at: Vector3, colour: Color = Pal.SUN) -> void:
	if Motion.reduce:
		return
	_fire(sparkles[_next_sparkle], at, colour)
	_next_sparkle = (_next_sparkle + 1) % SPARKLE_POOL

## Audio hook. Effects name their sound here; nothing plays yet.
func cue(cue_name: String) -> void:
	last_cue = cue_name

func _fire(p: CPUParticles3D, at: Vector3, colour: Color) -> void:
	p.position = at
	p.color = colour
	p.restart()

static func _emitter(nm: String, amount: int, life: float, spread: float, v0: float, v1: float, gravity: Vector3, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = nm
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = gravity
	p.scale_amount_min = size
	p.scale_amount_max = size
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## A four-point star drawn in code: alpha 1 inside the astroid
## |x|^0.5 + |y|^0.5 < 1, with a soft edge. White, so the particle colour tints it.
static func star_texture() -> ImageTexture:
	if _star != null:
		return _star
	var img := Image.create(STAR_SIZE, STAR_SIZE, false, Image.FORMAT_RGBA8)
	for y in STAR_SIZE:
		for x in STAR_SIZE:
			var u := (x + 0.5) / STAR_SIZE * 2.0 - 1.0
			var v := (y + 0.5) / STAR_SIZE * 2.0 - 1.0
			var d := sqrt(absf(u)) + sqrt(absf(v))
			var a := clampf((1.05 - d) / 0.1, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_star = ImageTexture.create_from_image(img)
	return _star
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: no `FAIL`, `failed=0`.

- [ ] **Step 5: Commit**

```bash
git add world/fx.gd tests/test_fx.gd tests/run_tests.gd
git commit -m "feat: pooled puff and sparkle emitters with an audio cue hook"
```

---

### Task 8: Roll settle and lift, neighbour bob, dust

**Files:**
- Modify: `puzzles/binairo3d.gd`
- Modify: `tests/test_binairo3d.gd`

**Interfaces:**
- Consumes: `Motion.settle/hop/stop/running`, `Fx.puff/cue`, `Placeholders.TILE_RISE/TILE_APOTHEM/TILE_SIDE`.
- Produces (on `Binairo3D`): constants `ROLL_TIME := 0.34`, `ROLL_TIME_TWO := 0.42`, `ROLL_LIFT := 0.04`, `BOB_DIP := 0.02`, `BOB_TIME := 0.35`, `BOB_LAG := 0.04`, `BOB_LAG_DIAG := 0.07`; vars `_rest_y: float`, `_hops: Array`, `_bobs: Array`, `fx: Node3D`; functions `_roll(r, c, thirds := 1, delay := 0.0)`, `_on_roll_landed(r, c)`, `_settle(r, c)` (now also snaps height and kills hops and bobs), `_bob_neighbours(r, c)`, `_dip(r, c, depth, delay := 0.0)`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_binairo3d.gd`, add `const Motion = preload("res://core/motion.gd")` after the `Placeholders` preload, and in `run_in_tree` add `_test_neighbour_bob(t, p)` right after `_test_tap_rolls(t, p)`. Then edit `_test_tap_rolls`: replace the block from `# Drive the roll to its end` down to the `"after the roll only the sun emblem is visible"` check with:

```gdscript
	var lift: Tween = p._hops[r][c]
	t.check(Motion.running(lift), "a lift rides along the roll")
	# Drive the roll to its end. The back ease is already overshooting at the
	# half, so the between-faces check steps a quarter.
	first.custom_step(p.ROLL_TIME * 0.25)
	t.check(pivot.rotation.x < -0.2 and pivot.rotation.x > -THIRD, "a quarter in, the prism is between faces (%.3f)" % pivot.rotation.x)
	lift.custom_step(p.ROLL_TIME * 0.25)
	t.check(pivot.position.y > p._rest_y + 0.01, "the prism has lifted off its axis (%.3f)" % (pivot.position.y - p._rest_y))
	first.custom_step(p.ROLL_TIME * 0.25)
	t.check(pivot.rotation.x < -THIRD, "halfway, the prism has rolled past the face and is springing back (%.3f)" % pivot.rotation.x)
	first.custom_step(p.ROLL_TIME)
	lift.custom_step(p.ROLL_TIME)
	t.check(is_equal_approx(pivot.rotation.x, -THIRD), "the roll lands exactly on the sun face (%.3f)" % pivot.rotation.x)
	t.check(is_equal_approx(pivot.position.y, p._rest_y), "the lift lands back on the axis (%.4f)" % pivot.position.y)
	t.check(not first.is_running(), "the roll tween finished")
	t.check(p._suns[r][c].visible and not p._marks[r][c].visible and not p._moons[r][c].visible,
		"after the roll only the sun emblem is visible")
	t.eq(p.fx.last_cue, "land", "landing fires the land cue and its dust")
```

Add the new test function:

```gdscript
## A tap ripples through the neighbours: the side cells dip and return a
## beat later, the diagonals half as deep and later still. A rolling cell is
## skipped, so no cell ever runs two height tweens.
static func _test_neighbour_bob(t, p) -> void:
	var cell := _find_cell(p, false)
	var r := cell.y
	var c := cell.x
	var side := Vector2i(c + 1, r) if c + 1 < p.n else Vector2i(c - 1, r)
	var diag := Vector2i(side.x, r + 1) if r + 1 < p.n else Vector2i(side.x, r - 1)
	_tap(p, r, c)
	var sb: Tween = p._bobs[side.y][side.x]
	var db: Tween = p._bobs[diag.y][diag.x]
	t.check(Motion.running(sb), "a side neighbour bobs")
	t.check(Motion.running(db), "a diagonal neighbour bobs")
	t.check(p._bobs[r][c] == null, "the tapped cell itself does not bob; it rolls")
	sb.custom_step(p.BOB_LAG + p.BOB_TIME * 0.5)
	db.custom_step(p.BOB_LAG_DIAG + p.BOB_TIME * 0.5)
	var side_y: float = p._cells[side.y][side.x].position.y
	var diag_y: float = p._cells[diag.y][diag.x].position.y
	t.check(side_y < p._rest_y - 0.015, "at its deepest the side neighbour is down %.3f" % (p._rest_y - side_y))
	t.check(diag_y < p._rest_y and diag_y > side_y, "the diagonal dips, but half as far (%.3f)" % (p._rest_y - diag_y))
	sb.custom_step(p.BOB_TIME)
	db.custom_step(p.BOB_TIME)
	t.check(is_equal_approx(p._cells[side.y][side.x].position.y, p._rest_y), "the side neighbour returns to rest")
	t.check(is_equal_approx(p._cells[diag.y][diag.x].position.y, p._rest_y), "the diagonal returns to rest")
	# Tidy: land the roll so later tests start from a resting board.
	p._settle(r, c)
```

In `_test_locked_cell`, after the existing two checks add:

```gdscript
	t.check(Motion.running(p._bobs[r][c]), "a given cell answers a tap with a dip")
	p._bobs[r][c].custom_step(p.BOB_TIME * 0.5)
	t.check(p._cells[r][c].position.y < p._rest_y, "the dip goes down")
	p._bobs[r][c].custom_step(p.BOB_TIME)
	t.check(is_equal_approx(p._cells[r][c].position.y, p._rest_y), "the dip returns to rest")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: `FAIL [binairo3d]` lines (the suite may instead fail to load, since `p._hops`, `p._rest_y`, `p.fx` do not exist). `failed=` greater than 0.

- [ ] **Step 3: Write the implementation**

In `puzzles/binairo3d.gd`:

Replace the class doc comment's last two sentences (`The pivot's angle is the only visual state; ... so the player learns the rules by touching.`) with:

```gdscript
## once; the roll is only how the change is shown, with a settle, a lift and a
## puff of dust on landing, and the neighbours bob as if the stone were soft.
## The pivot's angle is the only visual state; the emblems on the two buried
## faces are merely made invisible between rolls so they cost no draw calls.
## Tiles in a line that already breaks a rule blush, so the player learns the
## rules by touching. Motion: docs/superpowers/specs/2026-09-13-binairo-polish-design.md.
```

Add preloads after `Platform`:

```gdscript
const Motion = preload("res://core/motion.gd")
const Fx = preload("res://world/fx.gd")
```

Replace `const ROLL_TIME := 0.3` with:

```gdscript
## Roll and bob timings (polish spec, section 2).
const ROLL_TIME := 0.34        # one third of a turn, settle included
const ROLL_TIME_TWO := 0.42    # two thirds in one roll (reset)
const ROLL_LIFT := 0.04
const BOB_DIP := 0.02
const BOB_TIME := 0.35
const BOB_LAG := 0.04
const BOB_LAG_DIAG := 0.07
```

Replace the `_rolls` declaration with:

```gdscript
var _rest_y: float = 0.0  # pivot height at rest: the prism's axis
var _rolls: Array = []    # [r][c] -> Tween or null, the roll in flight
var _hops: Array = []     # [r][c] -> the lift riding along the roll
var _bobs: Array = []     # [r][c] -> a neighbour bob or a given's dip
var fx: Node3D            # pooled one-shot particles, a child of the board
```

In `_build_scene`, after `_rolls = []` add `_hops = []` and `_bobs = []`; after `board.add_child(Platform.build(n, n))` add:

```gdscript
	fx = Fx.new()
	board.add_child(fx)
	_rest_y = Placeholders.TILE_RISE - Placeholders.TILE_APOTHEM
```

In the per-row setup add `var hop_row := []` and `var bob_row := []` beside `var roll_row := []`; in the per-cell loop after `roll_row.append(null)` add `hop_row.append(null)` and `bob_row.append(null)`; after `_rolls.append(roll_row)` add `_hops.append(hop_row)` and `_bobs.append(bob_row)`.

Replace `_settle` and `_roll` with:

```gdscript
## Ends every motion on cell (r, c) at once: the prism snaps to the face it
## was turning to and back onto its axis, buried faces hidden.
func _settle(r: int, c: int) -> void:
	Motion.stop(_rolls[r][c])
	Motion.stop(_hops[r][c])
	Motion.stop(_bobs[r][c])
	_rolls[r][c] = null
	_hops[r][c] = null
	_bobs[r][c] = null
	var pivot: Node3D = _cells[r][c]
	pivot.rotation.x = _target_angle(r, c)
	pivot.position.y = _rest_y
	_show_faces(r, c, false)

## Rolls cell (r, c) `thirds` faces toward the player after `delay`, with the
## settle and the lift that make it a hop rather than a grind. All three
## emblems show while it turns; _on_roll_landed hides the buried two again.
func _roll(r: int, c: int, thirds := 1, delay := 0.0) -> void:
	var pivot: Node3D = _cells[r][c]
	_show_faces(r, c, true)
	var time := ROLL_TIME if thirds == 1 else ROLL_TIME_TWO
	var tw: Tween = Motion.settle(pivot, "rotation:x", _target_angle(r, c), time, delay, true)
	tw.finished.connect(_on_roll_landed.bind(r, c))
	_rolls[r][c] = tw
	Motion.stop(_hops[r][c])
	_hops[r][c] = Motion.hop(pivot, ROLL_LIFT, time, delay, _rest_y)
	fx.cue("roll")

## The roll has landed: buried faces go invisible and dust rises from the
## near edge, where the arriving face touched down.
func _on_roll_landed(r: int, c: int) -> void:
	_show_faces(r, c, false)
	var pivot: Node3D = _cells[r][c]
	fx.puff(Vector3(pivot.position.x, Placeholders.TILE_RISE, pivot.position.z + Placeholders.TILE_SIDE * 0.5))
	fx.cue("land")

## The eight cells around a tapped one dip and return: the sides a beat after
## the tap, the diagonals half as deep and a beat later, like a soft surface.
## A rolling cell is left alone, so no cell ever runs two height tweens.
func _bob_neighbours(r: int, c: int) -> void:
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var rr := r + dr
			var cc := c + dc
			if rr < 0 or cc < 0 or rr >= n or cc >= n:
				continue
			if Motion.running(_rolls[rr][cc]):
				continue
			var diagonal := dr != 0 and dc != 0
			_dip(rr, cc, BOB_DIP * (0.5 if diagonal else 1.0), BOB_LAG_DIAG if diagonal else BOB_LAG)

## A dip and return on one cell, replacing any bob already on it.
func _dip(r: int, c: int, depth: float, delay := 0.0) -> void:
	Motion.stop(_bobs[r][c])
	_cells[r][c].position.y = _rest_y
	_bobs[r][c] = Motion.hop(_cells[r][c], -depth, BOB_TIME, delay, _rest_y)
```

Replace the body of `on_board_press` from `if _given[r][c]:` to the end with:

```gdscript
	if _given[r][c]:
		# Stone stays stone: the cell answers with a dip and nothing rolls.
		_dip(r, c, BOB_DIP)
		return
	# A tap mid-roll snaps that roll home first, so the next one starts from
	# a face, never from between two.
	_settle(r, c)
	# empty -> sun -> moon -> empty
	var v: int = _grid[r][c]
	_grid[r][c] = 0 if v == -1 else (1 if v == 0 else -1)
	_turns[r][c] += 1
	_roll(r, c)
	_bob_neighbours(r, c)
	_recolour()
	note_move()
```

`reset_board` stays as it is for now (Task 10 turns it into the wave); `_settle` inside it now also restores heights.

- [ ] **Step 4: Run the tests and the win harness**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: no `FAIL`, `failed=0`.

Run: `godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | grep -E "winnable|FAIL"`

Expected: `winnable=10/10`.

- [ ] **Step 5: Commit**

```bash
git add puzzles/binairo3d.gd tests/test_binairo3d.gd
git commit -m "feat: rolls settle with a lift and dust; neighbours bob; givens dip"
```

---

### Task 9: Focus ring and blush pulse

**Files:**
- Modify: `puzzles/binairo3d.gd`
- Modify: `tests/test_binairo3d.gd`

**Interfaces:**
- Consumes: `Models.instance("focus_ring")` (Task 2), `Motion.fade/stop/running`, `Fx.cue`.
- Produces (on `Binairo3D`): `focus_cell: Vector2i` (public; sub-project 2's working-line card reads it), constants `BAD_BLEND := 0.375`, `BLUSH_STEPS := 16`, `BLUSH_IN := 0.25`, `BLUSH_OUT := 0.4`, `BLUSH_BEATS := 0.8`, `BLUSH_BEAT_EXTRA := 0.125`, `FOCUS_HOLD := 2.5`, `FOCUS_FADE := 0.5`, `FOCUS_MOVE := 0.15`, `FOCUS_POP := 0.15`, `FOCUS_PULSE := 1.2`, `FOCUS_ALPHA := 0.9`, `FOCUS_ALPHA_LOW := 0.6`; vars `_ring: Node3D`, `_ring_mat: StandardMaterial3D`, `_ring_tw`, `_ring_pulse`, `_ring_hold: Tween`, `_fades`, `_blend`, `_blend_target: Array`; functions `_focus(r, c)`, `_focus_fade()`, `_focus_clear()`, `_paint(blend: float, r: int, c: int)`, `_recolour()` (now animated), `_fade_blend(r, c, from, to) -> Tween`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_binairo3d.gd`, in `run_in_tree`, add `_test_focus_ring(t, p)` and `_test_blush_pulse(t, p)` after `_test_neighbour_bob(t, p)`. Add:

```gdscript
## The focus ring (polish spec, section 2): it pops onto the first tapped
## cell, slides to the next, pulses while shown, and fades after a pause.
## Given cells take the focus too, since "look at this line" is a gesture.
static func _test_focus_ring(t, p) -> void:
	var a := _find_cell(p, false)
	var g := _find_cell(p, true)
	var ring: Node3D = p._ring
	t.check(ring != null and ring.get_parent() == p.board and not ring.visible, "the ring exists, under the board, hidden at first")
	t.check(p.focus_cell == Vector2i(-1, -1), "no focus before the first tap")
	_tap(p, a.y, a.x)
	t.check(p.focus_cell == Vector2i(a.x, a.y), "focus_cell is the tapped cell as (col, row)")
	var want := BoardMath.cell_center(a.y, a.x, p.n, p.n, Placeholders.TILE_RISE + 0.005)
	t.check(ring.visible and ring.position.is_equal_approx(want), "the ring shows on the tapped cell (%s)" % ring.position)
	t.check(Motion.running(p._ring_tw), "the ring pops in")
	p._ring_tw.custom_step(p.FOCUS_POP)
	t.check(ring.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(p._ring_mat.albedo_color.a, p.FOCUS_ALPHA), "the pop ends at full size and alpha")
	t.check(Motion.running(p._ring_pulse), "the ring pulses once shown")
	t.check(Motion.running(p._ring_hold), "the hold timer is running")
	_tap(p, g.y, g.x)
	t.check(p.focus_cell == Vector2i(g.x, g.y), "a tap on a given cell takes the focus")
	t.check(p._grid[g.y][g.x] != -1 and p._rolls[g.y][g.x] == null, "and rolls nothing")
	t.check(Motion.running(p._ring_tw), "the ring slides")
	p._ring_tw.custom_step(p.FOCUS_MOVE)
	var want_g := BoardMath.cell_center(g.y, g.x, p.n, p.n, Placeholders.TILE_RISE + 0.005)
	t.check(ring.position.is_equal_approx(want_g), "the slide lands on the given cell")
	t.check(Motion.running(p._ring_pulse), "the pulse keeps going through a slide")
	p._ring_hold.custom_step(p.FOCUS_HOLD + 0.01)
	t.check(Motion.running(p._ring_tw) and not Motion.running(p._ring_pulse), "after the hold the ring fades and stops pulsing")
	p._ring_tw.custom_step(p.FOCUS_FADE + 0.01)
	t.check(not ring.visible, "the faded ring hides")
	t.check(is_zero_approx(p._ring_mat.albedo_color.a), "the fade ends fully clear")
	# Tidy for later tests.
	p._settle(a.y, a.x)
	p._focus_clear()

## Blush (polish spec, section 2): a newly broken line fades to the rose
## blend with two heartbeats past it, a fixed line fades back, and every
## level sits on the 16-step grid so the material cache stays bounded.
static func _test_blush_pulse(t, p) -> void:
	var saved: Array = (p._grid[0] as Array).duplicate()
	for c in 3:
		p._grid[0][c] = 0
	p._recolour()
	var base := Pal.STONE_GIVEN if p._given[0][0] else Pal.STONE
	var fade: Tween = p._fades[0][0]
	t.check(Motion.running(fade), "a broken row starts a blush fade on its cells")
	t.check(is_equal_approx(p._blend_target[0][0], p.BAD_BLEND), "the cell heads for BAD_BLEND")
	fade.custom_step(p.BLUSH_IN)
	t.check(is_equal_approx(p._blend[0][0], p.BAD_BLEND), "after the fade in the cell sits on BAD_BLEND (%.3f)" % p._blend[0][0])
	fade.custom_step(p.BLUSH_BEATS * 0.25)
	t.check(p._blend[0][0] > p.BAD_BLEND, "a heartbeat pushes past the blend (%.3f)" % p._blend[0][0])
	t.check(is_equal_approx(p._blend[0][0] * p.BLUSH_STEPS, roundf(p._blend[0][0] * p.BLUSH_STEPS)), "mid-beat the blend is on the 16-step grid")
	fade.custom_step(p.BLUSH_BEATS)
	t.check(not Motion.running(fade), "the blush comes to rest")
	var blushed := _face_colour(p, 0, 0, "Face_Empty")
	t.check(blushed.is_equal_approx(base.lerp(Pal.BAD, p.BAD_BLEND)), "at rest the face is exactly the blushed stone (%s)" % blushed.to_html(false))
	for c in p.n:
		if Motion.running(p._fades[0][c]):
			p._fades[0][c].custom_step(5.0)
	p._grid[0] = saved
	p._recolour()
	var out: Tween = p._fades[0][0]
	t.check(Motion.running(out), "fixing the row fades the blush out")
	out.custom_step(p.BLUSH_OUT * 0.5)
	t.check(p._blend[0][0] > 0.0 and p._blend[0][0] < p.BAD_BLEND, "halfway out the blush is partway (%.3f)" % p._blend[0][0])
	out.custom_step(p.BLUSH_OUT)
	t.check(is_zero_approx(p._blend[0][0]), "the fade out ends at no blush")
	t.check(_face_colour(p, 0, 0, "Face_Empty").is_equal_approx(base), "the face is exactly its stone again")
	for r in p.n:
		for c in p.n:
			if Motion.running(p._fades[r][c]):
				p._fades[r][c].custom_step(5.0)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: `FAIL [binairo3d]` lines or `could not load suite`; `failed=` greater than 0.

- [ ] **Step 3: Write the implementation**

In `puzzles/binairo3d.gd`:

Replace `const BAD_BLEND := 0.35` with:

```gdscript
## Blush toward BAD on a broken line: 6/16, so it and every quantised level
## of the fade land on the 16-step grid _paint uses (polish spec, section 2).
const BAD_BLEND := 0.375
const BLUSH_STEPS := 16
const BLUSH_IN := 0.25
const BLUSH_OUT := 0.4
const BLUSH_BEATS := 0.8
const BLUSH_BEAT_EXTRA := 0.125
## Focus ring on the last tapped cell.
const FOCUS_HOLD := 2.5
const FOCUS_FADE := 0.5
const FOCUS_MOVE := 0.15
const FOCUS_POP := 0.15
const FOCUS_PULSE := 1.2
const FOCUS_ALPHA := 0.9
const FOCUS_ALPHA_LOW := 0.6
const FOCUS_LIFT := 0.005
```

After `var fx: Node3D` add:

```gdscript
var _fades: Array = []         # [r][c] -> a blush fade in flight
var _blend: Array = []         # [r][c] -> painted blend toward BAD, on the grid
var _blend_target: Array = []  # [r][c] -> the blend the cell is heading for
var _ring: Node3D
var _ring_mat: StandardMaterial3D
var _ring_tw: Tween     # pop, slide or fade
var _ring_pulse: Tween  # the loop while shown
var _ring_hold: Tween   # the pause before the fade
## The last tapped cell as (col, row); (-1, -1) before the first tap. The
## working-line card in the HUD reads this.
var focus_cell := Vector2i(-1, -1)
```

In `build()`, replace `_build_scene()` / `_recolour()` / `_refit()` with:

```gdscript
	_build_scene()
	_recolour()
	_refit()
```

(unchanged lines; the initial paint now happens inside `_build_scene`).

In `_build_scene`: after `_bobs = []` add `_fades = []`, `_blend = []`, `_blend_target = []`; after the `_rest_y` line add:

```gdscript
	_ring = Models.instance("focus_ring")
	_ring.name = "FocusRing"
	_ring.visible = false
	_ring_mat = Models.meshes(_ring)[0].material_override
	board.add_child(_ring)
	focus_cell = Vector2i(-1, -1)
```

In the per-row setup add `var fade_row := []`, `var blend_row := []`, `var target_row := []`; in the per-cell loop after `bob_row.append(null)` add `fade_row.append(null)`, `blend_row.append(0.0)`, `target_row.append(0.0)`; after `_bobs.append(bob_row)` add `_fades.append(fade_row)`, `_blend.append(blend_row)`, `_blend_target.append(target_row)`. Replace the final loop of `_build_scene`:

```gdscript
	for r in n:
		for c in n:
			_show_faces(r, c, false)
			_paint(0.0, r, c)
```

Replace `_recolour` with:

```gdscript
## Rule feedback. Cells whose line just broke fade toward the rose blend and
## give two heartbeats; cells whose line was fixed fade back. A cell already
## heading for the right blend is left alone, beats and all.
func _recolour() -> void:
	_bad = Gen.bad_lines(_grid)
	for r in n:
		for c in n:
			var target := BAD_BLEND if (_bad.rows.has(r) or _bad.cols.has(c)) else 0.0
			if is_equal_approx(_blend_target[r][c], target):
				continue
			_blend_target[r][c] = target
			Motion.stop(_fades[r][c])
			_fades[r][c] = _fade_blend(r, c, _blend[r][c], target)

## The fade from one blend to another. Blushing in gets two heartbeats past
## the target; fading out is plain. Under reduce-motion _paint lands at once.
func _fade_blend(r: int, c: int, from: float, to: float) -> Tween:
	var setter := _paint.bind(r, c)
	if to > from:
		var tw: Tween = Motion.fade(board, setter, from, to, BLUSH_IN, BLUSH_STEPS)
		if tw == null:
			return null
		var beat := BLUSH_BEATS * 0.25
		for i in 2:
			tw.tween_method(setter, to, to + BLUSH_BEAT_EXTRA, beat).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_method(setter, to + BLUSH_BEAT_EXTRA, to, beat).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fx.cue("blush_in")
		return tw
	fx.cue("blush_out")
	return Motion.fade(board, setter, from, to, BLUSH_OUT, BLUSH_STEPS)

## Face colours at a blend toward BAD: stone for the empty and sun faces and
## the caps, slate for the moon face, darker when the cell is a given. The
## blend snaps to the 16-step grid, so a fade never asks the toon cache for
## more than 17 colours per base.
func _paint(blend: float, r: int, c: int) -> void:
	blend = roundf(blend * BLUSH_STEPS) / BLUSH_STEPS
	_blend[r][c] = blend
	var locked: bool = _given[r][c]
	var stone: Color = (Pal.STONE_GIVEN if locked else Pal.STONE).lerp(Pal.BAD, blend)
	var slate: Color = (Pal.SLATE_GIVEN if locked else Pal.SLATE).lerp(Pal.BAD, blend)
	var tile: Node3D = _tiles[r][c]
	Models.tint_named(tile, "Face_Empty", stone)
	Models.tint_named(tile, "Face_Sun", stone)
	Models.tint_named(tile, "Face_Moon", slate)
	Models.tint_named(tile, "Cap", stone)
```

Add the focus functions after `_dip`:

```gdscript
# --- focus ring ---

## Moves the focus to cell (r, c): the ring pops in on a first tap, slides
## from the previous cell otherwise, pulses while shown, and fades after
## FOCUS_HOLD without a tap. It lives on the board, never on a pivot.
func _focus(r: int, c: int) -> void:
	var at := BoardMath.cell_center(r, c, n, n, Placeholders.TILE_RISE + FOCUS_LIFT)
	var shown := _ring.visible and focus_cell.x >= 0
	focus_cell = Vector2i(c, r)
	Motion.stop(_ring_tw)
	Motion.stop(_ring_hold)
	if Motion.reduce:
		Motion.stop(_ring_pulse)
		_ring.position = at
		_ring.scale = Vector3.ONE
		_ring_mat.albedo_color.a = FOCUS_ALPHA
		_ring.visible = true
	elif shown:
		_ring_tw = _ring.create_tween().set_parallel(true)
		_ring_tw.tween_property(_ring, "position", at, FOCUS_MOVE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if not Motion.running(_ring_pulse):
			# A tap during the fade: bring the ring back up and pulse again.
			_ring_tw.tween_property(_ring_mat, "albedo_color:a", FOCUS_ALPHA, FOCUS_MOVE)
			_ring_tw.finished.connect(_start_pulse)
	else:
		Motion.stop(_ring_pulse)
		_ring.position = at
		_ring.scale = Vector3(0.8, 1.0, 0.8)
		_ring_mat.albedo_color.a = 0.0
		_ring.visible = true
		_ring_tw = _ring.create_tween().set_parallel(true)
		_ring_tw.tween_property(_ring, "scale", Vector3.ONE, FOCUS_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_ring_tw.tween_property(_ring_mat, "albedo_color:a", FOCUS_ALPHA, FOCUS_POP)
		_ring_tw.finished.connect(_start_pulse)
	_ring_hold = _ring.create_tween()
	_ring_hold.tween_interval(FOCUS_HOLD)
	_ring_hold.tween_callback(_focus_fade)
	fx.cue("focus")

## The breathing loop: a little larger and dimmer, then back, while shown.
func _start_pulse() -> void:
	Motion.stop(_ring_pulse)
	if Motion.reduce or not _ring.visible:
		return
	var half := FOCUS_PULSE * 0.5
	_ring_pulse = _ring.create_tween().set_loops()
	_ring_pulse.tween_property(_ring, "scale", Vector3(1.04, 1.0, 1.04), half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ring_pulse.parallel().tween_property(_ring_mat, "albedo_color:a", FOCUS_ALPHA_LOW, half).set_trans(Tween.TRANS_SINE)
	_ring_pulse.tween_property(_ring, "scale", Vector3.ONE, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ring_pulse.parallel().tween_property(_ring_mat, "albedo_color:a", FOCUS_ALPHA, half).set_trans(Tween.TRANS_SINE)

## Fades the ring out and hides it.
func _focus_fade() -> void:
	Motion.stop(_ring_pulse)
	Motion.stop(_ring_tw)
	if Motion.reduce or not _ring.visible:
		_ring.visible = false
		_ring_mat.albedo_color.a = 0.0
		return
	_ring_tw = _ring.create_tween()
	_ring_tw.tween_property(_ring_mat, "albedo_color:a", 0.0, FOCUS_FADE)
	_ring_tw.tween_callback(func() -> void: _ring.visible = false)

## Drops the focus: reset, a new puzzle, a solve.
func _focus_clear() -> void:
	Motion.stop(_ring_hold)
	focus_cell = Vector2i(-1, -1)
	_focus_fade()
```

In `on_board_press`, add `_focus(r, c)` as the first line inside the `if _given[r][c]:` block (before `_dip`), and add `_focus(r, c)` right after `_roll(r, c)` in the free-cell path.

In `reset_board`, add `_focus_clear()` as its first line.

- [ ] **Step 4: Run the tests, the win harness and a look**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: no `FAIL`, `failed=0`.

Run: `godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | grep -E "winnable|FAIL"`

Expected: `winnable=10/10`.

Run: `godot --path . --resolution 540x960 --script res://tests/_tap.gd 2>&1 | grep saved` and open `/tmp/shot_tapped.png`. Expected: row 0's cells blushed rose (three suns in a row after the harness's taps), and the sky-blue focus ring around the last tapped cell in row 1.

- [ ] **Step 5: Commit**

```bash
git add puzzles/binairo3d.gd tests/test_binairo3d.gd
git commit -m "feat: focus ring on the last tapped cell; blush fades in with heartbeats and fades out"
```

---

### Task 10: Board entrance, reset wave, solved wave

**Files:**
- Modify: `puzzles/binairo3d.gd`
- Modify: `tests/test_binairo3d.gd`
- Modify: `tests/_shot.gd`

**Interfaces:**
- Consumes: `Motion.settle/hop/stagger/stop/running`, `Stage.splash(origin)` (Task 5), `Fx.cue`.
- Produces (on `Binairo3D`): constants `ENTER_DROP := 0.5`, `ENTER_PLATFORM := 0.5`, `ENTER_POP := 0.25`, `ENTER_STAGGER := 0.03`, `RESET_STAGGER := 0.02`, `RESET_HOP := 0.03`, `SOLVE_HOP := 0.08`, `SOLVE_TIME := 0.4`, `SOLVE_STAGGER := 0.04`; var `_entrance: Array` (tweens); functions `_enter()`, `_stop_entrance()`, `_splash()`, `_on_solved()`; `reset_board()` becomes the wave; `_ready()` connects `solved`.

- [ ] **Step 1: Write the failing tests**

In `tests/test_binairo3d.gd`:

In `run_in_tree`, insert `_test_entrance(t, p)` immediately after `p.build(rng, 0)` (before `_test_platform_under_board`), because the entrance leaves the prisms tiny until it is stepped through and the geometry tests measure them. Replace `_test_reset_snaps(t, p)` with `_test_reset_wave(t, p)` and add `_test_solved_wave(t, p)` as the last call before the teardown.

Add:

```gdscript
## The board arrives (polish spec, section 2): the platform rises from below,
## then the prisms pop in along a diagonal wave from the far-left corner.
## Stepping every entrance tween to its end leaves a resting board.
static func _test_entrance(t, p) -> void:
	var platform: Node3D = p.board.get_node("Platform")
	t.check(is_equal_approx(platform.position.y, -p.ENTER_DROP), "the platform starts below the surface (%.2f)" % platform.position.y)
	t.check(p._cells[0][0].scale.x < 0.05, "the prisms start tiny")
	t.check(p._entrance.size() >= p.n * p.n + 1, "one entrance tween per prism plus the platform (%d)" % p._entrance.size())
	# The far-left prism pops first, the near-right one last.
	var first_pop: float = p.ENTER_PLATFORM + Motion.stagger(0, p.ENTER_STAGGER)
	var last_pop: float = p.ENTER_PLATFORM + Motion.stagger(2 * (p.n - 1), p.ENTER_STAGGER)
	for tw in p._entrance:
		tw.custom_step(first_pop + p.ENTER_POP * 0.5)
	t.check(p._cells[0][0].scale.x > 0.5, "half a pop after the platform lands, the far-left prism is well on its way (%.2f)" % p._cells[0][0].scale.x)
	t.check(p._cells[p.n - 1][p.n - 1].scale.x < 0.05, "the near-right prism has not started (%.2f)" % p._cells[p.n - 1][p.n - 1].scale.x)
	t.check(is_equal_approx(platform.position.y, 0.0), "the platform has landed")
	for tw in p._entrance:
		tw.custom_step(last_pop + p.ENTER_POP + 1.0)
	var all_home := true
	for r in p.n:
		for c in p.n:
			if not p._cells[r][c].scale.is_equal_approx(Vector3.ONE):
				all_home = false
	t.check(all_home, "every prism ends at scale one")
	t.eq(p.fx.last_cue, "enter", "the entrance fires its cue")

## Reset rolls every filled free cell forward to empty in a wave from the
## near-left corner and gives the givens a little hop; the grid clears at once.
static func _test_reset_wave(t, p) -> void:
	var free := _find_cell(p, false)
	# Earlier tests have rolled this cell an unknown number of times; tap it
	# round to a sun so the two-thirds roll is what reset has to do.
	var guard := 0
	while p._grid[free.y][free.x] != 0 and guard < 3:
		_tap(p, free.y, free.x)
		p._settle(free.y, free.x)
		guard += 1
	t.eq(p._grid[free.y][free.x], 0, "setup: a sun is placed")
	var turns_before: int = p._turns[free.y][free.x]
	var given := _find_cell(p, true)
	p.reset_board()
	t.eq(p._grid[free.y][free.x], -1, "reset clears the grid at once")
	t.eq(p.moves, 0, "reset zeroes the move count")
	t.check(p.focus_cell == Vector2i(-1, -1), "reset drops the focus")
	t.check(Motion.running(p._rolls[free.y][free.x]), "the placed cell rolls home")
	t.check(Motion.running(p._bobs[given.y][given.x]), "a given hops to say it stays")
	t.eq(p._turns[free.y][free.x], turns_before + 2, "a sun rolls two more thirds forward to reach empty, never back")
	t.eq(p._turns[free.y][free.x] % 3, 0, "and lands on the empty face")
	for r in p.n:
		for c in p.n:
			for tw in [p._rolls[r][c], p._hops[r][c], p._bobs[r][c]]:
				if Motion.running(tw):
					tw.custom_step(5.0)
	var all_home := true
	var none_running := true
	for r in p.n:
		for c in p.n:
			var pivot: Node3D = p._cells[r][c]
			var state: int = p._grid[r][c]
			var want := -float(state + 1 if state >= 0 else 0) * THIRD
			if not is_equal_approx(wrapf(pivot.rotation.x - want, -PI, PI), 0.0):
				all_home = false
			if not is_equal_approx(pivot.position.y, p._rest_y):
				all_home = false
			for tw in [p._rolls[r][c], p._hops[r][c], p._bobs[r][c]]:
				if Motion.running(tw):
					none_running = false
	t.check(all_home, "after the wave every prism shows its grid face and rests on its axis")
	t.check(none_running, "the wave leaves nothing running")
	if Motion.running(p._ring_tw):
		p._ring_tw.custom_step(5.0)
	t.check(not p._ring.visible, "reset hides the ring")

## On a solve every prism hops once, row by row from the far edge, after the
## last roll has had time to land.
static func _test_solved_wave(t, p) -> void:
	for r in p.n:
		for c in p.n:
			p._grid[r][c] = p._solution[r][c]
	p.note_move()
	t.check(p.is_done(), "setup: the board is solved")
	t.check(Motion.running(p._bobs[0][0]) and Motion.running(p._bobs[p.n - 1][p.n - 1]), "every prism has a solve hop scheduled")
	p._bobs[0][0].custom_step(p.ROLL_TIME + p.SOLVE_TIME * 0.5)
	p._bobs[p.n - 1][0].custom_step(p.ROLL_TIME + p.SOLVE_TIME * 0.5)
	t.check(p._cells[0][0].position.y > p._rest_y + 0.05, "the far row is up first (%.3f)" % (p._cells[0][0].position.y - p._rest_y))
	t.check(p._cells[p.n - 1][0].position.y < p._cells[0][0].position.y, "the near row lags behind")
	for r in p.n:
		for c in p.n:
			if Motion.running(p._bobs[r][c]):
				p._bobs[r][c].custom_step(5.0)
	var rested := true
	for r in p.n:
		for c in p.n:
			if not is_equal_approx(p._cells[r][c].position.y, p._rest_y):
				rested = false
	t.check(rested, "after the wave every prism rests on its axis")
	t.eq(p.fx.last_cue, "solved", "the solve fires its cue")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: `FAIL [binairo3d]` lines or `could not load suite`; `failed=` greater than 0.

- [ ] **Step 3: Write the implementation**

In `puzzles/binairo3d.gd`:

After `const FOCUS_LIFT := 0.005` add:

```gdscript
## Entrance, reset wave and solved wave (polish spec, section 2).
const ENTER_DROP := 0.5
const ENTER_PLATFORM := 0.5
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.03
const RESET_STAGGER := 0.02
const RESET_HOP := 0.03
const SOLVE_HOP := 0.08
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.04
```

After `var focus_cell := Vector2i(-1, -1)` add:

```gdscript
var _entrance: Array = []  # tweens of the board entrance, killed by reset
```

Add after the `FACE` constant block, before `var n`:

```gdscript
func _ready() -> void:
	super()
	solved.connect(_on_solved)
```

In `build()`, after `_refit()` add `_enter()`.

Replace `reset_board` with:

```gdscript
## Reset as a wave: every filled free cell rolls forward to empty (a sun takes
## two thirds, a moon one) with a stagger from the near-left corner, and the
## givens hop a little to say they stay. The grid, the count and the blush
## change at once; only the prisms take their time.
func reset_board() -> void:
	_stop_entrance()
	_focus_clear()
	for r in n:
		for c in n:
			_settle(r, c)
			var delay := Motion.stagger((n - 1 - r) + c, RESET_STAGGER)
			if _given[r][c]:
				_bobs[r][c] = Motion.hop(_cells[r][c], RESET_HOP, BOB_TIME, delay, _rest_y)
				continue
			var v: int = _grid[r][c]
			if v == -1:
				continue
			_grid[r][c] = -1
			var thirds := 2 if v == 0 else 1
			_turns[r][c] += thirds
			_roll(r, c, thirds, delay)
	moves = 0
	_recolour()
	fx.cue("reset")
```

Add after `_focus_clear()`:

```gdscript
# --- entrance and solve ---

## The board arrives: the platform rises from below and rings the water, then
## the prisms pop in along a diagonal wave from the far-left corner. Taps are
## accepted throughout; scale, rotation and height are separate properties.
func _enter() -> void:
	_stop_entrance()
	var platform: Node3D = board.get_node("Platform")
	platform.position.y = -ENTER_DROP
	var rise: Tween = Motion.settle(platform, "position:y", 0.0, ENTER_PLATFORM)
	if rise != null:
		_entrance.append(rise)
		var splash := board.create_tween()
		splash.tween_interval(ENTER_PLATFORM * 0.9)
		splash.tween_callback(_splash)
		_entrance.append(splash)
	for r in n:
		for c in n:
			var pivot: Node3D = _cells[r][c]
			pivot.scale = Vector3.ONE * 0.01
			var pop: Tween = Motion.settle(pivot, "scale", Vector3.ONE, ENTER_POP, ENTER_PLATFORM + Motion.stagger(r + c, ENTER_STAGGER))
			if pop != null:
				_entrance.append(pop)
	fx.cue("enter")

## Cuts the entrance short: everything lands where it was going.
func _stop_entrance() -> void:
	for tw in _entrance:
		Motion.stop(tw)
	_entrance = []
	if _cells.is_empty():
		return
	var platform: Node3D = board.get_node_or_null("Platform")
	if platform != null:
		platform.position.y = 0.0
	for r in n:
		for c in n:
			_cells[r][c].scale = Vector3.ONE

## Rings the water under the board, when there is a stage to ask.
func _splash() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.has_method("splash"):
		_stage.splash(board.global_position)

## Every prism hops once, row by row from the far edge, once the last roll
## has landed. The celebration in sub-project 3 builds on this.
func _on_solved() -> void:
	_focus_clear()
	for r in n:
		for c in n:
			Motion.stop(_bobs[r][c])
			_bobs[r][c] = Motion.hop(_cells[r][c], SOLVE_HOP, SOLVE_TIME, ROLL_TIME + Motion.stagger(r, SOLVE_STAGGER), _rest_y)
	fx.cue("solved")
```

In `tests/_shot.gd`, change `const SLOT := 40` to `const SLOT := 120`, `elif local == 30:` to `elif local == 100:` and `elif local == 36:` to `elif local == 110:`, and add to the class doc comment: `## The slot is long enough for a board's entrance to finish before the shot.`

- [ ] **Step 4: Run the tests and both harnesses**

Run: `godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="`

Expected: no `FAIL`, `failed=0`.

Run: `godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | grep -E "winnable|FAIL"`

Expected: `winnable=10/10`. The harness taps during the entrance; that is by design.

Run: `godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | grep -E "saved /tmp/shot_binairo"` and open `/tmp/shot_binairo.png`.

Expected: the board fully in, every prism at full size, platform level with the rim.

- [ ] **Step 5: Commit**

```bash
git add puzzles/binairo3d.gd tests/test_binairo3d.gd tests/_shot.gd
git commit -m "feat: board entrance wave with a water splash, reset as a rolling wave, solved hop wave"
```

---

### Task 11: Animation strip harness, budget, docs, spec amendments

**Files:**
- Create: `tests/_shot_anim.gd`
- Modify: `README.md` (Tests section), `docs/superpowers/specs/2026-09-13-binairo-polish-design.md`

**Interfaces:**
- Consumes: everything above.
- Produces: `/tmp/anim_binairo_0.png` to `_5.png` and one line `idle frames=<n> mean_ms=<x> max_draw_calls=<d>`.

- [ ] **Step 1: Write the harness**

Create `tests/_shot_anim.gd`:

```gdscript
extends SceneTree

## Animation strip for Binairo: frames across the entrance, a tap, the roll
## and two seconds of idle, plus the draw-call count and mean frame time over
## the idle window. Vsync is off so the delta is the real cost of a frame.
## Judge the ambience by eye and the budget by the numbers
## (polish spec, section 7: idle mean under 8 ms at 1080 x 1920 on the Mac).
##
##     godot --path . --resolution 1080x1920 --script res://tests/_shot_anim.gd
##
## Saves /tmp/anim_binairo_<n>.png for n = 0..5.

const SHOTS := [0.35, 0.9, 1.65, 1.8, 2.8, 3.8]  # seconds after opening
const TAP_AT := 1.6
const IDLE_FROM := 2.2
const IDLE_TO := 4.2

var _menu: Node
var _host: Node
var _puzzle: Node
var _t := -0.2   # the first frames carry the load; the board opens at 0
var _opened := false
var _tapped := false
var _shot := 0
var _idle: Array[float] = []
var _draws := 0

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if not _opened:
		if _t >= 0.0:
			_opened = true
			_t = 0.0
			_menu._open(load("res://ui/registry.gd").PUZZLES[0])
			_host = _menu.get_child(_menu.get_child_count() - 1)
			_puzzle = _host._puzzle
		return false
	if not _tapped and _t >= TAP_AT:
		_tapped = true
		_tap_first_free()
	if _t >= IDLE_FROM and _t <= IDLE_TO:
		_idle.append(delta * 1000.0)
		_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _shot < SHOTS.size() and _t >= SHOTS[_shot]:
		var path := "/tmp/anim_binairo_%d.png" % _shot
		root.get_texture().get_image().save_png(path)
		print("saved %s at t=%.2f" % [path, _t])
		_shot += 1
	if _t > IDLE_TO:
		var mean := 0.0
		for ms in _idle:
			mean += ms
		mean /= maxf(_idle.size(), 1.0)
		print("idle frames=%d mean_ms=%.2f max_draw_calls=%d" % [_idle.size(), mean, _draws])
		return true
	return false

## One real touch on the first free cell, through the viewport like a thumb.
func _tap_first_free() -> void:
	for r in _puzzle.n:
		for c in _puzzle.n:
			if _puzzle._given[r][c]:
				continue
			var at: Vector2 = _puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(r, c)
			for pressed in [true, false]:
				var ev := InputEventScreenTouch.new()
				ev.index = 0
				ev.pressed = pressed
				ev.position = at
				root.push_input(ev, true)
			return
```

- [ ] **Step 2: Run it and look**

Run: `godot --path . --resolution 1080x1920 --script res://tests/_shot_anim.gd 2>&1 | grep -E "saved|idle frames|SHADER|ERROR"`

Expected: six `saved` lines and the `idle frames=` line. Open the six images (`open /tmp/anim_binairo_*.png`, or read them one by one) and confirm:

- `_0`: platform still rising or just landed, prisms tiny or popping along the far-left diagonal; a ring on the water under the board.
- `_1`: near-right prisms mid-pop, the rest at full size.
- `_2`: the tapped prism mid-roll, lifted, both faces showing; the sky-blue focus ring at the cell; side neighbours slightly dipped.
- `_3`: the prism landed on its sun face with a puff of dust at the near edge.
- `_4` and `_5`: idle a second apart. Grass tufts and flowers on the rim differ slightly in lean between the two; the water stripes and sparkles have moved; the pollen specks are in different places; the focus ring is fading or gone (it fades 2.5 s after the tap, at t = 4.1).

Budget: `mean_ms` must be at or under 8.0 and `max_draw_calls` at most 10 above the count printed by the same harness run on the commit of Task 7 (`git stash` is not needed; run `git checkout <task-7-sha> -- .` in a scratch worktree if a baseline is wanted, or simply record the number). If `mean_ms` is over 8.0, halve `Ambient.POLLEN_AMOUNT` first, then `Fx.PUFF_POOL` to 2, and re-measure; record what was changed in the commit message.

- [ ] **Step 3: Camera breath decision**

Run the game for twenty seconds and watch the board at rest:

```bash
godot --path . --resolution 540x960
```

(Open Binairo from the menu, then close the window.) The drift is 0.2 percent of the camera distance. If it reads as the picture being slightly alive, keep it. If it reads as wobble or makes the HUD text swim against the board, set `var breathing := false` in `world/camera_rig.gd` and note the result in the spec's camera-breath paragraph.

- [ ] **Step 4: Docs and spec amendments**

In `README.md`, in the Tests section after the screenshot command, add:

```bash
# Animation strip for Binairo (entrance, tap, roll, idle) plus draw calls and frame time
godot --path . --resolution 1080x1920 --script res://tests/_shot_anim.gd
```

In `docs/superpowers/specs/2026-09-13-binairo-polish-design.md`, apply these amendments (they record what implementation taught):

1. Section 1, the `fade` signature gains a leading `node: Node` parameter (the tween needs a node to live on): `static func fade(node: Node, setter: Callable, from: float, to: float, time: float, steps := 16, delay := 0.0) -> Tween`. `hop` gains a trailing `base := NAN` (the resting height, for nodes that may already be mid-hop).
2. Section 2, Blush pulse row: `BAD_BLEND` is `0.375` (6/16) and the heartbeat adds `0.125` (2/16), so every level sits on the 16-step grid. Mention that `_blend_target` per cell keeps a still-broken line's beats from being restarted by an unrelated recolour.
3. Section 4, Water: replace "unshaded" with "lit with the same two-band step as the toon shader, so the platform's shadow still falls on it".
4. Section 4, Camera breath: record the decision from Step 3.
5. Section 8: add `tests/test_ambient.gd` (Ambient and camera breath) and `tests/test_fx.gd` (the pools) to the headless suites, and section 9's "New" list likewise.
6. Section 7: record the measured `mean_ms` and `max_draw_calls` from Step 2 with the date.

- [ ] **Step 5: Full verification**

Run all three, in order:

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | grep -E "FAIL|passed="
godot --path . --resolution 540x960 --script res://tests/_win.gd 2>&1 | grep -E "winnable|FAIL"
godot --path . --resolution 540x960 --script res://tests/_shot.gd 2>&1 | grep -ciE "shader error"
```

Expected: `failed=0`; `winnable=10/10`; `0`.

- [ ] **Step 6: Commit**

```bash
git add tests/_shot_anim.gd README.md docs/superpowers/specs/2026-09-13-binairo-polish-design.md world/camera_rig.gd
git commit -m "test: animation strip harness with frame-time and draw-call budget; spec records the measurements"
```

(Include `world/camera_rig.gd` only if Step 3 changed it.)

---

## Plan self-review

Spec coverage, section by section of "Sub-project 1":

| Spec item | Task |
|---|---|
| 1 Motion foundation: recipes, reduce, persistence | 1 |
| 2 Roll settle, neighbour bob, dust puff | 8 |
| 2 Focus glow (incl. given-cell tap), blush pulse | 9 |
| 2 Board entrance, reset wave, solved wave | 10 |
| 2 Sparkle and wobble primitives | 7 (sparkle), 1 (wobble) |
| 3 Fx pools and `cue()` | 7 |
| 4 `motion_scale` global, `Ambient.refresh()` | 3 (declaration), 5 |
| 4 Grass sway shader and `_sway` convention | 3, 4 |
| 4 Water shader with splash | 5 |
| 4 Pollen, `fit_to` | 5 |
| 4 Camera breath (try-and-keep) | 6, 11 |
| 5 Palette additions | 2 |
| 6 `focus_ring` slot, water dressing, contract rule 11, README, `project.godot` | 2, 3, 4, 5 |
| 7 Performance budget | 11 |
| 8 Tests: motion, binairo3d, toon, models, platform, `_shot_anim`, `_win`, `_shot` | 1, 8-10, 3-5, 2-5, 4, 11, 8-10, 10 |
| 10 What sub-project 2 relies on | `Motion` (1), `Fx.sparkle/cue` (7), `Motion.wobble` (1), `focus_cell` (9), `Ambient.refresh()` (5) |

Deviations from the spec, all recorded as amendments in Task 11: `fade` takes a node, `hop` takes a base, `BAD_BLEND` is 0.375, the water is lit not unshaded, two extra test files.
