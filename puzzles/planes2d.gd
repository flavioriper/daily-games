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
## How it moves (spec section 10). Nothing here tweens a node, because there
## is no node to tween: every moment is a **book of moments** -- a plane index
## against the second something began -- read off the clock in `_draw` through
## `core/motion.gd`'s curve readers, which is docs/art/flat-motion.md's rule 8.
## There are four books (`_fly`, `_beat`, `_shiver`, `_nudge`) and one record
## (`_refuse`), and `_animating()` asks about **every one of them**: One Line
## shipped two lines frozen at four fifths of a fade because a second wave was
## left out of that function, and this board has six waves able to overlap.
## Every book is emptied as its moment expires (`_retire`), so the quiet board
## is quiet and none of it is state: **the wake in particular is derived from
## a diff of `free_planes()` and never stored**, which is Queens' `_settle`,
## so an undo leaves nothing behind to clean up.
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
## The lane band a refusal lays down the cells ahead of a dart. **0.34 was drawn
## against 0.86 at the hard band's 58 px cell and kept** (Task 4): a stripe
## a third of a cell wide runs down the middle of the lane and leaves the
## dots on either side of it showing, so the band reads as *the way out* --
## the line the plane would take -- while 0.86 floods the cells kerb to kerb,
## swallows those dots and reads as a highlighted region, which is a
## different sentence about the same rule. The stripe is also what the mock
## draws (its `WASH_W`, 0.34, for the refusal, the press preview and the
## hint's glow alike); the spec's "0.86 wash" was a misreading of it, and the
## spec's section 8 is amended to say so rather than to record a
## disagreement that was never there.
## A refusal's own band is `BAD_TILE` at the flash's level and needs no alpha
## of its own, so this is the only lane width on the board. **The mock's
## second lane -- `SUN` at 0.35 under a held finger, previewing a lane that
## *is* clear -- was struck rather than built** (Task 6). Two reasons, and
## the first is the binding one: **this board acts on press-down**, so there
## is no held-finger state to preview with. A preview would have to wait for
## a press that has already launched the plane, which means either a gate on
## the press (the one thing `_tap` is written not to have) or a second,
## slower input path -- and either would change what a single press does,
## which is what `tests/_win.gd`'s `_tap_local` drives and what the whole
## one-frame solve depends on. The second is that it would be saying a thing
## already said better: **the flight is the preview**. Tap a plane with a
## clear lane and it flies down that exact band, so the lane is shown by the
## plane taking it rather than by a stripe promising it could.
const LANE_W := 0.34
## The wash that stays under a hinted plane until it goes, and the ring that
## lands on its head: the only glow on this board. **This one is wider than
## the mock's** -- the mock draws every wash at its single `WASH_W` of 0.34 --
## and it is kept wide on purpose, because it is doing a different job: the
## lane band above names a *path* and wants to read as a line, and this names
## a *piece* and wants to read as a halo round the body it sits under. Shot
## both ways at 58 px (Task 4): 0.34 under a 0.17 trail leaves a gold rim
## barely a stroke wider than the ink, which reads as the trail having been
## outlined rather than as a light standing under the plane, and under the
## dart itself it all but disappears.
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

# --- this board's own motion, and no more of it (spec section 10) ---
## **Three constants, and nothing added to `core/motion.gd`.** Everything
## else below is a recipe from the vocabulary read as a curve, or a number
## handed to a recipe through its own parameter (rule 6).
##
## Cells a second along the track. Nothing else in the game moves a piece
## along its own body, so nothing else can want this number. The floor under
## a short flight is **not a fourth constant**: it is the family's
## `Motion.POP_IN`, because a launch is never quicker than the pop a piece
## arrives with, and a two-cell dart on a one-cell lane would otherwise blink
## out rather than fly.
const LAUNCH_SPEED := 22.0
## One ring of the wake per king-move step out from the departing plane's
## head. `Motion.WAVE_STEP` is 0.045 and measures a queen's *sight*, which is
## a fact about the piece that moved; this measures a *departure*, and the
## field it crosses is twenty-two rows rather than a court of eight.
const WAKE_STEP := 0.04
## How long the refused lane holds its band. The family's own flash runs
## `FLASH_IN` + `FLASH_OUT` = 0.6 s; this one is shorter because a refusal
## here is frequent by design and 0.6 s of rose across half the board reads
## as a scolding. The *shape* is still the family's, compressed into this:
## see `_flash_now`.
const BLOCK_FLASH := 0.35

## How long the win screen waits behind the board, and **it is arithmetic
## rather than taste** -- the two things that still have to happen when the
## last plane is tapped, added up at their worst:
##
## - **The last flight: 1.364 s.** A flight is `_s_end / LAUNCH_SPEED` with a
##   `Motion.POP_IN` floor. **The plane a first draft of this comment
##   described cannot exist**: a ten-cell plane's head on row 0 of the
##   22-row hard band, pointing off that edge, needs a cell at row -1 for
##   `add_plane` to derive its direction from -- the head is never the first
##   row a plane can point off of. The true ceiling is a head on **row 1**:
##   a body of 9 cells behind the head, a lane of 20 to the far edge, and one
##   more cell for the tail to leave on, for `_s_end` 30. 30 / 22 = 1.364 s,
##   the longest flight this game can generate; the worst actually measured
##   over 120 generated boards was `_s_end` 29 (1.318 s).
## - **The solve wave after it: 1.25 s.** `SOLVE_DELAY` (0.25) plus the far
##   corner's own stagger, which `Motion.stagger` caps at 0.6 however wide
##   the field is (rule 4, and a 16 x 22 field reaches that cap), plus
##   `SOLVE_TIME` (0.4).
##
## 1.364 + 1.25 = 2.614, rounded up. `WIN_WAIT` stays at 2.7 -- it now has
## *more* headroom than the arithmetic it was set against claimed, not less.
## It is the longest wait of any flat board -- Shikaku's 2.2 was the previous
## -- and the cost is named rather than hidden: when the last plane's flight
## is a short one, which is the common case, the board stands empty and still
## for up to a second after the wave before the win screen arrives. That is
## the price of a constant, which is the shape every sibling uses; the
## alternative is a `win_delay()` that measures the flight it is actually
## waiting for, and nothing in the family does that yet.
const WIN_WAIT := 2.7

const TIP_CYCLE := 8.0
const TIPS := [
	"PP_TIP_TAP",
	"PP_TIP_LANE",
	"PP_TIP_SAFE",
	"PP_TIP_FRONT",
]

## What the sprout says after a launch, and **it stops** (spec section 13).
## The first few launches are still teaching the rule, so each gets a line;
## after that a launch says nothing at all and whatever was on the card
## stays. **It never counts planes**: the board is its own scoreboard, and
## "forty-one planes left" said forty-one times on the hard band is noise
## over a picture that already says it better -- the sky empties in front of
## the player. That is Mushroom Patch's rule about a running commentary,
## taken further because this field is five times the size of that patch.
const SAID := [
	"PP_SAID_1",
	"PP_SAID_2",
	"PP_SAID_3",
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
## The second the solve wave begins, or -1 while there is no wave. It is a
## record and not a book, exactly like `_refuse`: `_retire` clears it the
## frame it runs out, so the quiet board is quiet.
var _solved_at := -1.0
## The cell the last plane's head stood on, which is where the solve wave is
## staggered out from -- the point the sky was emptied at.
var _solve_from := Vector2i.ZERO

# --- the books of moments ---
## The flights in the air: plane index -> {"at", "dur", "s_end", "back"}.
## **Not state.** The state is launched on the tap and this only draws the
## going, which is what lets several planes be in the air at once and what
## lets `tests/_win.gd` clear a whole board inside a single frame. A `back`
## flight is an undo's or a reset's, the same track run the other way.
var _fly: Dictionary = {}
## The wake: plane index -> the second its wings beat. Written by `_wake`
## off a diff of `free_planes()` across the tap and never read for anything
## but the beat, so an undo has nothing to undo here.
var _beat: Dictionary = {}
## The refusal's two movers: the blocking plane's shiver and the tapped
## plane's nudge, each plane index -> the second it began.
var _shiver: Dictionary = {}
var _nudge: Dictionary = {}
## The refused lane itself: {"cells": Array[Vector2i], "at": float}, or empty.
var _refuse: Dictionary = {}
## Sparkles waiting for the plane they belong to to reach the edge of the
## board: {"at": float, "pos": Vector2, "i": int}. `ui/fx2d.gd` has no delay
## of its own and fifty CPU timers is fifty too many, so `_process` fires
## them. The plane index rides along so `_fly_back` can drop a puff whose
## flight reversed before it fired.
var _puffs: Array[Dictionary] = []

var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "planes"
func title() -> String: return "Paper Planes"

## The three sentences of the spec's section 3: what a lane is, what a tap
## does, and that a blocked tap costs nothing.
func rules() -> String:
	return tr("PP_RULES")

## Undo and Hint, and nothing else. There is no Check because nothing wrong
## can ever be sitting on the board: a launch only empties cells, so the
## registry drops the actions row and Reset rides up into the top bar.
func capabilities() -> Array[String]:
	return ["undo", "hint"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **The card is the wall a plane disappears behind**, and this is the one
	# flat board that clips: a launch runs its track a whole body-length past
	# the edge of the grid, which is out of this Control and over the top bar
	# unless it is cut off. The Control is a full-rect child of the board
	# slot, and the board card fills that slot, so the cut lands exactly on
	# the card's own edge -- the mock's picture, where a plane flies off the
	# grid, across the hem and is gone.
	clip_contents = true
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
	_state.build(rng, difficulty)
	_hint_lit = -1
	_anim_until = 0.0
	_solved_at = -1.0
	_solve_from = Vector2i.ZERO
	_forget()
	_layout()
	_enter()
	_tip_idx = 0
	_say(tr(TIPS[0]), Face.Expr.HAPPY)
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
	if _state.planes.is_empty():
		return
	var t := _now()
	_spend_puffs(t)
	# Sudoku's lesson: decide once a frame, here, and never again in _draw --
	# two asks disagreeing on the frame a moment expires is the One Line bug
	# in another costume. A moment that has just landed still owes one frame,
	# which is what _retire's answer buys. It runs **before** the cell guard
	# on purpose: a board with no layout yet still has to let its books empty,
	# or `_animating()` is true for ever the moment one is ever given a size.
	var dirty := _retire(t)
	if _cell <= 0.0:
		return
	if dirty or _animating(t):
		_refresh()

## Whether anything on this card is still moving, and **every wave is in
## here** -- the entrance, the hint's ring (through `_anim_until`), the
## flights, the wake's beats, the refusal's band, its shiver and its nudge.
## One Line shipped two lines frozen at four fifths of a fade because one
## wave was left out of its own version of this, and it showed in a rendered
## frame and in no test. The books are asked directly as well as through
## `_anim_until`, so a moment cannot outlive the window that was booked for
## it: whichever is longer wins.
func _animating(t: float) -> bool:
	if t < _anim_until:
		return true
	if not _fly.is_empty() or not _beat.is_empty():
		return true
	if not _shiver.is_empty() or not _nudge.is_empty() or not _refuse.is_empty():
		return true
	# The solve wave, which `_retire` clears the frame it runs out; while it
	# is set, the dots are still hopping (or waiting for the last flight to
	# land before they start).
	if _solved_at >= 0.0:
		return true
	if Motion.reduce:
		return false
	# The field's wide pop, then the last plane's own pop at the far end of
	# the capped stagger.
	return t - _opened < Motion.ENTER_DELAY + ENTER_CAP + Motion.POP_IN

## Closes every moment that has run out, so a landed plane is drawn from the
## state again and a quiet board goes quiet. Answers true when something
## actually left, because that frame is the first one drawn without it.
func _retire(t: float) -> bool:
	var dirty := false
	for i in _fly.keys():
		var f: Dictionary = _fly[i]
		if t >= float(f["at"]) + float(f["dur"]):
			_fly.erase(i)
			dirty = true
	for i in _beat.keys():
		if t >= float(_beat[i]) + Motion.BUMP_TIME:
			_beat.erase(i)
			dirty = true
	for i in _shiver.keys():
		if t >= float(_shiver[i]) + Motion.SHIVER_TIME:
			_shiver.erase(i)
			dirty = true
	for i in _nudge.keys():
		if t >= float(_nudge[i]) + Motion.NUDGE_LAG + Motion.NUDGE_TIME:
			_nudge.erase(i)
			dirty = true
	if not _refuse.is_empty() and t >= float(_refuse["at"]) + BLOCK_FLASH:
		_refuse = {}
		dirty = true
	if _solved_at >= 0.0 and t >= _solved_at + _wave_span():
		_solved_at = -1.0
		dirty = true
	return dirty

## How long the solve wave takes from the second it begins: the family's own
## delay, the far corner's stagger off `_solve_from` (capped at 0.6 by
## `Motion.stagger`, which a 16 by 22 field reaches), and one hop.
func _wave_span() -> float:
	return Motion.SOLVE_DELAY \
		+ Motion.stagger(_wave_reach(), Motion.SOLVE_STAGGER) + Motion.SOLVE_TIME

## The king-move distance from `_solve_from` to the furthest cell of the
## field, which is always one of the four corners.
func _wave_reach() -> int:
	return maxi(maxi(_solve_from.x, _state.cols - 1 - _solve_from.x),
		maxi(_solve_from.y, _state.rows - 1 - _solve_from.y))

## Every book emptied at once: a new board inherits nobody's flight.
func _forget() -> void:
	_fly = {}
	_beat = {}
	_shiver = {}
	_nudge = {}
	_refuse = {}
	_puffs = []

## The sparkles a launch leaves where it crossed the edge of the board, each
## fired on the frame its own plane reaches that point rather than when the
## tap happened. `ui/fx2d.gd` has no delay of its own; a `SceneTreeTimer` a
## plane would be fifty timers on the hard band and a generation counter to
## guard them, where this is four lines and dies with the board.
func _spend_puffs(t: float) -> void:
	var i := 0
	while i < _puffs.size():
		if t >= float(_puffs[i]["at"]):
			fx.puff(_puffs[i]["pos"], Pal.SUN_RAY)
			_puffs.remove_at(i)
		else:
			i += 1

## Drops any puff still booked for plane `i`: its flight reversed before the
## sparkle fired, and there is nothing left at that edge to mark.
func _forget_puff(i: int) -> void:
	var j := 0
	while j < _puffs.size():
		if int(_puffs[j]["i"]) == i:
			_puffs.remove_at(j)
		else:
			j += 1

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
## the spec's table: a lane band is BAD_TILE at the flash's own level, drawn
## on a refusal, and the thing it explains is the ink it would be covering --
## a band laid over a dart rubs out the dart. Nothing is lost by it: the
## band's cells are empty by definition except the blocker's, and the blocker
## is exactly what the player is being pointed at.
func _build_field(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_dots(b, _covers(t), t)
	if _hint_lit >= 0 and not _state.planes[_hint_lit]["gone"]:
		_ink(b, _state.planes[_hint_lit]["cells"], GLOW_W * _cell,
			Color(Pal.SUN_RAY, GLOW_ALPHA))
	if not _refuse.is_empty():
		var lv := _flash_now(t - float(_refuse["at"]))
		if lv > 0.0:
			_ink(b, _refuse["cells"], LANE_W * _cell, Color(Pal.BAD_TILE, lv))
	for i in _state.planes.size():
		# A plane in the air is drawn from its flight and not from the state:
		# the state let it go on the tap, and a returning one is back in the
		# state before it has flown home.
		if _fly.has(i) or not _state.planes[i]["gone"]:
			_plane(b, i, t)
	return b.mesh() if not b.verts.is_empty() else null

## A faint dot on every cell no plane stands on, and a **fading** one on
## every cell a plane is in the act of leaving. This is the lattice, and it
## is why a launch reads as emptying the board rather than as a jump cut: the
## cells a plane leaves are places, not holes, and each of them comes back
## the moment the tail passes over it.
##
## The solve wave rides here too, and nowhere else: when the sky is empty the
## dots are the only thing left on the card, so the family's wave is a hop on
## each of them. It is read as a curve off `Motion` the way everything on
## this board is -- no tween, no node -- and the whole of it is `_hop`.
func _dots(b, cover: Dictionary, t: float) -> void:
	var r := DOT * _cell
	for y in _state.rows:
		for x in _state.cols:
			var cell := Vector2i(x, y)
			var shown := 1.0
			if cover.has(cell):
				shown = 1.0 - float(cover[cell])
			elif _state.plane_at(cell) >= 0:
				shown = 0.0
			if shown > 0.004:
				b.disc(_centre(cell) + Vector2(0.0, _hop(cell, t)), r,
					Color(Pal.LINE, DOT_ALPHA * shown))

## One dot's place in the solve wave: the family's `hop_lift`, handed the
## seconds since this cell's own moment began -- `SOLVE_DELAY` after the wave
## starts, plus `SOLVE_STAGGER` per king-move step out from the cell the last
## plane's head stood on. Zero before the moment, after it, and under
## reduce-motion (`_solved_at` is never set there, and `hop_lift` answers
## zero anyway, so it is stilled twice over).
func _hop(cell: Vector2i, t: float) -> float:
	if _solved_at < 0.0:
		return 0.0
	return Motion.hop_lift(t - _solved_at - Motion.SOLVE_DELAY
		- Motion.stagger(_king(cell, _solve_from), Motion.SOLVE_STAGGER),
		Motion.SOLVE_HOP, Motion.SOLVE_TIME)

## How much of each cell is still under a plane in flight, 0 to 1, for every
## cell of every flight in the air. The fade is the family's own
## (`appear_level`), read against the second that plane's **tail** crosses
## that cell rather than against a distance -- which is how the dot's return
## costs this board no constant of its own. A flight home runs it backwards:
## the dot goes out as the tail arrives.
func _covers(t: float) -> Dictionary:
	var out: Dictionary = {}
	for i in _fly:
		var f: Dictionary = _fly[i]
		var cells: Array = _state.planes[i]["cells"]
		var s_end := float(f["s_end"])
		var back: bool = f["back"]
		for j in cells.size():
			var u := _ease_inv(float(j) / s_end)
			var when := float(f["at"]) + float(f["dur"]) * (1.0 - u if back else u)
			var lv := Motion.appear_level(t - when)
			out[cells[j]] = lv if back else 1.0 - lv
	return out

## One plane: its trail, its dart and the crease down the dart, wearing every
## moment it is in at once -- the entrance's pop about its **head** (that is
## where the eye is; a body scaling about its tail swings), the wake's beat
## across its wings, and the refusal's shiver or nudge under the whole of it.
## While it is in the air the body is the slice of its track between the tail
## and the head, so the tail follows the head through every bend the plane
## ever made.
func _plane(b, i: int, t: float) -> void:
	var cells: Array = _state.planes[i]["cells"]
	var n := cells.size()
	var dir := Vector2(_state.planes[i]["dir"])
	var flying := _fly.has(i)
	var s := _flown(i, t) if flying else 0.0
	var head: Vector2 = _track(i, s + float(n - 1)) if flying else _centre(cells[n - 1])
	var since := t - _opened - Motion.ENTER_DELAY \
		- Motion.stagger(_king(cells[n - 1], Vector2i.ZERO),
			Motion.ENTER_STAGGER, ENTER_CAP)
	var grow := Motion.pop_in_scale(since)
	var seen := Motion.appear_level(since)
	if grow.x <= 0.0 or seen <= 0.0:
		return
	# The refusal's two movers, both read as curves: the blocker shivers
	# across the board and the tapped plane leans the way it wanted to go.
	# Both take the vocabulary's own pixels -- the family measures a shiver
	# and a nudge in the 1080-wide design space, not in cells -- so neither
	# costs this board a constant.
	var off := Vector2(Motion.shiver_offset(t - float(_shiver.get(i, -1e9))), 0.0) \
		+ dir * Motion.nudge_offset(t - float(_nudge.get(i, -1e9)))
	var xf := Transform2D(0.0, grow, 0.0, head - head * grow + off)
	var ink := Color(Pal.TEXT, seen)
	_ink_pts(b, _body(i, s) if flying else _cell_pts(cells), TRAIL * _cell, ink, xf)
	_dart(b, head, dir.angle(), seen, xf,
		Motion.bump_scale(t - float(_beat.get(i, -1e9))))

## A trail, a wash or a band: **one round-capped stroke** along the cell
## centres of `cells`, with a disc at every bend -- never a rounded rect a
## cell. Laid side by side those leave a four-pointed hole where their
## corners meet, and a lane full of little stars reads as a bug; the mock
## found that with a screenshot. The discs are not decoration either: a
## stroke's own join averages the two tangents, so at the right angle every
## one of these paths turns it pinches to seven tenths of its width and
## leaves a notch on the outside of the corner.
func _ink(b, cells: Array, width: float, colour: Color) -> void:
	_ink_pts(b, _cell_pts(cells), width, colour)

## The centres of `cells`, which is what a plane standing still is drawn
## along. A plane in flight hands `_ink_pts` its track's points instead.
func _cell_pts(cells: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for cell: Vector2i in cells:
		pts.append(_centre(cell))
	return pts

func _ink_pts(b, pts: PackedVector2Array, width: float, colour: Color,
		xf := Transform2D.IDENTITY) -> void:
	if pts.is_empty() or width <= 0.0:
		return
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
##
## `beat` is the wake's `bump_scale`, and it opens the **wings**: the bump
## whole across the spine and three tenths of it along, which is the mock's
## proportion and the reason a beating dart reads as flapping rather than as
## swelling. It is a shape and not a timing -- the timing is the family's
## `BUMP_TIME` -- so it stands here beside `DART_WING` rather than among this
## board's three motion constants. A dart at rest is handed 1.0 and the
## arithmetic falls out to the plain dart.
func _dart(b, head: Vector2, angle: float, seen: float, xf: Transform2D,
		beat: float) -> void:
	var turn := Transform2D(angle, head)
	var wings := Vector2(1.0 + (beat - 1.0) * 0.3, beat) * _cell
	var pts := PackedVector2Array([
		Vector2(DART_TIP, 0.0) * wings,
		Vector2(-DART_BACK, DART_WING) * wings,
		Vector2(-DART_NOTCH, 0.0) * wings,
		Vector2(-DART_BACK, -DART_WING) * wings,
	])
	b.polygon(xf * (turn * pts), Color(Pal.TEXT, seen))
	var spine := PackedVector2Array([
		Vector2(CREASE_FROM, 0.0) * wings,
		Vector2(CREASE_TO, 0.0) * wings,
	])
	b.stroke(xf * (turn * spine), CREASE * _cell * xf.get_scale().x,
		Color(Pal.PAPER, seen))

## King-move distance, the step every wave on this board is staggered by.
static func _king(a: Vector2i, z: Vector2i) -> int:
	return maxi(absi(a.x - z.x), absi(a.y - z.y))

# --- the track: the launch's one piece of arithmetic ---

## A point on plane `i`'s **track**, `x` cells along it: its own body
## polyline from the tail at 0 to the head at `len - 1`, and then straight on
## down the lane and out past the edge of the board. Everything about the
## launch is a slice of this -- the body drawn is the track between `s` and
## `s + len - 1` -- and that is why the tail follows the head through every
## bend the plane ever made instead of sliding sideways off it. **Nothing
## else in the game moves a piece along its own body.**
func _track(i: int, x: float) -> Vector2:
	var cells: Array = _state.planes[i]["cells"]
	var n := cells.size()
	if x < float(n - 1):
		var j := clampi(int(floorf(x)), 0, n - 2)
		return _centre(cells[j]).lerp(_centre(cells[j + 1]), x - float(j))
	return _centre(cells[n - 1]) \
		+ Vector2(_state.planes[i]["dir"]) * (x - float(n - 1)) * _cell

## The body as a polyline, `s` cells along the track: the tail, every bend
## between it and the head, and the head. The bends are the whole-numbered
## points, because those are the cell centres the plane was drawn through.
func _body(i: int, s: float) -> PackedVector2Array:
	var n: int = (_state.planes[i]["cells"] as Array).size()
	var pts := PackedVector2Array([_track(i, s)])
	for k in range(int(floorf(s)) + 1, int(ceilf(s + float(n - 1)))):
		pts.append(_track(i, float(k)))
	pts.append(_track(i, s + float(n - 1)))
	return pts

## The whole flight, in cells: the body's own length, the lane it crosses,
## and one more cell, which is where the tail leaves the board. `lane()` is
## geometry and not occupancy, so this is the same number before the launch,
## during it, and on the way home.
func _s_end(i: int) -> float:
	var n: int = (_state.planes[i]["cells"] as Array).size()
	return float(n - 1 + _state.lane(i).size() + 1)

## How long that flight takes. The floor is the family's `POP_IN` rather than
## a constant of this board's: a launch is never quicker than the pop a piece
## arrives with.
func _dur(i: int) -> float:
	return maxf(Motion.POP_IN, _s_end(i) / LAUNCH_SPEED)

## The launch's ease, and it is **the family's own curve read backwards**:
## `pop_out_scale` is a quarter-cosine falling from one to nothing, so one
## minus it rises from nothing and accelerates away, which is a launch. No
## new curve, no new constant, and nothing added to `core/motion.gd`.
static func _ease(u: float) -> float:
	return 1.0 - Motion.pop_out_scale(clampf(u, 0.0, 1.0), 1.0)

## Its inverse: the fraction of the flight at which the plane has covered `e`
## of its track. Two things need it -- the puff, which has to know the frame
## the head crosses the edge of the board, and every cell's dot, which has to
## know the frame the tail passed over it.
static func _ease_inv(e: float) -> float:
	return acos(clampf(1.0 - e, -1.0, 1.0)) * 2.0 / PI

## Where plane `i` has got to, in cells along its track. A flight home reads
## the same curve from the far end, so an undo is the launch played
## backwards and not a second animation.
func _flown(i: int, t: float) -> float:
	var f: Dictionary = _fly[i]
	var u := clampf((t - float(f["at"])) / maxf(float(f["dur"]), 0.0001), 0.0, 1.0)
	return float(f["s_end"]) * _ease(1.0 - u if bool(f["back"]) else u)

## The refusal's band level: **the family's flash, compressed into
## `BLOCK_FLASH`**. `flash_level` takes its two halves as parameters, so the
## rise and the fall keep the vocabulary's own proportion (0.15 against 0.45)
## at a quarter less than the vocabulary's length -- a recipe's parameter,
## never a copied curve (rule 6).
static func _flash_now(elapsed: float) -> float:
	var span := Motion.FLASH_IN + Motion.FLASH_OUT
	return Motion.flash_level(elapsed, BLOCK_FLASH * Motion.FLASH_IN / span,
		BLOCK_FLASH * Motion.FLASH_OUT / span)

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

## The whole game. A free plane goes and a blocked one is refused, and the
## refusal costs nothing: no toast, no counter, no analytics event, no mark
## left on the board.
##
## **The state goes first and the picture follows.** The plane is out of the
## state on the frame of the tap, which is what makes the freed planes right
## while the flight is still in the air -- the wake is diffed against a
## snapshot taken a line earlier -- and what lets the departing plane be
## drawn from its flight rather than from a board it has already left.
##
## **There is no busy gate**: a tap is never refused because something else
## is still moving, several planes may be in the air at once, and a player
## who taps quickly is playing well rather than fighting the board. Boards
## here that gate on animation do it to protect a *shared* piece; nothing on
## this board is shared. It is also what lets `tests/_win.gd` clear a whole
## board inside a single frame.
func _tap(i: int) -> void:
	if _state.planes[i]["gone"]:
		return
	var t := _now()
	var blocked := _state.blocker(i)
	if blocked >= 0:
		_refuse_tap(i, blocked, t)
		_refresh()
		return
	var before := _free_set()
	if not _state.launch(i):
		return
	if _hint_lit == i:
		_hint_lit = -1
	_refuse = {}
	_beat.erase(i)
	var cells: Array = _state.planes[i]["cells"]
	# Where the wake runs out of, and -- if this was the last plane -- where
	# the solve wave runs out of too. Written before `note_move()`, which is
	# what emits `solved` and calls `_on_solved` on this same frame.
	_solve_from = cells[cells.size() - 1]
	_fly_out(i, t)
	_wake(before, _solve_from, t)
	fx.cue("place")
	_speak()
	_refresh()
	# note_move() counts the move and ends the puzzle if that was the last
	# plane; the host raises the win screen after win_delay().
	note_move()

## Every plane that can go right now, as a set to diff against.
func _free_set() -> Dictionary:
	var out: Dictionary = {}
	for i in _state.free_planes():
		out[i] = true
	return out

## Puts plane `i` in the air, and books the sparkles for the moment its head
## crosses the edge of the board -- `(lane + 0.5)` cells past the head is the
## edge, and `_ease_inv` says which frame that is. Under reduce-motion a
## launch is an instant removal: no flight, no puff, nothing to retire.
##
## **A plane turns around in the air; it never snaps home first.** `undo()`
## and `reset_board()` put a plane back in the state the instant its flight
## home *begins*, not when it lands -- the board has to be correct before the
## picture is -- so its cells are tappable again while it is still out over
## the edge, and there is deliberately no busy gate to stop that. A fresh
## flight starting at `s = 0` would therefore teleport the plane back to its
## resting cells and only then launch it, which on a Reset wave is a whole
## field of planes jumping. So a launch that finds a flight already in the
## air for that plane **starts at the phase whose eased position is where the
## plane actually is**: the position is `s_end * _ease((t - at) / dur)`, so
## sliding `at` back by `u0 * dur` puts the new flight exactly under the old
## one's last frame and leaves `(1 - u0) * dur` of it to run -- shorter,
## because there is less track left. The turn is continuous in the dots too:
## a cell is covered while the tail is short of it, which both directions
## agree on at the moment of the switch.
##
## The edge's sparkles are skipped when that phase is already past the edge:
## a plane still off the board when it is re-launched never crosses it again.
func _fly_out(i: int, t: float) -> void:
	if Motion.reduce:
		return
	var dur := _dur(i)
	var s_end := _s_end(i)
	var at := t
	if _fly.has(i):
		at = t - _ease_inv(clampf(_flown(i, t) / s_end, 0.0, 1.0)) * dur
	_fly[i] = {"at": at, "dur": dur, "s_end": s_end, "back": false}
	_busy_for(at + dur - t)
	var cells: Array = _state.planes[i]["cells"]
	var out := float(_state.lane(i).size()) + 0.5
	var crosses := at + dur * _ease_inv(out / s_end)
	if crosses >= t:
		_puffs.append({
			"at": crosses,
			"pos": _centre(cells[cells.size() - 1])
				+ Vector2(_state.planes[i]["dir"]) * out * _cell,
			"i": i,
		})

## Flies plane `i` home along the same track, `delay` from now: an undo's
## flight, or one of Reset's wave. The state already has it back, so the
## board is correct the instant the button is pressed and only the picture
## is late.
##
## **The same turn as `_fly_out`'s, the other way round**, and for the same
## reason: Undo takes back the last launch, which on a quick finger is still
## in the air, and Reset takes back a whole handful of them. Starting the
## flight home at the far end of the track would throw the plane off the
## board first and only then bring it in. So a plane already in the air turns
## where it is -- `at` slides back by `(1 - u0) * dur`, the backward phase
## whose eased position is the plane's own -- and **it does not wait its turn
## in the wave**: `delay` is dropped for it, because a piece that is already
## moving has nothing to queue for and holding it would be the teleport
## again, one beat later.
func _fly_back(i: int, t: float, delay: float) -> void:
	# The flight has reversed, so any puff still booked for this plane's old
	# outbound crossing is for an edge it is no longer headed toward. Undo
	# during a flight, and Reset's whole wave, both come through here, and
	# both used to leave that puff to fire at an empty edge.
	_forget_puff(i)
	if Motion.reduce:
		return
	var dur := _dur(i)
	var s_end := _s_end(i)
	var at := t + delay
	if _fly.has(i):
		at = t - (1.0 - _ease_inv(clampf(_flown(i, t) / s_end, 0.0, 1.0))) * dur
	_fly[i] = {"at": at, "dur": dur, "s_end": s_end, "back": true}
	_busy_for(at + dur - t)

## **The board answers the move.** This is Queens' `_settle` with a departure
## in place of a queen's sight: the free planes were snapshotted before the
## launch, they are asked again after it, and every plane that was not free
## and now is beats its wings once, `WAKE_STEP` a king-move step out from the
## departing plane's head. The set is **derived and never stored** -- nothing
## remembers who was freed by what -- so an undo leaves nothing behind to
## clean up, which is the whole reason the shape is worth copying.
func _wake(before: Dictionary, from: Vector2i, t: float) -> void:
	if Motion.reduce:
		return
	for q in _state.free_planes():
		if before.has(q):
			continue
		var cells: Array = _state.planes[q]["cells"]
		var at := t + Motion.stagger(_king(cells[cells.size() - 1], from), WAKE_STEP)
		_beat[q] = at
		_busy_for(at - t + Motion.BUMP_TIME)

## A refused tap, and **nothing is lost by it**: the lane flashes in
## `BAD_TILE` from the dart as far as the plane that is in the way, that
## plane shivers, the tapped one leans the way it wanted to go and settles,
## and the tip card says why. No toast (the flash already is the sentence, and
## a refusal here is frequent by design), no counter, no analytics event, no
## move counted, and no mark left on the board once the band has gone.
func _refuse_tap(i: int, blocked: int, t: float) -> void:
	_say(tr("PP_REFUSE"), Face.Expr.PUZZLED)
	if Motion.reduce:
		return
	var cells: Array[Vector2i] = []
	for c in _state.lane(i):
		cells.append(c)
		if _state.plane_at(c) == blocked:
			break
	_refuse = {"cells": cells, "at": t}
	_shiver[blocked] = t
	_nudge[i] = t
	_busy_for(maxf(BLOCK_FLASH, Motion.NUDGE_LAG + Motion.NUDGE_TIME))
	fx.cue("refuse")

# --- the sprout's line ---

## What a launch says, which after the first few is nothing at all. The line
## is picked by how many planes have gone rather than by how many are left,
## so it is a lesson running out and not a countdown running down -- see
## `SAID`. The win's own line comes from `_on_solved`, not from here.
func _speak() -> void:
	if is_done():
		return
	var gone: int = _state.planes.size() - _state.left()
	if gone < 1 or gone > SAID.size():
		return
	_say(tr(SAID[gone - 1]), Face.Expr.HAPPY)

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
	_say(tr(TIPS[_tip_idx]), Face.Expr.HAPPY)

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

## Calls the last plane back, flying it home along the track it left on.
## Counts no move.
func undo() -> bool:
	if is_done() or not can_undo():
		return false
	var i := _state.undo()
	if i < 0:
		return false
	_hint_lit = -1
	_refuse = {}
	# Nothing to unwind in the wake: who was freed by what was never written
	# down. The one thing that is this plane's own is its beat, and only
	# because a plane mid-beat that is also mid-flight reads as a stutter.
	_beat.erase(i)
	_fly_back(i, _now(), 0.0)
	_say(tr("PP_UNDO"), Face.Expr.HAPPY)
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
	# It beats its wings once, out of the wake's own book: the hint names a
	# plane that can go, and that is exactly what a beat means here.
	if not Motion.reduce:
		_beat[i] = _now()
	_busy_for(Motion.RING_TIME)
	fx.cue("hint")
	_say(tr("PP_HINT"), Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	check_solved()
	return true

## Every plane back on the field. What a hint gave stays given: the hints
## spent are not refunded, only unpinned.
func reset_board() -> void:
	var t := _now()
	var far := Vector2i(_state.cols - 1, _state.rows - 1)
	# Pulled back one at a time rather than with `reset()`, because each one
	# needs a flight home of its own and the state's `undo()` is the only
	# thing that knows what went and in what order. `reset()` afterwards is a
	# no-op that keeps this honest if the history and the board ever part.
	while true:
		var i := _state.undo()
		if i < 0:
			break
		_beat.erase(i)
		var cells: Array = _state.planes[i]["cells"]
		# The family's reset wave, from the far corner (rule 4's cap and all).
		_fly_back(i, t, Motion.stagger(
			_king(cells[cells.size() - 1], far), Motion.RESET_STAGGER))
	_state.reset()
	_hint_lit = -1
	_refuse = {}
	_solved_at = -1.0
	moves = 0
	_running = true
	_say(tr("PP_RESET"), Face.Expr.HAPPY)
	fx.cue("reset")
	_refresh()

## A completed daily is rebuilt from its seed, so it reopens with a full sky.
## Launch every plane in the state's own solve order and settle the picture
## at once: no flight, no wake, no puff, no entrance and no solve wave left
## to run -- the empty lattice a finished board shows once its wave has gone.
## Never `check_solved()`: the host owns the win for an already-completed
## daily and `solved` must not fire a second time.
func restore_completed_board() -> void:
	var t := _now()
	for i in _state.solve_order():
		_state.launch(i)
	# Clears the launch history (every cell is already empty), so nothing is
	# left for an undo to call back.
	_state.clear_occupancy()
	_forget()
	_hint_lit = -1
	_solved_at = -1.0
	_anim_until = 0.0
	_opened = t - 10.0
	_tip_timer.stop()
	_say(tr("PP_WIN"), Face.Expr.JOY)
	_refresh()

# --- the win ---

## No cast and a subtitle, so the win screen keeps the family's sun and moon.
## The host's `faces` are Controls out of `ui/faces/` and **this board has
## none** (spec section 9): a dart drawn up there would be a new Control for
## one screen's sake, which is exactly the bargain that section declines.
## Nonogram, Word Trail and Sudoku all answer this way for the same reason.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": tr("PP_WIN")}

## How long the host holds the win screen back. See `WIN_WAIT` for the
## arithmetic; under reduce-motion there is neither a flight nor a wave to
## wait for, so the win follows the last tap (spec section 10's
## reduce-motion row).
func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

## **The wave waits for the plane that won the board.** The last launch is
## still in the air when `note_move()` ends the puzzle -- the state let it go
## on the tap -- and a field hopping under a plane that has not left yet is
## two hands at once, which is Word Trail's lesson at its own solve. So the
## wave is booked for the second the last flight lands, and rolls out from
## `_solve_from`, the cell that plane's head stood on: the sky empties from
## the place the last plane left it.
##
## Nothing here is a book, because nothing here needs retiring one entry at
## a time: the wave is one second (`_solved_at`) and one origin, read by
## every dot in `_hop`, and `_retire` drops it when it has run.
func _on_solved() -> void:
	var t := _now()
	_tip_timer.stop()
	_hint_lit = -1
	_refuse = {}
	_say(tr("PP_WIN"), Face.Expr.JOY)
	fx.cue("solved")
	_refresh()
	if Motion.reduce:
		return
	_solved_at = t + _flight_left(t)
	_busy_for(_solved_at - t + _wave_span())

## How much of the longest flight still in the air is left to run. Zero on a
## quiet board, and zero under reduce-motion, where a launch is an instant
## removal and `_fly` is never written.
func _flight_left(t: float) -> float:
	var left := 0.0
	for i in _fly:
		var f: Dictionary = _fly[i]
		left = maxf(left, float(f["at"]) + float(f["dur"]) - t)
	return maxf(0.0, left)

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
