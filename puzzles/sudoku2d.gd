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

## The grid is nine cells of 100 -- 900 -- and not the 104.9 the card's 28
## inset would allow, because the heavy rule is drawn ROUND the grid and the
## 22 of hem either side is what it stands in. PAD is those two together, so
## the board asks the slot for 900 + 100 and gets exactly the 1000 the host
## hands it on the phone; on a narrower screen the cell shrinks under the
## nominal 100 rather than the rule running off the card.
const CELL := 100.0
const HEM := 22.0
const CARD_INSET := 28.0
const PAD := HEM + CARD_INSET
const RULE_W := 6.0
const THIN_W := 2.0
const THIN_ALPHA := 0.8
## The heavy rule's corner radius where it runs round the grid.
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
const WASH_TWIN := 0.20
const WASH_PEER := 0.08
const WASH_CLASH := 0.10
const WASH_WRONG := 0.22
## The gold a cell reaches at the peak of the wave. A wash like the five
## above and not a timing: the wave's own three are below.
const WASH_FLASH := 0.55

## This board's own three. Everything else is a recipe or a constant in
## core/motion.gd, read as a curve (rule 8 of docs/art/flat-motion.md).
const WAVE_STEP := 0.045
const WAVE_FLASH := 0.5
const WIN_WAIT := 1.4

## How long a refusal holds the tip card before the cycling rules resume.
const SAY_HOLD := 2.2
const TIP_CYCLE := 10.0
const TIPS := [
	"Every row, every column and every region holds 1 to 9 once.",
	"Tap a cell, then a number. Tap that number again to take it out.",
	"The pencil writes small: use it for the numbers a cell might be.",
	"A number already placed nine times goes pale in the pad.",
]

## The pencil's seat in the tray, ui/flat/digit_pad.gd's PENCIL. Declared
## here rather than preloaded off the pad on purpose: the tray asks and the
## board decides, and no board in the flat family preloads its own tray.
const PENCIL_CHIP := 9

var state: State = null

var fx: Node2D
## The cell the pad will write into, and whether it writes small.
var _sel := -1
var _pencil := false
## cell -> true: what the last Check found, cleared per cell when it is
## written again. The only thing on this board that is remembered rather
## than derived, because it is a memory of a question that was asked.
var _wrong: Dictionary = {}

## Every drawn moment, each the second it begins -- which may be in the
## future, since a wave hands the far cells a later one. Read off Motion's
## curve readers in _build_grid and _draw_numerals.
var _flash: Dictionary = {}    # cell -> at: the wave reaches it then
var _bump: Dictionary = {}     # cell -> at: its numeral beats then
var _drop: Dictionary = {}     # cell -> at: a digit falls in then
var _shiver: Dictionary = {}   # cell -> at: a refusal shook it then

## The geometry the input and the draw both read, so neither can drift.
var _cell := 0.0
var _grid := Vector2.ZERO

var _opened := -1.0e9
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
	return "Fill the grid so every row, every column and every three-by-three region holds the numbers 1 to 9, each exactly once.\n\nTap a cell, then tap a number. Tapping the number a cell already holds takes it out again.\n\nThe pencil writes small: use it for the numbers a cell might be. Placing a number rubs it out of every cell that can see it.\n\nCheck marks anything that disagrees with the answer, and costs nothing but a count."

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
	_layout()
	_tip_idx = 0
	_hold_until = 0.0
	_say(TIPS[0], Face.Expr.HAPPY)
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
	return minf(CELL, minf(size.x - 2.0 * PAD, available - 2.0 * PAD) / float(Gen.N))

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
	if _cell <= 0.0 or state == null:
		return
	if _moving(_now()):
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
		or _live(_drop, now, Motion.DROP_TIME) \
		or _live(_shiver, now, Motion.SHIVER_TIME)

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
	if state == null or _cell <= 0.0:
		return
	var now := _now()
	if _dirty or _moving(now):
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

## Everything but the numerals, in the order section 10's table is written:
## the region chequer, the selection's washes over it, the wave's gold over
## those, then the thin rules between cells, the heavy rules between regions
## and round the grid, and last the selected cell's own gold edge.
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
	var clash: Dictionary = state.clashes()
	for i in Gen.CELLS:
		var at := _corner_of(i)
		var region_shaded := ((Gen.row_of(i) / 3) + (Gen.col_of(i) / 3)) % 2 == 1
		b.fan(_square(at, _cell), Pal.GRID_TINT if region_shaded else Pal.SURFACE)
		var wash := _wash_of(i, peers, twins, clash)
		if wash.a > 0.0:
			b.fan(_square(at, _cell), wash)
		var lit := _flash_level(now, i)
		if lit > 0.0:
			b.fan(_square(at, _cell), Color(Pal.SUN_RAY, WASH_FLASH * lit))
	# The thin rule between two cells of one region, and the heavy one
	# between two regions. Flat-ended: a round cap would bulge past the
	# frame the heavy rule draws round the whole grid.
	var thin := Color(Pal.LINE, THIN_ALPHA)
	for step in range(1, Gen.N):
		var wide := step % 3 == 0
		var ink: Color = Pal.GRID_RULE if wide else thin
		var width: float = (RULE_W if wide else THIN_W) * k
		var d: float = step * _cell
		b.stroke(PackedVector2Array([_grid + Vector2(d, 0.0), _grid + Vector2(d, field)]),
			width, ink, false, false)
		b.stroke(PackedVector2Array([_grid + Vector2(0.0, d), _grid + Vector2(field, d)]),
			width, ink, false, false)
	# The frame: the heavy rule run round the grid, its centreline pushed out
	# by half its width so its inner edge lands on the grid's own edge. This
	# is the mock's wooden frame, which a flat board draws rather than builds.
	var half := RULE_W * k * 0.5
	b.stroke(Face.Builder.round_rect(_grid - Vector2.ONE * half,
		Vector2.ONE * (field + RULE_W * k), CORNER * k), RULE_W * k, Pal.GRID_RULE, true)
	if _sel >= 0:
		var inset := EDGE_INSET * k
		b.stroke(Face.Builder.round_rect(_corner_of(_sel) + Vector2.ONE * inset,
			Vector2.ONE * (_cell - 2.0 * inset), EDGE_RADIUS * k), EDGE_W * k, Pal.SUN, true)
	if b.verts.is_empty():
		return null
	return b.mesh()

## A cell's square from its top-left corner.
static func _square(at: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(s, 0.0), at + Vector2.ONE * s, at + Vector2(0.0, s)])

## What `i` is washed with, in the order section 10's table decides it: the
## selection first, then its twins -- the most useful scan in sudoku, and the
## reason the selection survives the tap -- then what the last Check found,
## then a clash, then the twenty cells the selection cannot repeat into.
## A clash and a mistake are two different things: the first is visible with
## no answer in hand and is drawn faintly, the second needs the answer and
## costs a Check.
func _wash_of(i: int, peers: Dictionary, twins: Dictionary, clash: Dictionary) -> Color:
	if i == _sel:
		return Color(Pal.SUN, WASH_SELECTED)
	if twins.has(i):
		return Color(Pal.SUN, WASH_TWIN)
	if _wrong.has(i):
		return Color(Pal.BAD, WASH_WRONG)
	if clash.has(i):
		return Color(Pal.BAD, WASH_CLASH)
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
		at.x += Motion.shiver_offset(now - float(_shiver.get(i, -1.0e9)), Motion.SHIVER_PX * k)
		var grow := Motion.bump_scale(now - float(_bump.get(i, -1.0e9)))
		var d: int = state.grid[i]
		if d > 0:
			var fell := now - float(_drop.get(i, -1.0e9))
			at.y -= Motion.drop_in_lift(fell, Motion.DROP * k)
			var alpha := seen * (Motion.appear_level(fell) if _drop.has(i) else 1.0)
			_seat(at, centre, pop, grow)
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
				var spot := Vector2(float((n - 1) % 3) - 1.0, float((n - 1) / 3) - 1.0) \
					* (_cell * NOTE_STEP)
				_numeral(note_font, note_px, note_rise, str(n), spot,
					Color(Pal.TEXT_DIM, seen))
	draw_set_transform(Vector2.ZERO)

## Puts the canvas at `at` under the entrance's pop about `centre`, scaled by
## the cell's own bump: one transform, so a numeral never drifts off the cell
## the mesh drew under it.
func _seat(at: Vector2, centre: Vector2, pop: float, grow: float) -> void:
	draw_set_transform(centre + (at - centre) * pop, 0.0, Vector2.ONE * (pop * grow))

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
## rose while the last Check still points at it.
func _digit_ink(i: int) -> Color:
	if state.is_given(i):
		return Pal.TEXT
	return Pal.BAD if _wrong.has(i) else Pal.LEAF_DEEP

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
	if state == null or is_done():
		return
	if not (event is InputEventScreenTouch and event.pressed):
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

## A chip was tapped: 0..8 are the digits 1..9 and PENCIL_CHIP is the pencil,
## which is the one thing on this screen that stays armed.
func pick(i: int) -> bool:
	if state == null or is_done():
		return false
	if i == PENCIL_CHIP:
		_pencil = not _pencil
		focus_changed.emit()
		return false
	if _sel < 0:
		_speak("Tap a cell first", Face.Expr.PUZZLED)
		return false
	return _apply(_sel, i + 1)

# --- the one door every move goes through ---

## Every move that can change the grid comes through here, so the wave is
## diffed in exactly one place: what was finished before the move against
## what is finished after it. Nothing else may call state.place or state.mark.
func _apply(i: int, d: int) -> bool:
	var before: Array = state.finished_units()
	var code: int = state.mark(i, d) if _pencil else state.place(i, d)
	match code:
		State.GIVEN:
			_refuse(i, "That one came with the puzzle")
			return false
		State.FILLED:
			_refuse(i, "Pencil marks go in an empty cell")
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
	fx.cue("place")
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
			var when := now + step * WAVE_STEP
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
	# WAVE_STEP a step. `_settle` will not re-light it (`before` says it was
	# already finished), but nothing else would put it out either, and the
	# gold would go on sweeping a row that is no longer right. Section 7's
	# rule is that there is no highlight to leave behind; this is the one
	# place on the board that could leave one.
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
	_say("There it is. That one had the fewest numbers left to be.", Face.Expr.HAPPY)
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
			var when := now + absi(Gen.row_of(i) - 4) * Motion.RESET_STAGGER
			_shiver[i] = when
			_busy_for(when - now + Motion.SHIVER_TIME)
	_speak(_check_line(w.size()), Face.Expr.STRAIN if w.size() > 0 else Face.Expr.JOY)
	fx.cue("check" if w.size() > 0 else "check_ok")
	_redraw()
	return w.size()

func _check_line(wrong: int) -> String:
	if wrong == 0:
		return "Every number you have put down belongs there."
	if wrong == 1:
		return "One number to look at again."
	return "%d numbers to look at again." % wrong

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
			_busy_for(when - now + Motion.BUMP_TIME)
	state.clear_board()
	_sel = -1
	_wrong = {}
	_flash = {}
	_drop = {}
	_shiver = {}
	moves = 0
	_say("The board is back to its givens. The hints you spent are not refunded.",
		Face.Expr.HAPPY)
	fx.cue("reset")
	_redraw()

# --- the win ---

## The whole grid waves along the diagonal with the family's stagger, and
## every seventh cell sparkles in gold; the win screen follows WIN_WAIT later.
func _on_solved() -> void:
	var now := _now()
	_tip_timer.stop()
	_sel = -1
	_wrong = {}
	_say("Every number in its place.", Face.Expr.JOY)
	fx.cue("solved")
	if not Motion.reduce:
		for i in Gen.CELLS:
			var when := now + Motion.SOLVE_DELAY \
				+ Motion.stagger(Gen.row_of(i) + Gen.col_of(i), Motion.SOLVE_STAGGER)
			_flash[i] = when
			_bump[i] = when
			_busy_for(when - now + maxf(WAVE_FLASH, Motion.BUMP_TIME))
		# One burst, at the middle of the grid. The scatter along the
		# diagonal the spec's table asks for wants a scheduled emitter per
		# cell against a pool of three, and it is the motion task's to build.
		fx.sparkle(_centre(), Pal.SUN)
	_redraw()

# --- the sprout's line ---

## The chrome is the host's; here the grid pops in wide after the family's
## delay and the givens fade in region by region behind it.
func _enter() -> void:
	_opened = _now()
	_busy_for(_enter_delay(Gen.CELLS - 1) + Motion.DROP_TIME)
	fx.cue("enter")

## What the tip card shows. A Dictionary, because that is what
## ui/flat/tip_card.gd reads: a board that answers this owns its own line and
## its own cycle, and the card stops cycling its Binairo rules for it.
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
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

func _cycle_tip() -> void:
	if is_done() or _now() < _hold_until:
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
