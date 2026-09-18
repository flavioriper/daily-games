extends "res://ui/hud/panel.gd"

## The flat screen's tip card: the sprout and one line. Idle, it cycles the
## three rules; the moment a tap breaks a line it names the broken rule and
## the sprout worries; on a solve the sprout beams and it says Perfect
## balance. It stands where the How to play card and the working-line card
## stood, and a tap on it opens the rules sheet (the host listens to `open`).
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 7.

signal open

const Face = preload("res://ui/faces/face.gd")
const SproutFace = preload("res://ui/faces/sprout_face.gd")

const HEIGHT := 140.0
const SPROUT := 88.0
const CYCLE := 8.0
const FADE := 0.25
const HOP := -8.0
const HOP_TIME := 0.35
const RULES := [
	"Never three alike in a line",
	"Every line holds as many suns as moons",
	"No two lines are the same",
]
const BROKEN := [
	"No more than two alike side by side!",
	"A line needs as many suns as moons",
	"Two lines cannot be the same",
]

var sprout: Control
var _label: Label
var _idx := 0
var _broken := 0
var _done := false
var _timer: Timer
var _fade: Tween

func _init() -> void:
	enter_from = Vector2(0, 100)

func _build() -> void:
	_inner.add_theme_stylebox_override("panel", CozyTheme.card(Pal.SURFACE, 28, Pal.LINE, 6, 24))
	_inner.custom_minimum_size.y = HEIGHT
	_inner.mouse_filter = Control.MOUSE_FILTER_STOP
	_inner.gui_input.connect(_on_input)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_child(row)
	# The sprout stands in a slot of its own so its hop moves it, not the row.
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SPROUT, SPROUT)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	sprout = SproutFace.new()
	sprout.size = Vector2(SPROUT, SPROUT)
	slot.add_child(sprout)
	sprout.set_idle(true)
	_label = Label.new()
	_label.theme_type_variation = "TipBody"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = RULES[0]
	row.add_child(_label)
	_timer = Timer.new()
	_timer.wait_time = CYCLE
	_timer.timeout.connect(_next_tip)
	add_child(_timer)
	_timer.start()

func _on_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		open.emit()

## Reads what the board says is broken and whether it is done.
func refresh(puzzle) -> void:
	var broken: int = 0
	var done := false
	if puzzle != null:
		if puzzle.has_method("broken_rule"):
			broken = puzzle.broken_rule()
		done = puzzle.is_done()
	if done and not _done:
		_done = true
		_timer.stop()
		_say("Perfect balance!", Face.Expr.JOY)
		return
	if not done and _done:
		_done = false
		_broken = 0
		_say(RULES[_idx], Face.Expr.HAPPY)
		_timer.start()
		return
	if done:
		return
	if broken != _broken:
		_broken = broken
		if broken > 0:
			_timer.stop()
			_say(BROKEN[broken - 1], Face.Expr.WORRIED)
		else:
			_say(RULES[_idx], Face.Expr.HAPPY)
			_timer.start()

func _next_tip() -> void:
	if _broken > 0 or _done:
		return
	_idx = (_idx + 1) % RULES.size()
	_say(RULES[_idx], Face.Expr.HAPPY)

## Swaps the line with a fade and gives the sprout its new face and a hop.
func _say(text: String, expr: int) -> void:
	Motion.stop(_fade)
	_label.text = text
	_fade = Motion.appear(_label, 0.0, 1.0, FADE)
	sprout.expression = expr
	Motion.hop(sprout, HOP, HOP_TIME, 0.0, 0.0)
