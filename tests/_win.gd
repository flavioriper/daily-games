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
		"mastermind": return "cracked in %d guesses, camera fit=%s" % [_puzzle._guesses.size(), _fit_ok]
		"balance": return "weights %s, camera fit=%s, hud=%s" % [_puzzle._guess, _fit_ok, _hud_ok]
		"pipes": return "%d turns, camera fit=%s, hud=%s" % [_puzzle.moves, _fit_ok, _hud_ok]
		"untangle": return "%d crossings, camera fit=%s, hud=%s" % [_puzzle._crossings, _fit_ok, _hud_ok]
		"shikaku": return "%d plots, camera fit=%s, hud=%s" % [_puzzle._rects.size(), _fit_ok, _hud_ok]
		"tents": return "%d tents, camera fit=%s, hud=%s" % [_puzzle._solution_tents.size(), _fit_ok, _hud_ok]
		"lightup": return "%d lanterns, camera fit=%s, hud=%s" % [_puzzle._solution_bulbs.size(), _fit_ok, _hud_ok]
		"oneline": return "%d planks walked, camera fit=%s, hud=%s" % [_puzzle._walked.size(), _fit_ok, _hud_ok]
		"nonogram": return "%dx%d picture, camera fit=%s, hud=%s" % [_puzzle.w, _puzzle.h, _fit_ok, _hud_ok]
		"horse": return "%d fences, pen %d/%d, camera fit=%s, hud=%s" % [_puzzle._walls.size(), _puzzle.score(), _puzzle._target, _fit_ok, _hud_ok]
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
		"horse": _solve_horse()

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
	# Camera fit check: every socket centre must project inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for g in _puzzle.max_guesses:
		for s in length:
			if not slot.has_point(_puzzle.cell_to_local(g, s)):
				_fit_ok = false
	# The HUD's tray fills the active row with the code, then the real Check.
	var tray = _host.action_bar.tray
	for s in length:
		_press(tray.buttons[int(_puzzle._code[s])])
	_press(_host.action_bar.check_button)

func _solve_balance() -> void:
	# Camera fit check: both pads of every plinth must project inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for i in _puzzle.shapes:
		for add in [true, false]:
			if not slot.has_point(_puzzle.pad_to_local(i, add)):
				_fit_ok = false
	# The HUD's hint reveals and locks one shape; the rest are dialled in on
	# the board, one tap per disc. A locked shape already reads its true
	# weight, so its loop never runs.
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1
	for i in _puzzle.shapes:
		var target: int = int(_puzzle._secret[i])
		var guard := 0
		while int(_puzzle._guess[i]) != target and guard < 12:
			guard += 1
			_tap_local(_puzzle.pad_to_local(i, int(_puzzle._guess[i]) < target))

func _solve_pipes() -> void:
	var w: int = _puzzle.w
	var h: int = _puzzle.h
	# Camera fit check: every cell centre must project inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for y in h:
		for x in w:
			if not slot.has_point(_puzzle.cell_to_local(y, x)):
				_fit_ok = false
	# The HUD's own buttons: one hint (turns and locks a cell), then one tap
	# undone. The tap must land on a cell the hint cannot have taken, and a
	# hint always takes the first wrong cell in reading order, so walk
	# backwards to the last cell it did not lock.
	_press(_host.top_bar.hint_button)
	var free_cell := Vector2i(-1, -1)
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			if free_cell.x < 0 and not _puzzle._locked.has(Vector2i(x, y)):
				free_cell = Vector2i(x, y)
	_tap_local(_puzzle.cell_to_local(free_cell.y, free_cell.x))
	_press(_host.top_bar.undo_button)
	# If the hint (or the tap it left in place to undo) happened to solve the
	# board outright, undo() returns false at once and can_undo() is false
	# only because is_done() is -- neither says the undo actually ran. Check
	# is_done() first, and only then assert undo popped its entry.
	_hud_ok = _puzzle.hints_used == 1
	if not _puzzle.is_done():
		_hud_ok = _hud_ok and _puzzle._history.is_empty() and _puzzle.moves == 1
	# rot 0 everywhere is the configuration the spanning tree was built in.
	for y in h:
		for x in w:
			if _puzzle.is_done():
				return
			var taps: int = (4 - int(_puzzle._rot[y][x])) % 4
			for k in taps:
				_tap_local(_puzzle.cell_to_local(y, x))

func _solve_untangle() -> void:
	# Camera fit check: every post must project inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for i in _puzzle.nodes:
		if not slot.has_point(_puzzle.node_to_local(i)):
			_fit_ok = false
	# One hint through the HUD; it pins a post on its untangled spot.
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1
	for i in _puzzle._pos.size():
		# Stop the moment it is won -- further taps land on the solved
		# overlay's dismiss button, which is correct behaviour, not a bug.
		if _puzzle.is_done():
			return
		if _puzzle._locked[i]:
			continue
		_drag_local(_puzzle.node_to_local(i), _puzzle.planar_to_local(i))

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

func _solve_shikaku() -> void:
	var w: int = _puzzle.w
	var h: int = _puzzle.h
	# Camera fit check: every cell centre must project inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in h:
		for c in w:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The HUD's own buttons: one hint (draws and pins a plot), then one check.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	# Drag each solution rectangle corner to corner, exactly as a player would.
	for rect in _puzzle._solution:
		if _puzzle.is_done():
			return
		_drag_local(_puzzle.cell_to_local(rect.position.y, rect.position.x),
			_puzzle.cell_to_local(rect.position.y + rect.size.y - 1,
				rect.position.x + rect.size.x - 1))

func _solve_tents() -> void:
	var w: int = _puzzle.w
	var h: int = _puzzle.h
	# Camera fit check: every field cell centre must project inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in h:
		for c in w:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The HUD's own buttons: one hint (pitches and pins a tent), then one check.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	for t in _puzzle._solution_tents:
		if _puzzle.is_done():
			return
		_tap_local(_puzzle.cell_to_local(t.y, t.x))

func _solve_lightup() -> void:
	var w: int = _puzzle.w
	var h: int = _puzzle.h
	# Camera fit check: every cell centre must project inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in h:
		for c in w:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The HUD's own buttons: one hint (lights and pins a lantern), then one check.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	for b in _puzzle._solution_bulbs:
		if _puzzle.is_done():
			return
		_tap_local(_puzzle.cell_to_local(b.y, b.x))

func _solve_oneline() -> void:
	# Camera fit check: every post must project inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for n in _puzzle._nodes:
		if not slot.has_point(_puzzle.node_to_local(n)):
			_fit_ok = false
	var Gen = load("res://puzzles/oneline_gen.gd")
	var trail: Array = Gen.find_path(_puzzle._edges, _puzzle._nodes)
	if trail.is_empty():
		return
	# The HUD's own buttons: one hint (which takes the starting post, since
	# the stroke has not begun), then one check, which must find nothing
	# stranded on a board nobody has walked yet.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	# The hint takes the first odd-degree post, which is the same post
	# Gen.find_path begins its trail at, so this tap lands on the post the
	# stroke is already standing on and does nothing. It is here so the walk
	# below reads as the whole trail rather than the whole trail bar one.
	_tap_local(_puzzle.node_to_local(trail[0]))
	for i in range(1, trail.size()):
		if _puzzle.is_done():
			return
		_tap_local(_puzzle.node_to_local(trail[i]))

func _solve_nonogram() -> void:
	var w: int = _puzzle.w
	var h: int = _puzzle.h
	# Camera fit check: every grid cell centre must project inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in h:
		for c in w:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The HUD's own buttons: one hint (lays and pins a tile), then one check.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	for y in h:
		for x in w:
			if _puzzle.is_done():
				return
			if int(_puzzle._bitmap[y][x]) == 1:
				_tap_local(_puzzle.cell_to_local(y, x))

func _solve_horse() -> void:
	var w: int = _puzzle.w
	var h: int = _puzzle.h
	# Camera fit check: every meadow cell centre must project inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in h:
		for c in w:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The HUD's own buttons: one hint (builds and pins a fence), then one
	# check, which shows where the horse can still get to.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	# Build the generator's own pen, fence by fence.
	for cell in _puzzle._solution_walls:
		if _puzzle.is_done():
			return
		if _puzzle._walls.has(cell):
			continue
		_tap_local(_puzzle.cell_to_local(cell.y, cell.x))
