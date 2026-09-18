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

## Kills `tw` if it is still alive. Null-safe.
static func stop(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()

## Returns true if `tw` is valid and running; null-safe.
static func running(tw: Tween) -> bool:
	return tw != null and tw.is_valid() and tw.is_running()
