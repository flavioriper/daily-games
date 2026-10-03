extends RefCounted

## The phone's knock: a small vocabulary every screen shares, the settings
## sheet's third switch. A board never names milliseconds: it maps its cue
## names to a kind (`Fx2D.haptics`) or calls `play(kind)` itself, so a tile
## set feels the same on every board and a lost heart never feels like a
## win. Saved beside Motion's `reduce` and Sound's `on` in the same file.
##
## **On Android these are the system's own effects, not timed pulses**
## (2026-10-03, the user's word after the first build: "too much", against a
## game whose buzz is "a subtle hit inside the phone"). `Input.
## vibrate_handheld` is `VibrationEffect.createOneShot`, a motor spun for N
## ms that rings on 20-50 ms after: the buzzy kind Android's guidance says to
## avoid. `createPredefined(EFFECT_TICK / CLICK / HEAVY_CLICK)` is a waveform
## the phone's maker tuned and brakes: one crisp knock. They are reached
## through the AndroidRuntime singleton and JavaClassWrapper, no plugin.
## Where the phone composes primitives (Android 11 and up, most Pixels) a
## kind is built from them, each at its own strength, so the kinds differ in
## weight as well as shape. The timed pulses stay only as the fallback
## (Android under 10, iOS).
##
## **What is heard is felt** (2026-10-03, the user's word: a board whose
## pebbles sound under the finger and knock only as they merge "feels
## incomplete"). A cue the board gave no kind still knocks as its sound
## plays: an ECHO, the weakest kind, so it never covers a knock the board
## chose (`Fx2D.cue`).
##
## Only one knock is ever in the motor. A kind asked for while another is
## still playing lands only if it outranks it (a lost heart over the tap that
## cost it, never a tick over a win), so several cues on one frame come out
## as the strongest of them and a per-cell cue cannot rattle.
## Off the phone nothing buzzes, but `last`, `count` and `trace` still say
## what would have, which is how a harness checks a board.
## Rules and the per-board list: docs/agents/haptics.md.

const Motion = preload("res://core/motion.gd")

## The kinds, weakest first: the order is the rank.
enum {
	ECHO,   ## a sound nothing else answers: what is heard is felt, faintly
	TICK,   ## a selection moved: a clear, an undo, a button
	TAP,    ## a piece set down
	BUMP,   ## something finished or locked: a line, a milestone, a reveal
	GOOD,   ## a small yes: a hint, a clean check, a heart back (rising pair)
	WARN,   ## not yet: a rule broken, a check that found something (even pair)
	THUD,   ## one heavy landing: a stamp, a slam
	BAD,    ## a mistake that cost something: a heart lost (a hard knock, twice)
	LOSE,   ## the day is lost: two heavy knocks, falling
	WIN,    ## solved: three rising knocks
}

const NAMES := ["echo", "tick", "tap", "bump", "good", "warn", "thud", "bad", "lose", "win"]

## android.os.VibrationEffect's predefined effects (API 29), by value: a
## constant read through JavaClassWrapper is one more thing to go wrong.
const FX_CLICK := 0
const FX_DOUBLE := 1
const FX_TICK := 2
const FX_HEAVY := 5

## VibrationEffect.Composition's primitives (API 30), by value. Only these
## three are asked for: a phone that has any has them.
const PR_CLICK := 1
const PR_THUD := 2
const PR_TICK := 7

## Each kind where the phone composes primitives: [ms after the one before,
## primitive, strength 0-1]. This is where the kinds differ most: a
## primitive takes a strength, so an echo is a third of a tap, and a yes, a
## no and a loss each have a shape of their own. `play`'s gain scales it.
const COMPOSED := {
	ECHO: [[0, PR_TICK, 0.35]],
	TICK: [[0, PR_TICK, 0.6]],
	TAP: [[0, PR_TICK, 1.0]],
	BUMP: [[0, PR_CLICK, 0.7]],
	GOOD: [[0, PR_TICK, 0.7], [60, PR_CLICK, 0.8]],
	WARN: [[0, PR_CLICK, 0.5], [80, PR_CLICK, 0.5]],
	THUD: [[0, PR_THUD, 1.0]],
	BAD: [[0, PR_CLICK, 1.0], [70, PR_THUD, 0.8]],
	LOSE: [[0, PR_THUD, 1.0], [140, PR_THUD, 0.6]],
	WIN: [[0, PR_TICK, 0.8], [80, PR_CLICK, 0.8], [80, PR_CLICK, 1.0]],
}
## How long a primitive is taken to hold the motor, for the rank.
const PRIMITIVE_MS := 40

## Each kind on the predefined effects (a phone with no primitives):
## [starts at ms, effect]. Three strengths and the double click are all
## there is, so the shape says what the strength cannot.
const EFFECTS := {
	ECHO: [[0, FX_TICK]],
	TICK: [[0, FX_TICK]],
	TAP: [[0, FX_CLICK]],
	BUMP: [[0, FX_CLICK]],
	GOOD: [[0, FX_TICK], [70, FX_CLICK]],
	WARN: [[0, FX_DOUBLE]],
	THUD: [[0, FX_HEAVY]],
	BAD: [[0, FX_HEAVY]],
	LOSE: [[0, FX_HEAVY], [150, FX_HEAVY]],
	WIN: [[0, FX_CLICK], [110, FX_CLICK], [220, FX_HEAVY]],
}
## How long a predefined effect is taken to hold the motor, for the rank.
const EFFECT_MS := 40

## The fallback where there are no predefined effects: [starts at ms, lasts
## ms, strength 0-1]. Short weak pulses, shaped like the effects above.
const PATTERNS := {
	ECHO: [[0, 8, 0.1]],
	TICK: [[0, 10, 0.15]],
	TAP: [[0, 10, 0.25]],
	BUMP: [[0, 14, 0.3]],
	GOOD: [[0, 10, 0.2], [70, 14, 0.3]],
	WARN: [[0, 12, 0.3], [90, 12, 0.3]],
	THUD: [[0, 18, 0.45]],
	BAD: [[0, 18, 0.5]],
	LOSE: [[0, 20, 0.5], [150, 20, 0.4]],
	WIN: [[0, 12, 0.3], [110, 12, 0.3], [220, 18, 0.45]],
}

static var on := true
## The last kind that landed and how many have, for harnesses.
static var last := -1
static var count := 0
## Set to an Array and every kind that lands is appended by name.
static var trace: Variant = null
static var _kind := -1
static var _until := 0
static var _token := 0
## Android's vibrator and the effects made so far (effect id -> JavaObject);
## `_native` is -1 until asked, then the tier (`_tier`).
static var _native := -1
static var _vibrator: Variant = null
static var _effects := {}
static var _composed := {}

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	on = true
	if cfg.load(Motion.settings_path) == OK:
		on = bool(cfg.get_value("haptics", "on", true))

static func set_on(value: bool) -> void:
	on = value
	var cfg := ConfigFile.new()
	cfg.load(Motion.settings_path)  # keeps other sections; a missing file is fine
	cfg.set_value("haptics", "on", on)
	cfg.save(Motion.settings_path)
	if on:
		play(TAP)
	else:
		_token += 1
		_until = 0

static func kind_name(kind: int) -> String:
	return NAMES[kind] if kind >= 0 and kind < NAMES.size() else ""

## Plays `kind` unless the switch is off or a pulse that ranks at least as
## high is still in the motor. True when it landed. `gain` scales the
## strength where the phone can (a quiet sound's echo is fainter still).
static func play(kind: int, gain := 1.0) -> bool:
	if not on or not PATTERNS.has(kind):
		return false
	var now := Time.get_ticks_msec()
	if now < _until and kind <= _kind:
		return false
	var tier := _tier()
	var steps: Array = COMPOSED[kind] if tier == 2 else (EFFECTS[kind] if tier == 1 else PATTERNS[kind])
	var length := 0
	if tier == 2:
		for step: Array in steps:
			length += int(step[0]) + PRIMITIVE_MS
	else:
		var end: Array = steps[steps.size() - 1]
		length = int(end[0]) + (EFFECT_MS if tier == 1 else int(end[1]))
	_kind = kind
	_until = now + length
	_token += 1
	last = kind
	count += 1
	if trace is Array:
		trace.append(NAMES[kind])
	if not OS.has_feature("mobile"):
		return true
	if tier == 2:
		_compose(kind, steps, gain)
		return true
	var token := _token
	var tree := Engine.get_main_loop() as SceneTree
	for step: Array in steps:
		if int(step[0]) == 0 or tree == null:
			_fire(step, tier, gain)
		else:
			# A later knock of the pattern, dropped if a stronger kind took
			# the motor meanwhile or the switch went off.
			tree.create_timer(int(step[0]) / 1000.0, true, false, true).timeout.connect(func() -> void:
				if token == _token and on:
					_fire(step, tier, gain))
	return true

static func _fire(step: Array, tier: int, gain: float) -> void:
	if tier == 1:
		var id := int(step[1])
		if not _effects.has(id):
			_effects[id] = JavaClassWrapper.wrap("android.os.VibrationEffect").createPredefined(id)
		if _effects[id] != null:
			_vibrator.vibrate(_effects[id])
	else:
		Input.vibrate_handheld(int(step[1]), clampf(float(step[2]) * gain, 0.05, 1.0))

## One composition a kind and a gain (in tenths), kept once made. A new
## effect handed to the vibrator cancels the one before, so a stronger kind
## cuts a weaker pattern short by itself.
static func _compose(kind: int, steps: Array, gain: float) -> void:
	var tenths := clampi(roundi(gain * 10.0), 3, 20)
	var key := kind * 100 + tenths
	if not _composed.has(key):
		var c: Variant = JavaClassWrapper.wrap("android.os.VibrationEffect").startComposition()
		for step: Array in steps:
			c.addPrimitive(int(step[1]), clampf(float(step[2]) * tenths / 10.0, 0.05, 1.0), int(step[0]))
		_composed[key] = c.compose()
	if _composed[key] != null:
		_vibrator.vibrate(_composed[key])

## What the phone's motor can do, asked once: 2 where it composes primitives
## (Android 11 and up, and the maker tuned them), 1 where it has the
## predefined effects (Android 10 and up), 0 for the timed fallback.
static func _tier() -> int:
	if _native < 0:
		_native = 0
		if OS.get_name() == "Android" and Engine.has_singleton("AndroidRuntime"):
			var runtime := Engine.get_singleton("AndroidRuntime")
			# The release ("14", "8.1.0"): createPredefined came with 10.
			var release := int(OS.get_version().split(".")[0])
			if release >= 10:
				_vibrator = runtime.getApplicationContext().getSystemService("vibrator")
				if _vibrator != null and _vibrator.hasVibrator():
					_native = 1
					if release >= 11:
						var all: Variant = _vibrator.areAllPrimitivesSupported(PackedInt32Array([PR_CLICK, PR_THUD, PR_TICK]))
						if all is bool and all:
							_native = 2
	return _native
