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
## True while a solver that awaits is still playing: the slots stand still.
var _waiting := false
var _late := 0

func _initialize() -> void:
	# No card is `soon` any more (the last one, Pipes, gave up its slot to
	# Word Trail on 2026-09-20), but the guard stays for whenever a board is
	# next named before it is drawn: a `soon` card has no script to open, so
	# the harness walks only the entries that do.
	# A harness plays the real game: its solves must not land in the
	# player's own save, where they mark today's boards done.
	# Cleared every run: a board this file already holds as solved today opens
	# straight onto its win screen, and the solver's taps land on its buttons
	# (six boards read "host or board freed" that way on 2026-09-25).
	var progress_path := "user://progress_harness.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress_path))
	var progress = load("res://core/progress.gd")
	progress.path = progress_path
	_entries = []
	# `-- <id> ...` walks only those boards.
	var only := OS.get_cmdline_user_args()
	for e in load("res://ui/registry.gd").all():
		if not only.is_empty() and not only.has(String(e.id)):
			continue
		if not e.get("soon", false):
			_entries.append(e)
			progress.mark_tutorial_seen(String(e.id))
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _process(_delta: float) -> bool:
	# A board whose win takes wall time (How Big?'s rounds) holds the walk
	# until its solver is through.
	if _waiting:
		return false
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
		# A card that asks for its difficulty would put the sheet up instead.
		if bool(_entries[_idx].get("pick_difficulty", false)):
			_menu._open_at(_entries[_idx], 1)
		else:
			_menu._open(_entries[_idx])
		_host = _menu.get_child(_menu.get_child_count() - 1)
		# The first-play tutorial would cover the board and eat every tap: the
		# harness's own progress file has never seen one.
		if _host.has_node("HowToPlay"):
			_host.get_node("HowToPlay").free()
			_host._hold_clock(false)
	elif slot == 12:
		_puzzle = _host._puzzle
		_fit_ok = true
		_hud_ok = true
		_solve(_entries[_idx].id)
	elif slot == 20 and not (is_instance_valid(_host) and is_instance_valid(_puzzle)):
		# The board or its host went away under the harness: record it and
		# move on, rather than erroring on the same board for ever.
		_results.append({"id": _entries[_idx].id, "solved": false, "done": false,
			"overlay": false, "ok": false, "note": "host or board freed before the check"})
		if is_instance_valid(_host):
			_host.closed.emit()
		_idx += 1
		_frames = 26
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
	elif slot == 26 and OS.has_environment("WIN_LATE") and _late < 260:
		# `WIN_LATE=1`: stand still until the win screen has settled and
		# shoot it to /tmp/won_<id>_late.png.
		_late += 1
		_frames -= 1
		if _late == 260:
			root.get_texture().get_image().save_png("/tmp/won_%s_late.png" % _entries[_idx].id)
	elif slot == 26:
		_late = 0
		_host.closed.emit()
		_idx += 1
	return false

func _note(id: String) -> String:
	match id:
		"binairo": return "%d moves, hints=%d checks=%d, camera fit=%s" % [_puzzle.moves, _puzzle.hints_used, _puzzle.checks, _fit_ok]
		"untangle": return "%d holes, %d ropes, %d moves, board fit=%s, hud=%s" % [_puzzle.state.holes, _puzzle.state.ropes, _puzzle.moves, _fit_ok, _hud_ok]
		"shikaku": return "%d plots, board fit=%s, hud=%s" % [_puzzle._rects.size(), _fit_ok, _hud_ok]
		"lightup": return "%d lanterns, board fit=%s, hud=%s" % [_puzzle._solution_bulbs.size(), _fit_ok, _hud_ok]
		"nonogram": return "%dx%d picture, camera fit=%s, hud=%s" % [_puzzle.w, _puzzle.h, _fit_ok, _hud_ok]
		"queens": return "%dx%d court, %d queens, board fit=%s, hud=%s" % [_puzzle.n, _puzzle.n, _puzzle.state.queens.size(), _fit_ok, _hud_ok]
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
		"picket": return "%dx%d, %d plots (%d lost), %d givens, %d moves, hints=%d, caps %s, board fit=%s, hud=%s" % [
			int(sqrt(_puzzle.state.sol.size())), int(sqrt(_puzzle.state.sol.size())), _puzzle.state.plots.size(),
			_puzzle.state.lost_count(), _puzzle.state.given.size() - _puzzle.state.given.count(0),
			_puzzle.moves, _puzzle.hints_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"fairylights": return "%dx%d garden, %d lanterns, %d turns, board fit=%s, hud=%s" % [
			_puzzle.state.n, _puzzle.state.n, _puzzle.state.lanterns().size(),
			_puzzle.state.turns, _fit_ok, _hud_ok]
		"quilt": return "%dx%d backing, %d patches, hints=%d, board fit=%s, hud=%s" % [
			_puzzle._state.cols, _puzzle._state.rows, _puzzle._state.shapes.size(),
			_puzzle.hints_used, _fit_ok, _hud_ok]
		"rings": return "%d pegs, %d colours, %d moves" % [
			_puzzle._state.pegs.size(), _puzzle._state.colours, _puzzle.moves]
		"caterpillar": return "%dx%d garden, %d leaves, %d strokes, hints=%d, board fit=%s, hud=%s" % [
			_puzzle._state.cols, _puzzle._state.rows, _puzzle._state.last_leaf(),
			_puzzle.moves, _puzzle.hints_used, _fit_ok, _hud_ok]
		"sunbeam": return "%dx%d floor, %d pieces, %d drops, %d slides, hints=%d, board fit=%s, hud=%s" % [
			_puzzle._state.cols, _puzzle._state.rows, _puzzle._state.pieces().size(),
			_puzzle._state.drops().size(), _puzzle.moves, _puzzle.hints_used, _fit_ok, _hud_ok]
		"knight": return "%dx%d board, %d rose knights, shortest %d, %d moves, hints=%d, board fit=%s, hud=%s" % [
			_puzzle._state.w, _puzzle._state.w, _puzzle._state.foes.size(), _puzzle._state.opt(),
			_puzzle.moves, _puzzle.hints_used, _fit_ok, _hud_ok]
		"slider": return "band %d, shortest %d, %d moves, hints=%d, board fit=%s, hud=%s" % [
			_puzzle._state.band, _puzzle._state.par, _puzzle.moves, _puzzle.hints_used, _fit_ok, _hud_ok]
		"hedgehogs": return "%dx%d lawn, %d hedgehogs, woken=%d, hints=%d, checks=%d, board fit=%s, hud=%s" % [
			_puzzle._state.cols(), _puzzle._state.rows(), int(_puzzle._state.g.k), _puzzle._state.woken,
			_puzzle.hints_used, _puzzle.checks, _fit_ok, _hud_ok]
		"patio": return "%dx%d, %d tiles (%d spare), %d beds, unique=%s, %d moves, hints=%d, caps %s, board fit=%s, hud=%s" % [
			_puzzle._st.cols, _puzzle._st.rows, _puzzle._st.laid_count(), _puzzle._st.tiles.size() - _puzzle._st.laid_count(),
			_puzzle._st.beds.size(), _puzzle._st.unique, _puzzle.moves, _puzzle.hints_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"market": return "%s -> %d, par %d, %d steps, stars=%d, hints=%d, caps %s, board fit=%s, hud=%s" % [
			str(_puzzle._st.numbers), _puzzle._st.target, _puzzle._st.par, _puzzle._st.steps, _puzzle._st.stars(),
			_puzzle.hints_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"hoses": return "%dx%d, %d hoses (%d seeds), %d strokes, hints=%d, caps %s, board fit=%s, hud=%s" % [
			_puzzle._st.n, _puzzle._st.n, _puzzle._st.count(), _puzzle._st.seeds.size(), _puzzle._st.strokes,
			_puzzle.hints_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"honeycomb": return "%s/%s, %d words, honey %d of %d (line %d), %d misses, flights %d, hints=%d, caps %s, board fit=%s, hud=%s" % [
			_puzzle._st.letters, _puzzle._st.first_queen, _puzzle._st.found.size(), _puzzle._st.honey, _puzzle._st.total, _puzzle._st.goal,
			_puzzle._st.misses, _puzzle._st.flights, _puzzle.hints_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"pie": return "%dx%d, %d ate, dish %d, %d marks, %d slips, hints=%d, caps %s, board fit=%s, hud=%s" % [
			_puzzle._st.cols, _puzzle._st.rows, _puzzle._st.eaters(), _puzzle._st.dish, _puzzle.moves, _puzzle._st.slips,
			_puzzle.hints_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"clues": return "band %d, %s, results %s, hints=%d, caps %s, board fit=%s, hud=%s" % [
			_puzzle._st.band, _puzzle._st.source, str(_puzzle._st.results), _puzzle.hints_used,
			_puzzle.capabilities(), _fit_ok, _hud_ok]
		"shelves": return "band %d, %s, %d of %d shelves, %d mistakes, %d hearts, hints=%d, caps %s, board fit=%s, hud=%s" % [
			_puzzle._st.band, _puzzle._st.source, _puzzle._st.shelved.size(), _puzzle._st.count(), _puzzle._st.mistakes,
			_puzzle._st.hearts, _puzzle.hints_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"paperbox": return "band %d, %d rounds, %d wrong picks %s, hints=%d, caps %s, board fit=%s, hud=%s" % [
			_puzzle._st.band, _puzzle._st.current, _puzzle._st.wrongs, str(_puzzle._st.wrong_in),
			_puzzle.hints_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"teacups": return "%dx%d, %d pairs, %d lifts, %d misses, %d lapses, hints=%d, caps %s, board fit=%s, hud=%s" % [
			_puzzle._st.cols(), _puzzle._st.rows(), _puzzle._st.pairs(), _puzzle._st.lifts, _puzzle._st.misses,
			_puzzle._st.lapses, _puzzle.hints_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"birdsong": return "%d bpm, %d slots, %d knocks, %d rounds, %d clean, %d slips, good %d ok %d, hints=%d, caps %s, board fit=%s, hud=%s" % [
			_puzzle._st.bpm(), _puzzle._st.grid(), _puzzle._st.order.size(), _puzzle._st.rounds(), _puzzle._st.clean,
			_puzzle._st.slips, _puzzle._st.goods, _puzzle._st.oks, _puzzle.hints_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"glimpse": return "%dx%d, %d beads, %d right first, looks %d, caps %s, board fit=%s, hud=%s" % [
			_puzzle._state.n, _puzzle._state.n, _puzzle._state.target, _puzzle._state.first_right(),
			_puzzle.looks_used, _puzzle.capabilities(), _fit_ok, _hud_ok]
		"pixelgarden": return "%s %dx%d, %d beads, %d moves, hints=%d, checks=%d, board fit=%s, hud=%s" % [
			_puzzle._state.pic_id, _puzzle._state.n, _puzzle._state.n, _puzzle._state.target,
			_puzzle.moves, _puzzle.hints_used, _puzzle.checks, _fit_ok, _hud_ok]
		"trestle": return "gap %d, cost %d of %d, %d members, %d tests, hints=%d, board fit=%s, hud=%s" % [
			int(_puzzle.state.level.w), _puzzle.state.cost(), _puzzle.state.budget, _puzzle.state.design.size(),
			_puzzle.checks, _puzzle.hints_used, _fit_ok, _hud_ok]
		"minigolf": return "band %d, %d holes, par %d, card %s, hints=%d, board fit=%s, hud=%s" % [
			_puzzle._state.band, _puzzle._state.holes.size(), _puzzle._state.par_total(), str(_puzzle._state.card),
			_puzzle.hints_used, _fit_ok, _hud_ok]
		"horse": return "%dx%d meadow, %d of %d bales, pen %d of target %d (best %d), hints=%d, checks=%d, board fit=%s, hud=%s" % [
			_puzzle.state.w, _puzzle.state.h, _puzzle.state.bales(), _puzzle.state.budget, _puzzle.state.score(),
			_puzzle.state.target, _puzzle.state.best, _puzzle.hints_used, _puzzle.checks, _fit_ok, _hud_ok]
		"how_big": return "band %d, %d rounds, scores %s, %d of %d, hints=%d, checks=%d, board fit=%s, hud=%s" % [
			_puzzle.state.band, _puzzle.state.round_count(), str(_puzzle.completion_record().scores), _puzzle.state.total(),
			_puzzle.state.best_total(), _puzzle.hints_used, _puzzle.checks, _fit_ok, _hud_ok]
		"acorn": return "band %d, %d questions (%s), %d right, hints=%d, checks=%d, board fit=%s, hud=%s" % [
			_puzzle.state.band, _puzzle.state.count(), _puzzle.state.source, _puzzle.state.rights(),
			_puzzle.hints_used, _puzzle.checks, _fit_ok, _hud_ok]
		"gumdrop": return "band %d, %d moulds, served at %s in %d serves, board fit=%s, hud=%s" % [
			_puzzle.band, _puzzle.sim.moulds.size(), str(_puzzle.sim.marks), _puzzle.moves, _fit_ok, _hud_ok]
		"hoop": return "band %d, %d panels (%s), %d pins, %d sides, %d refused, best combo %d, hints=%d, board fit=%s, hud=%s" % [
			_puzzle.state.band, _puzzle.state.panels.size(), _puzzle.state.name_key, _puzzle.state.pins.size(),
			_puzzle.state.sides.size(), _puzzle.state.refused, _puzzle._best, _puzzle.hints_used, _fit_ok, _hud_ok]
		"train": return "band %d, %d blocks on %d by %d (%s), %d engines, %d sent (par %d), %d in the siding, jammed=%s, hints=%d, board fit=%s, hud=%s" % [
			_puzzle.state.band, _puzzle.state.count(), _puzzle.state.w, _puzzle.state.h, _puzzle.state.name_key,
			_puzzle.state.colour.size(), _puzzle.state.taps, _puzzle.state.par, _puzzle.state.parked(),
			str(_puzzle.state.jammed), _puzzle.hints_used, _fit_ok, _hud_ok]
		"buttons": return "band %d, %d buttons on %d by %d (%s), %d taps (par %d), tin %d of %d, %d left of %d, hints=%d, board fit=%s, hud=%s" % [
			_puzzle.state.band, _puzzle.state.count(), _puzzle.state.w, _puzzle.state.h, _puzzle.state.name_key,
			_puzzle.state.taps, _puzzle.state.par, _puzzle.state.in_tin(), _puzzle.state.capacity(),
			_puzzle.moves_left, _puzzle.max_moves, _puzzle.hints_used, _fit_ok, _hud_ok]
		"lattice": return "band %d, %d tiles on %d by %d, %d knots, %d swaps (par %d), %d left of %d, hints=%d, board fit=%s, hud=%s" % [
			_puzzle.state.band, _puzzle.state.count(), _puzzle.state.n, _puzzle.state.n, _puzzle.state.knots.size(),
			_puzzle.state.swaps, _puzzle.state.par, _puzzle.moves_left, _puzzle.max_moves, _puzzle.hints_used, _fit_ok, _hud_ok]
		"pearl": return "band %d, %d prompts (%s), %d m of %d, %d pearls, hints=%d, checks=%d, board fit=%s, hud=%s" % [
			_puzzle.state.band, _puzzle.state.count(), _puzzle.state.source, _puzzle.state.depth(),
			_puzzle.state.floor_depth(), _puzzle.state.pearls(), _puzzle.hints_used, _puzzle.checks, _fit_ok, _hud_ok]
		"pinwheel": return "%dx%d frame, %d pieces, %d taps, hints=%d, board fit=%s, hud=%s" % [
			_puzzle._state.cols, _puzzle._state.rows, _puzzle._state.shapes.size(),
			_puzzle.moves, _puzzle.hints_used, _fit_ok, _hud_ok]
	return ""

# --- per-puzzle solvers, all driven through touch ---

func _solve(id: String) -> void:
	match id:
		"binairo": _solve_binairo()
		"untangle": _solve_untangle()
		"shikaku": _solve_shikaku()
		"lightup": _solve_lightup()
		"nonogram": _solve_nonogram()
		"queens": _solve_queens()
		"wordtrail": _solve_wordtrail()
		"bridges": _solve_bridges()
		"planes": _solve_planes()
		"hiddenword": _solve_hiddenword()
		"sudoku": _solve_sudoku()
		"picket": _solve_picket()
		"quilt": _solve_quilt()
		"rings": _solve_rings()
		"fairylights": _solve_fairylights()
		"pinwheel": _solve_pinwheel()
		"caterpillar": _solve_caterpillar()
		"sunbeam": _solve_sunbeam()
		"knight": _solve_knight()
		"hedgehogs": _solve_hedgehogs()
		"slider": _solve_slider()
		"pixelgarden": _solve_pixelgarden()
		"glimpse": _solve_glimpse()
		"birdsong": _solve_birdsong()
		"patio": _solve_patio()
		"teacups": _solve_teacups()
		"paperbox": _solve_paperbox()
		"shelves": _solve_shelves()
		"clues": _solve_clues()
		"market": _solve_market()
		"pie": _solve_pie()
		"hoses": _solve_hoses()
		"honeycomb": _solve_honeycomb()
		"trestle": _solve_trestle()
		"minigolf": _solve_minigolf()
		"horse": _solve_horse()
		"how_big": _solve_how_big()
		"acorn": _solve_acorn()
		"pearl": _solve_pearl()
		"lattice": _solve_lattice()
		"buttons": _solve_buttons()
		"train": _solve_train()
		"hoop": _solve_hoop()
		"gumdrop": _solve_gumdrop()

## Gumdrop's syrup is a fluid on the GPU, so nothing here can pour it in a
## frame: each mould's cells are filled as the card has them (the sim's
## prefill, a tutorial page's), given a second to land, and served with a
## press on the table's own button. It takes wall time, so this one awaits
## and holds the walk (`_waiting`) to the win.
func _solve_gumdrop() -> void:
	_waiting = true
	var sim = _puzzle.sim
	var table = _puzzle.table
	_fit_ok = Rect2(Vector2.ZERO, table.field.size).encloses(table._tray)
	_hud_ok = table.clear.x > 0.0 and table._card.position.y >= table.clear.x
	for i in sim.moulds.size():
		var guard := 0
		while (sim.index != i or int(sim.phase) > 1) and guard < 900:
			guard += 1
			await process_frame
		for c in sim.mould.want.size():
			sim.filled(c, int(sim.mould.want[c]), 1.0)
		await create_timer(1.2).timeout
		var at: Vector2 = table.field.get_global_transform_with_canvas() * table._serve_at
		for down in [true, false]:
			var ev := InputEventScreenTouch.new()
			ev.index = 0
			ev.pressed = down
			ev.position = root.get_final_transform() * at
			Input.parse_input_event(ev)
			Input.flush_buffered_events()
	var wait := 0
	while not _puzzle.is_done() and wait < 900:
		wait += 1
		await process_frame
	_hud_ok = _hud_ok and _puzzle.moves == sim.moulds.size()
	_waiting = false

func _solve_binairo() -> void:
	var n: int = _puzzle.n
	# Camera fit check: every cell centre must project inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in n:
		for c in n:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The HUD's own button: one hint (fills and locks a cell). Binairo has had
	# no Check since 2026-10-13 (no actions row).
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1
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

## Untangle: every peg is dragged along a shortest way home the board's own
## solver finds, one drag at a time through touch, settling between them (the
## harness plays a move a frame, the board takes a fraction of a second).
func _solve_untangle() -> void:
	var st = _puzzle.state
	# Fit check: every hole must land inside the board slot.
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for h in st.holes:
		if not slot.has_point(_puzzle.hole_to_local(h)):
			_fit_ok = false
	# One hint through the HUD: it moves a peg along the way home.
	_press(_host.top_bar.hint_button)
	_puzzle.settle_now()
	_hud_ok = _puzzle.hints_used == 1
	for step in 40:
		if _puzzle.is_done() or st.is_solved():
			break
		var way = st.hint_step()
		if way.is_empty():
			break
		_drag_local(_puzzle.peg_to_local(way[0]), _puzzle.hole_to_local(way[2]))
		_puzzle.settle_now()
	_puzzle.settle_now()
	_puzzle.check_solved()

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
## Caterpillar: one hint through the HUD, which grows the answer from leaf 1
## to the next leaf, then one drag from the head along the rest of the
## answer -- the whole board in two strokes, the second of them real touch.
func _solve_caterpillar() -> void:
	var st = _puzzle._state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in st.rows:
		for c in st.cols:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1 and st.body.size() > 1
	var pts: Array[Vector2] = []
	for i in range(st.body.size() - 1, st.path.size()):
		var c: int = st.path[i]
		pts.append(_puzzle.cell_to_local(c / st.cols, c % st.cols))
	_drag_path_local(pts)

## Sunbeam: one hint through the HUD, which slides the first piece along the
## answer's beam home and pins it, then every other piece dragged home along
## its rail by real touch, a peg a step. A piece whose home another piece is
## standing on waits for a later pass; after two passes with nothing moved,
## the blocker is dragged to any free peg first.
## Super Slider: one hint through the HUD, which slides the next block of a
## shortest way out, then the rest of the way dragged block by block by real
## touch, the finger passing every cell of the block's path so a slide round
## a corner goes the way the solver meant.
func _solve_slider() -> void:
	var st = _puzzle._state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in 5:
		for c in 4:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1 and st.history.size() == 1
	for i in 400:
		if st.is_solved():
			break
		var m: Dictionary = st.hint_move()
		if m.is_empty():
			break
		var pts: Array[Vector2] = []
		for c: int in m.path:
			pts.append(_puzzle.cell_to_local(c / 4, c % 4))
		_drag_path_local(pts)

## Mini Golf: the bulb pressed once, then the steady putt from every lie,
## each a press, a pull back and a release, the roll played out at once
## (settle_now: a putt takes seconds this harness does not have).
func _solve_minigolf() -> void:
	var st = _puzzle._state
	_fit_ok = Rect2(Vector2.ZERO, _puzzle.size).has_point(_puzzle.ball_at())
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1
	_puzzle._drop_think()
	for i in 80:
		if st.is_solved():
			break
		var shot: Dictionary = st.sim.best_shot()
		var from: Vector2 = _puzzle.size * Vector2(0.5, 0.6)
		var to: Vector2 = _puzzle.pull_for(from, float(shot.a), float(shot.u))
		var pts: Array[Vector2] = [from, from.lerp(to, 0.5), to]
		_drag_path_local(pts)
		_puzzle.settle_now()

## Horse Pen: Submit pressed first on the open field (a not-yet, never an
## ending), the bulb once where there is one, then the rest of the answer's
## bales tapped in and Submit pressed again.
func _solve_horse() -> void:
	var st = _puzzle.state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for c in st.cells():
		if not slot.has_point(_puzzle.cell_centre(c)):
			_fit_ok = false
	_press_check()
	_hud_ok = _puzzle.checks == 1 and not st.is_solved()
	if _puzzle.capabilities().has("hint"):
		_press(_host.top_bar.hint_button)
		_hud_ok = _hud_ok and _puzzle.hints_used == 1 and st.pinned.size() == 1
	for c: int in st.m.sol:
		if not st.has_bale(c):
			_tap_local(_puzzle.cell_centre(c))
	_hud_ok = _hud_ok and st.closed() and st.score() == st.best
	_press_check()

## Golden Acorn: every question answered through the input path -- a touch
## on the right answer's plate, then the row's button to lock and again for
## the next (after the last, to finish) -- with the bulb once on the first
## question. The deal follows the open by a frame (or by the network), a
## lock's answer is held for a breath and Next waits for the plates to
## leave, so this one awaits, and holds the walk (`_waiting`) to the win.
func _solve_acorn() -> void:
	_waiting = true
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	var guard := 0
	while _puzzle.state.count() == 0 and guard < 900:
		guard += 1
		await process_frame
	var st = _puzzle.state
	var hint_ok := true
	for r in st.count():
		# the question asked and standing (the board's Phase: 1 PLAY)
		guard = 0
		while (st.index != r or int(_puzzle._phase) != 1) and guard < 600:
			guard += 1
			await process_frame
		await create_timer(0.6).timeout
		for i in 4:
			if not slot.has_point(_puzzle.plate_point(i)):
				_fit_ok = false
		if r == 0 and _puzzle.capabilities().has("hint"):
			_press(_host.top_bar.hint_button)
			hint_ok = _puzzle.hints_used == 1 and not st.is_cut(st.right_place())
		_tap_local(_puzzle.plate_point(st.right_place()))
		_press_check()
		_hud_ok = _hud_ok and st.locked() and bool(st.results[r].right)
		await create_timer(1.6).timeout
		_press_check()
		if r + 1 < st.count():
			await create_timer(0.4).timeout
			_hud_ok = _hud_ok and st.index == r + 1
	_hud_ok = _hud_ok and hint_ok and _puzzle.checks == st.count() and st.perfect()
	var wait := 0
	while not _puzzle.is_done() and wait < 600:
		wait += 1
		await process_frame
	_waiting = false

## Lattice: a tile at home tapped (refused), the bulb once where there is
## one, one swap of the answer by a drag and the rest by two taps each. A
## tile in the air is not picked up, so this one awaits between swaps, and
## holds the walk (`_waiting`) to the win.
func _solve_lattice() -> void:
	_waiting = true
	var st = _puzzle.state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for c in st.count():
		if not slot.has_point(_puzzle.cell_centre(c)):
			_fit_ok = false
	await create_timer(0.8).timeout
	for c in st.count():
		if st.is_home(c):
			_tap_local(_puzzle.cell_centre(c))
			break
	_hud_ok = st.swaps == 0
	if _puzzle.capabilities().has("hint"):
		# made fun: the first press reads (a square rimmed, the toast says
		# why, nothing swapped), the second makes the swap
		_press(_host.top_bar.hint_button)
		_hud_ok = _hud_ok and _puzzle.hints_used == 1 and st.swaps == 0 \
			and not _puzzle._reading.is_empty() and _puzzle._card_toast.text != ""
		await create_timer(0.4).timeout
		_press(_host.top_bar.hint_button)
		_hud_ok = _hud_ok and _puzzle.hints_used == 1 and st.swaps == 1 and _puzzle._reading.is_empty()
		await create_timer(0.4).timeout
		print("lattice: bulb read and swapped, hud=%s, stars %d" % [_hud_ok, _puzzle._stars.stars])
	var dragged := false
	var guard := 0
	while not st.is_solved() and guard < 60:
		guard += 1
		var pair: Array = st.hint()
		var before: int = st.swaps
		if not dragged:
			dragged = true
			_drag_local(_puzzle.cell_centre(pair[0]), _puzzle.cell_centre(pair[1]))
		else:
			_tap_local(_puzzle.cell_centre(pair[0]))
			_tap_local(_puzzle.cell_centre(pair[1]))
		_hud_ok = _hud_ok and st.swaps == before + 1
		await create_timer(0.4).timeout
	_hud_ok = _hud_ok and st.is_solved() and (_puzzle.max_moves == 0 or _puzzle.moves_left == _puzzle.max_moves - st.swaps)
	var wait := 0
	while not _puzzle.is_done() and wait < 600:
		wait += 1
		await process_frame
	_waiting = false

## Toy Cannons: a buried engine tapped (refused), the bulb once where there is
## one, then the deal's own line, an engine at a time through the board's
## input, each sent when the loop is empty (the way the line was proved).
## The loop runs on its clock, so this one awaits, and holds the walk
## (`_waiting`) to the win.
## Yarn Hoop: the bulb once, then every side still open dragged pin to pin
## through the window, as a finger would.
func _solve_hoop() -> void:
	_waiting = true
	var st = _puzzle.state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for v in st.pins.size():
		_fit_ok = _fit_ok and slot.has_point(_puzzle.pin_screen(v))
	await create_timer(0.8).timeout
	_hud_ok = true
	if _puzzle.capabilities().has("hint"):
		_press(_host.top_bar.hint_button)
		await create_timer(1.0).timeout
		_hud_ok = _puzzle.hints_used == 1 and st.threads == 1
	var guard := 0
	for s in st.sides.size():
		if st.laid[s]:
			continue
		var sd: Vector2i = st.sides[s]
		_drag_local(_puzzle.pin_screen(sd.x), _puzzle.pin_screen(sd.y))
		guard += 1
		if guard % 8 == 0:
			await process_frame
	_waiting = false

func _solve_train() -> void:
	_waiting = true
	var st = _puzzle.state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = slot.encloses(_puzzle._rug) and slot.encloses(_puzzle._siding_rect) and slot.encloses(_puzzle._shed_rect)
	await create_timer(0.8).timeout
	_hud_ok = true
	for column: PackedInt32Array in st.sheds:
		if column.size() > 1:
			_tap_local(_puzzle.engine_screen(column[1]))
			_hud_ok = st.taps == 0
			break
	var sent := {}
	if _puzzle.capabilities().has("hint"):
		var pick: int = st.hint()
		_press(_host.top_bar.hint_button)
		await create_timer(1.0).timeout
		_hud_ok = _hud_ok and _puzzle.hints_used == 1 and st.taps == 1
		sent[pick] = true
	# the line's order, but for the engine the bulb already sent: the state's
	# own hand finishes what the line cannot
	var guard := 0
	var i := 0
	while not st.is_solved() and not st.jammed and guard < 4000:
		guard += 1
		if not st.idle():
			await create_timer(0.1).timeout
			continue
		var e := -1
		if sent.is_empty() and i < st.line.size():
			e = st.line[i]
			i += 1
		else:
			e = st.hint()
		if e < 0:
			break
		var before: int = st.taps
		_tap_local(_puzzle.engine_screen(e))
		_hud_ok = _hud_ok and st.taps == before + 1
		await create_timer(0.1).timeout
	_hud_ok = _hud_ok and st.is_solved() and st.parked() == 0
	var wait := 0
	while not _puzzle.is_done() and wait < 600:
		wait += 1
		await process_frame
	_waiting = false

## Button Box: a sewn button tapped where there is one (refused), the bulb
## once where there is one, then the state's own moves, each a pick and a
## tap on where it goes (a bare patch or the tin), through the board's input. A button still in the air is not lifted, so this one
## awaits between taps, and holds the walk (`_waiting`) to the win.
func _solve_buttons() -> void:
	_waiting = true
	var st = _puzzle.state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = slot.encloses(_puzzle._tin_rect)
	for c in st.slot.size():
		if st.slot[c] >= 0 and not slot.has_point(_puzzle.cell_centre(c)):
			_fit_ok = false
	await create_timer(0.8).timeout
	for c in st.slot.size():
		if st.slot[c] >= 0 and st.is_home(c):
			_tap_local(_puzzle.cell_centre(c))
			break
	_hud_ok = st.taps == 0
	if _puzzle.capabilities().has("hint"):
		_press(_host.top_bar.hint_button)
		# the bulb picks, and half a second on says where
		_hud_ok = _hud_ok and _puzzle.hints_used == 1 and _puzzle.holding() and st.taps == 0
		await create_timer(1.2).timeout
		_hud_ok = _hud_ok and st.taps == 1
	var guard := 0
	while not st.is_solved() and guard < 600:
		guard += 1
		var before: int = st.taps
		var move: Dictionary = st.hint()
		# a pick stays picked after its move: put it down before the next
		if _puzzle.holding():
			_puzzle._drop()
		if (move.cells as PackedInt32Array).is_empty():
			_tap_local(_puzzle.tin_centre(move.places[0]))
		else:
			_tap_local(_puzzle.cell_centre(move.cells[0]))
		_hud_ok = _hud_ok and _puzzle.holding() and st.taps == before
		await create_timer(0.15).timeout
		if int(move.to) >= 0:
			_tap_local(_puzzle.cell_centre(int(move.to)))
		else:
			_tap_local(_puzzle.tin_centre(mini(st.in_tin(), st.capacity() - 1)))
		_hud_ok = _hud_ok and st.taps == before + 1
		# a run leaves one jewel after another, and a tap on one still in
		# the air is dropped: wait for the last to land
		await create_timer(maxf(0.45, _puzzle._last_land - _puzzle._now() + 0.3)).timeout
	_hud_ok = _hud_ok and st.is_solved() and st.in_tin() == 0
	var wait := 0
	while not _puzzle.is_done() and wait < 600:
		wait += 1
		await process_frame
	_waiting = false

## Pearl Dive: every prompt answered through the way in a player has -- the
## tray's own keys pressed with a touch, letter by letter, and its Enter to
## dive, to offer the line and to ask the next -- with the bulb once on the
## first prompt, a line the list does not hold on the second, and the Pearl
## typed everywhere else. The deal follows the open by a frame (or by the
## network) and a prompt takes a moment to change, so this one awaits, and
## holds the walk (`_waiting`) to the win.
func _solve_pearl() -> void:
	_waiting = true
	var S = load("res://puzzles/pearl_state.gd")
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	# the phone's keyboard types into the board's own field (2026-10-29)
	var field: LineEdit = _puzzle._field_edit
	var key := func(ch: String) -> void:
		field.text += ch
		field.text_changed.emit(field.text)
	var enter := func() -> void: field.text_submitted.emit(field.text)
	var guard := 0
	while _puzzle.state.count() == 0 and guard < 900:
		guard += 1
		await process_frame
	var st = _puzzle.state
	_fit_ok = _fit_ok and slot.has_point(_puzzle.field_point())
	await create_timer(0.6).timeout
	enter.call()
	var hint_ok := true
	var miss_ok := true
	for r in st.count():
		# the prompt asked and standing (the board's Phase: 2 PLAY)
		guard = 0
		while (st.index != r or int(_puzzle._phase) != 2) and guard < 600:
			guard += 1
			await process_frame
		await create_timer(0.3).timeout
		if r == 0 and _puzzle.capabilities().has("hint"):
			_press(_host.top_bar.hint_button)
			hint_ok = _puzzle.hints_used == 1 and not st.told().is_empty()
			# the second press on the same prompt is free and shows more
			_press(_host.top_bar.hint_button)
			hint_ok = hint_ok and _puzzle.hints_used == 1 and str(st.told().more) != ""
		if r == 1:
			# a fair try misspelt is free; a line the list lacks is not
			if S.norm(st.pearl_name()).length() >= S.CLOSE_FROM:
				for ch in S.norm(st.pearl_name()).substr(0, 2) + "qq" + S.norm(st.pearl_name()).substr(2):
					key.call(ch)
				enter.call()
				miss_ok = st.misses == 0 and not st.answered() and field.text != ""
				field.text = ""
				field.text_changed.emit("")
			for ch in "zzzqx":
				key.call(ch)
			enter.call()
			miss_ok = miss_ok and st.misses == 1 and not st.answered()
		for ch in S.norm(st.pearl_name()):
			key.call(ch)
		enter.call()
		_hud_ok = _hud_ok and st.answered() and int(st.results[r].t) == S.PEARL
		await create_timer(1.3).timeout
		enter.call()
	_hud_ok = _hud_ok and hint_ok and miss_ok and st.pearls() == st.count() and st.depth() == st.floor_depth()
	var wait := 0
	while not _puzzle.is_done() and wait < 600:
		wait += 1
		await process_frame
	_waiting = false

## How Big?: every round sized through the input path -- a touch pressed on
## the grip, dragged to where the answer reads its truth, let go -- then the
## row's button to lock and again for the next, with the bulb once on the
## first round. A lock waits a beat after the deal and Next for the pair to
## walk off, so this one awaits, and holds the walk (`_waiting`) to the win.
func _solve_how_big() -> void:
	_waiting = true
	var st = _puzzle.state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	var hint_ok := true
	for r in st.round_count():
		# the round dealt and standing (the board's Phase: 0 PLAY)
		var guard := 0
		while (st.index != r or int(_puzzle._phase) != 0) and guard < 600:
			guard += 1
			await process_frame
		await create_timer(0.5).timeout
		if not slot.has_point(_puzzle.grip_point()) or not slot.has_point(_puzzle.grip_for(st.truth())):
			_fit_ok = false
		if r == 0 and _puzzle.capabilities().has("hint"):
			_press(_host.top_bar.hint_button)
			hint_ok = _puzzle.hints_used == 1
		# A press too near the answer's foot steers by the finger's rise, not
		# by the grip: a second drag from the grip's new place lands it.
		for _try in 3:
			if st.ratio_off(_puzzle._guess(), st.truth()) > 1.02:
				_drag_local(_puzzle.grip_point(), _puzzle.grip_for(st.truth()))
		_press_check()
		_hud_ok = _hud_ok and st.locked() and int(st.results[r].score) == 100
		if r + 1 < st.round_count():
			await create_timer(0.9).timeout
			_press_check()
			_hud_ok = _hud_ok and st.index == r + 1
	_hud_ok = _hud_ok and hint_ok and _puzzle.checks == st.round_count()
	var wait := 0
	while not _puzzle.is_done() and wait < 600:
		wait += 1
		await process_frame
	_waiting = false

func _solve_sunbeam() -> void:
	var st = _puzzle._state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in st.rows:
		for c in st.cols:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1 and st.pinned.size() == 1
	for pass_i in 12:
		var moved := false
		for p in st.pieces().size():
			var home: int = st.home(p)
			if st.pos[p] == home:
				continue
			if st.taken(p, home):
				continue
			_slide_sunbeam(p, home)
			moved = true
		if st.is_solved():
			break
		if not moved:
			for p in st.pieces().size():
				if st.pos[p] != st.home(p):
					for o in st.pieces().size():
						if o != p and not st.pinned.has(o) and st.cells_of(o, st.pos[o]).has(st.cells_of(p, st.home(p))[0]):
							for q in st.g.pieces[o].rail.size():
								if q != st.pos[o] and not st.taken(o, q):
									_slide_sunbeam(o, q)
									break
					break

func _slide_sunbeam(p: int, to: int) -> void:
	var from: int = _puzzle._state.pos[p]
	var pts: Array[Vector2] = []
	var step := 1 if to > from else -1
	var q := from
	pts.append(_puzzle._pt(_puzzle._piece_mid(p, float(q))))
	while q != to:
		q += step
		pts.append(_puzzle._pt(_puzzle._piece_mid(p, float(q))))
	_drag_path_local(pts)

## Knight: one hint through the HUD, pressed twice -- it rings the shortest
## line's next hop, then plays it for you -- then the rest of the line
## tapped square by square by real touch.
## The board ignores taps while its pieces travel, and this drives input
## synchronously, so each tap first clears that wait.
func _solve_knight() -> void:
	var st = _puzzle._state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in st.w:
		for c in st.w:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The harness drives synchronously a few frames after opening, inside
	# the board's entrance wait.
	_puzzle._busy_until = -100.0
	# The bulb in two presses (2026-10-29): the first rings the hop and
	# spends the hint, the second hops there for free.
	_press(_host.top_bar.hint_button)
	var rang: bool = _puzzle._reading >= 0 and st.history.size() == 0
	_press(_host.top_bar.hint_button)
	_hud_ok = rang and _puzzle.hints_used == 1 and st.history.size() == 1
	for i in 64:
		if st.is_solved():
			break
		var m: int = st.hint_move()
		if m < 0:
			break
		_puzzle._busy_until = -100.0
		_tap_local(_puzzle.cell_to_local(m / st.w, m % st.w))

## Hedgehogs: Check spent first on the opening, where nothing is flagged and
## it must find nothing wrong; one hint through the HUD; then every bare cell
## logic proves is raked by real touch with the rake chip the tray arms by
## default. A hedgehog logic proves is flagged through the state, since the
## win never needs a flag.
func _solve_hedgehogs() -> void:
	var st = _puzzle._state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in st.rows():
		for c in st.cols():
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_puzzle._busy_until = -100.0
	_press_check()
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1 and st.woken == 0
	for i in 400:
		if _puzzle.is_done():
			break
		var h: Dictionary = st.hint_step()
		if h.is_empty():
			break
		if h.kind == "flag":
			st.apply_hint(h)
			continue
		var c: int = h.cell
		_tap_local(_puzzle.cell_to_local(c / st.cols(), c % st.cols()))

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
	_press_check()
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	# Drag each solution rectangle corner to corner, exactly as a player would.
	for rect in _puzzle._solution:
		if _puzzle.is_done():
			return
		_drag_local(_puzzle.cell_to_local(rect.position.y, rect.position.x),
			_puzzle.cell_to_local(rect.position.y + rect.size.y - 1,
				rect.position.x + rect.size.x - 1))

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
	# The HUD's own buttons: the bulb twice (made fun: the first press reads,
	# a stone rimmed and the toast saying why, the second lights and pins
	# it), then one check.
	_press(_host.top_bar.hint_button)
	var read_ok: bool = not _puzzle._reading.is_empty() and _puzzle._toast.text != "" and _puzzle.state.lamps().is_empty()
	_press(_host.top_bar.hint_button)
	read_ok = read_ok and _puzzle._reading.is_empty() and _puzzle.state.lamps().size() == 1
	print("lightup: bulb read then pinned: %s" % read_ok)
	_press_check()
	_hud_ok = read_ok and _puzzle.hints_used == 1 and _puzzle.checks == 1
	for b in _puzzle._solution_bulbs:
		if _puzzle.is_done():
			return
		_tap_local(_puzzle.cell_to_local(b.y, b.x))

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
	_press_check()
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
	_press_check()
	for r in range(1, n):
		if _puzzle.is_done():
			return
		var cell := Vector2i(int(_puzzle.state.solution[r]), r)
		if _puzzle.state.queens.has(cell):
			continue
		# A tap cycles blank -> cross -> queen (d57e17a), so a queen is two.
		for k in 2:
			_tap_local(_puzzle.cell_to_local(r, cell.x))
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
	_press_check()
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
	# A Windy Day sky (Insane) is a timetable: any free plane can strand it,
	# so it is played in the state's own solve order, and it has no hints.
	var order: Array = st.solve_order() if st.windy() else []
	var guard := 0
	while not _puzzle.is_done() and guard < 400:
		guard += 1
		var free: Array[int] = st.free_planes()
		if free.is_empty():
			return
		var i: int = free[0]
		if not order.is_empty():
			i = order.pop_front()
		if st.left() == 1 and _puzzle.hints_left() > 0:
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
	# Laid out above a phone's keyboard 42% of the screen tall: the grid
	# over the phone's, and the board's own keys hidden.
	var osk: float = _puzzle.size.y * 0.42
	_puzzle.osk_override = osk
	_puzzle._watch_osk()
	var keys: Control = _puzzle._keys
	_fit_ok = _fit_ok and not keys.visible and _puzzle._origin().y + _puzzle._block().y <= _puzzle.size.y - osk \
		and _puzzle._cell() >= 40.0
	_puzzle.osk_override = -1.0
	_puzzle._watch_osk()
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.moves == 0 and _host.tray == null
	# A wrong word on the phone's keyboard (the board's unseen line): the
	# row commits, the line empties, and fewer words fit.
	var st = _puzzle.state
	var wrong := ""
	for w in st._answers:
		var f := Locale.fold(String(w))
		if f != st.answer and f.length() == State.LEN:
			wrong = f
			break
	var field: LineEdit = _puzzle._field
	field.text = wrong.to_upper()
	field.text_changed.emit(field.text)
	field.text_submitted.emit(field.text)
	_hud_ok = _hud_ok and st.rows == [wrong] and field.text == "" and st.words_left(1) < st.words_left(0)
	# The answer on the board's own keys, touched.
	var word: String = st.answer
	for i in word.length():
		var chip = keys.find_child("Key_%s" % word[i].to_upper(), true, false)
		if chip is Button:
			_press(chip)
	var enter = keys.find_child("Key_Enter", true, false)
	if enter is Button:
		_press(enter)

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
	_press_check()
	_hud_ok = _puzzle.hints_used == 1 and _puzzle.checks == 1
	for i in Gen.CELLS:
		if _puzzle.is_done():
			return
		var d: int = _puzzle.state.sol[i]
		if _puzzle.state.grid[i] == d:
			continue
		_tap_local(_puzzle.cell_to_local(i / Gen.N, i % Gen.N))
		_tap_key("Digit%d" % (d - 1))

## Picket Sums: Sudoku's path through the real pad -- the bulb first, then
## a wrong number into a two-cell plot's cell (its fence turns rose), taken
## out with the same number, then every cell from the answer.
func _solve_picket() -> void:
	var Gen = load("res://puzzles/sudoku_gen.gd")
	var st = _puzzle.state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in Gen.N:
		for c in Gen.N:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle.hints_used == 1
	for i in Gen.CELLS:
		if st.grid[i] == 0:
			var wrong: int = st.sol[i] % Gen.N + 1
			_tap_local(_puzzle.cell_to_local(i / Gen.N, i % Gen.N))
			_tap_key("Digit%d" % (wrong - 1))
			_tap_key("Digit%d" % (wrong - 1))
			# Let it go again, or the solve's first tap there would.
			_tap_local(_puzzle.cell_to_local(i / Gen.N, i % Gen.N))
			break
	for i in Gen.CELLS:
		if _puzzle.is_done():
			return
		var d: int = st.sol[i]
		if st.grid[i] == d:
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
	# A band with no hints (none since 2026-10-13): every piece is tapped
	# round, and the HUD check is only that nothing was spent.
	var hinted: bool = _puzzle.hints_left() > 0
	if not hinted:
		_hud_ok = _puzzle.hints_used == 0
	if hinted and wrong.size() < 2:
		_press(_host.top_bar.hint_button)
		_hud_ok = _puzzle.hints_used == 1
	for k in range(wrong.size() - (1 if hinted else 0)):
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
	if hinted and wrong.size() >= 2:
		_press(_host.top_bar.hint_button)
		_hud_ok = _puzzle.hints_used == 1

## Rings: the generator's own solver hands back the path that proved the
## day's deal solvable, and it is played back move by move through the
## board's real lift and drop -- a tap on the source peg's station, then on
## the destination's, with RenderingServer.force_draw() between the two
## letting a frame pass so the move the board just made is what actually
## reaches the screen before the next one starts, rather than racing the
## whole path through in one unrendered burst. Nothing here pokes `pegs`
## directly or calls state.drop -- only the board's own _tap does that.
func _solve_rings() -> void:
	var Gen = load("res://puzzles/rings_gen.gd")
	var path: Array = Gen.solve(_puzzle._state.pegs, Gen.NODE_BUDGET, _puzzle._state.cap)
	for m: Vector2i in path:
		if _puzzle.is_done():
			return
		_tap_local(_station_centre(m.x))
		RenderingServer.force_draw()
		_tap_local(_station_centre(m.y))
		RenderingServer.force_draw()

## The middle of peg `i`'s own station, comfortably inside _peg_at's hit
## column whatever the row it stands in.
func _station_centre(i: int) -> Vector2:
	var st: Dictionary = _puzzle._station(i)
	# A station is in the board's design space; in a world of its own the
	# board lays that space in a box under the host's rows.
	return _puzzle._box.position + Vector2(float(st["cx"]), (float(st["top"]) + float(st["ground"])) * 0.5) * _puzzle._s

## One tap on a key of the keyboard tray or a chip of the digit pad, found by
## the name that tray gives it.
func _tap_key(key_name: String) -> void:
	if _host.get("tray") == null:
		return
	var chip = _host.tray.find_child(key_name, true, false)
	if chip is Button:
		_press(chip)

## Pixel Garden: the hint seats (or fixes) one peg, Check rings nothing on a
## board with no wrong beads; then one wrong bead is seated and lifted again
## (a tap on a bead of the chosen colour lifts it), and every colour's chip
## is tapped and its pegs tapped in turn.
## Glimpse: the first show put down at once (a tap on the board), one
## wrong bead tapped (it hops home, a miss, a star falls), then every bead
## seated by tapping, as Pixel Garden's solve does; no hint, Check or Undo.
func _solve_glimpse() -> void:
	var st = _puzzle._state
	var n: int = st.n
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in n:
		for c in n:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	_puzzle._first_at = 0.0
	_puzzle._process(0.0)
	_tap_local(_puzzle.cell_to_local(n / 2, n / 2))
	_hud_ok = not _puzzle._showing() and _puzzle.capabilities().is_empty()
	# One miss: a bead the picture does not want there hops home at once,
	# a star falls and the toast says so.
	_tap_local(_puzzle.chip_to_local(0))
	for c in st.size():
		if int(st.want[c]) != 0 and int(st.beads[c]) == -1:
			_tap_local(_puzzle.cell_to_local(c / n, c % n))
			break
	_hud_ok = _hud_ok and _puzzle.misses == 1 and st.placed() == 0 and _puzzle._stars.stars == 2 \
		and _puzzle._toast == "GL_MISS_FIRST"
	for k in st.names.size():
		_tap_local(_puzzle.chip_to_local(k))
		for c in st.size():
			if _puzzle.is_done():
				return
			if int(st.want[c]) == k and int(st.beads[c]) != k:
				_tap_local(_puzzle.cell_to_local(c / n, c % n))

## Birdsong: the woodpecker's bar run on (the board's own clock stepped in
## 1/120 s) until it is the player's turn, then the round knocked back by
## tapping the drum on each knock's place; round two's last knock left out
## (a slip, found by the clock), and one bulb, on the way.
func _solve_birdsong() -> void:
	var st = _puzzle._st
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = slot.has_point(_puzzle.drum_to_local())
	_hud_ok = _puzzle.capabilities() == ["hint"] and _puzzle.hints_left() > 0
	var slipped := false
	var hinted := false
	var dt := 1.0 / 120.0
	for step in 40000:
		if _puzzle.is_done():
			return
		if _puzzle.phase() != _puzzle.Phase.PLAY:
			_puzzle._process(dt)
			continue
		if not hinted and st.round_no() == 1:
			hinted = true
			# the bulb knocks the round again and keeps its holes on the card
			_hud_ok = _hud_ok and _puzzle.hint() and _puzzle._peek
			continue
		var next: int = st.landed
		if st.started() and _puzzle.clock() < _puzzle.knock_due(next):
			_puzzle._process(dt)
			continue
		if not slipped and st.round_no() == 2 and next == st.knocks.size() - 1:
			slipped = true
			while st.slips == 0:
				_puzzle._process(dt)
			# the slip says why on the toast, and a star (bulb + slip) holds
			_hud_ok = _hud_ok and st.why == st.Why.MISSED and _puzzle._toast.text != "" \
				and _puzzle._stars.stars == 2
			print("birdsong slip toast: ", _puzzle._toast.text)
			continue
		_tap_local(_puzzle.drum_to_local())
		_puzzle._process(dt)

## Market Sums: a share that leaves a remainder refused (crate, sign, crate
## by real touches), the answer's first step made and taken back with Undo
## (Easy to Hard), the bulb through the real button, then the rest by the
## state's own shortest steps, each crate and sign tapped where it stands.
func _solve_market() -> void:
	var st = _puzzle._st
	var Gen = load("res://puzzles/market_gen.gd")
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for s in 6:
		if not slot.has_point(_puzzle.crate_to_local(s)):
			_fit_ok = false
	for o in 4:
		if not slot.has_point(_puzzle.sign_to_local(o)):
			_fit_ok = false
	var settle := func() -> void:
		for i in 40:
			if not _puzzle.sliding():
				return
			_puzzle._process(0.05)
	var play := func(from: int, into: int, op: int) -> void:
		if _puzzle.picked() != from:
			if _puzzle.picked() >= 0:
				_tap_local(_puzzle.crate_to_local(_puzzle.picked()))
			_tap_local(_puzzle.crate_to_local(from))
		_tap_local(_puzzle.sign_to_local(op))
		_tap_local(_puzzle.crate_to_local(into))
		settle.call()
	# a refused share: nothing changes, nothing is counted
	for i in range(5, -1, -1):
		var done := false
		for j in 6:
			if i != j and st.would(i, j, Gen.Op.DIV) == Gen.UNEVEN:
				var before: Array = st.slots.duplicate()
				play.call(i, j, Gen.Op.DIV)
				_hud_ok = st.slots == before and st.steps == 0 and _puzzle._say == "MK_SAY_UNEVEN"
				done = true
				break
		if done:
			break
	# a step and its Undo
	if _puzzle.capabilities().has("undo"):
		var first: Array = st.hint_step()
		var before: Array = st.slots.duplicate()
		play.call(first[0], first[1], first[2])
		_hud_ok = _hud_ok and st.steps == 1 and st.slots != before
		_press(_host.top_bar.undo_button)
		settle.call()
		_hud_ok = _hud_ok and st.slots == before
	_press(_host.top_bar.hint_button)
	settle.call()
	_hud_ok = _hud_ok and _puzzle.hints_used == 1
	for step in 8:
		if _puzzle.is_done():
			return
		var h: Array = st.hint_step()
		if h.is_empty():
			_hud_ok = false
			return
		play.call(h[0], h[1], h[2])

## Honeycomb: an entry without the middle letter refused (cells and the
## tick by real touches), a letter typed and taken back with the delete key,
## a shuffle, the bulb through the real button and its word finished, then
## the day's words spelt cell by cell until the jar reaches its line (on
## Insane following the queen's flights).
func _solve_honeycomb() -> void:
	var st = _puzzle._st
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for i in 7:
		if not slot.has_point(_puzzle.cell_to_local(i)):
			_fit_ok = false
	for k in 3:
		if not slot.has_point(_puzzle.key_to_local(k)):
			_fit_ok = false
	var settle := func() -> void:
		for i in 40:
			if not _puzzle.busy():
				return
			_puzzle._process(0.05)
	var spell := func(word: String) -> void:
		for ch in word:
			_tap_local(_puzzle.cell_to_local(_puzzle.cell_of(ch)))
		_tap_local(_puzzle.key_to_local(2))
		settle.call()
	# no middle letter: refused, nothing counted
	var wrong := ""
	for ch in st.ring:
		if wrong.length() < 4:
			wrong += ch
	spell.call(wrong)
	_hud_ok = st.found.is_empty() and st.misses == 0 and _puzzle._say == "HC_SAY_QUEEN"
	# a letter and the delete key
	_tap_local(_puzzle.cell_to_local(0))
	_hud_ok = _hud_ok and st.entry == st.queen
	_tap_local(_puzzle.key_to_local(0))
	_hud_ok = _hud_ok and st.entry == ""
	var ring_before: Array = st.ring.duplicate()
	_tap_local(_puzzle.key_to_local(1))
	_hud_ok = _hud_ok and st.ring.size() == 6 and _sorted(st.ring) == _sorted(ring_before)
	# the bulb, and its word spelt to the end
	_press(_host.top_bar.hint_button)
	_hud_ok = _hud_ok and _puzzle.hints_used == 1 and st.entry.length() >= 2
	var hinted: String = st.hinted[0]
	for k in range(st.entry.length(), hinted.length()):
		_tap_local(_puzzle.cell_to_local(_puzzle.cell_of(hinted[k])))
	_tap_local(_puzzle.key_to_local(2))
	settle.call()
	_hud_ok = _hud_ok and st.found.has(hinted)
	for guard in 120:
		if _puzzle.is_done():
			return
		var w: String = st.hint_word()
		if w == "":
			_hud_ok = false
			return
		st.hinted.append(w)
		spell.call(w)

func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out

## Hosepipes: bare soil pressed (heard, nothing changes), a hose drawn,
## another dragged across it (cut) and back off (grown back, no stroke
## counted), a stroke and its Undo, the bulb, then every hose the answer has
## drawn by real drags through its squares.
func _solve_hoses() -> void:
	var st = _puzzle._st
	var n: int = st.n
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for i in n * n:
		if not slot.has_point(_puzzle.cell_to_local(i)):
			_fit_ok = false
	var draw_path := func(path: Array) -> void:
		var pts: Array[Vector2] = []
		for v in path:
			pts.append(_puzzle.cell_to_local(int(v)))
		_drag_path_local(pts)
	var settle := func() -> void:
		for i in 30:
			if not _puzzle.laying():
				return
			_puzzle._process(0.05)
	_hud_ok = true
	# a square no end is on, pressed while the bed is bare: nothing changes
	for i in n * n:
		if st.end_of(i) < 0 and not st.is_seed(i):
			_tap_local(_puzzle.cell_to_local(i))
			_hud_ok = st.history.is_empty() and st.watered() == 0
			break
	# the longest hose drawn, the nearest other tap dragged across it and back
	var order := range(st.count())
	order.sort_custom(func(x, y): return (st.answer[x] as Array).size() > (st.answer[y] as Array).size())
	var a: int = order[0]
	var path_a: Array = st.answer[a]
	draw_path.call(path_a)
	_hud_ok = _hud_ok and (st.hoses[a] as Array).size() == path_a.size() and st.strokes == 1
	var run: Array = load("res://ui/hud/hoses_tutorial_diagram.gd").run_into(st, a)
	if not run.is_empty():
		var before: Array = st.hoses.duplicate(true)
		var touch := func(cell: int, pressed: bool) -> void:
			var ev := InputEventScreenTouch.new()
			ev.index = 0
			ev.pressed = pressed
			ev.position = _to_global(_puzzle.cell_to_local(cell))
			root.push_input(ev, true)
		var move := func(cell: int) -> void:
			var ev := InputEventScreenDrag.new()
			ev.index = 0
			ev.position = _to_global(_puzzle.cell_to_local(cell))
			root.push_input(ev, true)
		touch.call(int(run[0]), true)
		for i in range(1, run.size()):
			move.call(int(run[i]))
		var cut: bool = (st.hoses[a] as Array).size() < path_a.size()
		for i in range(run.size() - 2, -1, -1):
			move.call(int(run[i]))
		var regrown: bool = (st.hoses[a] as Array).size() == path_a.size()
		touch.call(int(run[0]), false)
		print("hoses: cut %s, regrown %s" % [cut, regrown])
		_hud_ok = _hud_ok and cut and regrown and st.hoses == before and st.strokes == 1
	# a stroke and its Undo
	if _puzzle.capabilities().has("undo"):
		var b: int = order[1]
		var before: Array = st.hoses.duplicate(true)
		draw_path.call(st.answer[b])
		_hud_ok = _hud_ok and st.joined(b)
		_press(_host.top_bar.undo_button)
		_hud_ok = _hud_ok and st.hoses == before
	# the bulb reads (one hint, nothing laid), then lays that hose free
	var joined_before: int = st.joined_count()
	_press(_host.top_bar.hint_button)
	var read_ok: bool = _puzzle.hints_used == 1 and st.joined_count() == joined_before and not _puzzle._reading.is_empty()
	_press(_host.top_bar.hint_button)
	settle.call()
	print("hoses: bulb read %s, then laid" % read_ok)
	_hud_ok = _hud_ok and read_ok and _puzzle.hints_used == 1 and st.joined_count() >= 1
	for c in st.count():
		if _puzzle.is_done():
			break
		if not st.joined(c) or st.hoses[c] != st.answer[c]:
			draw_path.call(st.answer[c])
	print("hoses: joined %d of %d, watered %d of %d" % [st.joined_count(), st.count(), st.watered(), n * n])

## Who Ate the Pie?: a mark nothing proves yet (refused, free), a mark the
## clues prove wrong (a slip), the bulb, then every proven baker picked and
## marked by real touches on the card and the verdict button.
func _solve_pie() -> void:
	var st = _puzzle._st
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for i in st.count():
		if not slot.has_point(_puzzle.card_to_local(i)):
			_fit_ok = false
	var mark := func(i: int, eat: bool) -> void:
		if _puzzle.picked() != i:
			_tap_local(_puzzle.card_to_local(i))
		_tap_local(_puzzle.button_to_local(eat))
		for k in 10:
			_puzzle._process(0.05)
	# a baker nothing proves yet: turned away, nothing counted
	_hud_ok = true
	for i in st.count():
		if not st.is_marked(i) and not st.proven(i):
			mark.call(i, false)
			_hud_ok = not st.is_marked(i) and st.slips == 0 and _puzzle._say == "PI_SAY_UNPROVEN"
			break
	# a proven baker marked the wrong way: a slip
	var p: int = st.hint_baker(-1)
	mark.call(p, not st.did_eat(p))
	_hud_ok = _hud_ok and st.slips == 1 and not st.is_marked(p) and _puzzle._say == "PI_SAY_WRONG"
	# the bulb twice: the clues that prove somebody lit, then that baker marked
	_press(_host.top_bar.hint_button)
	for k in 10:
		_puzzle._process(0.05)
	var nudge: Dictionary = _puzzle.nudge()
	_hud_ok = _hud_ok and _puzzle.hints_used == 1 and int(nudge.clues) != 0 and int(nudge.baker) >= 0 \
		and not st.is_marked(int(nudge.baker))
	_press(_host.top_bar.hint_button)
	for k in 10:
		_puzzle._process(0.05)
	_hud_ok = _hud_ok and _puzzle.hints_used == 2 and st.is_marked(int(nudge.baker))
	for step in 30:
		if _puzzle.is_done():
			return
		var i: int = st.hint_baker(-1)
		if i < 0:
			_hud_ok = false
			return
		mark.call(i, st.did_eat(i))

## Five Clues: dealt after its short wait on the network (it awaits and
## holds the walk), then every key pressed by a real touch on Hidden Word's
## keyboard: Enter on an empty line (a card turns), a wrong idea (another
## turns), the bulb through the real button, then the idea's first accepted
## word and Enter, and Enter again for the next round.
func _solve_clues() -> void:
	_waiting = true
	for i in 600:
		if _puzzle.dealt():
			break
		await process_frame
	var st = _puzzle._st
	# the phone's keyboard types into the board's own field
	var field: LineEdit = _puzzle._field
	var type := func(word: String) -> void:
		field.text = word
		field.text_changed.emit(word)
		field.text_submitted.emit(word)
	_fit_ok = Rect2(Vector2.ZERO, _puzzle.size).has_point(_puzzle.slate_to_local())
	# laid out above a keyboard half the screen tall
	_puzzle.osk_override = _puzzle.size.y * 0.42
	await process_frame
	await process_frame
	var slate: Rect2 = _puzzle._L.slate
	_fit_ok = _fit_ok and slate.end.y <= _puzzle.size.y * 0.58 and field.get_rect().is_equal_approx(slate) \
		and _puzzle._card_pos(4).y + _puzzle._l("card_h") * 0.5 < slate.position.y and _puzzle._l("card_h") >= 40.0
	_puzzle.osk_override = -1.0
	await process_frame
	_hud_ok = _puzzle.capabilities() == ["hint"] and _puzzle.hints_left() > 0 and not _puzzle.can_reset() and _host.tray == null
	# a tap on the next face-down card turns it, no guess spent
	_tap_local(_puzzle._card_pos(3))
	_hud_ok = _hud_ok and st.shown == 2 and st.wrongs == 0
	var wrong := "PEBBLE" if not st.accepts(st.round_now().accept, "pebble", st.round_now().label) else "CLOUD"
	type.call(wrong)
	_hud_ok = _hud_ok and st.shown == 3 and st.wrongs == 1 and _puzzle._tried == [wrong]
	# a slip two letters off a long key word is pointed out, free
	for a in st.round_now().accept:
		var f: String = st.norm(String(a))
		if f.length() >= 6 and f.length() < 9:
			var slip := f.substr(0, 1) + "qq" + f.substr(3)
			if st.near(st.round_now().accept, slip, st.round_now().label):
				type.call(slip)
				_hud_ok = _hud_ok and st.shown == 3 and st.wrongs == 1 and _puzzle._say == _puzzle.tr("FC_CLOSE")
			break
	_press(_host.top_bar.hint_button)
	_hud_ok = _hud_ok and _puzzle.hints_used == 1 and st.hinted == 1
	for r in 8:
		if _puzzle.is_done():
			break
		if _puzzle.phase() == _puzzle.Phase.PLAY:
			# a typo of the key word is right
			var word: String = st.norm(String(st.round_now().accept[0]))
			type.call(word.substr(0, word.length() - 1) + "z" if word.length() >= 6 and r == 0 else word)
			_hud_ok = _hud_ok and _puzzle.phase() == _puzzle.Phase.OVER and _puzzle._praise != ""
		# the first round moves on by itself; the rest by a tap
		for i in 400:
			if _puzzle.phase() != _puzzle.Phase.OVER:
				break
			if r > 0 and i == 50:
				_tap_local(_puzzle.size * 0.5)
			await process_frame
	for i in 120:
		await process_frame
	_waiting = false

## Four Shelves: dealt after its short wait on the network (it awaits and
## holds the walk), then by real touches: three jars of one shelf and one of
## another shelved (close, a heart lost), the same four again (refused as
## tried, free), the picks cleared, the bulb through the real button, then
## every shelf's jars and the tick.
func _solve_shelves() -> void:
	_waiting = true
	for i in 600:
		if _puzzle.dealt():
			break
		await process_frame
	var st = _puzzle._st
	var settle := func() -> void:
		for i in 120:
			if not _puzzle.busy():
				return
			await process_frame
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for i in st.tiles.size():
		if not slot.has_point(_puzzle.tile_to_local(i)):
			_fit_ok = false
	for k in 3:
		if not slot.has_point(_puzzle.key_to_local(k)):
			_fit_ok = false
	_hud_ok = _puzzle.capabilities() == ["hint"] and _puzzle.hints_left() > 0 and not _puzzle.can_reset()
	var g0: Array = st.groups[0].words
	var g1: Array = st.groups[1].words
	for w in [g0[0], g0[1], g0[2], g1[0]]:
		_tap_local(_puzzle.word_to_local(w))
	_tap_local(_puzzle.key_to_local(_puzzle.Key.ENTER))
	# the four hop before they are judged
	_hud_ok = _hud_ok and st.hearts == st.HEARTS and _puzzle.busy()
	await settle.call()
	_hud_ok = _hud_ok and st.hearts == st.HEARTS - 1 and st.picked.size() == 4
	_tap_local(_puzzle.key_to_local(_puzzle.Key.ENTER))
	_hud_ok = _hud_ok and st.hearts == st.HEARTS - 1
	_tap_local(_puzzle.key_to_local(_puzzle.Key.DELETE))
	_hud_ok = _hud_ok and st.picked.is_empty()
	_press(_host.top_bar.hint_button)
	_hud_ok = _hud_ok and _puzzle.hints_used == 1 and st.picked.size() == 1
	for round in 8:
		if _puzzle.is_done():
			break
		await settle.call()
		var g := -1
		for k in st.count():
			if not st.shelved.has(k):
				g = k
				break
		for w in st.groups[g].words:
			if not st.picked.has(w):
				_tap_local(_puzzle.word_to_local(w))
		_tap_local(_puzzle.key_to_local(_puzzle.Key.ENTER))
		await process_frame
	for i in 120:
		await process_frame
	_waiting = false

## Paper Box: a wrong box picked on purpose (struck, counted), a tap on it
## again (nothing), a tap on the mat's foot over a box (nothing), the bulb through the real button twice (a reading, then one more struck), then
## each round's right box picked by a real touch, the fold stepped through on
## the board's own clock.
func _solve_paperbox() -> void:
	var st = _puzzle._st
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for o in st.struck.size():
		if not slot.has_point(_puzzle.option_to_local(o)):
			_fit_ok = false
	_hud_ok = _puzzle.capabilities() == ["hint"] and _puzzle.hints_left() > 0 and not _puzzle.can_reset()
	var answer := int(st.now().answer)
	var wrong := 0 if answer != 0 else 1
	_tap_local(_puzzle.option_to_local(wrong))
	# made fun: the wrong box says why and a star falls
	_hud_ok = _hud_ok and st.struck[wrong] and st.wrongs == 1 and _puzzle._toast.text != "" and _puzzle._stars.stars == 2
	_tap_local(_puzzle.option_to_local(wrong))
	_hud_ok = _hud_ok and st.wrongs == 1
	# the mat's foot, just over a box: no pick
	var mat: Rect2 = _puzzle._L.mat
	_tap_local(Vector2(_puzzle.option_to_local(answer).x, mat.end.y - 10.0))
	_hud_ok = _hud_ok and _puzzle.phase() == _puzzle.Phase.PLAY and st.struck.count(true) == 1
	# the bulb in two presses: a reading (one hint, nothing struck), then the strike, free
	var held: int = _puzzle.hints_left()
	_press(_host.top_bar.hint_button)
	_hud_ok = _hud_ok and _puzzle.hints_used == 1 and st.struck.count(true) == 1 and not _puzzle._reading.is_empty() and _puzzle.hints_left() == held
	_press(_host.top_bar.hint_button)
	_hud_ok = _hud_ok and _puzzle.hints_used == 1 and st.struck.count(true) == 2 and _puzzle._reading.is_empty()
	for r in 10:
		if _puzzle.is_done():
			return
		_tap_local(_puzzle.option_to_local(int(st.now().answer)))
		for i in 200:
			if _puzzle.phase() != _puzzle.Phase.FOLD:
				break
			_puzzle._process(0.05)

## Teacups: two misses on purpose (on Insane the second sets a waltz going,
## stepped through on the board's own clock), a cup lifted and the bulb
## pressed so its partner peeks, then every pair lifted by real touches,
## each cup's place read from the state as it is now.
func _solve_teacups() -> void:
	var st = _puzzle._st
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for s in st.cups():
		if not slot.has_point(_puzzle.slot_to_local(s)):
			_fit_ok = false
	_hud_ok = _puzzle.capabilities() == ["hint"] and _puzzle.hints_left() > 0 and not _puzzle.can_reset()
	var settle := func() -> void:
		for i in 200:
			if _puzzle.phase() == _puzzle.Phase.PLAY or _puzzle.is_done():
				return
			_puzzle._process(0.05)
	# two misses: cup 0 against a cup of another friend; then that cup's
	# twin against a third cup, a lapse (the twin was seen), which the toast
	# names and the twin's saucer is rimmed
	var a0: int = st.hidden()[0]
	var b0 := -1
	for c in st.hidden():
		if st.kind[c] != st.kind[a0]:
			b0 = c
			break
	var pb: int = st.partner(b0)
	var c0 := -1
	for c in st.hidden():
		if c != b0 and c != pb and st.kind[c] != st.kind[a0]:
			c0 = c
			break
	for turn in [[a0, b0], [pb, c0]]:
		_tap_local(_puzzle.slot_to_local(st.slot[turn[0]]))
		_tap_local(_puzzle.slot_to_local(st.slot[turn[1]]))
		_hud_ok = _hud_ok and _puzzle.phase() == _puzzle.Phase.HOLD
		_puzzle._process(1.0)
		settle.call()
	_hud_ok = _hud_ok and st.lapses == 1 and _puzzle._rim_slot == st.slot[b0] and _puzzle._toast.showing(_puzzle._t)
	# a cup in hand, the bulb: the first press reads (one hint, the toast, a
	# reading standing), the second lifts its partner, free
	var first: int = st.hidden()[0]
	_tap_local(_puzzle.slot_to_local(st.slot[first]))
	var stars_before: int = _puzzle._stars.stars
	_hud_ok = _hud_ok and _puzzle.hint() and _puzzle._reading == first and _puzzle.hints_used == 1 \
		and _puzzle._toast.showing(_puzzle._t) and _puzzle._stars.stars <= stars_before
	_hud_ok = _hud_ok and _puzzle.hint() and _puzzle._reading == -1 and _puzzle.hints_used == 1 \
		and _puzzle._up[st.partner(first)]
	# the Peeplets: one a cup, the ones under lifted cups shown
	_hud_ok = _hud_ok and _puzzle._views.size() == st.cups()
	_tap_local(_puzzle.slot_to_local(st.slot[st.partner(first)]))
	_puzzle._process(0.1)
	for step in 40:
		if _puzzle.is_done():
			return
		settle.call()
		var a: int = st.hidden()[0]
		_tap_local(_puzzle.slot_to_local(st.slot[a]))
		_tap_local(_puzzle.slot_to_local(st.slot[st.partner(a)]))
		_puzzle._process(0.1)

## Domino Patio: one bulb through the real button; then each tile of the
## answer turned on the rack by taps until it faces its answer's way and
## dragged by a real touch onto its two squares. The first one laid is
## dragged off the patio again (back to its bay) and laid once more.
func _solve_patio() -> void:
	var st = _puzzle._st
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for i in st.bed_of.size():
		if st.bed_of[i] >= 0 and not slot.has_point(_puzzle._patio_pos(i, 0) - Vector2(_puzzle._l("cell") * 0.5, 0)):
			_fit_ok = false
	for t in st.tiles.size():
		if not slot.has_point(_puzzle._bay(t)):
			_fit_ok = false
	# Made fun: the bulb reads first (a tile rimmed, the toast, one hint,
	# a star off), then lays it free.
	_press(_host.top_bar.hint_button)
	var read: Dictionary = _puzzle._reading
	_hud_ok = _puzzle.hints_used == 1 and not read.is_empty() and _puzzle._toast.showing(_puzzle._t) \
		and _puzzle._stars.stars == 2 and not st.right(int(read.tile))
	_press(_host.top_bar.hint_button)
	_hud_ok = _hud_ok and _puzzle.hints_used == 1 and _puzzle._reading.is_empty() and st.right(int(read.tile))
	# A tile laid where it breaks a bed: the toast says why, a star falls;
	# dragged off again, the toast goes.
	var broke := false
	for t in st.tiles.size():
		if broke or st.at[t] >= 0:
			continue
		for a in st.bed_of.size():
			if broke or st.bed_of[a] < 0 or not st.fits(t, a, st.dir[t]) or st.try_drop(t, a, st.dir[t]) >= 0:
				continue
			var lift0 := Vector2(0, _puzzle.HOLD_LIFT * _puzzle._l("cell"))
			_drag_local(_puzzle._bay(t), _puzzle._patio_pos(a, st.dir[t]) + lift0)
			_hud_ok = _hud_ok and st.at[t] == a and _puzzle._told_bed >= 0 and _puzzle._toast.showing(_puzzle._t) \
				and _puzzle._slips == 2 and _puzzle._stars.stars == 2
			print("  broke a bed: %s" % _puzzle._toast.text)
			_drag_local(_puzzle._patio_pos(a, st.dir[t]), Vector2(_puzzle.size.x * 0.5, _puzzle.size.y - 30.0))
			_hud_ok = _hud_ok and st.at[t] < 0 and _puzzle._told_bed == -1
			broke = true
	_hud_ok = _hud_ok and broke
	var lifted := false
	for t in st.tiles.size():
		if _puzzle.is_done():
			return
		if st.answer[t].x < 0 or st.right(t):
			continue
		var guard := 0
		while st.dir[t] != st.answer[t].y and guard < 4:
			guard += 1
			_tap_local(_puzzle._bay(t))
		var lift := Vector2(0, _puzzle.HOLD_LIFT * _puzzle._l("cell"))
		_drag_local(_puzzle._bay(t), _puzzle.answer_to_local(t) + lift)
		if not lifted and st.right(t):
			lifted = true
			# off the patio again, onto the open terrace under the rack
			_drag_local(_puzzle.answer_to_local(t), Vector2(_puzzle.size.x * 0.5, _puzzle.size.y - 30.0))
			_hud_ok = _hud_ok and st.at[t] < 0
			_drag_local(_puzzle._bay(t), _puzzle.answer_to_local(t) + lift)
		if not st.right(t):
			_hud_ok = false

func _solve_pixelgarden() -> void:
	var st = _puzzle._state
	var n: int = st.n
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for r in n:
		for c in n:
			if not slot.has_point(_puzzle.cell_to_local(r, c)):
				_fit_ok = false
	# The bulb reads (a peg ringed, one hint), then fixes it free.
	_press(_host.top_bar.hint_button)
	_hud_ok = _puzzle._reading >= 0 and _puzzle.hints_used == 1 and st.placed() == 0 and _puzzle._toast == "PG_READ_NEXT"
	_press(_host.top_bar.hint_button)
	_press_check()
	_hud_ok = _hud_ok and _puzzle.hints_used == 1 and _puzzle.checks == 1 and st.placed() == 1 and _puzzle._reading == -1
	# A wrong bead on a bare peg, then lifted by tapping it again.
	for c in st.size():
		if int(st.want[c]) == -1:
			_tap_local(_puzzle.chip_to_local(0))
			_tap_local(_puzzle.cell_to_local(c / n, c % n))
			if int(st.beads[c]) != 0:
				_hud_ok = false
			_tap_local(_puzzle.cell_to_local(c / n, c % n))
			if int(st.beads[c]) != -1:
				_hud_ok = false
			break
	for k in st.names.size():
		_tap_local(_puzzle.chip_to_local(k))
		for c in st.size():
			if _puzzle.is_done():
				return
			if int(st.want[c]) == k and int(st.beads[c]) != k:
				_tap_local(_puzzle.cell_to_local(c / n, c % n))

## Trestle: the day's proof laid member by member by touch -- each dragged
## from whichever of its ends already stands (a pin, or a bolt an earlier
## member left), its material picked on the chips first -- then a member
## tapped off and put back, then Go. The cart's crossing takes seconds of
## the sim's clock, past this harness's frame slot, so the test is run to
## its end through the board's own `run_test_now()`.
func _solve_trestle() -> void:
	var st = _puzzle.state
	var slot := Rect2(Vector2.ZERO, _puzzle.size)
	_fit_ok = true
	for a in st.anchors():
		if not slot.has_point(_puzzle.point_to_local(a)):
			_fit_ok = false
	var todo: Array = st.proof.duplicate()
	var stands := {}
	for a in st.anchors():
		stands[a] = true
	var guard := 0
	while not todo.is_empty() and guard < 400:
		guard += 1
		var p: Dictionary = todo.pop_front()
		var from: Vector2i
		var to: Vector2i
		if stands.has(p.a):
			from = p.a
			to = p.b
		elif stands.has(p.b):
			from = p.b
			to = p.a
		else:
			todo.append(p)
			continue
		_tap_local(_puzzle.chip_to_local(int(p.m)))
		_drag_local(_puzzle.point_to_local(from), _puzzle.point_to_local(to))
		stands[to] = true
	# a tap on the first member takes it down; Undo puts it back
	var first: Dictionary = st.design[0]
	var mid: Vector2 = (_puzzle.point_to_local(first.a) + _puzzle.point_to_local(first.b)) * 0.5
	var before: int = st.design.size()
	_tap_local(mid)
	_hud_ok = st.design.size() == before - 1
	_press(_host.top_bar.undo_button)
	_hud_ok = _hud_ok and st.design.size() == before and st.design.size() == st.proof.size()
	_press_check()
	_puzzle.run_test_now()


## Check, where a board still has one. A board in a world of its own lost
## the button (docs/agents/flat-screens.md): its `check()` is called
## directly, so the counts the solvers read still add up.
func _press_check() -> void:
	if _host.action_bar != null and _host.action_bar.check_button.visible:
		_press(_host.action_bar.check_button)
	elif _puzzle.has_method("check"):
		_puzzle.check()
