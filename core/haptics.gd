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
## The timed pulses stay only as the fallback (Android under 10, iOS), one
## short weak pulse a kind.
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
	TICK,   ## a selection moved: focus, a brush armed, a button, an undo
	TAP,    ## a piece set down
	BUMP,   ## something finished or locked: a line, a milestone, a reveal
	GOOD,   ## a small yes: a hint, a clean check, a heart back (rising pair)
	WARN,   ## not yet: a rule broken, a check that found something (even pair)
	THUD,   ## one heavy landing: a stamp, a slam
	BAD,    ## a mistake that cost something: a heart lost (two hard knocks)
	LOSE,   ## the day is lost: a long fall
	WIN,    ## solved: three rising knocks
}

const NAMES := ["tick", "tap", "bump", "good", "warn", "thud", "bad", "lose", "win"]

## android.os.VibrationEffect's predefined effects (API 29), by value: a
## constant read through JavaClassWrapper is one more thing to go wrong.
const FX_CLICK := 0
const FX_TICK := 2
const FX_HEAVY := 5

## Each kind on Android: [starts at ms, effect]. Most are one knock; only the
## win is two. What is frequent is the faintest (a tile set is a tick).
const EFFECTS := {
	TICK: [[0, FX_TICK]],
	TAP: [[0, FX_TICK]],
	BUMP: [[0, FX_CLICK]],
	GOOD: [[0, FX_CLICK]],
	WARN: [[0, FX_CLICK]],
	THUD: [[0, FX_HEAVY]],
	BAD: [[0, FX_HEAVY]],
	LOSE: [[0, FX_HEAVY]],
	WIN: [[0, FX_CLICK], [130, FX_HEAVY]],
}
## How long a predefined effect is taken to hold the motor, for the rank.
const EFFECT_MS := 40

## The fallback where there are no predefined effects: [starts at ms, lasts
## ms, strength 0-1]. One short weak pulse a kind, the win two.
const PATTERNS := {
	TICK: [[0, 10, 0.15]],
	TAP: [[0, 10, 0.2]],
	BUMP: [[0, 14, 0.3]],
	GOOD: [[0, 14, 0.3]],
	WARN: [[0, 14, 0.3]],
	THUD: [[0, 18, 0.45]],
	BAD: [[0, 18, 0.45]],
	LOSE: [[0, 20, 0.5]],
	WIN: [[0, 14, 0.3], [130, 18, 0.45]],
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
## `_native` is -1 until asked, then 0 (the fallback) or 1.
static var _native := -1
static var _vibrator: Variant = null
static var _effects := {}

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
## high is still in the motor. True when it landed.
static func play(kind: int) -> bool:
	if not on or not PATTERNS.has(kind):
		return false
	var now := Time.get_ticks_msec()
	if now < _until and kind <= _kind:
		return false
	var native := _has_native()
	var steps: Array = EFFECTS[kind] if native else PATTERNS[kind]
	var end: Array = steps[steps.size() - 1]
	_kind = kind
	_until = now + int(end[0]) + (EFFECT_MS if native else int(end[1]))
	_token += 1
	last = kind
	count += 1
	if trace is Array:
		trace.append(NAMES[kind])
	if not OS.has_feature("mobile"):
		return true
	var token := _token
	var tree := Engine.get_main_loop() as SceneTree
	for step: Array in steps:
		if int(step[0]) == 0 or tree == null:
			_fire(step, native)
		else:
			# A later knock of the pattern, dropped if a stronger kind took
			# the motor meanwhile or the switch went off.
			tree.create_timer(int(step[0]) / 1000.0, true, false, true).timeout.connect(func() -> void:
				if token == _token and on:
					_fire(step, native))
	return true

static func _fire(step: Array, native: bool) -> void:
	if native:
		var id := int(step[1])
		if not _effects.has(id):
			_effects[id] = JavaClassWrapper.wrap("android.os.VibrationEffect").createPredefined(id)
		if _effects[id] != null:
			_vibrator.vibrate(_effects[id])
	else:
		Input.vibrate_handheld(int(step[1]), float(step[2]))

## Whether the system's predefined effects are there: Android 10 and up with
## a vibrator. Asked once.
static func _has_native() -> bool:
	if _native < 0:
		_native = 0
		if OS.get_name() == "Android" and Engine.has_singleton("AndroidRuntime"):
			var runtime := Engine.get_singleton("AndroidRuntime")
			# The release ("14", "8.1.0"): createPredefined came with 10.
			if int(OS.get_version().split(".")[0]) >= 10:
				_vibrator = runtime.getApplicationContext().getSystemService("vibrator")
				if _vibrator != null and _vibrator.hasVibrator():
					_native = 1
	return _native == 1
