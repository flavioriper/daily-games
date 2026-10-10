extends Control

## Reversi's board, seen from straight above as it lies on the deck: a painted
## blue tray of eight squares by eight in a wooden frame, and discs with two
## faces. The player's face is the sun's (cream, a sun stamped on it), the
## other player's the moon's (night blue, a crescent stamped on it), whichever
## of them moves first; a disc's edge shows the face underneath.
##
## While it is the player's turn every square that may be played carries a
## small dot. A finger on a square frames it and rings the discs it would
## turn, since the thumb hides the square it is on; letting go sets the disc
## there. The disc lands, and the runs it shut turn over one after another
## outwards from it.
##
## Everything that does not move is one baked mesh. A disc is one cached mesh
## a face, drawn under a transform wherever it lies and squashed across to
## turn it over. What changes shape (the dots, the frame under the finger, the
## rings, the tally under the board) is one small mesh rebuilt only while
## something moves.
##
## The board shows what it has been told (`play`, `sync`), not the rules it
## was set up from, so a disc is turned only once its move has been shown.
##
## The moments are light and the discs' own transforms, all in the mesh over
## the discs: the light of the side that moved runs along a run as it turns,
## a big move blooms and its discs answer, a corner is framed in brass, an
## edge filled lights its rail, a side passed over sinks twice, the tally's
## notch swells when the lead changes hands, and at the end the winner's
## discs are counted off in a wave. Light is soft and round, never a star.

## The player let go over a square that may be played.
signal chosen(cell: int)
## What was being shown has finished: the board is set, a move's discs have
## turned, a move taken back is off.
signal settled
## The square let go over may not be played: "taken" or "none".
signal refused(reason: String)

const Rules = preload("res://versus/reversi_rules.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## A square's side in the meshes' own space, whose origin is the top left of
## the squares.
const U := 100.0
const GRID := Vector2(Rules.W * U, Rules.W * U)
const FRAME := 34.0
const DISC_R := 40.0
## The tally under the board: its top, its height.
const TALLY_Y := 866.0
const TALLY_H := 22.0
## The space the board takes, alone and with the room over it (the screen's
## line of words) and the tally under it.
const SPACE := Rect2(-FRAME - 6.0, -FRAME - 6.0, GRID.x + 2.0 * FRAME + 12.0, GRID.y + 2.0 * FRAME + 22.0)
const SPACE_TALLY := Rect2(-FRAME - 6.0, -FRAME - 96.0, GRID.x + 2.0 * FRAME + 12.0, GRID.y + 2.0 * FRAME + 96.0 + 76.0)

const FIELD := Color("5f93cf")
const FIELD_LIT := Color("6ea2da")
const LINE := Color("47739f")
const WOOD := Color("b98457")
const WOOD_LIT := Color("d3a273")
const WOOD_DEEP := Color("7d5334")
## A disc's face, the ring raised on it, its shine and its stamp, by look: the
## sun's, the moon's.
const DISC := [Color("fbf1dc"), Color("2c3768")]
const RING := [Color("e6d4ae"), Color("3e4b86")]
const SHINE := [Color("ffffff"), Color("6f7fc4")]
const STAMP := [Color("e9a826"), Color("aab8ee")]
const HALO := Color("fff6e0")
const HINT := Color("f9c04a")
## A side's light, by look: the sun's is warm, the moon's silver. Light on a
## square or round a disc, never a tint of the disc.
const LIGHT := [Color("ffe7a0"), Color("e3e9ff")]
const BRASS := Color("d2a54f")
const BRASS_DEEP := Color("9a7330")
const BRASS_HI := Color("f1d58f")
const CORNERS := [0, Rules.W - 1, Rules.CELLS - Rules.W, Rules.CELLS - 1]

## Seconds: a disc landing, a disc turning over, the wait between one ring of
## turning discs and the next, the look at a move before the game goes on, a
## move taken back, the board cleared.
const POP := 0.2
const FLIP := 0.34
const STEP := 0.085
const WATCH := 0.22
const REWIND := 0.3
const SWEEP := 0.5

## The moments. A disc that has turned settles with a swell of `SETTLE`. The
## light under a turning disc is fullest when the disc is edge on and is gone
## `RIPPLE_OUT` s later, and a mote of it drifts `MOTE_DRIFT` off for
## `MOTE_TIME`. The disc set down blooms for `BLOOM_TIME`. A big move (at
## least `BIG` discs, or `BIG_LINES` lines at once) blooms again once the last
## disc is over, `BIG_MOTES` motes leaving it for `BIG_TIME`, and its discs
## answer with a swell of `ENCORE` a ring at a time. A corner is framed in
## brass for `CORNER_TIME`. An edge filled: light runs its rail from the disc
## both ways (`RAIL_TIME` the whole of it). A side passed over: its discs
## sink by `KNOCK` twice, `KNOCK_HOP` s each. The lead changing hands: the
## notch swells by `LEAD_BUMP` and the leader's disc at its end of the tally
## with it, in light for `LEAD_TIME`. The end: after `COUNT_DELAY` the
## winner's discs swell by `COUNT_HOP` one after another over `COUNT_SPAN`,
## each in its light, and the player's own sink once (`SIGH`, `SIGH_TIME`)
## when the game is lost. The only square that may be played beckons every
## `BECKON` s; the dots come up `DOT_STEP` apart when a turn begins.
const SETTLE := 0.07
const RIPPLE_OUT := 0.42
const MOTE_TIME := 0.75
const MOTE_DRIFT := 44.0
const BLOOM_TIME := 0.5
const BIG := 6
const BIG_LINES := 3
const BIG_TIME := 0.8
const BIG_MOTES := 8
const ENCORE := 0.12
const CORNER_TIME := 1.1
const RAIL_TIME := 0.5
const KNOCK := 0.1
const KNOCK_HOP := 0.2
const LEAD_BUMP := 0.7
const LEAD_TIME := 0.7
const COUNT_DELAY := 0.25
const COUNT_HOP := 0.16
const COUNT_SPAN := 1.1
const SIGH := 0.08
const SIGH_TIME := 0.7
const BECKON := 1.4
const DOT_STEP := 0.03

## The notches at play (docs/agents/sound.md, rule 2). A notch is never the
## same sound twice: `place`, `lift` and `refused` are played 0.94 to 1.06 at
## random (they were 1.0 every time). `flip` is played once a ring of discs
## turned, half a step higher a ring from FLIP_PITCH.x, and the whole run of
## a move is moved by one such draw, so it still climbs: 0.893 to 1.185 at
## the widest, 4.9 semitones. It was `0.92 + 0.045 * k` with no variation,
## 4.5 semitones over seven rings, which the variation would take to 6.5.
const TICK_VARY := Vector2(0.94, 1.06)
const VARIED := ["place", "lift", "refused"]
const FLIP_PITCH := Vector2(0.95, 0.028)

var rules: RefCounted
## The rules' side the player is: its face is the sun's.
var player := 0
var interactive := false:
	set(v):
		if v and not interactive:
			_turn_at = _t
			_single = rules != null and rules.legal_moves().size() == 1
			_busy(0.6)
		interactive = v
		queue_redraw()
## A picture, not a game (the Versus tab's card): drawn when asked, no input,
## no tally, as wide as the control.
var still := false
## Whether the tally under the board is drawn (not on a tutorial page).
var tally := true
## A tutorial page's board: it moves as a game's does, but hears no finger
## and makes no sound.
var deaf := false
## The rectangle the board takes.
var used_rect := Rect2()

var _xf := Transform2D.IDENTITY
var _base: ArrayMesh
var _disc: Array[ArrayMesh] = []
var _over_mesh: ArrayMesh
var _shown: Array = []
var _fx: Node2D
var _run := 0
var _t := 0.0
var _busy_until := 0.0
## What lies on each square as shown: 0 empty, else a look plus one.
var _cells := PackedByteArray()
## Discs turning over: cell -> {from: the look it shows first, at: when}.
var _turning := {}
## Discs landing: cell -> when.
var _pop := {}
## Discs going off the board: {cell, look, at}.
var _gone: Array[Dictionary] = []
## The square under the finger (-1 none), and whether a finger is down.
var _over := -1
var _down := false
var _hint := -1
## The square the other player has chosen and not yet played.
var _lifted := -1
var _last := -1
var _shake_at := -10.0
var _shake_cell := -1
## How the game ended, "" while it is on.
var _mood := ""
## The sun's share of the tally as drawn.
var _share := 0.5
## Light on a square while its disc turns: cell -> {at, look, dir}.
var _glow := {}
## The disc set down last: where, whose, when, how many it turned, and when
## a big move blooms again (-10 if it is not one).
var _bloom_c := -1
var _bloom_look := 0
var _bloom_at := -10.0
var _bloom_n := 0
var _big_at := -10.0
## Discs answering a big move: cell -> when.
var _encore := {}
var _corner_c := -1
var _corner_at := -10.0
## Edges filled by the last disc: {cells: the edge's squares, out: which way
## the rail lies, from: the disc's place along it, at}.
var _rails: Array[Dictionary] = []
var _knock_look := -1
var _knock_at := -10.0
## Who is ahead as the tally shows it (1 the sun, -1 the moon, 0 nobody yet),
## when that last changed hands, and until when a change is not a moment (a
## move being taken back).
var _lead := 0
var _lead_at := -10.0
var _lead_quiet := 0.0
## The end: when, the winner's look (-1 a draw), each of its discs' wait.
var _end_at := -10.0
var _end_look := -1
var _end_wait := {}
## When the turn became the player's, and whether one square only is open.
var _turn_at := 0.0
var _single := false
var _lifted_at := -10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if still or deaf else Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	if not still and not deaf:
		_fx = Fx2D.new()
		add_child(_fx)
	_layout()

# --- setting up ---

## A board showing `the_rules` as they stand, the player being `side`. With
## `enter`, whatever lay on the board before is swept off first, and `settled`
## is said once the opening's discs are down.
func setup(the_rules: RefCounted, side: int, enter := false) -> void:
	_run += 1
	var old := _cells
	rules = the_rules
	player = side
	_cells = PackedByteArray()
	_cells.resize(Rules.CELLS)
	for c in Rules.CELLS:
		if rules.cells[c] != Rules.EMPTY:
			_cells[c] = look_of(rules.cells[c] - 1) + 1
	_turning = {}
	_pop = {}
	_gone.clear()
	_over = -1
	_down = false
	_hint = -1
	_lifted = -1
	_last = -1
	_mood = ""
	_share = _want_share()
	_glow = {}
	_encore = {}
	_rails.clear()
	_bloom_at = -10.0
	_big_at = -10.0
	_corner_at = -10.0
	_knock_at = -10.0
	_lead = 0
	_lead_at = -10.0
	_end_at = -10.0
	_end_wait = {}
	_single = false
	var wait := 0.0
	if enter and not Motion.reduce:
		if old.size() == Rules.CELLS and old != _cells:
			for c in Rules.CELLS:
				if old[c] != 0:
					_gone.append({"cell": c, "look": old[c] - 1, "at": _t + 0.022 * (c % Rules.W + c / Rules.W)})
			if not _gone.is_empty():
				_cue("sweep")
				wait = SWEEP
		for c in Rules.CELLS:
			if _cells[c] != 0:
				_pop[c] = _t + wait + 0.06 * _pop.size()
		wait += 0.24 + POP
	if enter:
		_after(wait + 0.05, func() -> void: settled.emit())
	_busy(wait + 0.4)
	queue_redraw()

## The look of a rules' side: 0 the sun's (the player's), 1 the moon's.
func look_of(side: int) -> int:
	return 0 if side == player else 1

## The middle of a square, in the meshes' space.
static func mid(c: int) -> Vector2:
	return Vector2((c % Rules.W + 0.5) * U, (c / Rules.W + 0.5) * U)

## A point of the meshes' space, in the board's own.
func point_of(p: Vector2) -> Vector2:
	return _xf * p

## Where a line of words can stand without hiding a square: over the board.
func toast_point() -> Vector2:
	return _xf * Vector2(GRID.x * 0.5, -FRAME - 48.0)

# --- what the screen tells it ---

## The disc of the rules' `side` is set on `cell` and turns `turned` over,
## the nearest first.
func play(cell: int, turned: PackedInt32Array, side: int) -> void:
	var look := look_of(side)
	_hint = -1
	_lifted = -1
	_over = -1
	_down = false
	_cells[cell] = look + 1
	_last = cell
	if Motion.reduce:
		for q in turned:
			_cells[q] = look + 1
		_cue("place")
		_share = _want_share()
		_after(Motion.REDUCED_TIME, func() -> void: settled.emit())
		queue_redraw()
		return
	_cue("place")
	_pop[cell] = _t
	# The runs turn outwards from the disc, a ring of squares at a time.
	var far := 0
	var lines := {}
	for q in turned:
		var d := Vector2i(q % Rules.W - cell % Rules.W, q / Rules.W - cell / Rules.W)
		var ring := maxi(absi(d.x), absi(d.y))
		far = maxi(far, ring)
		lines[d.sign()] = true
		var at := _t + POP * 0.6 + STEP * (ring - 1)
		_turning[q] = {"from": _cells[q] - 1, "at": at}
		_glow[q] = {"at": at, "look": look, "dir": Vector2(d).normalized()}
		_cells[q] = look + 1
	var vary := randf_range(TICK_VARY.x, TICK_VARY.y)
	for ring in far:
		var k: int = ring
		_after(POP * 0.6 + STEP * k + FLIP * 0.5, func() -> void: _cue("flip", (FLIP_PITCH.x + FLIP_PITCH.y * k) * vary, -3.0 + 0.5 * k))
	var total := POP * 0.6 + STEP * (far - 1) + FLIP
	_bloom_c = cell
	_bloom_look = look
	_bloom_at = _t
	_bloom_n = turned.size()
	_big_at = -10.0
	if turned.size() >= BIG or lines.size() >= BIG_LINES:
		_big_at = _t + total - FLIP * 0.4
		_encore[cell] = _big_at
		for q in turned:
			var ring := maxi(absi(q % Rules.W - cell % Rules.W), absi(q / Rules.W - cell / Rules.W))
			_encore[q] = _big_at + Motion.stagger(ring, Motion.WAVE_STEP)
		_busy(total + BIG_TIME + 0.4)
	if cell in CORNERS:
		_corner_c = cell
		_corner_at = _t
		_busy(CORNER_TIME + 0.1)
	_rails.clear()
	_note_edges(cell)
	_busy(total + WATCH + 0.3 + MOTE_TIME)
	_after(total + WATCH, func() -> void: settled.emit())

## The edges the disc on `cell` has just filled: every square of the row or
## column along the frame now holds a disc.
func _note_edges(cell: int) -> void:
	var x := cell % Rules.W
	var y := cell / Rules.W
	var last := Rules.W - 1
	for e: Array in [[y == 0, Vector2i(1, 0), 0, Vector2.UP, x], [y == last, Vector2i(1, 0), last * Rules.W, Vector2.DOWN, x],
			[x == 0, Vector2i(0, 1), 0, Vector2.LEFT, y], [x == last, Vector2i(0, 1), last, Vector2.RIGHT, y]]:
		if not e[0]:
			continue
		var cells := PackedInt32Array()
		var full := true
		for i in Rules.W:
			var c: int = int(e[2]) + i * (e[1].x + e[1].y * Rules.W)
			cells.append(c)
			if _cells[c] == 0:
				full = false
		if full:
			_rails.append({"cells": cells, "out": e[3], "from": e[4], "at": _t + POP})
			_busy(POP + RAIL_TIME + Motion.FLASH_OUT + 0.2)

## The rules' `side` has no square and is passed over: its discs sink twice,
## the knock of a hand on the table. Nothing under reduce motion.
func knock(side: int) -> void:
	if Motion.reduce:
		return
	_knock_look = look_of(side)
	_knock_at = _t
	_busy(KNOCK_HOP * 2.0 + 0.5)
	queue_redraw()

## The board is made to show the rules as they now stand (a move taken back):
## a disc no longer there goes off, a disc turned turns back.
func sync() -> void:
	_lead_quiet = _t + REWIND + FLIP + 0.2
	_glow = {}
	_encore = {}
	_rails.clear()
	_bloom_at = -10.0
	_big_at = -10.0
	_corner_at = -10.0
	_hint = -1
	_lifted = -1
	_last = -1
	if not rules.history.is_empty():
		_last = rules.history[rules.history.size() - 1][0]
	var changed := false
	for c in Rules.CELLS:
		var want: int = 0 if rules.cells[c] == Rules.EMPTY else look_of(rules.cells[c] - 1) + 1
		if _cells[c] == want:
			continue
		changed = true
		if not Motion.reduce:
			if want == 0:
				_gone.append({"cell": c, "look": _cells[c] - 1, "at": _t})
			elif _cells[c] != 0:
				_turning[c] = {"from": _cells[c] - 1, "at": _t}
			else:
				_pop[c] = _t
		_cells[c] = want
	if changed:
		_cue("lift")
	_busy(REWIND + 0.4)
	_after(Motion.REDUCED_TIME if Motion.reduce else REWIND + 0.1, func() -> void: settled.emit())
	queue_redraw()

## The bulb's square, -1 for none.
func set_hint(cell: int) -> void:
	_hint = cell
	_busy(0.2)
	queue_redraw()

## The other player has chosen `cell`: it is ringed until the disc is down.
func set_lifted(cell: int) -> void:
	_lifted = cell
	_lifted_at = _t
	_busy(0.3)
	queue_redraw()

## The game is over: the winner's discs glint (`side` the rules', -1 a draw).
func finish(outcome: String, side := -1) -> void:
	_mood = outcome
	_hint = -1
	_lifted = -1
	_over = -1
	_down = false
	_end_wait = {}
	_end_look = -1
	if not Motion.reduce:
		# The count: the winner's discs one after another, a slant at a time
		# from the top left; a draw counts every disc.
		_end_at = _t + COUNT_DELAY
		_end_look = look_of(side) if side >= 0 else -1
		var mine: Array[int] = []
		for d in Rules.W * 2 - 1:
			for y in Rules.W:
				var x := d - y
				if x < 0 or x >= Rules.W:
					continue
				var c := x + y * Rules.W
				if _cells[c] != 0 and (_end_look < 0 or _cells[c] == _end_look + 1):
					mine.append(c)
		var per := minf(Motion.SOLVE_STAGGER, COUNT_SPAN / maxf(1.0, mine.size()))
		for i in mine.size():
			_end_wait[mine[i]] = Motion.stagger(i, per, COUNT_SPAN)
		_busy(COUNT_DELAY + COUNT_SPAN + Motion.SOLVE_TIME + MOTE_TIME + 0.2)
	_busy(1.2)
	queue_redraw()

## Whether a disc is still landing, turning or going off.
func is_busy() -> bool:
	return not _turning.is_empty() or not _pop.is_empty() or not _gone.is_empty() or not _glow.is_empty() or not _encore.is_empty()

# --- layout and time ---

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var space := SPACE_TALLY if tally and not still else SPACE
	var s := size.x / space.size.x if still else minf(size.x / space.size.x, size.y / space.size.y)
	var at := (size - space.size * s) * 0.5
	_xf = Transform2D(0.0, Vector2(s, s), 0.0, at - space.position * s)
	used_rect = Rect2(at, space.size * s)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var live := _t < _busy_until or _down
	for c: int in _turning.keys():
		if _t >= float(_turning[c].at) + FLIP + Motion.BUMP_TIME:
			_turning.erase(c)
	for c: int in _glow.keys():
		if _t >= float(_glow[c].at) + FLIP * 0.5 + maxf(RIPPLE_OUT, MOTE_TIME):
			_glow.erase(c)
	for c: int in _encore.keys():
		if _t >= float(_encore[c]) + Motion.BUMP_TIME:
			_encore.erase(c)
	for c: int in _pop.keys():
		if _t >= float(_pop[c]) + POP:
			_pop.erase(c)
	var i := 0
	while i < _gone.size():
		if _t >= float(_gone[i].at) + POP:
			_gone.remove_at(i)
		else:
			i += 1
	if is_busy():
		live = true
	var want := _want_share()
	if _share != want:
		_share = want if Motion.reduce else move_toward(_share, want, delta * 0.6)
		live = true
	var lead := signi(roundi((want - 0.5) * 1000.0))
	if lead != 0 and lead != _lead:
		if _lead != 0 and _t >= _lead_quiet and _mood == "" and not Motion.reduce:
			_lead_at = _t
			_busy(LEAD_TIME + 0.1)
		_lead = lead
	# the only open square beckons, and the board wakes for as long
	if interactive and _single and _mood == "" and not Motion.reduce and not _down \
			and fmod(_t - _turn_at, BECKON) < Motion.BUMP_TIME + 0.05 and _t - _turn_at > BECKON * 0.5:
		live = true
	if live:
		queue_redraw()

## The sun's share of the discs on the board, counting a disc as turned when
## it is seen to turn.
func _want_share() -> float:
	var sun := 0
	var moon := 0
	for c in Rules.CELLS:
		if _cells[c] == 0:
			continue
		var look := _cells[c] - 1
		if _turning.has(c) and _t < float(_turning[c].at) + FLIP * 0.5:
			look = int(_turning[c].from)
		if look == 0:
			sun += 1
		else:
			moon += 1
	return 0.5 if sun + moon == 0 else float(sun) / float(sun + moon)

func _busy(seconds: float) -> void:
	_busy_until = maxf(_busy_until, _t + seconds)

func _after(seconds: float, what: Callable) -> void:
	var run := _run
	if not is_inside_tree():
		return
	get_tree().create_timer(maxf(seconds, 0.01)).timeout.connect(func() -> void:
		if run == _run and is_inside_tree():
			what.call())

func _cue(cue_name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if _fx != null:
		if cue_name in VARIED:
			pitch *= randf_range(TICK_VARY.x, TICK_VARY.y)
		_fx.cue(cue_name, pitch, volume_db)

# --- input ---

## The square a point of the board is over, -1 off the squares.
func cell_at(p: Vector2) -> int:
	var q := _xf.affine_inverse() * p
	if q.x < 0.0 or q.y < 0.0 or q.x >= GRID.x or q.y >= GRID.y:
		return -1
	return int(q.x / U) + int(q.y / U) * Rules.W

func _gui_input(event: InputEvent) -> void:
	if still or deaf or not interactive:
		return
	var press := false
	var release := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		release = not event.pressed
		at = event.position
	elif event is InputEventScreenDrag and event.index == 0:
		at = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		at = event.position
	else:
		return
	accept_event()
	var cell := cell_at(at)
	if release:
		if not _down:
			return
		_down = false
		_over = -1
		if cell >= 0:
			if rules.can(cell):
				chosen.emit(cell)
			else:
				_shake_at = _t
				_shake_cell = cell
				_busy(0.4)
				_cue("refused")
				refused.emit("taken" if _cells[cell] != 0 else "none")
		queue_redraw()
		return
	if press:
		_down = true
	if not _down:
		return
	if cell != _over:
		_over = cell
		_busy(0.2)
	queue_redraw()

# --- drawing ---

func _draw() -> void:
	if rules == null or used_rect.size.x <= 0.0:
		return
	if _base == null:
		_base = _build_base()
		_disc = [_build_disc(0), _build_disc(1)]
	_over_mesh = _build_over()
	_shown = [_base, _disc, _over_mesh]
	draw_mesh(_base, null, _xf)
	for g: Dictionary in _gone:
		var f := clampf((_t - float(g.at)) / POP, 0.0, 1.0)
		if f >= 1.0:
			continue
		var k := 1.0 - 0.35 * f
		draw_mesh(_disc[int(g.look)], null, _xf * Transform2D(0.0, Vector2(k, k), 0.0, mid(int(g.cell))), Color(1, 1, 1, 1.0 - f))
	for c in Rules.CELLS:
		if _cells[c] == 0:
			continue
		var look := _cells[c] - 1
		var at := mid(c)
		if _pop.has(c):
			var f := (_t - float(_pop[c])) / POP
			if f < 0.0:
				continue
			if f < 1.0:
				var k := lerpf(1.35, 1.0, ease(f, 0.4))
				draw_mesh(_disc[look], null, _xf * Transform2D(0.0, Vector2(k, k), 0.0, at), Color(1, 1, 1, minf(1.0, f * 2.5)))
				continue
		var k := _swell(c, look)
		if _turning.has(c):
			var since := _t - float(_turning[c].at)
			var f := since / FLIP
			if f < 0.5:
				look = int(_turning[c].from)
			if f > 0.0 and f < 1.0:
				var lift := 1.0 + 0.16 * sin(PI * f)
				var across := maxf(0.04, absf(cos(PI * f)))
				draw_mesh(_disc[look], null, _xf * Transform2D(0.0, Vector2(across * lift, lift), 0.0, at))
				continue
			# over, it settles
			k *= Motion.bump_scale(since - FLIP, SETTLE)
		if k == 1.0:
			draw_mesh(_disc[look], null, _xf * Transform2D(0.0, at))
		else:
			draw_mesh(_disc[look], null, _xf * Transform2D(0.0, Vector2(k, k), 0.0, at))
	if _over_mesh != null:
		draw_mesh(_over_mesh, null, _xf)

## How much a disc at rest is swollen or sunk by the moment it is part of:
## a big move's answer, the knock of a side passed over, the count at the
## end. One when nothing is going on.
func _swell(c: int, look: int) -> float:
	var k := 1.0
	if _encore.has(c):
		k *= Motion.bump_scale(_t - float(_encore[c]), ENCORE)
	if look == _knock_look and _t - _knock_at < KNOCK_HOP * 2.0 + 0.4:
		var e := _t - _knock_at - Motion.stagger(c % Rules.W + c / Rules.W, 0.012)
		k *= 1.0 - KNOCK * (Motion.hop_lift(e, 1.0, KNOCK_HOP) + Motion.hop_lift(e - KNOCK_HOP, 1.0, KNOCK_HOP))
	if _mood != "":
		var e := _t - _end_at
		if _end_wait.has(c):
			k *= 1.0 + COUNT_HOP * Motion.hop_lift(e - float(_end_wait[c]), 1.0, Motion.SOLVE_TIME)
		elif _mood == "lost" and look == 0:
			k *= 1.0 - SIGH * Motion.hop_lift(e, 1.0, SIGH_TIME)
	return k

## The shadow the board throws on the deck, its wooden frame, the painted
## field and the lines between its squares.
func _build_base() -> ArrayMesh:
	var b := Face.Builder.new()
	var out := Vector2(FRAME, FRAME)
	Scenery.soft_disc(b, GRID * 0.5 + Vector2(0.0, 18.0), GRID.x * 0.66, 34.0, Color(0.15, 0.08, 0.03, 0.22))
	b.fan(Face.Builder.round_rect(-out + Vector2(0.0, 8.0), GRID + out * 2.0, 30.0), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(-out, GRID + out * 2.0, 30.0), WOOD)
	b.stroke(PackedVector2Array([Vector2(-6.0, -FRAME + 9.0), Vector2(GRID.x + 6.0, -FRAME + 9.0)]), 5.0, Color(WOOD_LIT, 0.8))
	# a line cut into the frame all the way round, and a brass pin a corner
	b.stroke(Face.Builder.round_rect(Vector2(-19.0, -19.0), GRID + Vector2(38.0, 38.0), 20.0), 2.5, Color(WOOD_DEEP, 0.4), true)
	for p: Vector2 in [Vector2(-19.0, -19.0), Vector2(GRID.x + 19.0, -19.0), Vector2(-19.0, GRID.y + 19.0), GRID + Vector2(19.0, 19.0)]:
		b.disc(p + Vector2(0.0, 1.5), 7.5, Color(WOOD_DEEP, 0.8))
		b.disc(p, 6.5, BRASS_DEEP)
		b.disc(p, 5.0, BRASS)
		b.disc(p + Vector2(-1.6, -1.8), 1.9, BRASS_HI)
	b.fan(Face.Builder.round_rect(Vector2(-8.0, -8.0), GRID + Vector2(16.0, 16.0), 14.0), LINE)
	b.fan(Face.Builder.round_rect(Vector2.ZERO, GRID, 8.0), FIELD)
	# every other square a touch lighter, so a row is easy to follow
	for c in Rules.CELLS:
		if (c % Rules.W + c / Rules.W) % 2 == 0:
			b.fan(Face.Builder.round_rect(Vector2(c % Rules.W, c / Rules.W) * U + Vector2(3.0, 3.0), Vector2(U - 6.0, U - 6.0), 10.0), FIELD_LIT)
	# the lamp's pool of light on the paint
	Scenery.soft_disc(b, GRID * Vector2(0.5, 0.44), GRID.x * 0.56, GRID.y * 0.52, Color(1.0, 0.97, 0.86, 0.17))
	for i in range(1, Rules.W):
		b.stroke(PackedVector2Array([Vector2(i * U, 4.0), Vector2(i * U, GRID.y - 4.0)]), 3.0, LINE)
		b.stroke(PackedVector2Array([Vector2(4.0, i * U), Vector2(GRID.x - 4.0, i * U)]), 3.0, LINE)
	for p: Vector2 in [Vector2(2, 2), Vector2(6, 2), Vector2(2, 6), Vector2(6, 6)]:
		b.disc(p * U, 7.0, LINE)
	return b.mesh()

## One disc about the origin: its shadow, the edge showing the face that is
## underneath, the face, a raised ring, a shine, and the side's stamp -- a
## sun with its rays, or a crescent -- so the two are told apart by more than
## their colour.
func _build_disc(look: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var r := DISC_R
	b.disc(Vector2(0.0, 8.0), r + 1.0, Color(0.05, 0.1, 0.2, 0.28))
	b.disc(Vector2(0.0, 4.5), r, DISC[1 - look].darkened(0.12))
	b.disc(Vector2.ZERO, r, RING[look])
	b.disc(Vector2(0.0, -1.0), r - 4.0, DISC[look])
	b.stroke(Face.Builder.ring(Vector2.ZERO, r - 10.0, r - 10.0), 2.5, Color(RING[look], 0.9), true)
	b.stroke(Face.Builder.arc_points(Vector2.ZERO, r - 6.5, PI * 1.08, PI * 1.5), 3.5, Color(SHINE[look], 0.75))
	if look == 0:
		b.disc(Vector2.ZERO, 9.5, STAMP[look])
		for k in 8:
			var d := Vector2.from_angle(TAU * k / 8.0)
			b.stroke(PackedVector2Array([d * 14.5, d * 20.5]), 4.5, STAMP[look])
	else:
		# a crescent: the outer arc of one disc, then back along another's
		var pts := Face.Builder.arc_points(Vector2(-2.0, 0.0), 17.0, PI * 0.32, PI * 1.68)
		pts.append_array(Face.Builder.arc_points(Vector2(6.0, 0.0), 14.0, PI * 1.5, PI * 0.5))
		b.polygon(pts, STAMP[look])
	return b.mesh()

## What lies over the discs: a dot on every square that may be played, the
## frame under the finger and the rings on what it would turn, the ring on
## the last disc set down, the bulb's ring, the other player's choice, and
## the tally.
func _build_over() -> ArrayMesh:
	var b := Face.Builder.new()
	var moving := not Motion.reduce
	if moving:
		_light_under(b)
	if interactive and _mood == "":
		var legal: PackedInt32Array = rules.legal_moves()
		var since := _t - _turn_at
		for i in legal.size():
			var c := legal[i]
			if c == _over and _down:
				continue
			var r := 9.0
			if moving:
				r *= Motion.back_out((since - Motion.stagger(i, DOT_STEP, 0.3)) / Motion.POP_IN) if since < 0.6 else 1.0
				if legal.size() == 1 and since > BECKON * 0.5:
					# the only square there is: it beckons
					var e := fmod(since, BECKON)
					var beat := Motion.bump_scale(e, 0.6)
					Scenery.soft_disc(b, mid(c), 34.0, 34.0, Color(HALO, 0.55 * clampf((beat - 1.0) / 0.6, 0.0, 1.0)))
					r *= beat
			if r > 0.5:
				b.disc(mid(c), r, Color(HALO, 0.55))
	if _down and _over >= 0:
		var ok: bool = rules.can(_over)
		var col := Color(HALO, 0.95) if ok else Color(Pal.BAD, 0.9)
		var at := Vector2(_over % Rules.W, _over / Rules.W) * U
		b.stroke(Face.Builder.round_rect(at + Vector2(5.0, 5.0), Vector2(U - 10.0, U - 10.0), 12.0), 6.0, col, true)
		if ok:
			b.disc(mid(_over), 13.0, Color(HALO, 0.9))
			for q: int in rules.flips(_over, rules.turn):
				b.stroke(Face.Builder.ring(mid(q), DISC_R + 4.0, DISC_R + 4.0), 5.0, Color(HALO, 0.95), true)
	var shake := _t - _shake_at
	if shake < 0.35 and _shake_cell >= 0:
		var m := mid(_shake_cell)
		var a := 0.9 * (1.0 - shake / 0.35)
		b.stroke(PackedVector2Array([m + Vector2(-16.0, -16.0), m + Vector2(16.0, 16.0)]), 8.0, Color(Pal.BAD, a))
		b.stroke(PackedVector2Array([m + Vector2(16.0, -16.0), m + Vector2(-16.0, 16.0)]), 8.0, Color(Pal.BAD, a))
	if _last >= 0 and _cells[_last] != 0 and not _pop.has(_last):
		b.stroke(Face.Builder.ring(mid(_last), DISC_R + 3.5, DISC_R + 3.5), 3.5, Color(HALO, 0.9), true)
	if _lifted >= 0:
		var r := (DISC_R - 8.0) * Motion.bump_scale(_t - _lifted_at, 0.3, 0.3)
		b.stroke(Face.Builder.ring(mid(_lifted), r, r), 6.0, Color(STAMP[1], 0.95), true)
	if _hint >= 0 and _cells[_hint] == 0:
		var beat := 0.0 if Motion.reduce else 0.5 + 0.5 * sin(_t * 5.0)
		var r := DISC_R - 9.0 + 4.0 * beat
		b.stroke(Face.Builder.ring(mid(_hint), r, r), 7.0, HINT, true)
		b.disc(mid(_hint), 8.0, HINT)
		if not Motion.reduce:
			_busy(0.2)
	if moving:
		_light_over(b)
	if tally and not still:
		_build_tally(b)
	return null if b.verts.is_empty() else b.mesh()

## Light that lies on the squares: under a disc while it turns (the disc is
## edge on when it is fullest, so it is the square that is lit), where the
## disc was set down, and round a corner taken.
func _light_under(b: Face.Builder) -> void:
	for c: int in _glow:
		var g: Dictionary = _glow[c]
		var since := _t - float(g.at)
		var level := Motion.flash_level(since, FLIP * 0.5, RIPPLE_OUT)
		if level > 0.0:
			# the square itself is lit only as far as the disc is edge on
			var edge_on := 1.0 - absf(cos(PI * clampf(since / FLIP, 0.0, 1.0)))
			_halo(b, mid(c), DISC_R, U * 0.74, Color(LIGHT[int(g.look)], 0.8 * level), 0.6 * edge_on)
	var since := _t - _bloom_at
	if since >= 0.0 and since < BLOOM_TIME and _bloom_c >= 0:
		var u := since / BLOOM_TIME
		var reach := U * (0.6 + 0.5 * u) * (1.0 + 0.05 * minf(_bloom_n, 10.0))
		_halo(b, mid(_bloom_c), DISC_R, DISC_R + reach, Color(LIGHT[_bloom_look], 0.85 * (1.0 - u)))
	since = _t - _corner_at
	if since >= 0.0 and since < CORNER_TIME and _corner_c >= 0:
		var u := since / CORNER_TIME
		_halo(b, mid(_corner_c), DISC_R, U * (0.9 + 0.7 * u), Color(BRASS_HI, 0.8 * (1.0 - u)))

## Light that leaves the board: the motes off a run turned, a big move's
## second bloom, the brass round a corner, the rail of an edge filled, the
## count at the end.
func _light_over(b: Face.Builder) -> void:
	for c: int in _glow:
		var g: Dictionary = _glow[c]
		var e := _t - float(g.at) - FLIP * 0.5
		if e > 0.0 and e < MOTE_TIME:
			var u := e / MOTE_TIME
			var out := 1.0 - (1.0 - u) * (1.0 - u)
			_mote(b, mid(c) + (g.dir as Vector2) * (DISC_R * 0.6 + MOTE_DRIFT * out) + Vector2(0.0, -12.0 * u),
				9.0 * (1.0 - 0.5 * u), LIGHT[int(g.look)], 1.0 - u)
	var since := _t - _big_at
	if since >= 0.0 and since < BIG_TIME and _bloom_c >= 0:
		var u := since / BIG_TIME
		var out := 1.0 - (1.0 - u) * (1.0 - u)
		var m := mid(_bloom_c)
		var reach := U * (0.9 + 1.5 * out)
		_halo(b, m, DISC_R, reach, Color(LIGHT[_bloom_look], 0.7 * (1.0 - u)))
		for i in BIG_MOTES:
			var a := TAU * i / BIG_MOTES + _big_at * 3.0
			_mote(b, m + Vector2(cos(a), sin(a)) * U * (0.5 + 1.25 * out) + Vector2(0.0, -10.0 * u),
				13.0 * (1.0 - 0.5 * u), LIGHT[_bloom_look], 1.0 - u)
	since = _t - _corner_at
	if since >= 0.0 and since < CORNER_TIME and _corner_c >= 0:
		var u := since / CORNER_TIME
		var out := 1.0 - (1.0 - u) * (1.0 - u)
		var at := Vector2(_corner_c % Rules.W, _corner_c / Rules.W) * U
		var grow := 6.0 * out
		b.stroke(Face.Builder.round_rect(at + Vector2(4.0 - grow, 4.0 - grow), Vector2(U - 8.0 + 2.0 * grow, U - 8.0 + 2.0 * grow), 14.0),
			6.0, Color(BRASS, 0.95 * (1.0 - u * u)), true)
		# the pin of that corner of the frame takes the light
		var pin := Vector2(-19.0 if _corner_c % Rules.W == 0 else GRID.x + 19.0, -19.0 if _corner_c / Rules.W == 0 else GRID.y + 19.0)
		Scenery.soft_disc(b, pin, 30.0, 30.0, Color(BRASS_HI, 0.9 * (1.0 - u)))
	for rail: Dictionary in _rails:
		var cells: PackedInt32Array = rail.cells
		for i in cells.size():
			var e := _t - float(rail.at) - absf(i - int(rail.from)) * RAIL_TIME / float(Rules.W - 1)
			var level := Motion.flash_level(e)
			if level > 0.0:
				var out: Vector2 = rail.out
				var at := mid(cells[i]) + out * (U * 0.5 + FRAME * 0.5)
				Scenery.soft_disc(b, at, 20.0 if out.x != 0.0 else 60.0, 60.0 if out.x != 0.0 else 20.0, Color(HALO, 0.85 * level))
	if _mood != "" and not _end_wait.is_empty():
		var e := _t - _end_at
		var n := 0
		for c: int in _end_wait:
			var mine := e - float(_end_wait[c])
			n += 1
			if mine <= 0.0:
				continue
			var look := _cells[c] - 1
			var level := Motion.hop_lift(mine, 1.0, Motion.SOLVE_TIME)
			if level > 0.0:
				b.stroke(Face.Builder.ring(mid(c), DISC_R + 5.0, DISC_R + 5.0), 5.0, Color(LIGHT[look], 0.9 * level), true)
			# every third one lets a mote go
			if n % 3 == 0 and mine < MOTE_TIME + 0.15 and mine > 0.15:
				var u := (mine - 0.15) / MOTE_TIME
				_mote(b, mid(c) + Vector2(sin(c * 1.7) * 14.0, -DISC_R * 0.4 - 50.0 * u), 10.0 * (1.0 - 0.4 * u), LIGHT[look], 1.0 - u)

## Light round a disc and not on it: `colour` at `r0` fading to clear at
## `r1`, and inside `r0` as much of it as `fill` at the middle (a disc edge
## on shows the square under it). Laid over a whole face it would read as the disc paling.
func _halo(b: Face.Builder, at: Vector2, r0: float, r1: float, colour: Color, fill := 0.0) -> void:
	const N := 28
	var first := b.verts.size()
	var clear := Color(colour, 0.0)
	for i in N:
		var d := Vector2.from_angle(TAU * i / N)
		b.verts.append(at + d * r0)
		b.cols.append(colour)
		b.verts.append(at + d * r1)
		b.cols.append(clear)
	for i in N:
		var a := first + i * 2
		var c := first + ((i + 1) % N) * 2
		b.idx.append_array(PackedInt32Array([a, a + 1, c + 1, a, c + 1, c]))
	if fill > 0.0:
		var centre := b.verts.size()
		b.verts.append(at)
		b.cols.append(Color(colour, colour.a * fill))
		for i in N:
			b.verts.append(at + Vector2.from_angle(TAU * i / N) * r0)
			b.cols.append(Color(colour, colour.a * lerpf(fill, 1.0, 0.5)))
		for i in N:
			b.idx.append_array(PackedInt32Array([centre, centre + 1 + i, centre + 1 + (i + 1) % N]))

## A soft round mote of light: its colour, and a paler heart.
func _mote(b: Face.Builder, at: Vector2, r: float, col: Color, a: float) -> void:
	Scenery.soft_disc(b, at, r, r, Color(col, a))
	Scenery.soft_disc(b, at, r * 0.5, r * 0.5, Color(HALO, a))

## The tally under the board: the sun's discs from the left, the moon's from
## the right, a notch at the half -- who is ahead without counting -- and a
## small disc of each at its own end. The notch swells when the lead changes
## hands, the new leader's disc with it; a side passed over dips its own.
func _build_tally(b: Face.Builder) -> void:
	var w := GRID.x
	var cut := clampf(_share, 0.0, 1.0) * w
	var half := TALLY_Y + TALLY_H * 0.5
	b.fan(Face.Builder.round_rect(Vector2(-4.0, TALLY_Y - 4.0), Vector2(w + 8.0, TALLY_H + 8.0), (TALLY_H + 8.0) * 0.5), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(Vector2.ZERO + Vector2(0.0, TALLY_Y), Vector2(w, TALLY_H), TALLY_H * 0.5), DISC[1])
	if cut > TALLY_H:
		b.fan(Face.Builder.round_rect(Vector2(0.0, TALLY_Y), Vector2(cut, TALLY_H), TALLY_H * 0.5), DISC[0])
	var since := _t - _lead_at
	var lead := Motion.bump_scale(since, LEAD_BUMP, LEAD_TIME * 0.6)
	var level := Motion.flash_level(since, Motion.FLASH_IN, LEAD_TIME - Motion.FLASH_IN)
	var look := 0 if _lead >= 0 else 1
	if level > 0.0:
		Scenery.soft_disc(b, Vector2(w * 0.5, half), 70.0, 38.0, Color(LIGHT[look], 0.85 * level))
	b.stroke(PackedVector2Array([Vector2(w * 0.5, half - 20.0 * lead), Vector2(w * 0.5, half + 20.0 * lead)]), 4.0, STAMP[0])
	for side in 2:
		var k := 0.44
		var at := Vector2(4.0 if side == 0 else w - 4.0, half - 1.0)
		if side == look and level > 0.0:
			k *= 1.0 + 0.5 * (lead - 1.0)
			Scenery.soft_disc(b, at, 40.0, 40.0, Color(LIGHT[side], 0.8 * level))
		if side == _knock_look:
			var e := _t - _knock_at
			k *= 1.0 - 2.0 * KNOCK * (Motion.hop_lift(e, 1.0, KNOCK_HOP) + Motion.hop_lift(e - KNOCK_HOP, 1.0, KNOCK_HOP))
		b.append(_disc[side], Transform2D(0.0, Vector2(k, k), 0.0, at))
