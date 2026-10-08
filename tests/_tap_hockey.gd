extends SceneTree

## Air hockey driven by input, as fingers would: two touches at once on a
## two-player table (one a half), then one touch and the mouse on a table
## against the computer. Checks that each mallet goes where its finger leads
## it (a little ahead of the finger, kept in its own half) and that a press
## in the other half moves nothing when there is one hand.
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_tap_hockey.gd
##
## Windowed: touches go through the viewport. user://versus.cfg is untouched
## (no match is finished).

const Sim = preload("res://versus/hockey_sim.gd")
const Table = preload("res://versus/hockey_table.gd")

var _s: Control
var _frame := 0
var _bad := 0
var _phase := 0

func _initialize() -> void:
	_open(4)

func _open(level: int) -> void:
	if _s != null:
		_s.queue_free()
	_s = load("res://versus/hockey_screen.gd").new(level)
	root.add_child(_s)
	_frame = 0

## A table point (metres) as a window position.
func _at(p: Vector2) -> Vector2:
	var t: Control = _s.table
	return root.get_final_transform() * (t.get_global_transform() * t.px(p))

func _touch(index: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _at(p)
	e.pressed = down
	root.push_input(e)

func _drag(index: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _at(p)
	root.push_input(e)

func _check(what: String, got: Vector2, want: Vector2) -> void:
	var ok := got.distance_to(want) < 0.02
	print("%s  %s: at %s, wanted %s" % ["ok" if ok else "! ", what, str(got.snapped(Vector2.ONE * 0.001)), str(want.snapped(Vector2.ONE * 0.001))])
	if not ok:
		_bad += 1

func _process(_delta: float) -> bool:
	_frame += 1
	var sim: RefCounted = _s.sim
	# The puck out of the way: this is about the hands.
	if sim != null:
		sim.puck_on = false
	if _phase == 0:
		match _frame:
			30:
				_touch(0, Vector2(0.3, 1.3), true)
				_touch(1, Vector2(0.7, 0.3), true)
			50:
				_check("two players, bottom finger", sim.mallet[0], Vector2(0.3, 1.3 - Table.LIFT))
				_check("two players, top finger", sim.mallet[1], Vector2(0.7, 0.3 + Table.LIFT))
				_drag(0, Vector2(0.6, 0.5))
				_drag(1, Vector2(0.2, 1.2))
			70:
				_check("bottom finger over the line", sim.mallet[0], Vector2(0.6, Sim.L * 0.5 + Sim.MALLET_R))
				_check("top finger over the line", sim.mallet[1], Vector2(0.2, Sim.L * 0.5 - Sim.MALLET_R))
				_touch(0, Vector2(0.6, 0.5), false)
				_touch(1, Vector2(0.2, 1.2), false)
			75:
				_phase = 1
				_open(1)
	else:
		_s.bot = null
		match _frame:
			30:
				_touch(0, Vector2(0.5, 0.3), true)
			45:
				_check("one hand, a press in the far half leads the near mallet", sim.mallet[0], Vector2(0.5, Sim.L * 0.5 + Sim.MALLET_R))
				_check("and not the far one", sim.mallet[1], Sim.home(1))
				_drag(0, Vector2(0.8, 1.5))
			60:
				_check("one hand, dragged", sim.mallet[0], Vector2(0.8, 1.5 - Table.LIFT))
				_touch(0, Vector2(0.8, 1.5), false)
				var m := InputEventMouseButton.new()
				m.button_index = MOUSE_BUTTON_LEFT
				m.pressed = true
				m.position = _at(Vector2(0.25, 1.2))
				root.push_input(m)
			75:
				_check("the mouse", sim.mallet[0], Vector2(0.25, 1.2 - Table.LIFT))
				var m := InputEventMouseButton.new()
				m.button_index = MOUSE_BUTTON_LEFT
				m.pressed = false
				m.position = _at(Vector2(0.25, 1.2))
				root.push_input(m)
			80:
				print("OK" if _bad == 0 else "FAILED: %d" % _bad)
				return true
	return false
