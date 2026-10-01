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
