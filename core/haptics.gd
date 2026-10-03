extends RefCounted

## The phone's buzz: a small vocabulary of pulses every screen shares, the
## settings sheet's third switch. A board never names milliseconds: it maps
## its cue names to a kind (`Fx2D.haptics`) or calls `play(kind)` itself, so
## a tap feels the same on every board and a lost heart never feels like a
## win. Saved beside Motion's `reduce` and Sound's `on` in the same file.
##
## Only one pulse is ever in the motor. A kind asked for while another is
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

## Each kind's pulses: [starts at ms, lasts ms, strength 0-1]. Nothing under
## 12 ms: a cheap Android motor does not spin up in less.
const PATTERNS := {
	TICK: [[0, 12, 0.3]],
	TAP: [[0, 16, 0.5]],
	BUMP: [[0, 26, 0.75]],
	GOOD: [[0, 14, 0.45], [90, 24, 0.8]],
	WARN: [[0, 20, 0.6], [90, 20, 0.6]],
	THUD: [[0, 45, 1.0]],
	BAD: [[0, 32, 0.95], [120, 32, 0.95]],
	LOSE: [[0, 70, 1.0], [150, 45, 0.7], [290, 45, 0.45]],
	WIN: [[0, 22, 0.6], [110, 22, 0.8], [220, 48, 1.0]],
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
	var steps: Array = PATTERNS[kind]
	var end: Array = steps[steps.size() - 1]
	_kind = kind
	_until = now + int(end[0]) + int(end[1])
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
			Input.vibrate_handheld(int(step[1]), float(step[2]))
		else:
			# A later knock of the pattern, dropped if a stronger kind took
			# the motor meanwhile or the switch went off.
			tree.create_timer(int(step[0]) / 1000.0, true, false, true).timeout.connect(func() -> void:
				if token == _token and on:
					Input.vibrate_handheld(int(step[1]), float(step[2])))
	return true
