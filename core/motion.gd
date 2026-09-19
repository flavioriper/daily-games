extends RefCounted

## Tween recipes every board and widget uses, so motion has one voice and one
## switch. Each recipe builds its tween on the target node and returns it, or
## null when reduce-motion skipped it, so callers can chain `finished` and
## headless tests can drive it with custom_step (see tests/test_motion.gd).
## Spec: docs/superpowers/specs/2026-09-13-binairo-polish-design.md, section 1.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, section 5.

## Essential motion under reduce-motion: this long, linear, no overshoot.
const REDUCED_TIME := 0.15

## When true, decorative recipes set their final state at once and return
## null; essential ones (the roll) shorten to REDUCED_TIME. Persisted in
## settings_path under [motion] reduce; the settings sheet toggles it.
static var reduce: bool = false
static var settings_path: String = "user://settings.cfg"

## Loads `reduce` from settings_path, section [motion], key reduce. A missing
## or unreadable file is treated as reduce = false.
static func load_settings() -> void:
	var cfg := ConfigFile.new()
	reduce = false
	if cfg.load(settings_path) == OK:
		reduce = bool(cfg.get_value("motion", "reduce", false))

## Saves `reduce` to settings_path, section [motion], key reduce. Keeps any
## other sections already in the file.
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
## so pass it explicitly for a node that may already be mid-hop. Works on a
## Node3D or a Control (both have a `position` with a y).
static func hop(node: Node, height: float, time: float, delay := 0.0, base := NAN) -> Tween:
	if reduce:
		return null
	if is_nan(base):
		base = node.get("position").y
	var tw := node.create_tween()
	tw.tween_property(node, "position:y", base + height, time * 0.5).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position:y", base, time * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tw

## Rolls a cube through a sequence of quarter turns without letting it cut
## into the floor it stands on. `turns` is one [from: Basis, axis: Vector3,
## angle: float] per quarter turn, played in order, so a two-face roll tumbles
## twice instead of sliding. Between turns the cube sits flat on the face it
## just landed on: its centre rides `half * sqrt(2) * cos(45 degrees - turned)`
## above `base`, which comes to exactly `half` at the start and end of every
## turn, so the cube pivots on the bottom edge it rolls over. The roll is the
## state change itself, so it is essential: under reduce-motion it still
## turns, shortened and linear.
static func roll(node: Node3D, turns: Array, half: float, base: float, time: float, delay := 0.0) -> Tween:
	var count := turns.size()
	var radius := half * sqrt(2.0)
	var play := func(t: float) -> void:
		var i := clampi(int(floorf(t)), 0, count - 1)
		var turn: Array = turns[i]
		var angle: float = turn[2] * (t - i)
		node.basis = Basis(turn[1], angle) * (turn[0] as Basis)
		# The back ease overshoots the last turn; clamping the lift at a
		# quarter keeps that overshoot from driving the cube into the floor.
		var turned := clampf(absf(angle), 0.0, PI * 0.5)
		node.position.y = base + radius * cos(PI * 0.25 - turned) - half
	var tw := node.create_tween()
	if reduce:
		tw.tween_method(play, 0.0, float(count), REDUCED_TIME).set_delay(delay).set_trans(Tween.TRANS_LINEAR)
	else:
		tw.tween_method(play, 0.0, float(count), time).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw

## Flattens y by `amount` and widens the other axes by half of it, then
## springs back. A Node3D squashes in x and z; a Control in x, around its
## pivot_offset.
static func squash(node: Node, amount := 0.12, time := 0.18, delay := 0.0) -> Tween:
	if reduce:
		return null
	var base = node.get("scale")
	var squashed
	if base is Vector2:
		squashed = Vector2(base.x * (1.0 + amount * 0.5), base.y * (1.0 - amount))
	else:
		squashed = Vector3(base.x * (1.0 + amount * 0.5), base.y * (1.0 - amount), base.z * (1.0 + amount * 0.5))
	var tw := node.create_tween()
	tw.tween_property(node, "scale", squashed, time * 0.4).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, time * 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw

## A uniform scale up and back about the node's pivot: the beat a numeral
## gives when the thing it counts changes. Distinct from squash, which
## flattens one axis against the other -- a number that squashes reads as
## pressed, and this one has not been pressed, it has been recounted.
## Decorative: null under reduce-motion, where the new value simply appears.
static func bump(node: Node, amount := BUMP, time := BUMP_TIME, delay := 0.0) -> Tween:
	if reduce:
		return null
	var base = node.get("scale")
	var tw := node.create_tween()
	tw.tween_property(node, "scale", base * (1.0 + amount), time * 0.4).set_delay(delay) \
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

## The wobble for a Control: the same damped shake, on `rotation` about the
## Control's pivot_offset (callers keep that at the centre). Decorative.
static func wobble2d(node: Control, angle := 0.105, time := 0.45) -> Tween:
	if reduce:
		return null
	var base := node.rotation
	var shake := func(t: float) -> void:
		node.rotation = base + angle * sin(t * 6.0 * PI) * (1.0 - t) * (1.0 - t)
	var tw := node.create_tween()
	tw.tween_method(shake, 0.0, 1.0, time)
	return tw

## A short horizontal shiver on a Control: two swings of `px` that die out and
## end exactly where they began. A tile whose line just broke a rule gives one.
## Decorative.
static func shiver(node: Control, px := 2.0, time := 0.2) -> Tween:
	if reduce:
		return null
	var base := node.position.x
	var swing := func(t: float) -> void:
		node.position.x = base + px * sin(t * 4.0 * PI) * (1.0 - t)
	var tw := node.create_tween()
	tw.tween_method(swing, 0.0, 1.0, time)
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

## Puts `property` at `from` at once, then eases it to `to`: with `overshoot`
## the back ease (it passes `to` a little and springs home), otherwise sine
## in-out. Decorative: under reduce-motion `to` is set and null returned.
static func slide(node: Node, property: String, from, to, time: float, delay := 0.0, overshoot := true) -> Tween:
	if reduce:
		node.set_indexed(property, to)
		return null
	node.set_indexed(property, from)
	var tw := node.create_tween()
	var step := tw.tween_property(node, property, to, time).set_delay(delay)
	if overshoot:
		step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		step.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

## Breathes `property` of `target` (the node itself by default) between `rest`
## and `peak` forever, sine in-out, one cycle per `period`. The caller keeps
## and kills the tween. Under reduce-motion `rest` is set and null returned.
static func pulse(node: Node, property: String, rest, peak, period: float, target: Object = null) -> Tween:
	if target == null:
		target = node
	if reduce:
		target.set_indexed(property, rest)
		return null
	var half := period * 0.5
	var tw := node.create_tween().set_loops()
	tw.tween_property(target, property, peak, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, property, rest, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

## Fades a CanvasItem's modulate alpha from `from` to `to`. Under
## reduce-motion `to` is set and null returned.
static func appear(item: CanvasItem, from: float, to: float, time: float, delay := 0.0) -> Tween:
	if reduce:
		item.modulate.a = to
		return null
	item.modulate.a = from
	var tw := item.create_tween()
	tw.tween_property(item, "modulate:a", to, time).set_delay(delay)
	return tw

## Lifts `node` by `lift` while it shrinks to nothing, then hides it. The
## caller frees the node on `finished` if it wants it gone. Decorative: under
## reduce-motion the node is hidden at once and null returned.
static func vanish(node: Node3D, lift: float, time: float, delay := 0.0) -> Tween:
	if reduce:
		node.visible = false
		return null
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "position:y", node.position.y + lift, time).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector3.ONE * 0.01, time).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: node.visible = false)
	return tw

# --- the flat boards' vocabulary ---
## The timings every flat board shares, lifted from the flat Binairo
## (docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 6) so a
## second board reads as the same hand. docs/art/flat-motion.md is the table
## of moments these serve; a new board calls these recipes and constants
## rather than writing its own tweens, and a number that has to differ for
## a board goes through a parameter, not a copy.
## A square thing (a tile, a lid, a face) pops in from nothing; something
## wide (a row, a card) pops from ENTER_WIDE_FROM, because the back ease's
## overshoot on a thousand units of width is a wobble. A board's pieces wait
## ENTER_DELAY for the chrome to slide in before the first of them pops.
const ENTER_DELAY := 0.18
const PRESS_SCALE := 0.94
const PRESS_TIME := 0.08
const RELEASE_TIME := 0.25
const LIFT_SCALE := 1.1
const LIFT_TIME := 0.12
const POP_IN := 0.22
const POP_SQUASH := 0.15
const POP_OUT := 0.12
const ENTER_POP := 0.25
const ENTER_STAGGER := 0.03
const ENTER_WIDE_FROM := 0.86
const ENTER_FACE_LAG := 0.12
const HOP := -6.0
const HOP_TIME := 0.3
const NUDGE := 3.0
const NUDGE_TIME := 0.3
const NUDGE_LAG := 0.04
const DROP := 40.0
const DROP_TIME := 0.3
const DROP_FADE := 0.1
const RING_TIME := 0.5
const FLASH_IN := 0.15
const FLASH_OUT := 0.45
const BUMP := 0.25
const BUMP_TIME := 0.24
const RESET_STAGGER := 0.02
const RESET_HOP := -4.0
const SOLVE_HOP := -10.0
const SOLVE_TIME := 0.4
const SOLVE_STAGGER := 0.04
const SOLVE_DELAY := 0.25
const CHIP_LIFT := 8.0
const CHIP_LIFT_TIME := 0.18
const CHIP_LIT := 0.35

## The press: `node` sinks to PRESS_SCALE of `base` under the finger and
## springs back to `base` with the back ease on release. The caller keeps
## the tween and stops it before the next press. Decorative: under
## reduce-motion the node sits at `base` and null is returned.
static func press(node: Control, down: bool, base := Vector2.ONE) -> Tween:
	if reduce:
		node.scale = base
		return null
	var tw := node.create_tween()
	if down:
		tw.tween_property(node, "scale", base * PRESS_SCALE, PRESS_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(node, "scale", base, RELEASE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw

## The pick-up: the press for a thing that is dragged rather than tapped.
## `node` grows to LIFT_SCALE of `base`, toward the finger, over LIFT_TIME,
## and springs back to `base` with the back ease when it is let go; a board
## with a ground parts the shadow from it meanwhile (Untangle reads the
## scale back for that). Pass the base a squashed thing rests at, so the
## lift rides on it. The caller keeps the tween and stops it before the
## next. Decorative: under reduce-motion the node sits at `base` and null
## is returned.
static func lift(node: Control, up: bool, base := Vector2.ONE) -> Tween:
	if reduce:
		node.scale = base
		return null
	var tw := node.create_tween()
	if up:
		tw.tween_property(node, "scale", base * LIFT_SCALE, LIFT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(node, "scale", base, RELEASE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw

## Pops `node` in from nothing about its pivot: to a squash wider than tall
## by POP_SQUASH over the first three fifths, then to `to` with the back
## ease. The way a face lands on a tile. Under reduce-motion `to` is set and
## null returned.
static func pop_in(node: Control, time := POP_IN, delay := 0.0, to := Vector2.ONE) -> Tween:
	if reduce:
		node.scale = to
		return null
	node.scale = Vector2.ZERO
	var tw := node.create_tween()
	tw.tween_property(node, "scale", to * Vector2(1.0 + POP_SQUASH, 1.0 - POP_SQUASH), time * 0.6).set_delay(delay) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", to, time * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw

## Shrinks `node` to nothing with a quarter turn over `time`, rising `lift`
## pixels on the way if asked. The caller frees the node on `finished`.
## Under reduce-motion it is hidden at once and null returned, so the caller
## frees it itself.
static func pop_out(node: Control, time := POP_OUT, delay := 0.0, lift := 0.0) -> Tween:
	if reduce:
		node.visible = false
		return null
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ZERO, time).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "rotation", node.rotation + PI * 0.5, time).set_delay(delay)
	if lift != 0.0:
		tw.tween_property(node, "position:y", node.position.y - lift, time).set_delay(delay) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tw

## Drops `node` in from `height` above where it stands with the back ease
## while it fades in over a tenth: a hint's arrival. Call it with the node
## already at its rest. Under reduce-motion it is simply shown.
static func drop_in(node: Control, height := DROP, time := DROP_TIME, delay := 0.0) -> Tween:
	if reduce:
		node.modulate.a = 1.0
		return null
	var rest := node.position.y
	node.position.y = rest - height
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position:y", rest, time).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, DROP_FADE).set_delay(delay)
	return tw

## Leans `node` `px` along `dir` from `rest` and back, sine out then in,
## after `delay`: what the neighbours of a landing do. Puts the node at
## `rest` first, so a nudge never compounds. Decorative.
static func nudge(node: Control, dir: Vector2, rest: Vector2, px := NUDGE, time := NUDGE_TIME, delay := NUDGE_LAG) -> Tween:
	node.position = rest
	if reduce:
		return null
	var tw := node.create_tween()
	tw.tween_property(node, "position", rest + dir * px, time * 0.5).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", rest, time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tw

## Blushes a value and lets it settle: `setter` is driven from `from` to
## `peak` over `time_in` in `steps` levels (the fade's bounded set of
## colours), then eased back to `back` over `time_out`. What a wrong cell on
## Check, an empty seat asked to score and a card that refused a press all
## do, each toward its own colour. Under reduce-motion `back` is set at once
## and null returned.
static func flash(node: Node, setter: Callable, from: float, peak: float, back: float, time_in := FLASH_IN, time_out := FLASH_OUT, steps := 16) -> Tween:
	var tw: Tween = fade(node, setter, from, peak, time_in, steps)
	if tw == null:
		setter.call(back)
		return null
	tw.tween_method(setter, peak, back, time_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

# --- the same recipes, read as curves ---
## A board that draws its pieces into a mesh rather than as nodes (Shikaku's
## beds, Untangle's rings) cannot call a recipe on them
## (docs/art/flat-motion.md, rule 8). These read a recipe's shape `elapsed`
## seconds in, from the same constants, so the drawn thing and the tweened
## one move as one hand and no board copies a number. Before the start each
## returns its start state and after the end its final one, and under
## reduce-motion the final one at once, exactly as the recipe would land.

## The back ease's overshoot, 0 to 1: the curve every pop above ends on.
static func back_out(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	const C := 1.70158
	return 1.0 + (C + 1.0) * pow(u - 1.0, 3.0) + C * pow(u - 1.0, 2.0)

## pop_in's scale: nothing, the squash over the first three fifths, then the
## back ease home to `to`.
static func pop_in_scale(elapsed: float, time := POP_IN, to := Vector2.ONE) -> Vector2:
	if reduce or elapsed >= time:
		return to
	if elapsed <= 0.0:
		return Vector2.ZERO
	var squash := to * Vector2(1.0 + POP_SQUASH, 1.0 - POP_SQUASH)
	var split := time * 0.6
	if elapsed < split:
		return squash * sin(elapsed / split * PI * 0.5)
	return squash.lerp(to, back_out((elapsed - split) / (time - split)))

## The wide thing's pop (rule 7): ENTER_WIDE_FROM to one with the back ease.
static func wide_pop_scale(elapsed: float, time := ENTER_POP) -> float:
	if reduce or elapsed >= time:
		return 1.0
	return lerpf(ENTER_WIDE_FROM, 1.0, back_out(maxf(elapsed, 0.0) / time))

## pop_out's scale: one to nothing, sine in. A wide thing drawn with it
## keeps its turn out, for the same reason it pops from most of the way.
static func pop_out_scale(elapsed: float, time := POP_OUT) -> float:
	if reduce or elapsed >= time:
		return 0.0
	if elapsed <= 0.0:
		return 1.0
	return cos(elapsed / time * PI * 0.5)

## drop_in's height above the rest: `height`, then the back ease home.
static func drop_in_lift(elapsed: float, height := DROP, time := DROP_TIME) -> float:
	if reduce or elapsed >= time:
		return 0.0
	return height * (1.0 - back_out(maxf(elapsed, 0.0) / time))

## The fade a dropping or popping thing arrives with: 0 to 1 over `time`.
static func appear_level(elapsed: float, time := DROP_FADE) -> float:
	if reduce:
		return 1.0
	return clampf(elapsed / time, 0.0, 1.0)

## bump's scale: up by `amount` with the sine over two fifths, home with the
## back ease over the rest. One is the rest.
static func bump_scale(elapsed: float, amount := BUMP, time := BUMP_TIME) -> float:
	if reduce or elapsed <= 0.0 or elapsed >= time:
		return 1.0
	var split := time * 0.4
	if elapsed < split:
		return 1.0 + amount * sin(elapsed / split * PI * 0.5)
	return 1.0 + amount * (1.0 - back_out((elapsed - split) / (time - split)))

## flash's level: 0 to 1 over `time_in`, then sine in-out back to 0 over
## `time_out`. The caller mixes toward its own colour by it.
static func flash_level(elapsed: float, time_in := FLASH_IN, time_out := FLASH_OUT) -> float:
	if reduce or elapsed <= 0.0 or elapsed >= time_in + time_out:
		return 0.0
	if elapsed < time_in:
		return elapsed / time_in
	var u := (elapsed - time_in) / time_out
	return 0.5 + 0.5 * cos(u * PI)

## Kills `tw` if it is still alive. Null-safe.
static func stop(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()

## Returns true if `tw` is valid and running; null-safe.
static func running(tw: Tween) -> bool:
	return tw != null and tw.is_valid() and tw.is_running()
