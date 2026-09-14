extends SceneTree

## End-to-end win check. For each prototype: open it, drive it to the solved
## state using real touch events through the viewport, then confirm the puzzle
## reports solved AND the host's solved overlay actually appeared.
## Nothing here reaches past the input layer -- if the tap maths or the win
## condition is wrong, this fails.

const SLOT := 30

var _menu: Node
var _host: Node
var _puzzle: Node
var _entries: Array = []
var _idx := 0
var _frames := 0
var _results: Array = []
var _fit_ok := true
var _hud_ok := true

func _initialize() -> void:
	_entries = load("res://ui/registry.gd").PUZZLES
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(_delta: float) -> bool:
	_frames += 1
	if _idx >= _entries.size():
		var bad := 0
		print("")
		for r in _results:
			print("  %s  %-12s solved=%s done=%s overlay=%s  %s" % [
				"PASS" if r.ok else "FAIL", r.id, r.solved, r.done, r.overlay, r.note])
			if not r.ok:
				bad += 1
		print("\nwinnable=%d/%d" % [_results.size() - bad, _results.size()])
		return true

	var slot := _frames % SLOT
	if slot == 5:
		_menu._open(_entries[_idx])
		_host = _menu.get_child(_menu.get_child_count() - 1)
	elif slot == 12:
		_puzzle = _host._puzzle
		_fit_ok = true
		_hud_ok = true
		_solve(_entries[_idx].id)
	elif slot == 20:
		var solved: bool = _puzzle.is_solved()
		var done: bool = _puzzle.is_done()
		var overlay: bool = _host._overlay.visible
		root.get_texture().get_image().save_png("/tmp/won_%s.png" % _entries[_idx].id)
		_results.append({
			"id": _entries[_idx].id, "solved": solved, "done": done, "overlay": overlay,
			"ok": solved and done and overlay and _fit_ok and _hud_ok, "note": _note(_entries[_idx].id),
		})
	elif slot == 26:
		_host.closed.emit()
		_idx += 1
	return false

func _note(id: String) -> String:
	match id:
		"binairo": return "%d moves, hints=%d checks=%d, camera fit=%s" % [_puzzle.moves, _puzzle.hints_used, _puzzle.checks, _fit_ok]
		"mastermind": return "cracked in %d guesses" % _puzzle._guesses.size()
		"balance": return "weights %s" % [_puzzle._guess]
		"pipes": return "%d turns" % _puzzle.moves
		"untangle": return "%d crossings" % _puzzle._crossings
		"shikaku": return "%d rectangles" % _puzzle._rects.size()
		"tents": return "%d tents placed" % _puzzle._solution_tents.size()
		"lightup": return "%d bulbs" % _puzzle._bulbs().size()
		"oneline": return "%d lines traced" % _puzzle._done_edges.size()
		"nonogram": return "%dx%d picture" % [_puzzle.w, _puzzle.h]
	return ""

# --- per-puzzle solvers, all driven through touch ---

func _solve(id: String) -> void:
	match id:
		"binairo": _solve_binairo()
		"mastermind": _solve_mastermind()
		"balance": _solve_balance()
		"pipes": _solve_pipes()
		"untangle": _solve_untangle()
		"shikaku": _solve_shikaku()
		"tents": _solve_tents()
		"lightup": _solve_lightup()
		"oneline": _solve_oneline()
		"nonogram": _solve_nonogram()

func _solve_binairo() -> void:
	var n: int = _puzzle.n
	# Camera fit check: every cell centre must project inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in n:
		for c in n:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The HUD's own buttons: one hint (fills and locks a cell) and one check.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	for r in n:
		for c in n:
			if _puzzle.is_done():
				return
			if _puzzle._given[r][c]:
				continue
			var target: int = _puzzle._solution[r][c]
			# empty -> sun is one tap, empty -> moon is two.
			for k in (1 if target == 0 else 2):
				_tap_local(_puzzle.cell_to_local(r, c))

func _solve_mastermind() -> void:
	var length: int = _puzzle.length
	var palette: int = _puzzle.palette
	var slot_w: float = (_puzzle.size.x * 0.72) / float(length)
	var y: float = _puzzle._row_h * 0.5
	for s in length:
		var taps: int = (int(_puzzle._code[s]) - int(_puzzle._current[s])) % palette
		if taps < 0:
			taps += palette
		for k in taps:
			_tap_local(Vector2(slot_w * (s + 0.5), y))
	# Press the real Check button rather than calling the handler.
	var btn: Button = _puzzle._check
	_tap_global(btn.get_global_transform_with_canvas() * (btn.size * 0.5))

func _solve_balance() -> void:
	for i in _puzzle.shapes:
		if i == int(_puzzle._anchor.shape):
			continue
		var target: int = int(_puzzle._secret[i])
		var guard := 0
		while int(_puzzle._guess[i]) != target and guard < 12:
			guard += 1
			_tap_local(Vector2(_puzzle._answer_w * (i + 0.5), _puzzle._answer_y + 100.0))

func _solve_pipes() -> void:
	# rot 0 everywhere is the configuration the spanning tree was built in.
	for y in _puzzle.h:
		for x in _puzzle.w:
			if _puzzle.is_done():
				return
			var taps: int = (4 - int(_puzzle._rot[y][x])) % 4
			for k in taps:
				_tap_local(Vector2(_puzzle._origin.x + (x + 0.5) * _puzzle._cell,
					_puzzle._origin.y + (y + 0.5) * _puzzle._cell))

func _solve_untangle() -> void:
	for i in _puzzle._pos.size():
		# Stop the moment it is won -- further taps land on the solved
		# overlay's dismiss button, which is correct behaviour, not a bug.
		if _puzzle.is_done():
			return
		var from: Vector2 = _puzzle._to_screen(_puzzle._pos[i])
		var to: Vector2 = _puzzle._to_screen(_puzzle._planar[i])
		_drag_local(from, to)

# --- input helpers (viewport-local coordinates) ---

func _to_global(p: Vector2) -> Vector2:
	return _puzzle.get_global_transform_with_canvas() * p

func _tap_local(local: Vector2) -> void:
	_tap_global(_to_global(local))

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

func _drag_local(from_local: Vector2, to_local: Vector2) -> void:
	var a := _to_global(from_local)
	var b := _to_global(to_local)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = a
	root.push_input(down, true)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = b
	drag.relative = b - a
	root.push_input(drag, true)

	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = b
	root.push_input(up, true)

func _cell_centre(origin: Vector2, cell: float, x: int, y: int) -> Vector2:
	return Vector2(origin.x + (x + 0.5) * cell, origin.y + (y + 0.5) * cell)

func _solve_shikaku() -> void:
	# Drag each solution rectangle corner to corner, exactly as a player would.
	for r in _puzzle._solution:
		if _puzzle.is_done():
			return
		var a := _cell_centre(_puzzle._origin, _puzzle._cell, r.position.x, r.position.y)
		var b := _cell_centre(_puzzle._origin, _puzzle._cell,
			r.position.x + r.size.x - 1, r.position.y + r.size.y - 1)
		_drag_local(a, b)

func _solve_tents() -> void:
	for t in _puzzle._solution_tents:
		if _puzzle.is_done():
			return
		_tap_local(_cell_centre(_puzzle._origin, _puzzle._cell, t.x, t.y))

func _solve_lightup() -> void:
	for b in _puzzle._solution_bulbs:
		if _puzzle.is_done():
			return
		_tap_local(_cell_centre(_puzzle._origin, _puzzle._cell, b.x, b.y))

func _solve_oneline() -> void:
	var Gen = load("res://puzzles/oneline_gen.gd")
	var trail: Array = Gen.find_path(_puzzle._edges, _puzzle._nodes)
	if trail.is_empty():
		return
	_tap_local(_puzzle._screen(trail[0]))
	for i in range(1, trail.size()):
		if _puzzle.is_done():
			return
		_tap_local(_puzzle._screen(trail[i]))

func _solve_nonogram() -> void:
	for y in _puzzle.h:
		for x in _puzzle.w:
			if _puzzle.is_done():
				return
			if int(_puzzle._bitmap[y][x]) == 1:
				_tap_local(_cell_centre(_puzzle._origin, _puzzle._cell, x, y))
