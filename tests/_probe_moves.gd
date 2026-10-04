extends SceneTree

## Insane's move counter on any board (docs/agents/flat-screens.md, "Insane
## counts moves"). Windowed, one at a time:
##
##     godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_probe_moves.gd -- id=<board> [d=3] [out=<dir>]
##
## Opens the board through the menu, prints its counter and capabilities,
## shoots it at rest (<dir>/moves_<id>_rest.png), spends the whole budget
## through the board's own `_spend` and shoots the out-of-moves card
## (..._out.png), then presses Try again and prints the counter once more.

var _t := 0.0
var _id := "nonogram"
var _level := 3
var _dir := "/tmp"
var _menu: Node
var _host: Node
var _puzzle: Node
var _opened := false
var _plan: Array = []
var _draws := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("d="):
			_level = int(a.substr(2))
		elif a.begins_with("id="):
			_id = a.substr(3)
		elif a.begins_with("out="):
			_dir = a.substr(4)
	var progress = load("res://core/progress.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_probe_moves_progress.cfg"))
	progress.path = "user://_probe_moves_progress.cfg"
	for e in load("res://ui/registry.gd").PUZZLES:
		progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(delta: float) -> bool:
	_t += delta
	if not _opened:
		_opened = true
		_t = 0.0
		var entry: Dictionary = {}
		for e in load("res://ui/registry.gd").PUZZLES:
			if e.id == _id:
				entry = e
		if entry.is_empty():
			print("no board ", _id)
			quit()
			return true
		_menu._open_at(entry, _level)
		_host = _menu.get_child(_menu.get_child_count() - 1)
		_puzzle = _host._puzzle
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
		_plan = [
			[2.5, _rest], [2.6, _shot.bind("rest")],
			[2.8, _lose], [6.5, _shot.bind("out")],
			[6.7, _again], [7.4, _report.bind("after try again")]]
		return false
	while not _plan.is_empty() and float(_plan[0][0]) <= _t:
		var step: Array = _plan.pop_front()
		(step[1] as Callable).call()
	if _t > 1.0:
		_draws = maxi(_draws, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	if _t >= 7.8:
		print("draw calls peak ", _draws)
		quit()
		return true
	return false

func _report(tag: String) -> void:
	print("%s %s: moves %s/%s, hearts %s/%s, out %s, caps %s, hints %s" % [_id, tag,
		_puzzle.get("moves_left"), _puzzle.get("max_moves"), _puzzle.get("hearts"),
		_puzzle.get("max_hearts"), _puzzle.get("out_of_hearts"), _puzzle.capabilities(),
		_puzzle.hints_left() if _puzzle.has_method("hints_left") else "-"])

func _rest() -> void:
	_report("rest")
	var pages: Array = _puzzle.tutorial_pages() if _puzzle.has_method("tutorial_pages") else []
	var titles: Array = []
	for p in pages:
		titles.append(p.title)
		p.diagram.free()
	print("tutorial: ", titles)
	print("rules: ", _puzzle.rules().right(220))

func _lose() -> void:
	if not _puzzle.has_method("_spend"):
		print("no _spend on ", _id)
		return
	_puzzle._spend(int(_puzzle.get("moves_left")), _puzzle._now())
	_report("spent")

func _again() -> void:
	var card := _host.get_node_or_null("OutOfHearts")
	print("card: ", card != null)
	if card != null:
		card.get_node("../OutOfHearts").try_again.emit()
		card.queue_free()

func _shot(tag: String) -> void:
	RenderingServer.force_draw()
	var path := "%s/moves_%s_%s.png" % [_dir, _id, tag]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
