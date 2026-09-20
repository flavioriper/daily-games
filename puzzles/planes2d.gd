extends "res://core/puzzle_base.gd"

## Paper Planes as a flat board: a lattice of faint dots with bent ink trails
## laid over it, each one ending in a folded paper dart. Tap a plane and it
## launches -- if, and only if, every cell straight ahead of its dart is empty
## out to the edge of the board. Clear the sky and the board is done. The
## rules live in puzzles/planes_state.gd, which this only draws.
##
## **Nothing here can go wrong.** A launch only ever empties cells, so it can
## never block another plane: there is no Check, no lose, and no order of taps
## that can dead-end the board (spec section 3). Undo and Reset are
## convenience rather than repair, and a refused tap costs nothing at all --
## no life, no counter, no mark left behind.
##
## How it is drawn. One mesh and no Controls: the dots, the hint's wash, every
## trail, every dart and every crease go into a single `ArrayMesh`, because
## none of them has a face on it and a Control per plane would be fifty-two
## nodes on the hard band. The mesh is rebuilt only when something changed --
## a launch, an undo, a reset, a relayout, or a frame of the entrance -- and
## the one the last `_draw` handed over is kept in `_shown` until the next
## replaces it: **a canvas command holds a mesh by RID and not by reference**,
## so dropping the only reference to a mesh still on the item's command list
## leaves the renderer drawing a freed one ("Parameter mesh is null", and an
## empty card) on any frame a harness forces with
## `RenderingServer.force_draw()`.
##
## Spec: docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md,
## sections 7 to 10. Ported from the canvas mock at
## docs/brainstorm/concepts.html#planes, which is the reference for every
## measure here; the two places the mock and the spec differ are named at the
## constants they differ on, and each says which number was taken and why.

const State = preload("res://puzzles/planes_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")

# --- the screen, measured (spec section 7) ---
## The board card's own inset: 28 off a 1000 by 1340 card leaves a field box
## of 944 by 1284, and the cell is the largest whole number of pixels that
## fits the band's grid in it -- 91 on easy, 71 on medium, 58 on hard.
const INSET := 28.0

# --- the pieces, every one of them a fraction of the cell (spec section 8) ---
## An empty cell's dot, and how far its LINE is let through. This is what
## makes the occupancy read at a glance, and it is the one thing the
## reference's picture gets exactly right.
const DOT := 0.05
const DOT_ALPHA := 0.45
## The trail's stroke, round-capped at the tail and round-jointed at every
## bend: the reference's 5 px on a 32 px lattice, said as a fraction.
const TRAIL := 0.17
## The dart, forward of the head cell's centre along the plane's direction:
## the tip, how far back the wings sit, how far aside they spread, and how
## deep the tail notch is cut. **A solid arrowhead is a symbol; a dart is an
## object** -- the notch and the crease below are the whole re-theme.
const DART_TIP := 0.42
const DART_BACK := 0.26
const DART_WING := 0.30
const DART_NOTCH := 0.12
## The crease down the dart's spine, in PAPER: its width, and the two ends it
## runs between -- not the whole spine, a fold slit near the tip. **All three
## are the mock's, and the width corrects the spec's 0.09**, which was
## reasoned rather than looked at: at 0.09 the crease hollows the dart out
## and the head stops reading as the solid ink the reference's arrowhead is.
## A dart is solid with a fine fold in it.
const CREASE := 0.06
const CREASE_FROM := 0.22
const CREASE_TO := -0.05
## The lane band a press or a refusal lays down the cells ahead of a dart,
## and how far its colour is let through. **Task 4 owns both moments** (the
## launch, the wake and the refusal); the band lives here because the field
## mesh is built in one place and the spec fixes its size. The mock's own
## band is 0.86 of a cell -- a wash over the whole lane rather than a stripe
## down it -- and the spec's 0.34 is the number taken.
const LANE_W := 0.34
const LANE_ALPHA := 0.35
## The wash that stays under a hinted plane until it goes, and the ring that
## lands on its head: the mock's, and the only glow on this board.
const GLOW_W := 0.86
const GLOW_ALPHA := 0.32
const RING_R := 0.5

## Three, as everywhere. A hint only ever *names* a plane that can go -- it
## never launches it, because there is no wrong move to save anyone from.
const HINTS := 3
## The entrance's stagger cap. A plane pops in ENTER_STAGGER after the one a
## king-move nearer the top-left corner, and **the cap is this board's own**:
## fifty-two planes at the family's uncapped 0.6 is a minute of entrance, so
## the number goes through `Motion.stagger`'s `cap` parameter rather than
## into a copied constant (docs/art/flat-motion.md's rule for a number that
## has to differ).
const ENTER_CAP := 0.5

const TIP_CYCLE := 8.0
const TIPS := [
	"Tap a plane and it flies out the way it points.",
	"Its lane has to be clear all the way off the board.",
	"Nothing here can go wrong. Any plane that can go, can go.",
	"Send the one in front first.",
]

var _state = State.new()
## The board's own effects node, as on every flat board: the hint's ring
## comes through it and nowhere else.
var fx: Node2D

## The layout, recomputed on a resize and on a new board rather than on every
## read: the cell's side in pixels and the grid's top-left inside this
## Control's rect.
var _cell := 0.0
var _origin := Vector2.ZERO

## The field: the dots, the hint's wash, the trails, the darts and the
## creases, in one mesh. Dropped whenever something changed so the next
## _draw rebuilds it.
var _field: ArrayMesh
## The mesh the last _draw actually handed to the canvas item. See the note
## at the top: a canvas command holds it by RID, so it is kept until the next
## one takes its place.
var _shown: ArrayMesh

var _opened := 0.0
var _anim_until := 0.0
## The plane a hint named, or -1: it keeps a soft wash under it until it goes.
var _hint_lit := -1

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "planes"
func title() -> String: return "Paper Planes"

## The three sentences of the spec's section 3: what a lane is, what a tap
## does, and that a blocked tap costs nothing.
func rules() -> String:
	return "Every plane points somewhere, and its lane is every cell straight ahead of it, out to the edge of the board. Tap a plane and it launches along its own trail and away, but only if that lane is completely empty. A tap on a plane whose lane is blocked costs you nothing at all -- there is nothing to lose here and no order of launches that can strand you, so clear the sky in whatever order you like."

## Undo and Hint, and nothing else. There is no Check because nothing wrong
## can ever be sitting on the board: a launch only empties cells, so the
## registry drops the actions row and Reset rides up into the top bar.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

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

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.build(rng, difficulty)
	_hint_lit = -1
	_anim_until = 0.0
	_layout()
	_enter()
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()

# --- layout ---

## The largest whole cell the card holds, and the grid centred in it. **Every
## band is bound by the height** -- 91, 71 and 58 against the 944 the width
## would allow -- so the few pixels left over go into the centring and there
## is nothing else to spend them on.
func _layout() -> void:
	_cell = 0.0
	_origin = Vector2.ZERO
	if _state.cols > 0 and _state.rows > 0:
		_cell = maxf(0.0, floorf(minf(
			(size.x - 2.0 * INSET) / float(_state.cols),
			(size.y - 2.0 * INSET) / float(_state.rows))))
		_origin = Vector2(size.x - float(_state.cols) * _cell,
			size.y - float(_state.rows) * _cell) * 0.5
	_refresh()

## The card this board wants: every pixel it is given. The grid is taller
## than it is wide in a slot that is taller than it is wide, so the height
## binds and there is no slack worth capping.
func card_height(available: float) -> float:
	return available

## False, and honestly so: card_height() hands back everything, so the slack
## is zero and there is nothing to centre. Word Trail's answer, for Word
## Trail's reason.
func card_centred() -> bool:
	return false

func _centre(cell: Vector2i) -> Vector2:
	return _origin + (Vector2(cell) + Vector2.ONE * 0.5) * _cell

## Control-local point over the centre of the cell at (row, column), the name
## every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return _centre(Vector2i(c, r))

## The cell under a local point, or (-1, -1). There are no gaps between cells
## on this board -- the lattice is continuous -- so every point inside the
## grid belongs to one.
func _cell_at(local: Vector2) -> Vector2i:
	if _cell <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - _origin) / _cell
	var at := Vector2i(int(floorf(p.x)), int(floorf(p.y)))
	return at if _state.in_board(at) else Vector2i(-1, -1)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or _state.planes.is_empty():
		return
	if _animating(_now()):
		_refresh()

## Whether anything on this card is still moving. Today that is the entrance
## and the hint's ring; Task 4's launch, wake and refusal each add their own
## wave here, and **every one of them has to be in this function** -- One Line
## shipped two lines frozen at four fifths of a fade because one was left out,
## and it showed in a rendered frame and in no test.
func _animating(t: float) -> bool:
	if t < _anim_until:
		return true
	if Motion.reduce:
		return false
	# The field's wide pop, then the last plane's own pop at the far end of
	# the capped stagger.
	return t - _opened < Motion.ENTER_DELAY + ENTER_CAP + Motion.POP_IN

## Keeps the field redrawing for `seconds` more: something on it is moving.
func _busy_for(seconds: float) -> void:
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the field so the next _draw rebuilds it, and asks for that draw. The
## mesh the last _draw handed over is still held by _shown, so the renderer is
## never left pointing at a freed RID.
func _refresh() -> void:
	_field = null
	queue_redraw()

# --- the drawing ---

## One mesh, one draw command, and one transform over it: the field pops in
## wide about its centre (rule 7 -- a wide thing comes from most of the way)
## while each plane pops in about its own head.
func _draw() -> void:
	if _cell <= 0.0 or _state.planes.is_empty():
		return
	var t := _now()
	if _field == null:
		_field = _build_field(t)
	if _field == null:
		return
	var grow := Motion.wide_pop_scale(t - _opened - Motion.ENTER_DELAY)
	var mid := _origin + Vector2(float(_state.cols), float(_state.rows)) * _cell * 0.5
	draw_mesh(_field, null, Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow)))
	_shown = _field

## Everything on the field, in the one order that works: the dots on the
## empty cells, the hint's wash and any lane band **under** the ink, then
## every plane's trail and its dart over them.
##
## The washes go under rather than over, which is the mock's order and not
## the spec's table: a lane band is a pale colour (SUN at 0.35, or BAD_TILE
## on a refusal) and the thing it explains is the ink it would be covering --
## a band laid over a dart rubs out the dart. Nothing is lost by it: the
## band's cells are empty by definition except the blocker's, and the blocker
## is exactly what the player is being pointed at.
func _build_field(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_dots(b)
	if _hint_lit >= 0 and not _state.planes[_hint_lit]["gone"]:
		_ink(b, _state.planes[_hint_lit]["cells"], GLOW_W * _cell,
			Color(Pal.SUN_RAY, GLOW_ALPHA))
	for i in _state.planes.size():
		if not _state.planes[i]["gone"]:
			_plane(b, i, t)
	return b.mesh() if not b.verts.is_empty() else null

## A faint dot on every cell no plane stands on. This is the lattice, and it
## is why a launch reads as emptying the board rather than as a jump cut: the
## cells a plane leaves are places, not holes.
func _dots(b) -> void:
	var ink := Color(Pal.LINE, DOT_ALPHA)
	var r := DOT * _cell
	for y in _state.rows:
		for x in _state.cols:
			var cell := Vector2i(x, y)
			if _state.plane_at(cell) < 0:
				b.disc(_centre(cell), r, ink)

## One plane: its trail, its dart and the crease down the dart, all wearing
## the entrance this frame. The pop is about the **head**, because that is
## where the eye is -- a body scaling about its tail swings.
func _plane(b, i: int, t: float) -> void:
	var cells: Array = _state.planes[i]["cells"]
	var head: Vector2 = _centre(cells[cells.size() - 1])
	var since := t - _opened - Motion.ENTER_DELAY \
		- Motion.stagger(_king(cells[cells.size() - 1], Vector2i.ZERO),
			Motion.ENTER_STAGGER, ENTER_CAP)
	var grow := Motion.pop_in_scale(since)
	var seen := Motion.appear_level(since)
	if grow.x <= 0.0 or seen <= 0.0:
		return
	var xf := Transform2D(0.0, grow, 0.0, head - head * grow)
	var ink := Color(Pal.TEXT, seen)
	_ink(b, cells, TRAIL * _cell, ink, xf)
	_dart(b, head, Vector2(_state.planes[i]["dir"]).angle(), seen, xf)

## A trail, a wash or a band: **one round-capped stroke** along the cell
## centres of `cells`, with a disc at every bend -- never a rounded rect a
## cell. Laid side by side those leave a four-pointed hole where their
## corners meet, and a lane full of little stars reads as a bug; the mock
## found that with a screenshot. The discs are not decoration either: a
## stroke's own join averages the two tangents, so at the right angle every
## one of these paths turns it pinches to seven tenths of its width and
## leaves a notch on the outside of the corner.
func _ink(b, cells: Array, width: float, colour: Color, xf := Transform2D.IDENTITY) -> void:
	if cells.is_empty() or width <= 0.0:
		return
	var pts := PackedVector2Array()
	for cell: Vector2i in cells:
		pts.append(_centre(cell))
	pts = xf * pts
	if pts.size() < 2:
		b.disc(pts[0], width * 0.5, colour)
		return
	b.stroke(pts, width * xf.get_scale().x, colour)
	for i in range(1, pts.size() - 1):
		b.disc(pts[i], width * 0.5 * xf.get_scale().x, colour)

## The folded dart at a plane's head: the four-point outline (tip, wing,
## notch, wing) turned to the plane's heading, with the crease laid down its
## spine in PAPER. The notch is what stops it reading as an arrow.
func _dart(b, head: Vector2, angle: float, seen: float, xf: Transform2D) -> void:
	var turn := Transform2D(angle, head)
	var pts := PackedVector2Array([
		Vector2(DART_TIP, 0.0) * _cell,
		Vector2(-DART_BACK, DART_WING) * _cell,
		Vector2(-DART_NOTCH, 0.0) * _cell,
		Vector2(-DART_BACK, -DART_WING) * _cell,
	])
	b.polygon(xf * (turn * pts), Color(Pal.TEXT, seen))
	var spine := PackedVector2Array([
		Vector2(CREASE_FROM, 0.0) * _cell,
		Vector2(CREASE_TO, 0.0) * _cell,
	])
	b.stroke(xf * (turn * spine), CREASE * _cell * xf.get_scale().x,
		Color(Pal.PAPER, seen))

## King-move distance, the step every wave on this board is staggered by.
static func _king(a: Vector2i, z: Vector2i) -> int:
	return maxi(absi(a.x - z.x), absi(a.y - z.y))

# --- the moments ---

## The chrome is the host's. The field's own entrance is one wide pop about
## its centre with each plane popping in about its head, staggered by its
## king-move distance from the top-left corner; it is read off the clock in
## _draw, so all this has to do is start it.
func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	_refresh()

# --- input ---

## A tap, and nothing else: there is no drag on this board and no cell to
## focus. The cell under the finger names a plane, and the plane answers.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	if not event.is_pressed():
		return
	var cell := _cell_at(event.position)
	if cell.x < 0:
		return
	var i := _state.plane_at(cell)
	if i < 0:
		return
	_tap(i)
	accept_event()

## The whole game, in six lines. A free plane goes; a blocked one does
## nothing at all yet -- Task 4 gives the flight, the wake and the refusal
## their pictures, and until then a launch is immediate.
##
## **There is no busy gate**, now or after Task 4: a tap is never refused
## because something else is still moving, and several planes may be in
## flight at once. `tests/_win.gd` clears a whole board inside a single
## frame, and a gate on animation would fail it.
func _tap(i: int) -> void:
	if not _state.is_free(i):
		return
	if not _state.launch(i):
		return
	if _hint_lit == i:
		_hint_lit = -1
	fx.cue("place")
	_speak()
	_refresh()
	# note_move() counts the move and ends the puzzle if that was the last
	# plane; the host raises the win screen after win_delay().
	note_move()

# --- the sprout's line ---

func _left_line() -> String:
	var left := _state.left()
	if left <= 0:
		return "That is the field cleared."
	return "One plane left." if left == 1 else "%d planes left." % left

func _speak() -> void:
	if is_done():
		return
	_say(_left_line(), Face.Expr.HAPPY)

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

func _cycle_tip() -> void:
	if is_done() or _state.left() < _state.planes.size():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

## The sprout's own line, rather than Binairo's cycle of broken rules: there
## is no rule a tap can break on this board.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func is_solved() -> bool:
	return _state.solved()

## Something has gone, so something can come back. The state keeps the
## launch history itself, and a plane is on the board or it is not, so this
## needs no book of its own.
func can_undo() -> bool:
	return _state.left() < _state.planes.size()

## Calls the last plane back. Counts no move.
func undo() -> bool:
	if is_done() or not can_undo():
		return false
	if _state.undo() < 0:
		return false
	_hint_lit = -1
	_say("Called back. " + _left_line(), Face.Expr.HAPPY)
	fx.cue("undo")
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Rings a plane that can go and leaves a wash under it until it does. It
## never launches it: **naming a legal move is the whole of the help this
## board can give**, because there is no wrong move to save anyone from. The
## pick is the state's -- the generator's own order while the player is still
## on it, any free plane once they are not.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var i: int = _state.hint_plane()
	if i < 0:
		return false
	hints_used += 1
	_hint_lit = i
	var cells: Array = _state.planes[i]["cells"]
	fx.ring(_centre(cells[cells.size() - 1]), _cell * RING_R, Pal.LEAF)
	_busy_for(Motion.RING_TIME)
	fx.cue("hint")
	_say("This one has a clear lane.", Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	check_solved()
	return true

## Every plane back on the field. What a hint gave stays given: the hints
## spent are not refunded, only unpinned.
func reset_board() -> void:
	_state.reset()
	_hint_lit = -1
	moves = 0
	_running = true
	_say("All of them back on the field. " + _left_line(), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
