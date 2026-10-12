extends SceneTree

## Pixel Garden's rules as they stand since the big pictures (2026-10-11),
## headless, through the board's own touches (ScreenTouch and ScreenDrag by
## finger, as a phone sends them): every band solved by tapping each peg
## right; Insane's budget (the beads and a twentieth of them, never under
## three) and what a solve leaves of it; no Windblown anywhere; a day kept
## under the old rules reopened; the 24 and 32 square pictures filled; the
## stroke a second finger cancels (no bead left, no move spent, even when it
## had spent the last one); the zoom's transform there and back, clamped,
## its button, its reset; a run that keeps its row zoomed, and stops at the
## edge of what shows; the two-row box inside its card; the share's size;
## and the tutorial's ZOOM page played for a loop.
##
##     [PG_BANK=<bank.json>] godot --headless --path . --script res://tests/_probe_pixel_garden.gd
##
## PG_BANK points it at another bank (a debug build): the big bands need
## pictures of 24 and 32, which the checks on size say when the bank in use
## has not got them yet.

const Board = preload("res://puzzles/pixel_garden2d.gd")
const State = preload("res://puzzles/pixel_garden_state.gd")
const Diagram = preload("res://ui/hud/pixel_garden_tutorial_diagram.gd")
const Motion = preload("res://core/motion.gd")
const PanZoom = preload("res://ui/flat/pan_zoom.gd")

const SIZE := Vector2(1000, 1350)

var _b
var _step := 0
var _wait := 0.0
var _band := 0
var _fails := 0
var _log: Array[String] = []
var _page: Control
var _page_k := 1.0

func _initialize() -> void:
	Motion.reduce = true

func _process(delta: float) -> bool:
	if _page != null:
		_page_k = maxf(_page_k, _page._art.zoom.k)
	if _wait > 0.0:
		_wait -= delta
		return false
	match _step:
		0:
			_deal(_band)
			_step = 1
		1:
			_band_checks()
			_band += 1
			_step = 0 if _band < 4 else 2
		2:
			_restore_old()
			_fill_big()
			_cancel_checks()
			_zoom_checks()
			_stroke_checks()
			_box_checks()
			_tutorial_pages()
			_step = 3
		3:
			# The ZOOM page, played by the board itself for one loop.
			Motion.reduce = false
			_page = Diagram.new()
			_page.lesson = Diagram.Lesson.ZOOM
			_page.band = 3
			_page.size = Vector2(900, 520)
			root.add_child(_page)
			_wait = 11.0
			_step = 4
		4:
			var art = _page._art
			_ok(_page_k > 1.5, "the tutorial's ZOOM page zooms its board (to %.2f)" % _page_k)
			_ok(art._zoom_b.visible or art.zoom.k <= 1.01, "its button shows while the board can zoom")
			_page.queue_free()
			_page = null
			print("\n".join(_log))
			print("pixel garden probe: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
			return true
	return false

func _deal(band: int, seed := 4242) -> void:
	if _b != null:
		_b.queue_free()
	_b = Board.new()
	_b.size = SIZE
	root.add_child(_b)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + band
	_b.start(rng, band)
	_b._layout()

# --- fingers ---

func _finger(i: int, at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = i
	ev.position = at
	ev.pressed = down
	_b._gui_input(ev)

func _slide(i: int, at: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = i
	ev.position = at
	_b._gui_input(ev)

func _at(c: int) -> Vector2:
	var n: int = _b._state.n
	return _b.cell_to_local(c / n, c % n)

func _tap(c: int) -> void:
	_finger(0, _at(c), true)
	_finger(0, _at(c), false)

func _solve_all() -> void:
	var st = _b._state
	for k in st.names.size():
		_b.set_brush(k)
		for c in st.size():
			if _b.is_done():
				return
			if int(st.want[c]) == k and int(st.beads[c]) != k:
				_tap(c)

func _ok(cond: bool, what: String, quiet := false) -> void:
	if not cond:
		_fails += 1
		_log.append("FAIL " + what)
	elif not quiet:
		_log.append("ok   " + what)

# --- every band ---

func _band_checks() -> void:
	var st = _b._state
	var want_n: int = [10, 12, 24, 32][_band]
	_ok(st.n == want_n, "band %d is %d pegs square (the bank's is %d)" % [_band, want_n, st.n])
	_ok(st.names.size() <= 12, "band %d has %d colours" % [_band, st.names.size()])
	_ok(not ("perm" in st) and not ("turn" in st) and not st.has_method("windblown") and not st.has_method("card_peg"),
		"band %d: no Windblown in the state" % _band)
	# no band counts its moves (2026-10-12)
	var budget := 0
	_ok(st.moves_budget() == budget and _b.max_moves == budget and _b.max_hearts == 0,
		"band %d: %d beads, budget %d, no hearts" % [_band, st.target, _b.max_moves])
	var caps: Array[String] = ["undo"]
	if _band < 3:
		caps = ["undo", "hint", "check"]
	_ok(_b.capabilities() == caps, "band %d capabilities %s" % [_band, _b.capabilities()])
	_ok(_b.zoom.enabled == (_band >= 2), "band %d zoom %s (near %.2f, most %.2f)" % [_band,
		"on" if _b.zoom.enabled else "off", _b.zoom.k_near, _b.zoom.k_max])
	if _band >= 2:
		_ok(absf(_b._cell * _b.zoom.k_near - 56.0) < 0.5 and absf(_b._cell * _b.zoom.k_max - 84.0) < 0.5,
			"band %d: a peg %.1f px whole, 56 close, 84 at most" % [_band, _b._cell])
	for c in [0, st.n - 1, st.size() / 2 + 3, st.size() - 1]:
		_ok(_b._peg_at(_b.zoom.to_layout(_at(c))) == c, "peg %d found under its centre" % c, true)
	var rows: int = st.share_glyphs().split("\n").size()
	_ok(rows == (st.n if st.n <= 16 else st.n / 2), "band %d shares %d rows" % [_band, rows])
	var t0 := Time.get_ticks_msec()
	_solve_all()
	_ok(_b.is_done(), "band %d solved by touch (%d moves, %d ms)" % [_band, _b.moves, Time.get_ticks_msec() - t0])
	_ok(st.ironed == PackedByteArray([1, 1, 1, 1]), "band %d every plate ironed" % _band)
	_ok(_b.zoom.k == 1.0, "band %d: the win leaves the board whole" % _band, true)
	if _band == 3:
		_ok(_b.max_moves == 0 and not _b.out_of_hearts, "Insane: no moves counted, and no end but the picture")
		_ok(_b.share_glyphs().contains(_b.tr("BN_INSANE_SEAL")) and not _b.share_glyphs().contains("🌬"),
			"Insane's share line")

## A day finished under the old rules: its record never held the card's
## shuffle, and one that did is read past.
func _restore_old() -> void:
	_deal(3)
	_b.completed_record = {"hearts": 2, "flawless": true, "moves": 2, "perm": [3, 2, 1, 0], "turn": [1, 2, 3, 1]}
	_b.restore_completed()
	_ok(_b.is_done() and _b._state.is_solved() and _b._flawless,
		"a day kept under the old rules reopens solved")
	_b._prepare(_b._now())
	_ok(_b._bands.size() == 8 or _b._state.n != 32, "its beads are in %d bands" % _b._bands.size())

func _fill_big() -> void:
	for band in [2, 3]:
		for pic: Dictionary in State.band_pictures(band):
			var st = State.new()
			st.band = band
			st.load_picture(pic)
			var colours: int = st.names.size()
			var solved_by_put := true
			st.begin_stroke()
			for c in st.size():
				if int(st.want[c]) != State.EMPTY and st.put(c, int(st.want[c])) != "put":
					solved_by_put = false
			st.end_stroke()
			var by_put: bool = solved_by_put and st.is_solved()
			st.reset()
			st.fill()
			_ok(by_put and st.is_solved() and colours <= 12,
				"band %d %s: %d square, %d colours, %d beads, put and filled" % [band, st.pic_id, st.n, colours, st.target], true)
	_log.append("ok   every picture of bands 2 and 3 loads, takes its beads and fills")

# --- a second finger ---

func _cancel_checks() -> void:
	Motion.reduce = false
	_deal(3)
	var st = _b._state
	# No band counts its moves since 2026-10-12. The board's counter is still
	# there for a budget over 0, and a second finger must still give back
	# what a stroke spent: it is handed a budget here.
	_b.max_moves = st.target + 3
	_b.moves_left = _b.max_moves
	var n: int = st.n
	var k: int = _b.brush
	# A row of bare pegs for a run of four.
	var c0 := 5 * n + 4
	var before: PackedInt32Array = st.beads.duplicate()
	_finger(0, _at(c0), true)
	for i in range(1, 4):
		_slide(0, _at(c0 + i))
	var seated := 0
	for c in st.size():
		if int(st.beads[c]) != State.EMPTY:
			seated += 1
	_ok(_b._stroking and seated == 4 and _b.moves_left == _b.max_moves - 4 and _b._incoming.size() == 4,
		"one finger's run seats %d beads and spends %d moves" % [seated, _b.max_moves - _b.moves_left])
	_finger(1, _at(c0 + n * 6 + 5), true)
	_ok(st.beads == before and st.placed() == 0 and st.left(k) == st.need[k], "a second finger takes the stroke back: no bead left")
	_ok(_b.moves_left == _b.max_moves, "... and no move spent (%d of %d)" % [_b.moves_left, _b.max_moves])
	_ok(not _b._stroking and st.history.is_empty() and _b._incoming.is_empty() and _b._press_finger == -2 and _b.moves == 0,
		"... the stroke over, nothing in the history, nothing in the air")
	_ok(_b.zoom.busy(), "... and the two fingers hold the zoom")
	var far := _at(c0 + n * 6 + 5) + Vector2(260, 220)
	_slide(1, far)
	_slide(1, far)
	_ok(_b.zoom.k > 1.2, "two fingers apart zoom in (to %.2f)" % _b.zoom.k)
	_slide(0, _at(c0))
	_ok(st.placed() == 0, "a finger of a pinch paints nothing")
	_finger(0, _at(c0), false)
	_finger(1, far, false)
	_ok(not _b.zoom.busy() and st.placed() == 0 and _b.moves_left == _b.max_moves, "the pinch let go: still no bead, no move")
	# One finger plays on, zoomed.
	var seen := -1
	for c in st.size():
		if _b.zoom.view.grow(-40.0).has_point(_at(c)):
			seen = c
			break
	_tap(seen)
	_ok(int(st.beads[seen]) == k and _b.moves_left == _b.max_moves - 1 and st.history.size() == 1,
		"then one finger seats a bead on the zoomed board, for one move")
	# A lift cancelled: the bead is back on its peg.
	_finger(0, _at(seen), true)
	_ok(int(st.beads[seen]) == State.EMPTY and _b.moves_left == _b.max_moves - 2, "a press on it lifts it", true)
	_finger(1, _at(seen) + Vector2(120, 90), true)
	_ok(int(st.beads[seen]) == k and _b.moves_left == _b.max_moves - 1 and _b._flying.is_empty(),
		"a lift cancelled by a second finger puts the bead back")
	_finger(0, _at(seen), false)
	_finger(1, _at(seen) + Vector2(120, 90), false)
	# The stroke that spends the last move, cancelled before the card.
	_b.zoom.reset()
	_b.moves_left = 1
	var bare := c0 + 2 * n
	_finger(0, _at(bare), true)
	_ok(_b.out_of_hearts and _b.moves_left == 0 and int(st.beads[bare]) == k, "the last move spent ends the board", true)
	_finger(1, _at(bare) + Vector2(150, 150), true)
	_ok(not _b.out_of_hearts and _b.moves_left == 1 and int(st.beads[bare]) == State.EMPTY and not _b._lost_ever,
		"the stroke that spent the last move, taken back by a second finger, is not the end")
	_finger(0, _at(bare), false)
	_finger(1, _at(bare) + Vector2(150, 150), false)
	_b.zoom.reset()
	# The card held, a second finger on the board: the card is set down.
	_finger(0, _b._thumb.get_center(), true)
	_ok(_b._peek, "the picture held", true)
	_finger(1, _at(bare), true)
	_finger(2, _at(bare) + Vector2(150, 150), true)
	_ok(not _b._peek, "a pinch sets the held picture down")
	for i in 3:
		_finger(i, Vector2.ZERO, false)
	_win_checks()
	Motion.reduce = true

## The win of a big board with motion on: the still beads are cut along the
## iron's diagonals, every one of them is in a band before the iron sets off
## and again once it has passed, and it takes no longer than a small board's.
func _win_checks() -> void:
	_deal(3)
	var st = _b._state
	var last := -1
	for c in st.size():
		if int(st.want[c]) != State.EMPTY:
			last = c
	st.begin_stroke()
	for c in st.size():
		if c != last and int(st.want[c]) != State.EMPTY:
			st.put(c, int(st.want[c]))
	st.end_stroke()
	_b.zoom.toggle()
	_b.zoom.step(1.0)
	_b.set_brush(int(st.want[last]))
	_b.zoom.show_point(_b._centre(last))
	_b.zoom.step(1.0)
	_ok(_b.zoom.zoomed() and _b.zoom.view.has_point(_at(last)), "a peg out of sight is brought into it", true)
	_tap(last)
	_ok(_b.is_done() and _b._won and _b._by_diag, "Insane won by the last bead, zoomed")
	_b.zoom.step(1.0)
	_ok(_b.zoom.k == 1.0, "the win glides back to the whole board")
	_ok(_b.win_delay() < 5.0 and _b._iron_step() * 2.0 * st.n <= 1.45, "the win's iron crosses in %.2f s (the card after %.2f)" % [
		_b._iron_step() * 2.0 * st.n, _b.win_delay()])
	var per: int = 0
	var count := func() -> int:
		_b._stale = true
		_b._prepare(_b._now())
		var total := 0
		for m in _b._bands:
			if m != null:
				total += m.surface_get_array_len(0)
		return total
	var before: int = count.call()
	per = _b._kit.count
	_ok(_b._bands.size() == 16 and before == (st.target - _b._moving.size()) * per and _b._moving.size() == 1,
		"before the iron every bead but the one just seated rests in one of %d diagonal bands (%d of %d)" % [
		_b._bands.size(), before / maxi(1, per), st.target])
	# Half way: the beads under the iron are live, the rest still in bands.
	_b._solved_at -= _b.IRON_AT + st.n * _b._iron_step()
	_b._win_front(_b._now())
	# (what a frame would have settled by now)
	for c: int in _b._moving.keys():
		if float(_b._until[c]) <= _b._now():
			_b._moving.erase(c)
	var mid: int = count.call()
	var live: int = _b._moving.size()
	_ok(live > 0 and live < 320 and mid == (st.target - live) * per, "half way %d beads are live and %d rest" % [live, mid / maxi(1, per)])
	_b._solved_at -= 10.0
	_b._win_front(_b._now())
	_b._moving.clear()
	_b._arrive_at[last] = -100.0  # (the last bead, still in the air a moment ago)
	var after: int = count.call()
	_ok(after == st.target * per and _b._pegs_gone(_b._now()) == 1.0, "once it has passed every bead rests again, fused (%d)" % (after / maxi(1, per)))

# --- the zoom ---

func _zoom_checks() -> void:
	for band in [2, 3]:
		_deal(band)
		var st = _b._state
		var z = _b.zoom
		var view: Rect2 = z.view
		_ok(Rect2(Vector2.ZERO, SIZE).encloses(Rect2(_b._zoom_b.position, _b._zoom_b.size))
			and view.encloses(Rect2(_b._zoom_b.position, _b._zoom_b.size)) and _b._zoom_b.size == Vector2(84, 84)
			and _b._zoom_b.position.x < view.get_center().x and _b._zoom_b.position.y > view.get_center().y,
			"band %d: the button is 84 square at the tray floor's lower left %s" % [band, _b._zoom_b.position])
		_b._opened -= 5.0
		_b._sync_zoom()
		_ok(_b._zoom_b.visible and _b._zoom_icon == "plus", "band %d: the button shows, a plus" % band)
		_b._on_zoom_button()
		_b._on_zoom_button()
		_b._sync_zoom()
		_ok(is_equal_approx(z.k, z.k_near) and _b._zoom_icon == "minus", "band %d: it goes close (%.2f), a minus" % [band, z.k])
		# There and back, and clamped, at a hundred pushes and pinches.
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		var worst := 0.0
		var covered := true
		for i in 100:
			var a := view.position + Vector2(rng.randf(), rng.randf()) * view.size
			var b := view.position + Vector2(rng.randf(), rng.randf()) * view.size
			_finger(0, a, true)
			_finger(1, b, true)
			_slide(0, a + Vector2(rng.randf_range(-900, 900), rng.randf_range(-900, 900)))
			_slide(1, b + Vector2(rng.randf_range(-900, 900), rng.randf_range(-900, 900)))
			_slide(1, b + Vector2(rng.randf_range(-900, 900), rng.randf_range(-900, 900)))
			_finger(0, a, false)
			_finger(1, b, false)
			var p := Vector2(rng.randf_range(0, 1000), rng.randf_range(0, 1350))
			worst = maxf(worst, z.to_layout(z.to_screen(p)).distance_to(p))
			var lo: Vector2 = z.to_screen(view.position)
			var hi: Vector2 = z.to_screen(view.end)
			var give: Vector2 = z.slack_hi
			if z.k < 1.0 - 1e-6 or z.k > z.k_max + 1e-6 or lo.x > view.position.x + 0.01 or lo.y > view.position.y + 0.01 \
					or hi.x < view.end.x - 0.01 or hi.y < view.end.y - give.y - 0.01:
				covered = false
		_ok(worst < 0.01, "band %d: a point to the screen and back is itself (off by %.5f at worst)" % [band, worst])
		_ok(covered, "band %d: a hundred pinches keep the board over its floor (the button's lift apart)" % band)
		_ok(st.placed() == 0 and _b.moves_left == _b.max_moves, "band %d: and seat nothing" % band)
		# Every peg in sight is found where it shows.
		z.reset()
		_b._on_zoom_button()
		_b._on_zoom_button()
		var found := true
		var count := 0
		for c in st.size():
			if view.has_point(_at(c)):
				count += 1
				if _b._peg_at(z.to_layout(_at(c))) != c:
					found = false
		_ok(found and count > 0, "band %d: zoomed, %d pegs show and each is found under its centre" % [band, count])
		# The lower left pegs come out from under the button.
		_finger(0, view.get_center(), true)
		_finger(1, view.get_center() + Vector2(100, 0), true)
		for i in range(1, 120):
			_slide(0, view.get_center() + Vector2(i * 20, -i * 20))
			_slide(1, view.get_center() + Vector2(100 + i * 20, -i * 20))
		_finger(0, Vector2.ZERO, false)
		_finger(1, Vector2.ZERO, false)
		var corner: int = (st.n - 1) * st.n
		_ok(view.has_point(_at(corner)) and not Rect2(_b._zoom_b.position, _b._zoom_b.size).grow(4.0).has_point(_at(corner)),
			"band %d: the lower left peg can be pushed clear of the button (peg at %s, k %.2f, view %s)" % [band, _at(corner), z.k, view])
		# A run keeps its row zoomed, and paints nothing out of sight.
		z.reset()
		_b._on_zoom_button()
		_b._on_zoom_button()
		var first := -1
		for c in st.size():
			if view.grow(-60.0).has_point(_at(c)) and int(st.beads[c]) == State.EMPTY:
				first = c
				break
		var from := _at(first)
		var step: float = _b._cell * z.k
		_finger(0, from, true)
		_slide(0, from + Vector2(step * 0.5, step * 0.3))
		_ok(st.placed() == 1, "band %d: half a peg on the screen is not yet a run" % band, true)
		for i in range(1, 60):
			_slide(0, from + Vector2(i * step * 0.6, sin(i * 1.7) * step * 0.45))
		_finger(0, from, false)
		var rows := {}
		var hidden := 0
		for c in st.size():
			if int(st.beads[c]) != State.EMPTY:
				rows[c / st.n] = true
				if not view.grow(step * 0.5).has_point(_at(c)):
					hidden += 1
		_ok(rows.size() == 1 and st.placed() >= 4, "band %d: a wobbly run on the zoomed board keeps its row (%d beads)" % [band, st.placed()])
		_ok(hidden == 0, "band %d: a finger past the tray's edge paints no peg out of sight" % band)
		# A hint out of sight is brought into view (Hard), and Reset goes whole.
		if band == 2:
			var ok := true
			for i in 2:
				if _b.hint():
					var h := -1
					for c in st.size():
						if st.locked[c] == State.HINTED and not view.has_point(_at(c)):
							h = c
					if h >= 0:
						ok = false
			_ok(ok and _b.hints_used == 2, "Hard: a hinted peg is in sight")
		_b.reset_board()
		_ok(z.k == 1.0 and not z.zoomed() and st.placed() == _b.hints_used, "band %d: Reset goes back to the whole board" % band)
		_b._sync_zoom()
		_ok(_b._zoom_icon == "plus", "band %d: and the button is a plus again" % band, true)
	# No zoom on the small bands: a second finger is just ignored.
	_deal(1)
	_finger(0, _at(14), true)
	_finger(1, _at(40), true)
	_ok(_b._stroking and _b._state.placed() == 1 and not _b.zoom.busy() and not _b._zoom_b.visible,
		"Medium: no zoom, no button, a second finger changes nothing")
	_finger(1, _at(40), false)
	_finger(0, _at(14), false)
	_ok(_b._state.placed() == 1 and _b._state.history.size() == 1, "... and the stroke lands", true)

## A run dragged sideways with a wobbling finger stays on its row; one that
## sets off downwards stays on its column; a peg holding another colour
## refuses a bead and keeps its own.
func _stroke_checks() -> void:
	_deal(1)
	var st = _b._state
	var n: int = st.n
	var cell: float = _b._cell
	var c0 := 2 * n + 1
	var from: Vector2 = _b.cell_to_local(2, 1)
	_b.set_brush(0)
	_finger(0, from, true)
	for i in range(1, 9):
		_slide(0, from + Vector2(i * cell * 0.6, sin(i * 1.7) * cell * 0.45))
	_finger(0, from, false)
	var rows := {}
	var placed := 0
	for c in st.size():
		if int(st.beads[c]) != -1:
			rows[c / n] = true
			placed += 1
	_ok(rows.size() == 1 and rows.has(2) and placed >= 4, "a wobbly sideways run stays on its row (%d beads)" % placed)
	_b.undo()
	_finger(0, from, true)
	for i in range(1, 7):
		_slide(0, from + Vector2(sin(i * 1.3) * cell * 0.45, i * cell * 0.6))
	_finger(0, from, false)
	var cols := {}
	for c in st.size():
		if int(st.beads[c]) != -1:
			cols[c % n] = true
	_ok(cols.size() == 1 and cols.has(1), "a run set off downwards stays on its column")
	_b.set_brush(1)
	_tap(c0)
	_ok(int(st.beads[c0]) == 0, "a peg holding another colour keeps its bead")
	_b.set_brush(0)
	_tap(c0)
	_ok(int(st.beads[c0]) == -1, "its own colour lifts it")

# --- the box ---

func _box_checks() -> void:
	for band in 4:
		_deal(band)
		var st = _b._state
		var card := Rect2(Vector2.ZERO, SIZE)
		var inside: bool = card.encloses(_b._thumb) and card.encloses(_b._board) and card.encloses(_b._box) \
			and _b._right.grow(1.0).encloses(_b._box) and _b._box.end.y < _b._right.end.y - 20.0 \
			and _b._board.position.y >= _b._thumb.end.y
		var apart := true
		var heaped := true
		for i in _b._chip_rects.size():
			var r: Rect2 = _b._chip_rects[i]
			if r.size.x < 60.0 or r.size.y < 60.0:
				apart = false
			for j in i:
				if r.intersects(_b._chip_rects[j]):
					apart = false
			if _b._chip_at_point(r.get_center()) != i:
				apart = false
			var shown: int = _b._heap_shown(i)
			if shown > _b._heap_most or shown > st.need[i] or (shown == 0) != (st.left(i) == 0):
				heaped = false
			if shown > 0 and not r.grow(2.0).has_point(_b._slot(i, shown - 1)):
				heaped = false
		_ok(inside and apart, "band %d: %d compartments in %d row(s), %s each, inside the head" % [band,
			_b._chip_rects.size(), _b._chip_rows, _b._chip_rects[0].size])
		_ok(heaped, "band %d: every heap lies in its compartment (%d beads at most, radius %.2f)" % [band, _b._heap_most, _b._heap_r])
		_ok(_b.card_height(SIZE.y) <= SIZE.y and _b._board.end.y <= SIZE.y, "band %d: the card is %d tall" % [band, int(_b.card_height(SIZE.y))], true)

func _tutorial_pages() -> void:
	for band in 4:
		_deal(band)
		var lessons: Array = []
		for page: Dictionary in _b.tutorial_pages():
			var d = page.diagram
			lessons.append(int(d.lesson) if "lesson" in d else -1)
			d.free()
		_ok(lessons.has(Diagram.Lesson.ZOOM) == (band >= 2), "band %d tutorial: %d pages, the zoom's %s" % [band, lessons.size(),
			"among them" if band >= 2 else "not"])
