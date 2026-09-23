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
	# No card is `soon` any more (the last one, Pipes, gave up its slot to
	# Word Trail on 2026-09-20), but the guard stays for whenever a board is
	# next named before it is drawn: a `soon` card has no script to open, so
	# the harness walks only the entries that do.
	_entries = []
	for e in load("res://ui/registry.gd").PUZZLES:
		if not e.get("soon", false):
			_entries.append(e)
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
		"untangle", "untangle_island": return "%d crossings, board fit=%s, hud=%s" % [_puzzle._crossings, _fit_ok, _hud_ok]
		"shikaku", "shikaku_island": return "%d plots, board fit=%s, hud=%s" % [_puzzle._rects.size(), _fit_ok, _hud_ok]
		"tents", "tents_island": return "%d tents, board fit=%s, hud=%s" % [_puzzle._solution_tents.size(), _fit_ok, _hud_ok]
		"lightup", "lightup_island": return "%d lanterns, board fit=%s, hud=%s" % [_puzzle._solution_bulbs.size(), _fit_ok, _hud_ok]
		"oneline", "oneline_island": return "%d planks walked, board fit=%s, hud=%s" % [_puzzle._walked.size(), _fit_ok, _hud_ok]
		"nonogram", "nonogram_island": return "%dx%d picture, camera fit=%s, hud=%s" % [_puzzle.w, _puzzle.h, _fit_ok, _hud_ok]
		"queens": return "%dx%d court, %d queens, board fit=%s, hud=%s" % [_puzzle.n, _puzzle.n, _puzzle.state.queens.size(), _fit_ok, _hud_ok]
		"mushroom": return "%dx%d patch, %d mushrooms, board fit=%s, hud=%s" % [
			_puzzle.n, _puzzle.n, _puzzle.state.mushrooms.size(), _fit_ok, _hud_ok]
		"wordtrail": return "%dx%d field, %d words traced, board fit=%s, hud=%s" % [
			_puzzle._state.n, _puzzle._state.n, _puzzle._state.words.size(),
			_fit_ok, _hud_ok]
		"bridges": return "%dx%d sea, %d islets, %d runs, board fit=%s, hud=%s" % [
			_puzzle.state.n, _puzzle.state.n, _puzzle.state.islets.size(),
			_puzzle.state.runs.size(), _fit_ok, _hud_ok]
		"hiddenword": return "%s in %d %s, hints=%d, board fit=%s, hud=%s" % [
			_puzzle.state.answer.to_upper(), _puzzle.state.rows.size(),
			"row" if _puzzle.state.rows.size() == 1 else "rows",
			_puzzle.hints_used, _fit_ok, _hud_ok]
		"planes": return "%d planes launched off a %dx%d sky, hints=%d, board fit=%s, hud=%s" % [
			_puzzle._state.planes.size(), _puzzle._state.cols, _puzzle._state.rows,
			_puzzle.hints_used, _fit_ok, _hud_ok]
		"sudoku": return "%d givens, %d moves, hints=%d, board fit=%s, hud=%s" % [
			_puzzle.state.given.size() - _puzzle.state.given.count(0), _puzzle.moves, _puzzle.hints_used, _fit_ok, _hud_ok]
		"fairylights": return "%dx%d garden, %d lanterns, %d turns, board fit=%s, hud=%s" % [
			_puzzle.state.n, _puzzle.state.n, _puzzle.state.lanterns().size(),
			_puzzle.state.turns, _fit_ok, _hud_ok]
		"quilt": return "%dx%d backing, %d patches, hints=%d, board fit=%s, hud=%s" % [
			_puzzle._state.cols, _puzzle._state.rows, _puzzle._state.shapes.size(),
			_puzzle.hints_used, _fit_ok, _hud_ok]
		"pinwheel": return "%dx%d frame, %d pieces, %d taps, hints=%d, board fit=%s, hud=%s" % [
			_puzzle._state.cols, _puzzle._state.rows, _puzzle._state.shapes.size(),
			_puzzle.moves, _puzzle.hints_used, _fit_ok, _hud_ok]
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
		"untangle", "untangle_island": _solve_untangle()
		"shikaku", "shikaku_island": _solve_shikaku()
		"tents", "tents_island": _solve_tents()
		"lightup", "lightup_island": _solve_lightup()
		"oneline", "oneline_island": _solve_oneline()
		"nonogram", "nonogram_island": _solve_nonogram()
		"queens": _solve_queens()
		"mushroom": _solve_mushroom()
		"wordtrail": _solve_wordtrail()
		"bridges": _solve_bridges()
		"planes": _solve_planes()
		"hiddenword": _solve_hiddenword()
		"sudoku": _solve_sudoku()
		"quilt": _solve_quilt()
		"fairylights": _solve_fairylights()
		"pinwheel": _solve_pinwheel()
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
	const Gen = preload("res://legacy/puzzles/pipes_iso_gen.gd")
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

## Drives both Untangles: the flat board and the island answer the same
## names, because the flat one keeps the state's positions under them.
func _solve_untangle() -> void:
	# Fit check: every lantern must land inside the board slot.
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

## Word Trail: a word is traced by dragging through its own cells, one
## side-adjacent step at a time, so this is the one board that needs a
## multi-point drag rather than `_drag_local`'s two. The hint only lights the
## next tile of the shortest unfound word (`word_trail_state.gd`'s `hint()`);
## it never completes a word on its own, so every word of the answer,
## including the one the hint touched, is still traced in full below. There
## is no Check on this board (only a right word locks), so `_hud_ok` watches
## the hint alone.
func _solve_wordtrail() -> void:
	var st = _puzzle._state
	# Fit check: every cell centre must land inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in st.n:
		for c in st.n:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1
	for w: Dictionary in st.words:
		if _puzzle.is_done():
			return
		var path: Array = w["path"]
		if path.size() < 2:
			continue
		var pts: Array[Vector2] = []
		for cell: Vector2i in path:
			pts.append(_puzzle.cell_to_local(cell.y, cell.x))
		_drag_path_local(pts)

# --- input helpers (viewport-local coordinates) ---

func _to_global(p: Vector2) -> Vector2:
	return _puzzle.get_global_transform_with_canvas() * p

## Quilt: every patch dragged off the rack and onto the cell the answer
## wants it on. Each is taken hold of by its own first cell -- wherever that
## cell happens to sit on the rack -- and the finger is aimed `HOLD_LIFT`
## cells *below* where the patch has to land, because this board holds a
## dragged patch above the thumb; aiming at the cell itself would place
## every patch a row and a bit too high and the board would refuse the lot.
##
## One hint first, through the HUD, which sews one patch and locks it; that
## patch is then skipped, because a given refuses to be picked up (which is
## itself worth exercising: the skip is the harness agreeing with the rule).
## There is no Check on this board -- nothing wrong can be sitting on it --
## so `_hud_ok` watches the hint alone, as Word Trail's does.
func _solve_quilt() -> void:
	var st = _puzzle._state
	# Fit check: every cell of the backing must land inside the board slot,
	# and so must every patch's bay on the rack.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in st.rows:
		for c in st.cols:
			if st.in_region(c, r) and not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	for p in st.shapes.size():
		if not slot.has_point(_puzzle._bay_home(p)):
			_fit_ok = false
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1
	var cell: float = _puzzle._cell()
	var rack: float = _puzzle._rack_cell()
	for p in st.shapes.size():
		if _puzzle.is_done():
			return
		if int(st.at[p]) >= 0:
			continue
		var first: Vector2i = (st.shapes[p] as Array)[0]
		var from: Vector2 = _puzzle._bay_home(p) + (Vector2(first) + Vector2(0.5, 0.5)) * rack
		var origin := int(st.answer[p])
		var corner: Vector2 = _puzzle._origin() + Vector2(
			float(origin % st.cols), float(origin / st.cols)) * cell
		var to: Vector2 = corner + (Vector2(first) + Vector2(0.5, 0.5 + _puzzle.HOLD_LIFT)) * cell
		_drag_local(from, to)

## Pinwheel: every piece turned home by tapping its own pinwheel, which is
## this board's entire input vocabulary -- one tap on one unambiguous target,
## repeated until the piece faces the way the answer wants. Nothing else on
## the frame does anything, so a pin drawn at the wrong cell, or a tap that
## reads the cell under the finger as `row * cols + column`, fails here
## rather than passing on a poke at the state.
##
## A piece that is *pinned fast* -- one in-frame orientation, so nowhere to
## go -- is skipped, and it has to be: it is already on its answer and the
## board refuses the tap, so a loop that waited for it to turn would spin
## for ever. That skip is the harness agreeing with rule 5.
##
## One hint first, through the real HUD, which walks the piece furthest from
## home all the way back in a single history entry; that piece is then
## already facing right and the loop below steps over it with no special
## case. There is no Check on this board -- nothing is hidden, and the stain
## a second piece lays on a cell is the answer a Check would give -- so
## `_hud_ok` watches the hint alone, as Quilt's and Word Trail's do.
func _solve_pinwheel() -> void:
	var st = _puzzle._state
	# Fit check: every cell centre must land inside the board slot, and so
	# must every pin. The pin is the only tap target on the screen, so a pin
	# off the card is a piece that can never be turned at all.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in st.rows:
		for c in st.cols:
			if not slot.has_point(_puzzle.cell_to_local(c, r)):
				_fit_ok = false
	for p in (st.shapes as Array).size():
		if not slot.has_point(_puzzle._pin_point(p)):
			_fit_ok = false
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1
	for p in (st.shapes as Array).size():
		if _puzzle.is_done():
			return
		if st.fixed(p):
			continue
		var pin: Vector2i = st.pin_cell(p)
		# A piece has at most four orientations, so four taps come home from
		# anywhere; the guard is there so a board that refused a tap stops
		# rather than hangs.
		var guard := 0
		while int(st.turned[p]) != int(st.answer[p]) and guard < 5:
			guard += 1
			_tap_local(_puzzle.cell_to_local(pin.x, pin.y))

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

## A drag through every point in turn, not just from the first to the last:
## Word Trail only accepts a step to a side-adjacent cell, so a two-point
## drag across a bending word is refused at the first corner.
func _drag_path_local(points: Array[Vector2]) -> void:
	if points.size() < 2:
		return
	var here := _to_global(points[0])
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = here
	root.push_input(down, true)
	for i in range(1, points.size()):
		var next := _to_global(points[i])
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = next
		drag.relative = next - here
		root.push_input(drag, true)
		here = next
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = here
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

## Drives both Tents boards: the flat one answers the island's own names,
## because it keeps the state's grid under them.
func _solve_tents() -> void:
	var w: int = _puzzle.w
	var h: int = _puzzle.h
	# Fit check: every field cell centre must land inside the board slot.
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

## Drives both One Line boards: the flat one answers the island's own names,
## because it keeps the state's figure under them.
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

## Queens: the hint is spent last, on purpose. Check first, on the bare
## court (it must return 0 and say "Seat a queen first."); then the answer's
## seat is tapped with the crown chip into every row but the last; then the
## hint seats the n-th queen and wins the board through the hint path. That
## order is what caught bug 1's shape: a hint that finishes the puzzle runs
## check_solved -> _on_solved -> _hop in the same call stack, and _hop's
## Motion.stop(_pos_tw.get(crown)) was killing the seating crown's drop-in
## tween at alpha 0, with nothing to restore it -- invisible on the solved
## court. Pressing the hint first, as this harness used to, never seats the
## last queen through the hint path and so never reached it.
func _solve_queens() -> void:
	var n: int = _puzzle.n
	# Board fit check: every cell centre must land inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in n:
		for c in n:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_press(_host.action_bar.check_button)
	for r in range(1, n):
		if _puzzle.is_done():
			return
		var cell := Vector2i(int(_puzzle.state.solution[r]), r)
		if _puzzle.state.queens.has(cell):
			continue
		_tap_local(_puzzle.cell_to_local(r, cell.x))
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1

## Mushroom Patch: the mushroom chip is the tray's default, so every mushroom
## of the answer is planted with a real touch on its own cell, in reading
## order -- and the last one is left to the hint, the way _solve_queens leaves
## the n-th queen, so the win comes through the hint path as well as through
## the tap path. Check is spent first, on a bare patch, where it must find
## nothing wrong and say so.
func _solve_mushroom() -> void:
	var n: int = _puzzle.n
	# Board fit check: every cell centre must land inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in n:
		for c in n:
			if not slot.has_point(_puzzle.cell_centre(Vector2i(c, r))):
				_fit_ok = false
	_press(_host.action_bar.check_button)
	var cells: Array = _puzzle.state.mushrooms.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for i in range(cells.size() - 1):
		if _puzzle.is_done():
			return
		_tap_local(_puzzle.cell_centre(cells[i]))
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
## Bridges: one hint and one check through the HUD, then the answer laid one
## run at a time with real drags from islet to islet. **Nothing here writes to
## the state** -- every plank goes in through the board's own `_gui_input`, so
## a board whose drag resolved to the wrong lane, or whose islet hit box was
## laid out wrongly, fails this rather than passing on a state poke.
##
## The answer's own runs never cross each other, so no order of laying them
## can ever be refused; and the hint has already laid one of them, so each
## lane is only dragged the planks it is still short of.
func _solve_bridges() -> void:
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for cell in _puzzle.state.islets:
		if not slot.has_point(_puzzle.cell_to_local(cell.y, cell.x)):
			_fit_ok = false
	# One hint (which lays a plank the answer wants and never an overshoot),
	# then one check, which must find nothing wrong on a board carrying only
	# the answer's own planks.
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	var keys: Array = _puzzle.state.answer.keys()
	keys.sort()
	for key in keys:
		var lane: Dictionary = _puzzle.state.lanes[key]
		var a: Vector2 = _puzzle.cell_to_local(lane.a.y, lane.a.x)
		var b: Vector2 = _puzzle.cell_to_local(lane.b.y, lane.b.x)
		for k in int(_puzzle.state.answer[key]) - _puzzle.state.planks(String(key)):
			# Stop the moment it is won -- further drags land on the solved
			# overlay, which is correct behaviour and not a bug.
			if _puzzle.is_done():
				return
			_drag_local(a, b)

## Paper Planes: every plane is tapped on its own head cell, with a real
## touch, until the sky is empty. It needs no order and no solver -- a launch
## only ever empties cells, so any plane that is free now is still free
## later and the greedy walk can never dead-end -- and it needs no waiting
## between taps, because the board updates the state on the press and
## animates afterwards. That is what lets the whole board be cleared inside
## this one frame; if a busy gate is ever added to `_tap`, this is the test
## that will catch it.
##
## The **last** plane goes through the hint, the way `_solve_queens` leaves
## the n-th queen to it, so the hint path is exercised as well as the tap
## path. It takes one extra step here: a hint on this board only *names* a
## free plane and never launches it (there is no wrong move to be saved
## from), so the harness presses Hint and then taps the plane it rang --
## `_hint_lit` -- and the win still arrives through a touch on the board.
##
## **There is no Check on this board**, so nothing presses one and `checks`
## stays 0; `_hud_ok` is the hint alone.
func _solve_planes() -> void:
	var st = _puzzle._state
	# Board fit check: every cell centre must land inside the slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in st.rows:
		for c in st.cols:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	var guard := 0
	while not _puzzle.is_done() and guard < 400:
		guard += 1
		var free: Array[int] = st.free_planes()
		if free.is_empty():
			return
		var i: int = free[0]
		if st.left() == 1:
			_press(_host.top_bar.hint_button)
			_hud_ok = _puzzle.hints_used == 1
			if _puzzle._hint_lit >= 0:
				i = _puzzle._hint_lit
		var cells: Array = st.planes[i]["cells"]
		var head: Vector2i = cells[cells.size() - 1]
		_tap_local(_puzzle.cell_to_local(head.y, head.x))

## Hidden Word: one hint, then the day's own word typed on the real keyboard
## a key at a time and committed with the real Enter. Nothing here writes to
## the state -- every letter goes in through the tray's own Button, so a
## keyboard whose keys were laid out or named wrongly fails this rather than
## passing on a state poke.
##
## The hint is spent first and on purpose: it greens a key and drops a ghost
## into the working row, and the answer is then typed straight over that
## column, which is the path a stuck player actually takes. A hint never
## commits a row, so the win still has to come from the Enter.
func _solve_hiddenword() -> void:
	# Board fit check: every tile centre must land inside the board slot.
	var State = load("res://puzzles/hidden_word_state.gd")
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in State.ROWS:
		for c in State.LEN:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.moves == 0
	var word: String = _puzzle.state.answer
	for i in word.length():
		_tap_key("Key_%s" % word[i].to_upper())
	_tap_key("Key_Enter")

## Sudoku: one hint and one Check off the real HUD, then the day's own answer
## a cell at a time -- a touch on the cell to select it and a touch on the
## pad's own chip to write the digit. That pair is the only way anything gets
## into this grid, so a pad whose chips were laid out or named wrongly fails
## here rather than passing on a poke at the state. The hint fills its cell
## with the answer, so the loop below steps over it with no special case.
func _solve_sudoku() -> void:
	# Board fit check: every cell centre must land inside the board slot.
	var Gen = load("res://puzzles/sudoku_gen.gd")
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in Gen.N:
		for c in Gen.N:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_press(_host.top_bar.hint_button)
	_press(_host.action_bar.check_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	for i in Gen.CELLS:
		if _puzzle.is_done():
			return
		var d: int = _puzzle.state.sol[i]
		if _puzzle.state.grid[i] == d:
			continue
		_tap_local(_puzzle.cell_to_local(i / Gen.N, i % Gen.N))
		_tap_key("Digit%d" % (d - 1))

## Fairy Lights: every piece that is out of place turned to its proven
## orientation **through the ordinary tap** -- one quarter turn a touch, up
## to three of them a cell, on the board's own `_gui_input`. **Nothing here
## writes to `grid`**: the harness's whole job is to prove the real move path
## reaches the win, and a state poke would prove only that the state class
## works, which its own suite entry already does.
##
## The last piece is left to the hint, the way _solve_queens leaves the n-th
## queen and _solve_mushroom the last mushroom, so the win comes through the
## hint path as well as through the tap path -- a hint here settles a cell
## *and* pins it, and pinning the cell that finishes the board is the one
## order in which `hint()` has to run `check_solved()` itself. There is no
## Check on this board -- nothing wrong can exist on it -- so `_hud_ok`
## watches the hint alone, as Word Trail's and Quilt's do.
func _solve_fairylights() -> void:
	var Gen = load("res://puzzles/fairy_lights_gen.gd")
	var st = _puzzle.state
	# Board fit check: every cell centre must land inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in st.n:
		for c in st.n:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	var wrong: Array = []
	for i in st.n * st.n:
		if st.grid[i] != st.sol[i]:
			wrong.append(i)
	# A deal that came out all but solved would leave the hint nothing to do;
	# the generator's 60% rule makes that impossible, and this is the guard
	# rather than the plan.
	if wrong.size() < 2:
		_press(_host.top_bar.hint_button)
		_hud_ok = _puzzle.hints_used == 1
	for k in range(wrong.size() - 1):
		if _puzzle.is_done():
			return
		var i: int = wrong[k]
		var m: int = st.grid[i]
		# However many quarter turns clockwise it takes, one tap each.
		for _q in 3:
			if m == st.sol[i]:
				break
			_tap_local(_puzzle.cell_to_local(i / st.n, i % st.n))
			m = Gen.cw(m)
	if wrong.size() >= 2:
		_press(_host.top_bar.hint_button)
		_hud_ok = _puzzle.hints_used == 1

## One tap on a key of the keyboard tray or a chip of the digit pad, found by
## the name that tray gives it.
func _tap_key(key_name: String) -> void:
	if _host.get("tray") == null:
		return
	var chip = _host.tray.find_child(key_name, true, false)
	if chip is Button:
		_press(chip)

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
	var Gen = load("res://legacy/puzzles/snake_gen.gd")
	var path: Array = Gen.solve(w, h, _puzzle._walls, _puzzle._apples, _puzzle._hole,
		_puzzle._snake, _puzzle._eaten)
	for d in path:
		if _puzzle.is_done():
			return
		var ahead: Vector2i = _puzzle._snake[0] + d
		_tap_local(_puzzle.cell_to_local(ahead.y, ahead.x))
