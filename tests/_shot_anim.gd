extends SceneTree

## Animation strip for Binairo: frames across the entrance, a tap, the roll
## and two seconds of idle, plus the draw-call count and mean frame time over
## the idle window. Vsync is off so the delta is the real cost of a frame.
## Judge the ambience by eye and the budget by the numbers
## (polish spec, section 7: idle mean under 8 ms at 1080 x 1920 on the Mac).
##
##     godot --path . --resolution 1080x1920 --script res://tests/_shot_anim.gd [-- <puzzle id> [empty]]
##
## Code Break is filled to its fullest board before the idle window, since
## that is the state the budget is written against; `empty` after the id
## measures the bare board instead, so both numbers come from this one probe.
## Untangle is dragged once, and its springs settle into the idle window, so
## `empty` is the number to compare with a board that was left alone. Shikaku
## has its first plot drawn corner to corner, so the strip shows the wash, the
## count and the bed landing and the idle window has a bed and a fence in it.
##
## Saves /tmp/anim_<id>_<n>.png for n = 0..5.

const SHOTS := [0.35, 0.9, 1.65, 1.8, 2.8, 3.8]  # seconds after opening
const TAP_AT := 1.6
const IDLE_FROM := 2.2
const IDLE_TO := 4.2

var _menu: Node
var _host: Node
var _puzzle: Node
var _t := -0.2   # the first frames carry the load; the board opens at 0
var _opened := false
var _tapped := false
var _shot := 0
var _idle: Array[float] = []
var _idle_from := IDLE_FROM
var _idle_to := IDLE_TO
var _filling := false
var _draws := 0
var _id := ""
var _empty := false   # skip the fill and measure the bare board
var _entry: Dictionary = {}
## A drag: a real touch at `_drag_from`, dragged over DRAG_TIME by `_drag_by`
## and let go. Untangle's is the first free lantern toward the middle of the
## card, so the strip shows the lift, the slack and the drop; Shikaku's is its
## first solution plot corner to corner.
const DRAG_TIME := 0.35
const UNTANGLE_BY := Vector2(150.0, 110.0)
var _drag_from := Vector2.ZERO
var _drag_by := Vector2.ZERO
var _drag_until := INF
var _drag_done := true

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_id = args[0]
	_empty = args.size() > 1 and args[1] == "empty"
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if not _opened:
		if _t >= 0.0:
			_opened = true
			_t = 0.0
			var entries: Array = load("res://ui/registry.gd").PUZZLES
			_entry = entries[0]
			for e in entries:
				if e.id == _id:
					_entry = e
			if _entry.get("soon", false):
				push_error("_shot_anim: %s has no flat board to shoot" % _id)
				quit(1)
				return true
			_menu._open(_entry)
			_host = _menu.get_child(_menu.get_child_count() - 1)
			_puzzle = _host._puzzle
		return false
	if not _tapped and _t >= TAP_AT:
		_tapped = true
		if _entry.id == "mastermind" and not _empty:
			# The flat board plays a row over about a second (the score, then
			# the slide), so the fill is one press a frame until it is done and
			# the idle window opens after it.
			_filling = true
			_idle_from = INF
			_idle_to = INF
		elif _entry.id == "balance":
			# One press on the first free weight card, so the strip shows a
			# beam swing and the kind's hop.
			_step_balance()
		elif _entry.id == "untangle" and not _empty:
			_begin_untangle_drag()
		elif _entry.id == "shikaku" and not _empty:
			_begin_shikaku_drag()
		elif _puzzle.get("_given") != null:
			# The tap walks Binairo's givens; a board without them idles instead.
			_tap_first_free()
	if _filling:
		_fill_mastermind_step()
	if not _drag_done:
		_drag_step()
	if _t >= _idle_from and _t <= _idle_to:
		_idle.append(delta * 1000.0)
		_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _shot < SHOTS.size() and _t >= SHOTS[_shot]:
		var path := "/tmp/anim_%s_%d.png" % [_entry.id, _shot]
		root.get_texture().get_image().save_png(path)
		print("saved %s at t=%.2f" % [path, _t])
		_shot += 1
	if _t > _idle_to:
		var mean := 0.0
		for ms in _idle:
			mean += ms
		mean /= maxf(_idle.size(), 1.0)
		print("idle frames=%d mean_ms=%.2f max_draw_calls=%d" % [_idle.size(), mean, _draws])
		return true
	return false

## One real touch on the first free cell, through the viewport like a thumb.
func _tap_first_free() -> void:
	for r in _puzzle.n:
		for c in _puzzle.n:
			if _puzzle._given[r][c]:
				continue
			var at: Vector2 = _puzzle.get_global_transform_with_canvas() * _puzzle.cell_to_local(r, c)
			for pressed in [true, false]:
				var ev := InputEventScreenTouch.new()
				ev.index = 0
				ev.pressed = pressed
				ev.position = at
				root.push_input(ev, true)
			return

## Balance: plus on the first card the player owns, through the real button.
func _step_balance() -> void:
	for i in _puzzle.state.shapes:
		if not _puzzle.state.locked[i]:
			_press(_host.tray.plus_button(i))
			return

## Untangle: touch the first free lantern's ring and start dragging it.
func _begin_untangle_drag() -> void:
	for i in _puzzle.nodes:
		if _puzzle._locked[i]:
			continue
		_begin_drag(_puzzle.get_global_transform_with_canvas() * _puzzle.node_to_local(i), UNTANGLE_BY)
		return

## Shikaku: draw the first solution plot, from the centre of its top-left
## cell to the centre of its bottom-right one.
func _begin_shikaku_drag() -> void:
	if _puzzle._solution.is_empty():
		return
	var rect: Rect2i = _puzzle._solution[0]
	var xf: Transform2D = _puzzle.get_global_transform_with_canvas()
	var from: Vector2 = xf * _puzzle.cell_to_local(rect.position.y, rect.position.x)
	var to: Vector2 = xf * _puzzle.cell_to_local(rect.end.y - 1, rect.end.x - 1)
	_begin_drag(from, to - from)

## The touch that starts a drag, at `from`, to travel `by` over DRAG_TIME.
func _begin_drag(from: Vector2, by: Vector2) -> void:
	_drag_from = from
	_drag_by = by
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _drag_from
	root.push_input(down, true)
	_drag_until = _t + DRAG_TIME
	_drag_done = false

## One drag event a frame along the way, eased, and the release at the end.
func _drag_step() -> void:
	var u := clampf(1.0 - (_drag_until - _t) / DRAG_TIME, 0.0, 1.0)
	var at := _drag_from + _drag_by * (1.0 - pow(1.0 - u, 2.0))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = at
	root.push_input(drag, true)
	if u >= 1.0:
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.pressed = false
		up.position = at
		root.push_input(up, true)
		_drag_done = true

## Code Break's fullest board: seven rows guessed and scored, the eighth
## filled and waiting on Check. Every row is one colour, and at difficulty 0
## the day's code has no repeats, so no monochrome row can win and the eighth
## row is still there to fill. Driven through the HUD the way tests/_win.gd
## drives it, so the board reaches the state by playing rather than by having
## its arrays written: one press a frame, and nothing while a score plays.
func _fill_mastermind_step() -> void:
	if _puzzle._busy:
		return
	var tray = _host.tray
	var played: int = _puzzle._guesses.size()
	if played >= 7:
		if not _puzzle.state.full():
			_press(tray.chips[0])
			return
		_filling = false
		_idle_from = _t + 0.6
		_idle_to = _idle_from + 2.0
		print("filled at t=%.2f" % _t)
		return
	if _puzzle.state.full():
		_press(_host.action_bar.check_button)
	else:
		_press(tray.chips[played % tray.chips.size()])

## Presses a HUD button through a touch at its centre, like a player would.
func _press(btn: Button) -> void:
	_tap_global(btn.get_global_transform_with_canvas() * (btn.size * 0.5))

func _tap_global(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = pressed
		ev.position = at
		root.push_input(ev, true)
