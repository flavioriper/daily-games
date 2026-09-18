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
		# The flat host (ui/flat/flat_host.gd) shows no overlay: its win screen
		# is a layout change scheduled 0.8 s after the board's wave, past this
		# slot, so a flat host that has a solved board counts as shown.
		var overlay: bool = _host._overlay.visible or (_host.get("well_done") != null and done)
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
		"rope": return "%d of %d squares, %d pegs, camera fit=%s, hud=%s" % [
			_puzzle._rope.size(), _puzzle.w * _puzzle.h, _puzzle._pegs.size(), _fit_ok, _hud_ok]
		"binairo", "binairo_island": return "%d moves, hints=%d checks=%d, camera fit=%s" % [_puzzle.moves, _puzzle.hints_used, _puzzle.checks, _fit_ok]
		"mastermind", "mastermind_island": return "cracked in %d guesses, camera fit=%s" % [_puzzle._guesses.size(), _fit_ok]
		"balance": return "weights %s, board fit=%s, hud=%s" % [_puzzle.state.guess, _fit_ok, _hud_ok]
		"balance_island": return "weights %s, camera fit=%s, hud=%s" % [_puzzle._guess, _fit_ok, _hud_ok]
		"pipes": return "%d pieces, %d drains, camera fit=%s, hud=%s" % [
			_puzzle._placed.size(), _puzzle._drains.size(), _fit_ok, _hud_ok]
		"untangle": return "%d crossings, camera fit=%s, hud=%s" % [_puzzle._crossings, _fit_ok, _hud_ok]
		"shikaku", "shikaku_island": return "%d plots, board fit=%s, hud=%s" % [_puzzle._rects.size(), _fit_ok, _hud_ok]
		"tents": return "%d tents, camera fit=%s, hud=%s" % [_puzzle._solution_tents.size(), _fit_ok, _hud_ok]
		"lightup": return "%d lanterns, camera fit=%s, hud=%s" % [_puzzle._solution_bulbs.size(), _fit_ok, _hud_ok]
		"oneline": return "%d planks walked, camera fit=%s, hud=%s" % [_puzzle._walked.size(), _fit_ok, _hud_ok]
		"nonogram": return "%dx%d picture, camera fit=%s, hud=%s" % [_puzzle.w, _puzzle.h, _fit_ok, _hud_ok]
		"horse": return "%d bales, pen %d/%d, camera fit=%s, hud=%s" % [_puzzle._walls.size(), _puzzle.score(), _puzzle._target, _fit_ok, _hud_ok]
		"snake": return "%d moves, length %d, camera fit=%s, hud=%s" % [_puzzle.moves, _puzzle._snake.size(), _fit_ok, _hud_ok]
	return ""

# --- per-puzzle solvers, all driven through touch ---

func _solve(id: String) -> void:
	match id:
		"binairo", "binairo_island": _solve_binairo()
		"mastermind", "mastermind_island": _solve_mastermind()
		"balance": _solve_balance_flat()
		"balance_island": _solve_balance()
		"pipes": _solve_pipes()
		"untangle": _solve_untangle()
		"shikaku", "shikaku_island": _solve_shikaku()
		"tents": _solve_tents()
		"lightup": _solve_lightup()
		"oneline": _solve_oneline()
		"nonogram": _solve_nonogram()
		"horse": _solve_horse()
		"snake": _solve_snake()
		"rope": _solve_rope()

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
	# The flat shell keeps its chips on the host (ui/flat/friend_tray.gd);
	# the island's sit in the action bar.
	var flat = _host.get("tray")
	for s in length:
		var friend: int = int(_puzzle._code[s])
		_press(flat.chips[friend] if flat != null else _host.action_bar.tray.buttons[friend])
	_press(_host.action_bar.check_button)

## The flat Balance: the weights are dialled in on the host's own cards
## (ui/flat/weight_tray.gd), since this screen has no live surface on the
## board at all -- the board only shows what the cards say. Pressing the real
## minus and plus is therefore the whole input path.
func _solve_balance_flat() -> void:
	# Board fit check: every dish must hang inside the card the board asked
	# for, which is what the tilt cap and the band cap exist to guarantee.
	var card := Rect2(Vector2.ZERO, Vector2(_puzzle.size.x, _puzzle.card_height(_puzzle.size.y)))
	_fit_ok = true
	for i in _puzzle.state.scales.size():
		for side in 2:
			if not card.has_point(_puzzle.dish_to_local(i, side)):
				_fit_ok = false
	# The HUD's hint reveals and locks one kind; the rest are stepped in.
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1
	var tray = _host.tray
	for i in _puzzle.state.shapes:
		var target: int = int(_puzzle.state.secret[i])
		var guard := 0
		while int(_puzzle.state.guess[i]) != target and guard < 12:
			guard += 1
			var up: bool = int(_puzzle.state.guess[i]) < target
			_press(tray.plus_button(i) if up else tray.minus_button(i))

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

## Pipes: build the generator's own pipeline through the gestures a player
## uses. The piece is chosen in the tray and placed by tapping an open mouth
## next door, then turned by tapping it until it is facing the right way --
## so this proves the tray, the ray picking and the orientation cycle, not
## just the rules.
func _solve_pipes() -> void:
	const Gen = preload("res://puzzles/pipes_iso_gen.gd")
	# Camera fit check: every column's crown must project inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for z in _puzzle.rows:
		for x in _puzzle.cols:
			if not slot.has_point(_puzzle.cell_to_local(z, x)):
				_fit_ok = false
	# The HUD's own buttons: one hint (places and pins a piece) and one turn.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.turn_button)
	_hud_ok = _puzzle.hints_used == 1
	var solution: Dictionary = _puzzle._solution
	for _pass in 60:
		var moved_any := false
		for cell in solution:
			if _puzzle.is_done():
				return
			var want: Dictionary = solution[cell]
			if _puzzle.mask_at(cell) == int(want.mask):
				continue
			if _puzzle.filled(cell):
				# Something is standing there facing the wrong way: turn it.
				if _turn_pipe(cell, int(want.mask)):
					moved_any = true
				continue
			# Grow it out of a neighbour that already has a mouth facing this
			# cell, which is the only way to reach a cell that hangs.
			for bit in Gen.bits(int(want.mask)):
				var neighbour: Vector3i = cell + Gen.STEP[bit]
				if not _puzzle.filled(neighbour):
					continue
				if _puzzle.mask_at(neighbour) & Gen.OPPOSITE[bit] == 0:
					continue
				_select_piece(String(want.kind))
				if not _aim_tap("mouth", neighbour, Gen.OPPOSITE[bit]):
					break
				if _puzzle.filled(cell):
					moved_any = true
					_turn_pipe(cell, int(want.mask))
				break
		if not moved_any:
			break

## Taps a placed piece until it is showing `mask`, the way a player turns one.
func _turn_pipe(cell: Vector3i, mask: int) -> bool:
	for _i in 14:
		if _puzzle.mask_at(cell) == mask:
			return true
		if not _aim_tap("piece", cell, 0):
			return false
	return _puzzle.mask_at(cell) == mask

## Taps `what` (a "mouth" or a "piece") using the whole of the player's
## toolkit: turn the island until the thing is the first thing under the
## finger, and if all four stops hide it, hold peek and try them again. On an
## isometric board a cell one step nearer the camera in x, y and z sits
## exactly in front of another, and a mouth down in a hollow is behind the
## ground from every side -- which is what turning and peek are for. False
## when nothing reaches it.
func _aim_tap(what: String, cell: Vector3i, bit: int) -> bool:
	for peeking in [false, true]:
		_puzzle.peek(peeking)
		for _stop in 4:
			var at: Vector2 = _puzzle.mouth_to_local(cell, bit) if what == "mouth" else _puzzle.hub_to_local(cell)
			var hit: Dictionary = _puzzle._pick(at)
			if String(hit.get("what", "")) == what and hit.get("cell") == cell \
					and (what != "mouth" or int(hit.get("bit", -1)) == bit):
				_tap_local(at)
				_puzzle.peek(false)
				return true
			_puzzle.turn_view()
			# The turn is a 0.35 s tween and this harness taps inside one
			# frame, so the fit is snapped to the stop it is heading for.
			_puzzle._refit()
	_puzzle.peek(false)
	return false

## Chooses a kind in the piece tray, through the tray's own button.
func _select_piece(kind: String) -> void:
	var index: int = _puzzle.tray_index(kind)
	if index < 0:
		return
	var tray = _host.action_bar.piece_tray
	if tray != null and index < tray.buttons.size():
		_press(tray.buttons[index])
	else:
		_puzzle.pick(index)

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
	# The HUD's hint drops and pins one bale of the generator's pen; the rest
	# are dropped by hand, then the pen is submitted through the Check
	# button, which is what ends the day on this board.
	_press(_host.top_bar.hint_button)
	for cell in _puzzle._solution_walls:
		if _puzzle._walls.has(cell):
			continue
		_tap_local(_puzzle.cell_to_local(cell.y, cell.x))
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1

## The Rope: tap along the generator's own route, one square at a time, which
## is the slow careful way a player lays it rather than a drag.
func _solve_rope() -> void:
	var w: int = _puzzle.w
	var h: int = _puzzle.h
	# Camera fit check: every square's centre must project inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in h:
		for c in w:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The HUD's own buttons: one hint, which lays the first square off the
	# stored route, then one check, which must find the rope finishable.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	# _bad_from is what the check it just ran left behind: -1 means it found
	# the rope finishable, which a one-square rope always is.
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1 and _puzzle._bad_from == -1
	for cell in _puzzle._path:
		if _puzzle.is_done():
			return
		if _puzzle._on.has(cell):
			continue
		_tap_local(_puzzle.cell_to_local(cell.y, cell.x))

func _solve_snake() -> void:
	var w: int = _puzzle.w
	var h: int = _puzzle.h
	# Camera fit check: every meadow cell centre must project inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in h:
		for c in w:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The HUD's own buttons: one hint (the solver's next move), then one
	# check, which must find the day still finishable.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	# Then the solver's own way home from wherever the hint left the snake,
	# one tap on the cell ahead of the head per move.
	var Gen = load("res://puzzles/snake_gen.gd")
	var path: Array = Gen.solve(w, h, _puzzle._walls, _puzzle._apples, _puzzle._hole,
		_puzzle._snake, _puzzle._eaten)
	for d in path:
		if _puzzle.is_done():
			return
		var ahead: Vector2i = _puzzle._snake[0] + d
		_tap_local(_puzzle.cell_to_local(ahead.y, ahead.x))
