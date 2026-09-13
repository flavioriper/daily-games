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
