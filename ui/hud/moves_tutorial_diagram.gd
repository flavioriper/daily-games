extends Control

## The tutorial page every Insane board with a move counter shares: the pill
## counting down from `moves` to nothing, on a loop. The board appends it to
## its own pages (`MovesDiagram.page(moves)`); ui/flat/moves_pill.gd draws it.

const Motion = preload("res://core/motion.gd")
const MovesPill = preload("res://ui/flat/moves_pill.gd")

## One count a tick.
const TICK := 0.7
## The pause on the full count and on nothing.
const REST := 1.4
## How many counts the loop shows before it starts over.
const SHOWN := 5

var moves := 5

var _pill := MovesPill.new()
var _left := 0
var _since := 0.0
var _clock := 0.0

## The page a board appends: {diagram, title, body}.
static func page(on: Control, budget: int) -> Dictionary:
	var d: Control = load("res://ui/hud/moves_tutorial_diagram.gd").new()
	d.moves = budget
	return {"diagram": d, "title": "HTP_MOVES", "body": on.tr("HTP_MOVES_BODY") % budget}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_left = mini(moves, SHOWN)
	set_process(not Motion.reduce)

func _process(delta: float) -> void:
	_clock += delta
	_since += delta
	var rest := _left == mini(moves, SHOWN) or _left == 0
	if _since >= (REST if rest else TICK):
		_since = 0.0
		_left = mini(moves, SHOWN) if _left == 0 else _left - 1
		_pill.bump(_clock)
	queue_redraw()

func _draw() -> void:
	_pill.draw(self, size * 0.5, _left, _clock)
