extends Button

## One colour on the tray: a toon disc in the peg's colour with its pip mark
## and a darker lower crescent for the shadow band, dimmed when the puzzle is
## not taking picks, squishing on press like IconButton.
## Spec: docs/superpowers/specs/2026-09-14-codebreak-3d-design.md, section 3.

const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Shapes = preload("res://core/shapes.gd")

const SIDE := 110.0
const DISC := 0.42
const SHADE := 0.25
const MARK_SHADE := 0.35
const RING := 4.0
const DIM := 0.45
const SQUASH := 0.10
const SQUASH_TIME := 0.18

var colour: Color = Pal.PEGS[0]
var mark := 1
var _press_tw: Tween

func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(SIDE, SIDE)
	text = ""

func _ready() -> void:
	button_down.connect(_squish)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5

func set_entry(colour_: Color, mark_: int, enabled: bool) -> void:
	colour = colour_
	mark = mark_
	disabled = not enabled
	queue_redraw()

func _squish() -> void:
	Motion.stop(_press_tw)
	scale = Vector2.ONE
	_press_tw = Motion.squash(self, SQUASH, SQUASH_TIME)

func _draw() -> void:
	var centre := size * 0.5
	var r := minf(size.x, size.y) * DISC
	var alpha := DIM if disabled else 1.0
	var fill := Color(colour, alpha)
	draw_circle(centre, r + RING, Color(Pal.OUTLINE, alpha))
	# The shadow band: a darker disc, then the lit disc drawn a little higher
	# over it, leaving a dark crescent along the bottom.
	draw_circle(centre, r, Color(colour.darkened(SHADE), alpha))
	draw_circle(centre - Vector2(0.0, r * 0.1), r * 0.88, fill)
	Shapes.draw_pips(self, mark, centre - Vector2(0.0, r * 0.12), r * 0.3, r * 0.1,
		Color(colour.darkened(MARK_SHADE), alpha))
