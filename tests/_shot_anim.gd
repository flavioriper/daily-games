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
var _draws := 0
var _id := ""
var _empty := false   # skip the fill and measure the bare board
var _entry: Dictionary = {}

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
			_menu._open(_entry)
			_host = _menu.get_child(_menu.get_child_count() - 1)
			_puzzle = _host._puzzle
		return false
	if not _tapped and _t >= TAP_AT:
		_tapped = true
		if _entry.id == "mastermind" and not _empty:
			_fill_mastermind()
		elif _puzzle.get("_given") != null:
			# The tap walks Binairo's givens; a board without them idles instead.
			_tap_first_free()
	if _t >= IDLE_FROM and _t <= IDLE_TO:
		_idle.append(delta * 1000.0)
		_draws = maxi(_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _shot < SHOTS.size() and _t >= SHOTS[_shot]:
		var path := "/tmp/anim_%s_%d.png" % [_entry.id, _shot]
		root.get_texture().get_image().save_png(path)
		print("saved %s at t=%.2f" % [path, _t])
		_shot += 1
	if _t > IDLE_TO:
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

## Code Break's fullest board: seven rows guessed and scored, the eighth
## filled and waiting on Check. Every row is one colour, and at difficulty 0
## the day's code has no repeats, so no monochrome row can win and the eighth
## row is still there to fill. Driven through the HUD the way tests/_win.gd
## drives it, so the board reaches the state by playing rather than by having
## its arrays written.
func _fill_mastermind() -> void:
	var tray = _host.action_bar.tray
	var check: Button = _host.action_bar.check_button
	for g in 7:
		var colour: Button = tray.buttons[g % tray.buttons.size()]
		for s in _puzzle.length:
			_press(colour)
		_press(check)
	for s in _puzzle.length:
		_press(tray.buttons[0])

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
