extends "res://core/puzzle_base.gd"

## Sudoku, flat: nine by nine in nine regions, every number once in every row,
## column and region. The rules are in puzzles/sudoku_state.gd and this file
## draws them.
##
## **The whole of the design is in what a 100-pixel cell can be made to say**,
## because nobody needs the rules explained. Two things do the saying: the
## selection's washes (section 10 of the spec -- peers pale, twins stronger,
## clashes warm, the last Check warmer still, all derived every frame and
## none of them stored) and the wave when a unit comes right (section 11,
## this board's signature).
##
## **Drawn, not nodes.** Eighty-one cells, their washes, their rules, their
## digits and up to nine marks each is far too much to make Controls out of;
## gl_compatibility pays per draw command. The cells, the washes and the
## rules are one ArrayMesh, rebuilt while something moves the way Nonogram's
## floor and Queens' ground are, and every numeral goes over it through one
## draw_set_transform -- Nonogram's precedent for drawn text on the flat
## boards' vocabulary. The mesh the last _draw handed over is kept in
## `_shown` until the next replaces it: a canvas command holds a mesh by RID
## and not by reference, so dropping the previous one leaves the renderer
## drawing a freed RID on any frame rendered without the queued redraw
## flushed -- exactly what a harness's force_draw() does, and six boards have
## already paid for it.
##
## Every move -- a chip, a hint, an undo, Reset -- goes through one `_apply`
## or one `_settle`, so the wave is diffed in exactly one place: a snapshot
## of which units were finished before the move against which are finished
## after it. That is Queens' shape with a unit in place of a queen's sight.
## Spec: docs/superpowers/specs/2026-09-20-sudoku-flat-design.md.
## Concept page: docs/brainstorm/concepts.html#sudoku.

const State = preload("res://puzzles/sudoku_state.gd")
const Gen = preload("res://puzzles/sudoku_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The grid is nine cells of 100 -- 900 -- and not the 104.9 the card's 28
## inset would allow, because the heavy rule is drawn ROUND the grid and the
## 22 of hem either side is what it stands in. PAD is those two together, so
## the board asks the slot for 900 + 100 and gets exactly the 1000 the host
## hands it on the phone; on a narrower screen the cell shrinks under the
## nominal 100 rather than the rule running off the card.
const CELL := 100.0
## The grid's nominal side, whatever its size: nine cells of 100 on hard,
## six of 150 on the mini. Everything drawn is written against CELL, so the
## mini's numerals and rules come out half as big again with its cells.
const GRID := 900.0
const HEM := 22.0
const CARD_INSET := 28.0
const PAD := HEM + CARD_INSET
const THIN_W := 2.0
const THIN_ALPHA := 0.8
## The tray's corner radius, less half its FRAME.
const CORNER := 14.0
## The selected cell's gold edge: inset from the cell's own square so the
## rule beside it still reads, and rounded to match the frame.
const EDGE_W := 5.0
const EDGE_INSET := 2.0
const EDGE_RADIUS := 10.0
const DIGIT_SIZE := 64.0
const NOTE_SIZE := 26.0
## Where a pencil mark sits in its cell: a third either way from the centre.
const NOTE_STEP := 0.28
## The hint's ring, in cells: it starts just outside the digit.
const RING_R := 0.4

## The washes, by what they mean (spec section 10). All derived; none stored.
const WASH_SELECTED := 0.34
const WASH_PEER := 0.08
const WASH_CLASH := 0.18
const WASH_WRONG := 0.22
## The gold a cell reaches at the peak of the wave. A wash like the five
## above and not a timing: it is one of the wave's own three, with the two
## below.
const WASH_FLASH := 0.55

## This board's own three: WASH_FLASH above is the gold's peak alpha,
## WAVE_FLASH below is how long the wave holds a cell at that peak, and
## WIN_WAIT is the win wait. The wave's step, Motion.WAVE_STEP, moved to
## core/motion.gd on 2026-09-20 when Sudoku became the second board to read
## it, alongside Queens; everything else here is a recipe or a constant in
## core/motion.gd, read as a curve (rule 8 of docs/art/flat-motion.md).
const WAVE_FLASH := 0.5
const WIN_WAIT := 1.4

# --- the polish (2026-09-25; the spec's section 16) ---
## The grid is a wooden tray and each region a paper panel laid in it: the
## heavy rule is the tray's own floor showing in the GUTTER between panels,
## not a stroke drawn over the paper; 8 where the rule was 6, because a groove
## reads narrower than an ink line of the same width. The
## tray's face runs FRAME of a 100 cell round the grid over a WOOD_DEEP lip
## TRAY_LIP deep; its floor is the tray's wood FLOOR_DARKEN darker, so the
## gutters read as grooves; a panel stands PANEL_LIP proud of it.
const GUTTER := 8.0
const FRAME := 15.0
const TRAY_LIP := 4.0
const FLOOR_DARKEN := 0.22
const PANEL_R := 7.0
const PANEL_LIP := 2.0
const PANEL_TONE := 0.012
const TRAY_SHINE := 0.35
## A cell's wash is a rounded square WASH_INSET in from the cell, so a lit
## row reads as tiles catching the light rather than a spreadsheet fill.
const WASH_INSET := 3.0
const WASH_R := 9.0
## The selected cell is a paper tile lifted SEL_LIFT off its panel over a soft
## shadow, rimmed in the sun; its digit rises with it.
const SEL_LIFT := 6.0
const SEL_SHADOW_A := 0.22
## A twin is a sun coin under the digit, TWIN_R of a cell, and not a square:
## the eye is scanning for digits, so the mark sits on the digit.
const TWIN_R := 0.36
const WASH_TWIN_COIN := 0.3
## A written digit lands: its shadow gathers under it as it falls, it squashes
## SQUASH on touching down (LAND_AT into the drop, where back_out first
## reaches the rest) over SQUASH_TIME, and a ring of its own ink RIPPLE_A
## strong spreads from RIPPLE_FROM to RIPPLE_TO of a cell over RIPPLE_TIME.
const LAND_AT := 0.37 * Motion.DROP_TIME
const SQUASH := 0.14
const SQUASH_TIME := 0.16
const RIPPLE_TIME := 0.4
const RIPPLE_FROM := 0.24
const RIPPLE_TO := 0.47
const RIPPLE_A := 0.45
const FALL_SHADOW_A := 0.16
## The givens drop ENTER_DROP in with their region as they fade in.
const ENTER_DROP := 14.0
## The wave hops each digit it reaches, WAVE_HOP at a 100 cell.
const WAVE_HOP := -9.0
## On the win the tray warms toward SUN_RAY by WIN_GLOW and stays warm, and a
## glint GLINT_TIME long runs once round it, clockwise from the top left.
const WIN_GLOW := 0.4
const GLOW_TIME := 0.35
const GLINT_TIME := 1.1
const GLINT_LEN := 110.0
const GLINT_A := 1.0

## How long a refusal holds the tip card before the cycling rules resume.
const SAY_HOLD := 2.2
const TIP_CYCLE := 10.0
## Translation keys (locale/ui.csv). A "%d" in a line is the grid's size,
## filled in by _tip() after tr().
const TIPS := ["SD_TIP_UNITS", "SD_TIP_TAP", "SD_TIP_CROSS", "SD_TIP_PALE"]

## The remove chip's seat in the tray, ui/flat/digit_pad.gd's REMOVE.
## Declared here rather than preloaded off the pad on purpose: the tray asks
## and the board decides, and no board in the flat family preloads its own
## tray. It took the pencil's seat on 2026-09-23 at the user's request, so
## nothing on the screen turns `_pencil` on any more; the pencil's drawing
## and state.mark stay for whenever it gets a door again.
const REMOVE_CHIP := 9

var state: State = null

var fx: Node2D
## The cell the pad will write into, and whether it writes small.
var _sel := -1
var _pencil := false
## cell -> true: what the last Check found, cleared per cell when it is
## written again. The only thing on this board that is remembered rather
## than derived, because it is a memory of a question that was asked.
var _wrong: Dictionary = {}
## `state.clashes()` as of the last grid rebuild, so the numerals drawn every
## frame read the same set the washes were built from.
var _clash: Dictionary = {}

## Every drawn moment, each the second it begins -- which may be in the
## future, since a wave hands the far cells a later one. Read off Motion's
## curve readers in _build_grid and _draw_numerals.
var _flash: Dictionary = {}    # cell -> at: the wave reaches it then
var _bump: Dictionary = {}     # cell -> at: the cell beats then
var _drop: Dictionary = {}     # cell -> at: a digit falls in then
var _shiver: Dictionary = {}   # cell -> at: a refusal shook it then

## Reset's wave: one {"i", "d", "notes", "at"} per cell the player wrote,
## still drawn where it was until its beat arrives. The state forgets the
## whole board the instant Reset is pressed -- the pad's counts, the undo
## history and `is_solved` cannot wait on an animation -- so a cell that is
## due to empty half a second from now has nothing left to bump, and the
## spec's "bumps ... and empties" would be a wave over eighty-one blanks.
## The board keeps the copy instead and draws it swelling and fading out as
## the wave reaches it: hidden_word2d.gd's `_ghosts` is the family's
## precedent for a piece outliving the state that held it.
var _leaving: Array = []

## Sparkles still owed, each {"at", "where"}. The solve's three ride the
## diagonal wave and so cannot all be fired at the move that won it;
## hidden_word2d.gd's `_fx_due` is the same queue for the same reason.
var _fx_due: Array = []

## The geometry the input and the draw both read, so neither can drift.
var _cell := 0.0
var _grid := Vector2.ZERO

var _opened := -1.0e9
## When the board was solved, for the tray's glow and glint; far past on a
## board not solved.
var _won_at := -1.0e9
var _anim_until := 0.0
var _dirty := true
var _grid_mesh: ArrayMesh
## The mesh the last _draw handed the canvas item. Held so its RID stays
## alive until the next _draw has put another one on the command list.
var _shown: ArrayMesh

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer
## While a refusal or a Check owns the line, the cycle waits.
var _hold_until := 0.0

func puzzle_id() -> String: return "sudoku"
func title() -> String: return "Sudoku"

func rules() -> String:
	var n := Gen.N
	return tr("SD_RULES") % [Gen.BOX_R, Gen.BOX_C, n]

func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.z_index = 2
	add_child(fx)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)
	resized.connect(_layout)
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	state = State.new()
	state.setup(rng, difficulty)
	_sel = -1
	_pencil = false
	_wrong = {}
	_flash = {}
	_bump = {}
	_drop = {}
	_shiver = {}
	_leaving = []
	_fx_due = []
	_won_at = -1.0e9
	_layout()
	_tip_idx = 0
	_hold_until = 0.0
	_say(_tip(0), Face.Expr.HAPPY)
	_tip_timer.start()
	_enter()

# --- layout ---

## The grid is centred in whatever square the card gives it. The cell is the
## nominal 100 on the phone -- 900 of grid and 50 of hem either side is
## exactly the 1000 the host's arithmetic hands this slot -- and shrinks
## under it only on a screen that cannot hold that.
func _layout() -> void:
	if state == null:
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var field: float = _cell * Gen.N
	_grid = (size - Vector2.ONE * field) * 0.5
	_redraw()

func _cell_for(available: float) -> float:
	return minf(GRID / float(Gen.N), minf(size.x - 2.0 * PAD, available - 2.0 * PAD) / float(Gen.N))

## Everything the grid is drawn with is written against a 100 cell, so a
## smaller one scales the rules, the numerals and the marks with it.
func _scale() -> float:
	return _cell / CELL

## The board takes the whole slot: the grid is square and so is the space,
## so the slack is zero in both directions and there is nothing to centre.
## card_centred is answered anyway, because _fit_card asks.
func card_height(available: float) -> float:
	return available

func card_centred() -> bool:
	return false

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## Control-local point over the centre of cell (r, c). The win harness taps
## these, exactly as it does on every other flat board.
func cell_to_local(r: int, c: int) -> Vector2:
	return _grid + Vector2(c + 0.5, r + 0.5) * _cell

## The cell's top-left corner.
func _corner_of(i: int) -> Vector2:
	return _grid + Vector2(Gen.col_of(i), Gen.row_of(i)) * _cell

func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0:
		return -1
	var p := (local - _grid) / _cell
	var c := int(floor(p.x))
	var r := int(floor(p.y))
	if c < 0 or c >= Gen.N or r < 0 or r >= Gen.N:
		return -1
	return r * Gen.N + c

## The grid's centre in board pixels: what the entrance pops about.
func _centre() -> Vector2:
	return _grid + Vector2.ONE * (_cell * Gen.N * 0.5)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or not _current():
		return
	var now := _now()
	_deliver_fx(now)
	# The rebuild is decided **here** and never in _draw. Asking `_mesh_moving`
	# twice a frame -- once to queue the redraw and once to decide whether to
	# rebuild -- is the oneline2d.gd trap in miniature: _draw's clock is a
	# hair later than _process's, so on the frame a moment expires the two
	# could disagree and the mesh would be left one frame stale with nothing
	# queuing another redraw. One ask, one flag, and _draw simply obeys it.
	if _mesh_moving(now):
		_dirty = true
	if _moving(now):
		queue_redraw()

## True while anything is still moving. **It asks about every wave, not just
## the entrance:** oneline2d.gd froze two lines at four fifths of their fade
## by asking only about its first, and it showed on a rendered frame and in
## no test. Each book holds the second a moment begins, which a wave puts in
## the future, so a cell the wave has not reached yet keeps the board
## redrawing until it has been and gone.
func _moving(now: float) -> bool:
	if now < _anim_until:
		return true
	return _live(_flash, now, WAVE_FLASH) \
		or _live(_bump, now, Motion.BUMP_TIME) \
		or _live(_drop, now, LAND_AT + RIPPLE_TIME) \
		or _live(_shiver, now, Motion.SHIVER_TIME) \
		or _winning(now)

## True while anything the **mesh** draws is moving. Deliberately narrower
## than `_moving`: the entrance is one transform laid over the finished mesh
## and a fade that lives entirely in the numerals, so for its whole 0.84 s
## not one vertex of the grid changes, and rebuilding eighty-one cells sixty
## times over would buy exactly nothing. `_drop` is in since the polish,
## because a falling digit's shadow and its landing ring are the mesh's;
## `_anim_until` is out because every wave it is ever set for has its own
## book listed here.
func _mesh_moving(now: float) -> bool:
	return _live(_flash, now, WAVE_FLASH) \
		or _live(_bump, now, Motion.BUMP_TIME) \
		or _live(_drop, now, LAND_AT + RIPPLE_TIME) \
		or _live(_shiver, now, Motion.SHIVER_TIME) \
		or _winning(now)

## True while the win's glow is rising or its glint is going round the tray.
func _winning(now: float) -> bool:
	return not Motion.reduce and now < _won_at + Motion.SOLVE_DELAY + maxf(GLOW_TIME, GLINT_TIME)

static func _live(book: Dictionary, now: float, span: float) -> bool:
	for at in book.values():
		if now < float(at) + span:
			return true
	return false

## Keeps the board redrawing for `seconds` more: the entrance and the pieces
## of a moment no book holds.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Something the mesh draws has changed: rebuild it on the next draw.
func _redraw() -> void:
	_dirty = true
	queue_redraw()

# --- the drawing ---

## The grid pops in wide about its centre (rule 7: a wide thing comes from
## most of the way) as one transform over the mesh, and every numeral rides
## the same pop in its own transform, so the board arrives as one thing.
func _draw() -> void:
	if not _current() or _cell <= 0.0:
		return
	var now := _now()
	# `_dirty` is the whole test: a state change sets it through `_redraw`
	# and a live cell moment sets it in `_process`, which is the one place
	# the question is asked. See the note there.
	if _dirty:
		_clash = state.clashes()
		_grid_mesh = _build_grid(now)
		_dirty = false
	# The mesh is handed over and held in the same breath, so what the canvas
	# item has by RID is always what this board still has by reference; see
	# the header for what happens when it is not.
	_shown = _grid_mesh
	var pop := Motion.wide_pop_scale(now - _opened - Motion.ENTER_DELAY)
	var centre := _centre()
	if _shown != null:
		draw_mesh(_shown, null, Transform2D(0.0, Vector2.ONE * pop, 0.0, centre * (1.0 - pop)))
	_draw_numerals(now, pop, centre)

## Everything but the numerals: the wooden tray and its floor, the region
## panels laid in it, the thin rules inside each panel, the washes, the wave's
## gold, a falling digit's shadow and its landing ring, and last the selected
## cell's lifted tile. The heavy rule is no longer a stroke: it is the tray's
## floor showing between the panels (section 16).
func _build_grid(now: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var k := _scale()
	var field: float = _cell * Gen.N
	# The washes are derived here and nowhere else: the state keeps no
	# highlight, so nothing can leave a stale one behind after an undo.
	var peers: Dictionary = {}
	var twins: Dictionary = {}
	if _sel >= 0:
		for j in Gen.peers_of(_sel):
			peers[j] = true
		for j in state.twins(_sel):
			twins[j] = true
	var clash: Dictionary = _clash
	_tray(b, now, field, k)
	_panels(b, k)
	for i in Gen.CELLS:
		if i == _sel:
			continue
		var grow := _cell_grow(now, i)
		var shift := _cell_shift(now, i)
		var wash := _wash_of(i, peers, twins, clash)
		if wash.a > 0.0:
			b.fan(_wash_quad(i, shift, grow), wash)
		elif twins.has(i):
			var mid := cell_to_local(Gen.row_of(i), Gen.col_of(i)) + Vector2(shift, 0.0)
			b.disc(mid, _cell * TWIN_R * grow, Color(Pal.SUN, WASH_TWIN_COIN))
		var lit := _flash_level(now, i)
		if lit > 0.0:
			b.fan(_wash_quad(i, shift, grow), Color(Pal.SUN_RAY, WASH_FLASH * lit))
	_landings(b, now, k)
	if _sel >= 0:
		_selected_tile(b, now, k, _wash_of(_sel, peers, twins, clash))
	if b.verts.is_empty():
		return null
	return b.mesh()

## The tray: a WOOD_DEEP lip under a face in the rule's own wood, lit along
## its top edge, and inside it the floor the panels stand on, darker so the
## gutters between them read as grooves. On the win the wood warms toward the
## sun and a glint runs once round it.
func _tray(b: Face.Builder, now: float, field: float, k: float) -> void:
	var f := FRAME * k
	var outer := _grid - Vector2.ONE * f
	var side := Vector2.ONE * (field + 2.0 * f)
	var r := (CORNER + FRAME * 0.5) * k
	var glow := _glow(now)
	var face: Color = Pal.GRID_RULE.lerp(Pal.SUN_RAY, WIN_GLOW * glow)
	var lip: Color = Pal.WOOD_DEEP.lerp(Pal.SUN, WIN_GLOW * glow * 0.5)
	b.fan(Face.Builder.round_rect(outer + Vector2(0.0, TRAY_LIP * k), side, r), lip)
	b.fan(Face.Builder.round_rect(outer, side, r), face)
	var shine: Color = face.lerp(Pal.SURFACE, TRAY_SHINE)
	b.stroke(PackedVector2Array([outer + Vector2(r, 2.0 * k), outer + Vector2(side.x - r, 2.0 * k)]),
		2.5 * k, Color(shine, 0.8), false, true)
	_glint(b, now, field, k)
	var floor_col: Color = face.darkened(FLOOR_DARKEN)
	b.fan(Face.Builder.round_rect(_grid - Vector2.ONE * k, Vector2.ONE * (field + 2.0 * k),
		PANEL_R * k), floor_col)

## How warm the tray is: nothing before the win, rising over GLOW_TIME once
## the solve's wave has started, and full for good after. Under reduce motion
## it is simply full, which is a state and not a motion.
func _glow(now: float) -> float:
	var since := now - _won_at - Motion.SOLVE_DELAY
	if since < -1.0e8:
		return 0.0
	if Motion.reduce:
		return 1.0
	return clampf(since / GLOW_TIME, 0.0, 1.0)

## The win's glint: a soft light GLINT_LEN long riding the tray's midline once
## round, clockwise from the top left, easing in and out of its lap.
func _glint(b: Face.Builder, now: float, field: float, k: float) -> void:
	if Motion.reduce:
		return
	var since := now - _won_at - Motion.SOLVE_DELAY
	if since <= 0.0 or since >= GLINT_TIME:
		return
	var u := since / GLINT_TIME
	var a := GLINT_A * sin(PI * u)
	var half := FRAME * k * 0.5
	var lo := _grid - Vector2.ONE * half
	var edge := field + 2.0 * half
	# Where on the lap u = 0..1 is, eased so the light gathers and settles.
	var d := (0.5 - 0.5 * cos(PI * u)) * edge * 4.0
	var at: Vector2
	var along := true
	if d < edge:
		at = lo + Vector2(d, 0.0)
	elif d < edge * 2.0:
		at = lo + Vector2(edge, d - edge)
		along = false
	elif d < edge * 3.0:
		at = lo + Vector2(edge * 3.0 - d, edge)
	else:
		at = lo + Vector2(0.0, edge * 4.0 - d)
		along = false
	# A wide soft light and a hot core inside it: one soft disc alone peaks
	# only at its very centre, and on a frame this narrow that read as nothing.
	for layer in [[1.0, 0.7], [0.45, 1.0]]:
		var long: float = GLINT_LEN * k * 0.5 * layer[0]
		var short: float = FRAME * k * 0.75 * layer[0]
		Scenery.soft_disc(b, at, long if along else short, short if along else long,
			Color(Pal.SURFACE, a * float(layer[1])))

## The region panels: paper laid in the tray a half gutter in from the
## region's edges, each over a lip PANEL_LIP proud of the floor, the chequer
## kept and every panel toned a hair off its neighbour's so they read as
## laid by hand. The thin rules between the cells of a panel run inside it
## and stop short of its rounded corners, so none crosses a gutter.
func _panels(b: Face.Builder, k: float) -> void:
	var g := GUTTER * k * 0.5
	var r := PANEL_R * k
	var thin := Color(Pal.LINE, THIN_ALPHA)
	var size := Vector2(Gen.BOX_C, Gen.BOX_R) * _cell
	for br in Gen.N / Gen.BOX_R:
		for bc in Gen.N / Gen.BOX_C:
			var at := _grid + Vector2(bc, br) * size
			var shaded := (br + bc) % 2 == 1
			var paper: Color = Pal.GRID_TINT if shaded else Pal.SURFACE
			var tone := _hash(br, bc) * 2.0 - 1.0
			paper = paper.lightened(tone * PANEL_TONE) if tone > 0.0 else paper.darkened(-tone * PANEL_TONE)
			var lip: Color = paper.lerp(Pal.GRID_RULE, 0.45)
			var inner := size - Vector2.ONE * (2.0 * g)
			b.fan(Face.Builder.round_rect(at + Vector2(g, g + PANEL_LIP * k), inner, r), lip)
			b.fan(Face.Builder.round_rect(at + Vector2.ONE * g, inner, r), paper)
			for c in range(1, Gen.BOX_C):
				var x := at.x + c * _cell
				b.stroke(PackedVector2Array([Vector2(x, at.y + g + r * 0.5),
					Vector2(x, at.y + size.y - g - r * 0.5)]), THIN_W * k, thin, false, false)
			for rr in range(1, Gen.BOX_R):
				var y := at.y + rr * _cell
				b.stroke(PackedVector2Array([Vector2(at.x + g + r * 0.5, y),
					Vector2(at.x + size.x - g - r * 0.5, y)]), THIN_W * k, thin, false, false)

## `i`'s wash: a rounded square WASH_INSET in from its cell under the cell's
## own shiver and bump.
##
## **The cell moves, not only its numeral.** A refused tap once shook a digit
## inside a square that never budged, and a cell whose digit had just been
## taken out bumped with nothing on it to see. What moves is everything that
## is *this cell* rather than the board: its washes, the wave's gold, its
## twin coin and the selected tile -- tents2d.gd's rule 9, a piece with no
## skin of its own blushing through its cell, applied to motion. The panels
## and the rules between the cells do **not** move: they are the paper the
## grid is ruled on, and a rule that shivered with one cell would tear it.
func _wash_quad(i: int, shift: float, grow: float) -> PackedVector2Array:
	var k := _scale()
	var inset := WASH_INSET * k
	var side := (_cell - 2.0 * inset) * grow
	var mid := _corner_of(i) + Vector2(_cell * 0.5 + shift, _cell * 0.5)
	return Face.Builder.round_rect(mid - Vector2.ONE * (side * 0.5), Vector2.ONE * side, WASH_R * k * grow)

## A falling digit's shadow gathering under it, and its ring of ink spreading
## once it has touched down.
func _landings(b: Face.Builder, now: float, k: float) -> void:
	if Motion.reduce:
		return
	for i in _drop:
		var fell := now - float(_drop[i])
		if fell < 0.0 or fell >= LAND_AT + RIPPLE_TIME or state.grid[i] == 0:
			continue
		var mid := cell_to_local(Gen.row_of(i), Gen.col_of(i)) + Vector2(_cell_shift(now, i), 0.0)
		var height := Motion.DROP * k
		var lift := Motion.drop_in_lift(fell, height)
		if lift > 0.5:
			var far := clampf(lift / height, 0.0, 1.0)
			Scenery.soft_disc(b, mid + Vector2(0.0, _cell * 0.3), _cell * 0.26 * (1.0 - 0.35 * far),
				_cell * 0.07, Color(Pal.TEXT, FALL_SHADOW_A * (1.0 - 0.6 * far) * Motion.appear_level(fell)))
		var since := fell - LAND_AT
		if since > 0.0:
			var u := since / RIPPLE_TIME
			var ease := 1.0 - (1.0 - u) * (1.0 - u)
			var rad := _cell * lerpf(RIPPLE_FROM, RIPPLE_TO, ease)
			b.stroke(Face.Builder.ring(mid, rad, rad), 3.0 * k * (1.0 - u) + 0.5,
				Color(_digit_ink(i), RIPPLE_A * (1.0 - u)), true)

## The selected cell as a paper tile lifted off its panel: a soft shadow on
## the panel, a lip in the sun's deep, a face washed as the cell is (gold, or
## rose while it clashes), and the gold rim. It takes the cell's shiver and
## bump, so a refusal still shakes the clearest thing on the cell.
func _selected_tile(b: Face.Builder, now: float, k: float, wash: Color) -> void:
	var grow := _cell_grow(now, _sel)
	var inset := EDGE_INSET * k
	var side := (_cell - 2.0 * inset) * grow
	var mid := _corner_of(_sel) + Vector2.ONE * (_cell * 0.5) + Vector2(_cell_shift(now, _sel), 0.0)
	Scenery.soft_disc(b, mid + Vector2(0.0, _cell * 0.34), side * 0.56, _cell * 0.16,
		Color(Pal.TEXT, SEL_SHADOW_A))
	var top := mid - Vector2(side * 0.5, side * 0.5 + SEL_LIFT * k)
	var r := EDGE_RADIUS * k * grow
	b.fan(Face.Builder.round_rect(top + Vector2(0.0, SEL_LIFT * k), Vector2.ONE * side, r),
		Pal.SUN.darkened(0.12))
	b.fan(Face.Builder.round_rect(top, Vector2.ONE * side, r), Pal.SURFACE.lerp(Color(wash, 1.0), wash.a))
	var lit := _flash_level(now, _sel)
	if lit > 0.0:
		b.fan(Face.Builder.round_rect(top, Vector2.ONE * side, r), Color(Pal.SUN_RAY, WASH_FLASH * lit))
	var w := EDGE_W * k * grow
	b.stroke(Face.Builder.round_rect(top + Vector2.ONE * (w * 0.5), Vector2.ONE * (side - w),
		maxf(r - w * 0.5, 0.0)), w, Pal.SUN, true)

static func _hash(a: int, c: int) -> float:
	return float(posmod(hash(Vector2i(a, c)), 1000)) / 1000.0

## How far `i` is shoved sideways this frame: the refusal's and the Check's
## shiver, read off the family's curve at the cell's own scale.
func _cell_shift(now: float, i: int) -> float:
	return Motion.shiver_offset(now - float(_shiver.get(i, -1.0e9)), Motion.SHIVER_PX * _scale())

## How much bigger `i` is this frame: the bump a place, a take-out, an undo,
## a hint, Reset's wave and the solve's wave all stamp.
func _cell_grow(now: float, i: int) -> float:
	return Motion.bump_scale(now - float(_bump.get(i, -1.0e9)))

## What `i` is washed with: what the last Check found and any clash first,
## then the selection, then its twins -- the most useful scan in sudoku, and
## the reason the selection survives the tap -- then the twenty cells the
## selection cannot repeat into. A clash outranks the selection because the
## two copies of a clashing digit are always the selection and its twin the
## moment one is placed, so ranked under them it was washed gold -- the
## selection's own colour -- exactly when it happened, and read as right. The
## selected cell keeps its gold edge either way. A clash and a mistake are
## two different things: the first is visible with no answer in hand, the
## second needs the answer and costs a Check.
func _wash_of(i: int, peers: Dictionary, twins: Dictionary, clash: Dictionary) -> Color:
	if _wrong.has(i):
		return Color(Pal.BAD, WASH_WRONG)
	if clash.has(i):
		return Color(Pal.BAD, WASH_CLASH)
	if i == _sel:
		return Color(Pal.SUN, WASH_SELECTED)
	if twins.has(i):
		return Color(1.0, 1.0, 1.0, 0.0)
	if peers.has(i):
		return Color(Pal.SUN, WASH_PEER)
	return Color(1.0, 1.0, 1.0, 0.0)

## The wave's gold on `i` now, 0 to 1. The family's flash read over this
## board's own WAVE_FLASH rather than the family's FLASH_IN + FLASH_OUT, in
## the same proportion, so the curve is the one hand and only its length is
## this board's.
func _flash_level(now: float, i: int) -> float:
	if not _flash.has(i):
		return 0.0
	var rise := WAVE_FLASH * Motion.FLASH_IN / (Motion.FLASH_IN + Motion.FLASH_OUT)
	return Motion.flash_level(now - float(_flash[i]), rise, WAVE_FLASH - rise)

## The digits and the pencil marks, over the mesh, each through one
## draw_set_transform so it takes the entrance's pop, the cell's bump, the
## refusal's shiver and the hint's drop together -- Nonogram's precedent for
## drawn text on the vocabulary.
func _draw_numerals(now: float, pop: float, centre: Vector2) -> void:
	var k := _scale()
	var digit_font: Font = CozyTheme.display(600)
	var note_font: Font = CozyTheme.body(600)
	var digit_px := int(roundf(DIGIT_SIZE * k))
	var note_px := int(roundf(NOTE_SIZE * k))
	if digit_px <= 0 or note_px <= 0:
		return
	var digit_rise := digit_font.get_ascent(digit_px) * 0.5
	var note_rise := note_font.get_ascent(note_px) * 0.5
	for i in Gen.CELLS:
		var seen := _appear_of(now, i)
		if seen <= 0.0:
			continue
		var at := cell_to_local(Gen.row_of(i), Gen.col_of(i))
		at.x += _cell_shift(now, i)
		at.y += _numeral_rise(now, i, k)
		var grow := _cell_grow(now, i)
		var d: int = state.grid[i]
		if d > 0:
			var fell := now - float(_drop.get(i, -1.0e9))
			at.y -= Motion.drop_in_lift(fell, Motion.DROP * k)
			var alpha := seen * (Motion.appear_level(fell) if _drop.has(i) else 1.0)
			_seat(at, centre, pop, grow, _squash(fell))
			_numeral(digit_font, digit_px, digit_rise, str(d), Vector2.ZERO,
				Color(_digit_ink(i), alpha))
		elif state.notes[i] != 0:
			_seat(at, centre, pop, grow)
			for n in range(1, Gen.N + 1):
				if not state.has_note(i, n):
					continue
				# Each mark sits in its own third of the cell, which is what
				# a round 100 buys: 33 is the smallest square a 26 px numeral
				# reads in.
				var spot := _note_spot(n)
				_numeral(note_font, note_px, note_rise, str(n), spot,
					Color(Pal.TEXT_DIM, seen))
	_draw_leaving(now, pop, centre, digit_font, digit_px, digit_rise,
		note_font, note_px, note_rise)
	draw_set_transform(Vector2.ZERO)

## Reset's wave, drawn over the emptied cells: what the player had written
## stands where it was until its beat arrives, then swells with the family's
## bump and fades out over the same BUMP_TIME, so the wave from the far
## corner is a thing coming apart and not a wave over eighty-one blanks.
## The alpha is `appear_level` read backwards -- a recipe, not a number of
## this board's -- and the scale is the bump every other moment here uses.
func _draw_leaving(now: float, pop: float, centre: Vector2, digit_font: Font,
		digit_px: int, digit_rise: float, note_font: Font, note_px: int,
		note_rise: float) -> void:
	if _leaving.is_empty():
		return
	var keep: Array = []
	for g in _leaving:
		var since: float = now - float(g.at)
		if since >= Motion.BUMP_TIME:
			continue
		keep.append(g)
		var i: int = g.i
		# The player can write into the cell again before the wave gets
		# there; what is really on the board wins, and the ghost gives way.
		if state.grid[i] != 0 or state.notes[i] != 0:
			continue
		var at := cell_to_local(Gen.row_of(i), Gen.col_of(i))
		var alpha := 1.0 - Motion.appear_level(since, Motion.BUMP_TIME)
		_seat(at, centre, pop, Motion.bump_scale(since))
		var d: int = g.d
		if d > 0:
			_numeral(digit_font, digit_px, digit_rise, str(d), Vector2.ZERO,
				Color(Pal.LEAF_DEEP, alpha))
			continue
		for n in range(1, Gen.N + 1):
			if int(g.notes) & (1 << (n - 1)) == 0:
				continue
			var spot := _note_spot(n)
			_numeral(note_font, note_px, note_rise, str(n), spot,
				Color(Pal.TEXT_DIM, alpha))
	_leaving = keep

## Where pencil mark `n` sits from its cell's centre: three to a line, in
## three lines on a nine and two on the mini, centred either way.
func _note_spot(n: int) -> Vector2:
	var lines := float((Gen.N + 2) / 3)
	return Vector2(float((n - 1) % 3) - 1.0, float((n - 1) / 3) - (lines - 1.0) * 0.5) \
		* (_cell * NOTE_STEP)

## Puts the canvas at `at` under the entrance's pop about `centre`, scaled by
## the cell's own bump: one transform, so a numeral never drifts off the cell
## the mesh drew under it.
func _seat(at: Vector2, centre: Vector2, pop: float, grow: float, squash := Vector2.ONE) -> void:
	draw_set_transform(centre + (at - centre) * pop, 0.0, squash * (pop * grow))

## How far `i`'s numeral stands off its cell, negative up: raised with the
## selected tile, hopped by the wave as it passes, and a given dropping in
## with its region on the entrance.
func _numeral_rise(now: float, i: int, k: float) -> float:
	var y := 0.0
	if i == _sel:
		y -= SEL_LIFT * k
	if _flash.has(i):
		y += Motion.hop_lift(now - float(_flash[i]), WAVE_HOP * k)
	if state.is_given(i):
		y -= Motion.drop_in_lift(now - _opened - _enter_delay(i), ENTER_DROP * k)
	return y

## A written digit's squash as it touches down, `fell` into its drop: wide
## and low for SQUASH_TIME, then round again.
func _squash(fell: float) -> Vector2:
	var since := fell - LAND_AT
	if Motion.reduce or since <= 0.0 or since >= SQUASH_TIME:
		return Vector2.ONE
	var s := SQUASH * sin(PI * since / SQUASH_TIME)
	return Vector2(1.0 + s, 1.0 - s)

## How much of `i`'s numeral is on screen. A given fades in with its region,
## ENTER_STAGGER apart, so the board assembles as three by three and not as
## eighty-one; anything the player put there is simply here.
func _appear_of(now: float, i: int) -> float:
	if not state.is_given(i):
		return 1.0
	return Motion.appear_level(now - _opened - _enter_delay(i), Motion.DROP_TIME)

## One step per region, nine of them: 0.24 s end to end, well inside
## `Motion.stagger`'s 0.6 cap. Stepping by band within a region instead would
## be twenty-seven indices, and 26 * ENTER_STAGGER overruns that cap -- the
## last seven bands would all land on one frame, which is neither region by
## region nor cell by cell.
func _enter_delay(i: int) -> float:
	return Motion.ENTER_DELAY + Motion.ENTER_FACE_LAG \
		+ Motion.stagger(Gen.box_of(i), Motion.ENTER_STAGGER)

## A given is ink and never changes; what the player put there is leaf, which
## is this game's own word for something that grew, and turns to the family's
## rose while it clashes or the last Check still points at it. A clash is
## wrong on its face, so a green digit in one read as a right answer.
func _digit_ink(i: int) -> Color:
	if state.is_given(i):
		return Pal.TEXT
	return Pal.BAD if _wrong.has(i) or _clash.has(i) else Pal.LEAF_DEEP

## One numeral centred on `centre`, in the transform already set.
func _numeral(font: Font, px: int, rise: float, text: String, centre: Vector2, ink: Color) -> void:
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	draw_string(font, centre + Vector2(-wide * 0.5, rise), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, ink)

# --- input ---

## A tap on the grid **only ever selects**, and tapping the selected cell
## again clears the selection. That is what makes a 100 cell bearable under a
## thumb: nothing is typed here, and the thing tapped next is a 91 by 130
## chip in the pad.
func _gui_input(event: InputEvent) -> void:
	if not _current() or is_done():
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not ((event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed):
		return
	var i := _cell_at(event.position)
	if i < 0:
		return
	_sel = -1 if i == _sel else i
	# The pad reads the counts and the pencil back off this board on every
	# refresh, and the host refreshes on this signal.
	focus_changed.emit()
	_redraw()
	accept_event()

# --- what the tray asks ---

func pencil_on() -> bool:
	return _pencil

func remaining(d: int) -> int:
	return state.remaining(d) if state != null else Gen.N

## How many digit chips the pad shows: six on the mini, nine on hard.
func digit_count() -> int:
	return Gen.N

## A chip was tapped: 0..8 are the digits 1..9 and REMOVE_CHIP empties the
## selected cell.
func pick(i: int) -> bool:
	if state == null or is_done():
		return false
	if _sel < 0:
		_speak(tr("SD_TAP_CELL"), Face.Expr.PUZZLED)
		return false
	if i == REMOVE_CHIP:
		return _erase(_sel)
	return _apply(_sel, i + 1)

## The remove chip: the selected cell's digit or marks come out, as one move
## undo can put back. Taking a digit out can only open a unit, never finish
## one, so there is no wave to settle -- but a unit it opens may still have
## its wave running, and that gold goes out with it, as in undo().
func _erase(i: int) -> bool:
	var before: Array = state.finished_units()
	match state.erase(i):
		State.GIVEN:
			_refuse(i, tr("SD_GIVEN"))
			return false
		State.EMPTY:
			_refuse(i, tr("SD_EMPTY"))
			return false
	var now := _now()
	_wrong.erase(i)
	_bump[i] = now
	_busy_for(Motion.BUMP_TIME)
	var units: Array = Gen.units()
	for u in units.size():
		if bool(before[u]) and not state.unit_done(units[u]):
			for c in units[u]:
				_flash.erase(c)
	fx.cue("undo")
	_redraw()
	note_move()
	return true

# --- the one door every move goes through ---

## Every move that can change the grid comes through here, so the wave is
## diffed in exactly one place: what was finished before the move against
## what is finished after it. Nothing else may call state.place or state.mark.
func _apply(i: int, d: int) -> bool:
	var before: Array = state.finished_units()
	var code: int = state.mark(i, d) if _pencil else state.place(i, d)
	match code:
		State.GIVEN:
			_refuse(i, tr("SD_GIVEN"))
			return false
		State.FILLED:
			_refuse(i, tr("SD_PENCIL"))
			return false
	var now := _now()
	_wrong.erase(i)
	_bump[i] = now
	# A digit falls in; a pencil mark does not, because nine of them dropping
	# is a rainstorm.
	if state.grid[i] != 0 and not _pencil:
		_drop[i] = now
		_busy_for(Motion.DROP_TIME)
	_busy_for(Motion.BUMP_TIME)
	_settle(before, i, now)
	fx.cue("pencil" if _pencil else "place")
	# A row, column or region the move finished rings as its wave goes out
	# (and under reduce motion, where the wave is not drawn, all the same).
	var after: Array = state.finished_units()
	for u in after.size():
		if bool(after[u]) and not bool(before[u]):
			fx.cue("line")
			break
	_redraw()
	note_move()
	return true

## Diff the units and hand each cell of one that has just come right its
## moment: it lights up in gold from `at` outwards, a king-move step apart.
## Queens' `_settle`, with a unit in place of a queen's sight.
##
## A digit that closes a row *and* a region runs both at once from the same
## seat, and it comes out right for free: `step` is read off `i` and `at`
## alone and never off the unit, so the second unit hands a shared cell the
## identical `when` and neither can disturb the other. The `<` test is not
## for that -- it is there because `_flash` is never pruned, so a cell may
## still be carrying a spent moment from an earlier move, and the new one has
## to win.
func _settle(before: Array, at: int, now: float) -> void:
	if Motion.reduce:
		return
	var units: Array = Gen.units()
	for u in units.size():
		if bool(before[u]) or not state.unit_done(units[u]):
			continue
		for i in units[u]:
			var step := 0
			if at >= 0:
				step = maxi(absi(Gen.row_of(i) - Gen.row_of(at)),
					absi(Gen.col_of(i) - Gen.col_of(at)))
			var when := now + step * Motion.WAVE_STEP
			if not _flash.has(i) or float(_flash[i]) < when:
				_flash[i] = when
			_busy_for(when - now + WAVE_FLASH)

## A refused tap: the cell shivers and the tip card says why. A refusal is
## never a silence, and it is never a toast either -- this board already has
## a card whose whole job is one line.
func _refuse(i: int, line: String) -> void:
	_shiver[i] = _now()
	_busy_for(Motion.SHIVER_TIME)
	_speak(line, Face.Expr.WORRIED)
	fx.cue("locked")
	_redraw()

# --- the HUD's actions ---

func is_solved() -> bool:
	return state != null and state.is_solved()

func can_undo() -> bool:
	return state != null and not is_done() and not state.history.is_empty()

## Takes the last move back, wherever it was. A hint's digit comes back out
## with it; **the hint it cost does not come back**, which is the same bargain
## Reset makes below.
func undo() -> bool:
	if state == null or is_done():
		return false
	var before: Array = state.finished_units()
	var i := state.undo()
	if i < 0:
		return false
	var now := _now()
	_sel = i
	_wrong.erase(i)
	_bump[i] = now
	_busy_for(Motion.BUMP_TIME)
	# An undo can take a finished unit apart, and most of that unit's wave is
	# still in the future when it does -- eight of a row's nine cells are, at
	# Motion.WAVE_STEP a step. `_settle` will not re-light it (`before` says it was
	# already finished), but nothing else would put it out either, and the
	# gold would go on sweeping a row that is no longer right. Section 7's
	# rule is that there is no highlight to leave behind; this is the one
	# place on the board that could leave one.
	#
	# The prune below is cell-granular, not unit-scoped: `_flash` is keyed by
	# cell alone with no record of which unit scheduled it, so erasing every
	# cell of a newly-reopened unit can also erase a wave a *different*,
	# still-complete unit legitimately scheduled for a cell the two units
	# share (a box cell that sits in the row this undo just broke). That is
	# accepted and cosmetic, not a bug to chase: it needs two units to finish
	# within about a wave's width of each other (eight steps of
	# Motion.WAVE_STEP, ~0.36 s) and then an undo inside that window, and the
	# cost is a legitimate flash cut a little short -- never a stale one left
	# behind, which is the failure this prune exists to prevent. Making the
	# prune unit-aware would mean tagging every `_flash` entry with the units
	# that scheduled it and only clearing a tag on their own reopening, which
	# is a real restructure for a case this narrow; over-eager is the right
	# trade until something else forces `_flash` to carry more than a time.
	var units: Array = Gen.units()
	for u in units.size():
		if not bool(before[u]) or state.unit_done(units[u]):
			continue
		for c in units[u]:
			_flash.erase(c)
	_settle(before, i, now)
	fx.cue("undo")
	_redraw()
	moved.emit()
	return true

func hints_left() -> int:
	return state.hints_left if state != null else 0

## One cell from the answer, wherever the player was closest: a ring in leaf,
## the digit dropping in under sparkles, and the wave if it finished
## anything. Counts no move, but it can finish the puzzle.
func hint() -> bool:
	if state == null or is_done():
		return false
	var before: Array = state.finished_units()
	var i := state.hint()
	if i < 0:
		return false
	var now := _now()
	hints_used += 1
	_sel = i
	_wrong.erase(i)
	_bump[i] = now
	_drop[i] = now
	_busy_for(maxf(Motion.BUMP_TIME, Motion.DROP_TIME))
	var at := cell_to_local(Gen.row_of(i), Gen.col_of(i))
	fx.ring(at, _cell * RING_R, Pal.LEAF)
	fx.sparkle(at, Pal.LEAF)
	fx.cue("hint")
	_settle(before, i, now)
	_say(tr("SD_HINT"), Face.Expr.HAPPY)
	_redraw()
	moved.emit()
	check_solved()
	return true

## Every cell that disagrees with the answer shivers, in a shallow wave out
## from the middle row, and keeps the rose wash until it is written again.
## Givens are never wrong and a pencil mark is a note rather than a claim, so
## neither is looked at.
func check() -> int:
	if state == null or is_done():
		return 0
	checks += 1
	var now := _now()
	_wrong = {}
	var w: PackedInt32Array = state.wrong()
	for i in w:
		_wrong[i] = true
		if not Motion.reduce:
			var when := now + absi(Gen.row_of(i) - (Gen.N - 1) / 2) * Motion.RESET_STAGGER
			_shiver[i] = when
			_busy_for(when - now + Motion.SHIVER_TIME)
	_speak(_check_line(w.size()), Face.Expr.STRAIN if w.size() > 0 else Face.Expr.JOY)
	fx.cue("check" if w.size() > 0 else "check_ok")
	_redraw()
	return w.size()

func _check_line(wrong: int) -> String:
	if wrong == 0:
		return tr("SD_CHECK_OK")
	if wrong == 1:
		return tr("SD_CHECK_ONE")
	return tr("SD_CHECK_N") % wrong

## Back to the givens, in a wave from the far corner. The hints spent are not
## refunded: a hint's effect on the grid is undoable and its cost is not,
## which is what the badge in the top bar is counting.
func reset_board() -> void:
	if state == null:
		return
	var now := _now()
	var far := Gen.CELLS - 1
	if not Motion.reduce:
		for i in Gen.CELLS:
			if state.given[i] != 0 or (state.grid[i] == 0 and state.notes[i] == 0):
				continue
			var step := maxi(absi(Gen.row_of(i) - Gen.row_of(far)),
				absi(Gen.col_of(i) - Gen.col_of(far)))
			var when := now + Motion.stagger(step, Motion.RESET_STAGGER)
			_bump[i] = when
			# **A cell can only be leaving once.** `_draw_leaving`'s "has the
			# player written here again?" guard reads the *current* state,
			# and after a second `clear_board` the current state is empty
			# again -- so it cannot tell a ghost this Reset has just made
			# from one an earlier Reset made, and both would draw over each
			# other, each fading on its own schedule. Two plain Resets do not
			# reach here twice for one cell (the second skips a cell that is
			# already empty); write a digit, Reset, write another into that
			# same cell and Reset again, and you do. Nothing in the state can
			# separate the two generations, so the cell index has to: the old
			# entry goes before the new one is appended.
			_leaving = _leaving.filter(func(g: Dictionary) -> bool: return int(g.i) != i)
			# The copy the wave will carry out; see `_leaving` and
			# `_draw_leaving`. Taken before clear_board empties the state.
			_leaving.append({"i": i, "d": int(state.grid[i]),
				"notes": int(state.notes[i]), "at": when})
			_busy_for(when - now + Motion.BUMP_TIME)
	state.clear_board()
	_sel = -1
	_wrong = {}
	_flash = {}
	_drop = {}
	_shiver = {}
	moves = 0
	_say(tr("SD_RESET"),
		Face.Expr.HAPPY)
	fx.cue("reset")
	_redraw()

# --- the win ---

## The whole grid waves along the diagonal with the family's stagger, and
## every seventh cell sparkles in gold; the win screen follows WIN_WAIT later.
func _on_solved() -> void:
	var now := _now()
	_tip_timer.stop()
	_won_at = now
	_sel = -1
	_wrong = {}
	_say(tr("SD_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	if not Motion.reduce:
		for i in Gen.CELLS:
			var when := now + _solve_delay(Gen.row_of(i) + Gen.col_of(i))
			_flash[i] = when
			_bump[i] = when
			_busy_for(when - now + maxf(WAVE_FLASH, Motion.BUMP_TIME))
		# Three sparkles marching down the main diagonal with the wave, at a
		# quarter, the middle and three quarters of it. Three and not eighty-
		# one because Fx2D's sparkle pool is three: a fourth would recycle
		# the first emitter and cut its burst in half. Spaced four diagonals
		# apart they are used once each and never reclaimed mid-flight.
		var span := 2 * (Gen.N - 1)
		for d in [span / 4, span / 2, span * 3 / 4]:
			var k: int = d / 2
			_fx_due.append({"at": now + _solve_delay(d),
				"where": cell_to_local(k, k)})
	_redraw()

## A completed daily is rebuilt from its seed, so it opens on the givens.
## Write the answer into every cell and settle the board as it stands once
## the solve's wave has passed: no selection, no pencil marks, no Check
## marks, no entrance and no moment still owed. Not check_solved(): the host
## owns the win screen and `solved` must not fire a second time.
func restore_completed_board() -> void:
	if state == null:
		return
	var now := _now()
	_tip_timer.stop()
	state.grid = state.sol.duplicate()
	state.notes = PackedInt32Array()
	state.notes.resize(Gen.CELLS)
	state.history = []
	_sel = -1
	_pencil = false
	_wrong = {}
	_flash = {}
	_bump = {}
	_drop = {}
	_shiver = {}
	_leaving = []
	_fx_due = []
	_hold_until = 0.0
	# The entrance long over, so the grid is at full size and every given
	# fully inked.
	_opened = now - 10.0
	_won_at = now - 10.0
	_anim_until = 0.0
	_say(tr("SD_WIN"), Face.Expr.JOY)
	_redraw()

## When the solve's wave reaches anti-diagonal `d` (row + col, 0 to 16).
##
## **The last two diagonals share a beat and that is left alone.**
## `Motion.stagger` caps at 0.6 s, and 16 x SOLVE_STAGGER is 0.64, so
## r+c = 15 and r+c = 16 both land at 0.6. That is three cells of eighty-one
## -- (7,8), (8,7) and (8,8) -- at the very tail of a wave that has already
## been running for most of a second, and nobody will catch it. The cap is
## the family's promise that no cell waits longer than 0.6 s to be answered,
## and `stagger` does take a `cap` parameter, so raising it here would be
## legal; it would also make Sudoku's solve the slowest wave in the game for
## a difference of four hundredths on three cells. The family's number wins.
func _solve_delay(diagonal: int) -> float:
	return Motion.SOLVE_DELAY + Motion.stagger(diagonal, Motion.SOLVE_STAGGER)

## Fires the sparkles that have come due, in the order they were queued.
func _deliver_fx(now: float) -> void:
	while not _fx_due.is_empty() and now >= float(_fx_due[0].at):
		var due: Dictionary = _fx_due.pop_front()
		fx.sparkle(due.where, Pal.SUN)

# --- the sprout's line ---

## The chrome is the host's; here the grid pops in wide after the family's
## delay and the givens fade in region by region behind it.
func _enter() -> void:
	_opened = _now()
	_busy_for(_enter_delay(Gen.CELLS - 1) + Motion.DROP_TIME)
	fx.cue("enter")

## What the tip card showed. The card (ui/flat/tip_card.gd) was removed on
## 2026-09-24 as nothing had loaded it since the first-play tutorial replaced
## it; the line stays for whatever speaks the board's tips next.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal. A refused tap is not a move, so this is
	# the only thing that can push a refusal's line out.
	focus_changed.emit()

## A line that owns the card for SAY_HOLD seconds, after which the cycling
## rules resume. Every refusal and every Check goes through it.
func _speak(line: String, mood: int) -> void:
	_say(line, mood)
	_hold_until = _now() + SAY_HOLD
	if get_tree() == null:
		return
	get_tree().create_timer(SAY_HOLD).timeout.connect(_resume_tips)

func _resume_tips() -> void:
	if is_done() or _now() < _hold_until - 0.01:
		return
	_say(_tip(_tip_idx), Face.Expr.HAPPY)

func _tip(k: int) -> String:
	var line: String = tr(TIPS[k])
	return line % Gen.N if line.contains("%d") else line

func _cycle_tip() -> void:
	if is_done() or _now() < _hold_until:
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(_tip(_tip_idx), Face.Expr.HAPPY)

# --- odds and ends ---

## Whether Gen's geometry is still this board's. Gen holds one size at a
## time, and a board being replaced by one of another band (the mini by
## hard) lives a frame after the new one has switched Gen over; it must not
## read the new geometry against its own arrays in that frame.
func _current() -> bool:
	return state != null and state.grid.size() == Gen.CELLS

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
