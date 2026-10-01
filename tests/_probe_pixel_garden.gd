extends SceneTree

## Pixel Garden's plates, hearts and Windblown, headless, through the board's
## own touches (reduce motion, so an iron is instant): every band solved by
## tapping each peg right; on Hard a plate filled with one bead astray, three
## times, to the out-of-hearts card and Try again; Windblown's card mapping
## checked to be a turn and a shuffle of the true plates.
##
##     godot --headless --script res://tests/_probe_pixel_garden.gd

const Board = preload("res://puzzles/pixel_garden2d.gd")
const Motion = preload("res://core/motion.gd")

var _b
var _step := 0
var _wait := 0.0
var _band := 0
var _fails := 0
var _log: Array[String] = []

func _initialize() -> void:
	Motion.reduce = true

func _process(delta: float) -> bool:
	if _wait > 0.0:
		_wait -= delta
		return false
	match _step:
		0:
			_deal(_band)
			_step = 1
		1:
			_solve_all()
			_ok(_b.is_done(), "band %d solved by touch (%d moves)" % [_band, _b.moves])
			_ok(_b._state.ironed == PackedByteArray([1, 1, 1, 1]), "band %d every plate ironed" % _band)
			_band += 1
			_step = 0 if _band < 4 else 2
		2:
			_deal(2)
			_ok(_b.max_hearts == 3 and _b.capabilities() == ["undo", "hint"], "Hard: 3 hearts, no Check")
			_astray(0)
			_step = 3
		3:
			_ok(_b.hearts == 2, "Hard: a plate with a bead astray cost a heart (%d)" % _b.hearts)
			_ok(_b._state.ironed[0] == 0, "Hard: the wrong plate stays un-ironed")
			_astray(0)
			_astray(0)
			_wait = 2.5
			_step = 4
		4:
			_ok(_b.out_of_hearts and _b._asleep, "Hard: out of hearts, asleep")
			_ok(is_instance_valid(_b._heart_card), "Hard: the out-of-hearts card is up")
			_b.try_again()
			_ok(_b.hearts == 3 and not _b.out_of_hearts and _b._state.placed() == 0, "Try again: hearts full, bare board")
			_solve_all()
			_ok(_b.is_done() and not _b._flawless, "Hard solved after Try again, not flawless")
			_step = 5
		5:
			_deal(3)
			var st = _b._state
			_ok(_b.capabilities() == ["undo"] and _b.max_hearts == 2, "Windblown: 2 hearts, undo only")
			var seen := {}
			var moved := 0
			for q in 4:
				if st.perm[q] != q or st.turn[q] != 0:
					moved += 1
				for v in st.half:
					for u in st.half:
						seen[st.card_peg(q, u, v)] = true
			_ok(seen.size() == st.size(), "Windblown: the card shows every peg once")
			_ok(moved == 4, "Windblown: no square left in place and upright")
			_solve_all()
			_ok(_b.is_done() and _b._flawless, "Windblown solved, flawless")
			_ok(_b.share_glyphs().contains("🌬"), "Windblown share line")
			_undo_after_fuse()
			_stroke_checks()
			print("\n".join(_log))
			print("pixel garden probe: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
			return true
	return false

func _deal(band: int) -> void:
	if _b != null:
		_b.queue_free()
	_b = Board.new()
	_b.size = Vector2(810, 1180)
	root.add_child(_b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + band
	_b.start(rng, band)
	_b._layout()

func _tap(c: int) -> void:
	var n: int = _b._state.n
	var at: Vector2 = _b.cell_to_local(c / n, c % n)
	_ok(_b._peg_at(at) == c, "peg %d found under its centre" % c, true)
	_b._press(at)
	_b._release()

func _solve_all() -> void:
	var st = _b._state
	for k in st.names.size():
		_b.set_brush(k)
		for c in st.size():
			if _b.is_done():
				return
			if int(st.want[c]) == k and int(st.beads[c]) != k:
				_tap(c)

## Fills plate q with its beads but one, which goes onto a bare peg of the
## same plate in that bead's colour.
func _astray(q: int) -> void:
	var st = _b._state
	var bare := -1
	var skip := -1
	for c in st.plate_pegs(q):
		if int(st.want[c]) == -1 and bare < 0:
			bare = c
		elif int(st.want[c]) != -1 and skip < 0:
			skip = c
	if bare < 0 or skip < 0:
		_ok(false, "plate %d has no bare peg to stray onto" % q)
		return
	for c in st.plate_pegs(q):
		if c != skip and int(st.want[c]) != -1 and int(st.beads[c]) != int(st.want[c]):
			_b.set_brush(int(st.want[c]))
			_tap(c)
	_b.set_brush(int(st.want[skip]))
	_tap(bare)

func _ok(cond: bool, what: String, quiet := false) -> void:
	if not cond:
		_fails += 1
		_log.append("FAIL " + what)
	elif not quiet:
		_log.append("ok   " + what)

## The review's case: the last bead of a colour, misplaced on a bare peg of
## another plate, lifted, then seated where plate 0 wants it -- completing
## plate 0, whose iron fuses it and forgets that stroke. Undo of the lift
## must not seat a bead the kit no longer has.
func _undo_after_fuse() -> void:
	_deal(0)
	var st = _b._state
	var target := -1
	for d in st.plate_pegs(0):
		if int(st.want[d]) != -1:
			target = d
	var k := int(st.want[target])
	var stray := -1
	for d in st.plate_pegs(3):
		if int(st.want[d]) == -1:
			stray = d
			break
	for d in st.plate_pegs(0):
		if d != target and int(st.want[d]) != -1:
			_b.set_brush(int(st.want[d]))
			_tap(d)
	_b.set_brush(k)
	for d in st.size():
		if d != target and int(st.want[d]) == k and int(st.beads[d]) != k:
			_tap(d)
	_tap(stray)
	_ok(st.left(k) == 0 and int(st.beads[stray]) == k, "the last bead of the colour sits astray")
	_tap(stray)
	_tap(target)
	_ok(st.ironed[0] == 1, "plate 0 ironed by the moved bead")
	_b.undo()
	_ok(st.left(k) >= 0, "undo after a fuse keeps the kit honest (left %d)" % st.left(k))

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
	_b._press(from)
	for i in range(1, 9):
		# Drifting up and down by half a peg either way as it goes right.
		_b._drag(from + Vector2(i * cell * 0.6, sin(i * 1.7) * cell * 0.45))
	_b._release()
	var rows := {}
	var placed := 0
	for c in st.size():
		if int(st.beads[c]) != -1:
			rows[c / n] = true
			placed += 1
	_ok(rows.size() == 1 and rows.has(2) and placed >= 4, "a wobbly sideways run stays on its row (%d beads, rows %s)" % [placed, rows.keys()])
	_b.undo()
	_b._press(from)
	for i in range(1, 7):
		_b._drag(from + Vector2(sin(i * 1.3) * cell * 0.45, i * cell * 0.6))
	_b._release()
	var cols := {}
	for c in st.size():
		if int(st.beads[c]) != -1:
			cols[c % n] = true
	_ok(cols.size() == 1 and cols.has(1), "a run set off downwards stays on its column (cols %s)" % [cols.keys()])
	_b.set_brush(1)
	_tap(c0)
	_ok(int(st.beads[c0]) == 0, "a peg holding another colour keeps its bead")
	_b.set_brush(0)
	_tap(c0)
	_ok(int(st.beads[c0]) == -1, "its own colour lifts it")
