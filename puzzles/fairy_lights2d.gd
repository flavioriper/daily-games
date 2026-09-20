extends "res://core/puzzle_base.gd"

## Fairy Lights as a flat board: a pale garden ruled into cells, a lantern
## post in the middle, and a length of garden wire in every other cell. One
## tap turns a piece a quarter turn clockwise, and that is the only gesture
## on the screen. Wire joined all the way back to the post runs warm and
## gold; everything else is pale and cool. Done when every stub meets a stub
## and every lantern is lit. The rules live in
## puzzles/fairy_lights_state.gd, which this only draws.
##
## **The cells abut, and on this board that is not a style choice.** A wire
## crosses the cell boundary and meets the wire on the other side, so the
## 14-pixel alley Word Trail and Nonogram draw between their tiles would put
## a break in the middle of every join. The cell is a round
## `floor((1000 - 2*28) / n)` -- 188, 157, 134 -- with nothing subtracted,
## and the 6-wide fence is drawn *round* the grid rather than inside it,
## which is Sudoku's reason for Sudoku's rule.
##
## **A loose end looks loose.** A stub that meets a stub runs to the cell's
## edge and joins; a stub that meets a wall or a closed neighbour stops at
## LOOSE of the way with a round cap. It is the only thing on this board
## that says "not finished here", and it is half of what the win is defined
## by.
##
## How it is drawn (spec section 6). The ground, the fence, the cell rules,
## the pinned washes, the halos, the wire and the post all go into **one
## `ArrayMesh`**, rebuilt on change; the lanterns are `ui/faces/lantern_face.gd`
## Controls in slots this board owns, which is Untangle's arrangement,
## because a lantern has a face and a face is a Control here. **The post is
## in the mesh**: it is iron and glass with no face on it, and there is no
## post in `ui/faces/` to borrow -- adding one would be the new character
## this screen is written not to need.
##
## **The order is the one the mock paints in and no other**: the fence, the
## ground, the rules, a pinned cell's wash, then the halo under *every* live
## run, then the wire's shade and the wire over it, then the post. A halo
## drawn after the wire is a smear over it; a halo drawn per cell as the
## wire is drawn washes out its own neighbour's cable.
##
## **The spin and the wash** (spec section 7). A turn spins the piece a
## quarter turn with `back_out`'s overshoot over TURN_TIME, pulling its arms
## in ARM_PULL at the middle so it does not reach into its neighbours on the
## way round; a lantern's slot takes that turn and the paper inside it
## counter-turns, because a hanging thing does not cartwheel. Behind the spin
## runs **the wash**, which is this board's signature: Queens' `_settle` with
## the tree's own depth in place of a queen's sight. Every move diffs a
## depth snapshot taken *before* it against `state.depths()` after it, and
## hands each changed cell a moment -- `depth * WAVE_STEP` for a cell just
## reached, and the same wave **reversed, far end first**, for a cell just
## cut off, which reads as the light being pulled back rather than switched
## off.
##
## **Nothing about the wash is stored.** The board keeps the *moments*
## (`_live_at`, `_out_at`, `_wake_at`) and never the live set: what is live
## is `state.depths()`, recomputed on every build and every dress, and the
## moment only says when the eye is allowed to see it. The snapshot a settle
## diffs against is a local taken at the move and thrown away. So an undo
## needs no book to unwind and a stale set cannot exist.
##
## **While anything moves, the mesh is rebuilt every frame**, because the
## spin, the shiver and the wash are all baked into it. `_animating()` is the
## one gate on that, and **every** wave has to be inside it: they all push
## `_anim_until` out through `_busy_for`, so a new wave that forgets to call
## it freezes part-way through and shows on a rendered frame and in no test
## (One Line's two pale lines).
##
## **Keep the mesh the last `_draw` handed over.** A canvas command holds a
## mesh by RID and not by reference, so rebuilding the cache and dropping
## the previous mesh leaves the renderer drawing a freed RID -- "Parameter
## mesh is null", and an empty card -- on any frame rendered without the
## queued redraw flushed first, which is exactly what a harness's
## `force_draw()` does.
##
## Analytics need nothing here: `ui/puzzle_host.gd` already sends every event
## this board has, and there is no `check_used` because there is no Check.
##
## Spec: docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md,
## sections 2, 2.1, 3, 5, 6 and 9. Ported number for number from the canvas
## mock at docs/brainstorm/concepts.html#fairylights, which is the reference
## for every measure here.

const State = preload("res://puzzles/fairy_lights_state.gd")
const Gen = preload("res://puzzles/fairy_lights_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Face = preload("res://ui/faces/face.gd")
const LanternFace = preload("res://ui/faces/lantern_face.gd")

# --- the screen, measured (spec section 2.1) ---
## The card's own inset. The grid is what is left of the card's width, cut
## into n cells with **no gap**: 188 at 5x5, 157 at 6x6, 134 at 7x7.
const INSET := 28.0
## The fence round the grid: Sudoku's heavy rule, 6 wide, drawn outside the
## cells because they run to the inset's edge and it has nowhere else to go.
const FENCE := 6.0
## The ground's corner and the fence's, which is the ground's plus the rule.
const GROUND_RADIUS := 20.0
const FENCE_RADIUS := 26.0
## The rules between two cells: a hairline, so the cells are visible and no
## more. The wire is the drawing.
const RULE_W := 2.0
const RULE_ALPHA := 0.34

# --- the pieces, as fractions of a cell (all the mock's) ---
## The wire's own width, and how far a loose end falls short of the edge.
const WIRE := 0.13
const LOOSE := 0.7
## A junction of three or four arms gets a collar; a straight or an elbow
## does not, because a disc wider than the wire reads as a lump on it rather
## than as a joint.
const COLLAR := 0.62
## How far the wire's shade sits under its face, in pixels -- the soft lip
## every piece on these screens wears.
const SHADE_DROP := 4.0
## The halo under a live run, drawn before any wire: two passes, so a live
## branch reads as light before it reads as cable.
const HALO_WIDE := 2.7
const HALO_WIDE_ALPHA := 0.15
const HALO_NEAR := 1.6
const HALO_NEAR_ALPHA := 0.22
## The highlight along a live cable's back.
const SHEEN := 0.3
const SHEEN_ALPHA := 0.55
## A pinned cell: Word Trail's hint mark, unchanged -- a SUN_RAY wash under a
## dotted SUN_DEEP ring. Each inset from the cell's corner, its corner, and
## the dash's on and off runs.
const PIN_INSET := 6.0
const PIN_RADIUS := 0.18
const PIN_ALPHA := 0.4
const DASH_INSET := 9.0
const DASH_RADIUS := 0.16
const DASH_W := 4.0
const DASH_ON := 0.1
const DASH_OFF := 0.08
## The hint's ring, in cells.
const RING_R := 0.3

# --- the post (the mock's `postAt`, in units of its own R) ---
## The post's R, as a fraction of the cell.
const POST_R := 0.34
## Its halo: the one light on the board that is never out.
const POST_GLOW_AT := -0.3
const POST_GLOW_INNER := 0.3
const POST_GLOW_R := 2.3
const POST_GLOW_ALPHA := 0.3
const POST_SHADOW_ALPHA := 0.12
const POST_GLASS_ALPHA := 0.55

# --- the lantern (ui/faces/lantern_face.gd, exactly as Untangle ships it) ---
## A lantern's R, as a fraction of the cell. Its Control is R * SEAT square.
const LANTERN_R := 0.27

# --- this board's own motion constants (spec section 7) ---
## The quarter turn and one step of the wash per depth. They stand here
## because they are this board's signature and nothing in core/motion.gd
## would ever read them. **`WAVE_STEP` is not `Motion.WAVE_STEP`** (0.045):
## GDScript resolves the unqualified name to this script's own const, and
## this one is a step along a tree's depth rather than the king-move ring
## step that constant measures -- Word Trail's own WAVE_STEP stands apart for
## the same reason.
const TURN_TIME := 0.26
const WAVE_STEP := 0.05
## How long the win waits after the last lantern wakes.
const WIN_WAIT := 1.4
## How far a spinning piece pulls its arms in at the middle of the turn, so a
## long arm does not sweep through the cell next door on the way round. The
## mock's own 11%, and the one number the spin needs that no recipe has.
const ARM_PULL := 0.11
## How far into the spin the wash sets off. The light leaves before the piece
## has finished turning, so the two arrive together rather than in sequence.
const WASH_LAG := TURN_TIME * 0.55
## The first wash's own lead: it runs out from the post this long after the
## chrome has slid in, so the screen opens by showing where the power is.
const ENTER_WASH := 0.2
## The refusal's shiver, through the recipe's `px` parameter rather than a
## copied constant (rule 6): a cell here is 134 to 188 across, and the
## family's 2 px on a piece that wide is not a shiver, it is a rounding
## error. Four times it is the mock's own amplitude.
const REFUSE_PX := Motion.SHIVER_PX * 4.0
## A moment far enough in the future never to arrive, and one far enough in
## the past that every curve reader is already past the end of it.
const FAR := 1.0e9
const AGO := -1.0e9
## Three, as the mock's badge says (spec section 8). **The cap lives on the
## board and not on the state**, the way binairo2d.gd, bridges2d.gd and
## mushroom2d.gd keep theirs: the state counts the hints it gave, the board
## decides how many it may give.
const HINTS := 3

const TIP_CYCLE := 8.0
const TIPS := [
	"Tap a length of wire to turn it a quarter turn.",
	"The post in the middle is where the light comes from.",
	"Warm wire is live. Pale wire has not been reached yet.",
	"Done when every lantern is lit and no end is loose.",
]

## The one truth this board draws. Named `state` because tests/_win.gd
## reaches for `_puzzle.state` on every other board.
var state = State.new()

## The board's own effects node, as on every flat board: the hint's ring and
## sparkle come through it and nowhere else.
var fx: Node2D

## The grid's size, the name the win harness and the status line read.
var n: int:
	get: return state.n

var _cell := 0.0
## The grid's top-left corner inside this Control's rect.
var _grid := Vector2.ZERO
## One slot per lantern cell, with its paper inside it: {cell index -> slot}.
## Untangle's arrangement -- the slot owns the place, the paper owns what it
## is doing inside it, so a container can never fight a moving face.
var _slots: Dictionary = {}
var _lanterns: Dictionary = {}
## Which paper each lantern wears, settled once per board so a lantern does
## not change colour when it wakes.
var _hue: Dictionary = {}

## The wash's book, and all of it is *moments* rather than state: when cell
## `i` is allowed to be seen lit, when it is allowed to go dark, and when its
## lantern wakes. What is live is never in here -- see the header.
var _live_at: PackedFloat64Array = PackedFloat64Array()
var _out_at: PackedFloat64Array = PackedFloat64Array()
var _wake_at: PackedFloat64Array = PackedFloat64Array()
## The spin: when cell `i` began turning and how many quarters it is turning
## (negative anticlockwise, which is Undo).
var _spin_at: PackedFloat64Array = PackedFloat64Array()
var _spin_q: PackedInt32Array = PackedInt32Array()
## When cell `i` was last refused, which is when its shiver began.
var _refuse_at: PackedFloat64Array = PackedFloat64Array()
## Nothing on this card moves past this second. Every wave pushes it out
## through _busy_for, and _animating() reads it and nothing else.
var _anim_until := 0.0
## When the wash now running finishes and the last lantern it wakes has
## finished waking. win_delay() spends the same figure, so the win screen and
## the wash can never disagree about how long the wash is.
var _wash_end := 0.0
## Whether the last frame was a moving one, so the board can lay one final
## frame at rest rather than stopping wherever the clock left it.
var _moving := false

var _opened := 0.0
var _mesh: ArrayMesh
## The mesh the last _draw actually handed to the canvas item -- see the
## header. Never dropped until the next _draw has handed one over.
var _shown: ArrayMesh
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY
var _tip_idx := 0
var _tip_timer: Timer

func puzzle_id() -> String: return "fairylights"
func title() -> String: return "Fairy Lights"

func rules() -> String:
	return "Every cell of the garden holds one length of wire, and the lantern post stands in the middle. Tap a piece to turn it a quarter turn clockwise -- that is the only move, and four taps bring it back where it started. A cross is already every way round, so it will not turn. Wire joined all the way back to the post runs warm and gold; everything else is pale, and a stub that meets nothing stops short with a rounded end. The garden is done when every stub meets a stub and every lantern is lit. Nothing can be lost and nothing can be wrong, so there is no Check."

## Undo and Hint, and nothing else. There is no Check because nothing wrong
## can exist on this board: a garden is unfinished or it is done. So the
## registry drops the actions row and Reset rides up into the top bar --
## Untangle's and Word Trail's shape, reached by a third route.
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
	solved.connect(_on_solved)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	state.start(rng, difficulty)
	_clear_clocks()
	_hue = {}
	for i in state.lanterns():
		# Settled once, off the cell and the board, so a lantern keeps its
		# paper when it wakes and two boards of the same day agree.
		_hue[i] = posmod(hash(Vector2i(i, state.post * 31 + state.n)),
			Pal.LANTERN_PAPER.size())
	_build_lanterns()
	_layout()
	_enter()
	_tip_idx = 0
	_say(TIPS[0], Face.Expr.HAPPY)
	_tip_timer.start()

## Every clock on the board back to "has not happened yet". A cell that has
## never been lit waits FAR, so it is never seen lit; every other clock sits
## AGO, long enough ago that its curve reader hands back the resting value.
func _clear_clocks() -> void:
	var cells: int = maxi(0, state.n * state.n)
	_live_at = PackedFloat64Array()
	_live_at.resize(cells)
	_live_at.fill(FAR)
	_out_at = PackedFloat64Array()
	_out_at.resize(cells)
	_out_at.fill(AGO)
	_wake_at = PackedFloat64Array()
	_wake_at.resize(cells)
	_wake_at.fill(AGO)
	_spin_at = PackedFloat64Array()
	_spin_at.resize(cells)
	_spin_at.fill(AGO)
	_refuse_at = PackedFloat64Array()
	_refuse_at.resize(cells)
	_refuse_at.fill(AGO)
	_spin_q = PackedInt32Array()
	_spin_q.resize(cells)
	_spin_q.fill(0)
	_anim_until = 0.0
	_wash_end = 0.0
	_moving = false

# --- the cast ---

## One slot per degree-1 cell, with Untangle's paper lantern inside it. The
## slot stands on the cell's centre and the paper hangs in the middle of it,
## so a turn can spin the slot while the paper stays level (spec section 7);
## for now neither moves.
func _build_lanterns() -> void:
	for slot: Control in _slots.values():
		slot.queue_free()
	_slots = {}
	_lanterns = {}
	for i in state.lanterns():
		var slot := Control.new()
		slot.name = "slot_%d" % i
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		var lantern := LanternFace.new()
		lantern.name = "lantern_%d" % i
		lantern.hue = int(_hue.get(i, 0))
		lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# An unlit lantern is `plain`: no face at all. The face is what
		# waking up looks like, so a dark garden is quiet paper and no eyes.
		lantern.plain = true
		# And it is washed out (spec section 5: the paper pair 55% toward
		# STONE, its deep edge half-way to FLAGSTONE). A garden is mostly
		# unlit, so full-saturation paper would neither read as dark nor let
		# the gold be told from an unlit amber, which is this screen's one
		# job. `dims` is off everywhere else.
		lantern.dims = true
		slot.add_child(lantern)
		_slots[i] = slot
		_lanterns[i] = lantern

# --- layout ---

## The cell: a round `floor((card - 2 * INSET) / n)` with **no gap taken
## out** -- 188, 157 and 134 by band, the largest any flat board has asked
## for. The width binds at every band, as it does on Word Trail: seven
## columns is fewer than nine and the slot is tall.
func _cell_for(_available: float) -> float:
	if state.n <= 0:
		return 0.0
	return floorf(maxf(0.0, size.x - 2.0 * INSET) / float(state.n))

## The card this board wants: the grid and its two insets, and no more. The
## 344 the card does not want is halved into air above and below by the host
## -- Tents' and Queens' arrangement, not a new one.
func card_height(available: float) -> float:
	var cell := _cell_for(available)
	if cell <= 0.0:
		return available
	return minf(available, cell * float(state.n) + 2.0 * INSET)

func card_centred() -> bool:
	return true

func _layout() -> void:
	if state.n <= 0:
		return
	_cell = _cell_for(size.y)
	if _cell <= 0.0:
		return
	var span := _cell * float(state.n)
	# Centred in whatever height the card ended up with as well as across
	# it, so the grid is square in its card whether or not the host trimmed
	# the card to card_height().
	var tall := minf(size.y, span + 2.0 * INSET)
	_grid = Vector2(size.x * 0.5 - span * 0.5, (size.y - tall) * 0.5 + INSET)
	var seat: float = _cell * LANTERN_R * LanternFace.SEAT
	for i in _slots:
		var slot: Control = _slots[i]
		slot.position = cell_centre(i)
		var lantern: Control = _lanterns[i]
		lantern.size = Vector2.ONE * seat
		lantern.pivot_offset = lantern.size * 0.5
		lantern.position = -lantern.size * 0.5
	_refresh()

## The centre of cell `i`, in this Control's coordinates.
func cell_centre(i: int) -> Vector2:
	if state.n <= 0:
		return Vector2.ZERO
	return _grid + Vector2(float(i % state.n) + 0.5, float(i / state.n) + 0.5) * _cell

## Control-local point over the centre of cell (row, column) -- the name
## every flat board gives it, and the one the win harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	return cell_centre(r * state.n + c)

## The cell under a local point, or -1. The cells abut, so there is no alley
## to fall between: anything inside the grid belongs to exactly one cell.
func _cell_at(local: Vector2) -> int:
	if _cell <= 0.0 or state.n <= 0:
		return -1
	var p := (local - _grid) / _cell
	var c := int(floor(p.x))
	var r := int(floor(p.y))
	if c < 0 or r < 0 or c >= state.n or r >= state.n:
		return -1
	return r * state.n + c

# --- the frame ---

## While anything is moving the whole card is rebuilt every frame -- the
## spin, the shiver and the wash are all baked into the mesh -- and the
## lanterns are placed with it. The frame after the last wave ends is laid
## once more, so nothing is left a pixel out from wherever the clock stopped.
func _process(delta: float) -> void:
	super(delta)
	if _cell <= 0.0 or state.n <= 0:
		return
	var t := _now()
	if _animating(t):
		_moving = true
		_dress(t)
		_refresh()
	elif _moving:
		_moving = false
		_dress(t)
		_refresh()

## Whether anything on this card is still moving: the entrance, or a wave
## that has not run out yet. **Every** wave has to be accounted for here --
## One Line shipped two lines frozen at four fifths of a fade because one was
## left out, and it showed in a rendered frame and in no test. They are, and
## without a line each: the spin, the wash, a lantern waking, a refusal's
## shiver, Reset's stagger and the solve all end by pushing `_anim_until` out
## through `_busy_for`, so a wave added later is covered the moment it says
## how long it lasts.
func _animating(t: float) -> bool:
	if Motion.reduce:
		return false
	if t - _opened < Motion.ENTER_DELAY + Motion.ENTER_POP \
			+ Motion.ENTER_FACE_LAG + Motion.POP_IN:
		return true
	return t < _anim_until

## Keeps the card moving for `seconds` more. Nothing under reduce-motion,
## where there is nothing to wait for.
func _busy_for(seconds: float) -> void:
	if Motion.reduce:
		return
	_anim_until = maxf(_anim_until, _now() + seconds)

## Drops the mesh so the next _draw rebuilds it, and asks for that draw. The
## mesh the last _draw handed over is still held by _shown, so the renderer
## is never left pointing at a freed RID.
func _refresh() -> void:
	_mesh = null
	queue_redraw()

# --- the drawing ---

## One mesh, popped in wide about the grid's centre while it fades (rule 7:
## a wide thing comes from most of the way). The lanterns are Controls and
## draw themselves over it.
func _draw() -> void:
	if state.n <= 0 or _cell <= 0.0:
		return
	var now := _now()
	var since := now - _opened - Motion.ENTER_DELAY
	var seen := Motion.appear_level(since, Motion.ENTER_POP)
	if seen <= 0.0:
		return
	if _mesh == null:
		_mesh = _build(now)
	if _mesh == null:
		return
	var grow := Motion.wide_pop_scale(since)
	var mid := _grid + Vector2.ONE * (_cell * float(state.n) * 0.5)
	draw_mesh(_mesh, null,
		Transform2D(0.0, Vector2.ONE * grow, 0.0, mid * (1.0 - grow)),
		Color(1.0, 1.0, 1.0, seen))
	_shown = _mesh

## Everything on the board with no face on it, in the mock's own order, as it
## stands `t` seconds into whatever is moving.
func _build(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var span := _cell * float(state.n)
	# The fence, and the ground over it so only the rule shows round the edge.
	b.fan(Face.Builder.round_rect(_grid - Vector2.ONE * FENCE,
		Vector2.ONE * (span + 2.0 * FENCE), FENCE_RADIUS), Pal.GRID_RULE)
	b.fan(Face.Builder.round_rect(_grid, Vector2.ONE * span, GROUND_RADIUS),
		Pal.SURFACE.lerp(Pal.PARCHMENT, 0.5))
	var rule := Color(Pal.LINE, RULE_ALPHA)
	for k in range(1, state.n):
		var at := float(k) * _cell
		b.stroke(PackedVector2Array([_grid + Vector2(at, 0.0), _grid + Vector2(at, span)]),
			RULE_W, rule, false, false)
		b.stroke(PackedVector2Array([_grid + Vector2(0.0, at), _grid + Vector2(span, at)]),
			RULE_W, rule, false, false)
	var cells: int = state.n * state.n
	for i in cells:
		if state.pinned[i] == 1:
			_pin(b, i)
	# What is live, recomputed here and never kept; the wash only decides when
	# the eye is allowed to see it. One frame and one pull a cell, read once
	# and handed to every pass, so the halo, the shade, the face and the
	# sheen can never disagree about where a spinning piece is.
	var depths: PackedInt32Array = state.depths()
	var frames: Array[Transform2D] = []
	frames.resize(cells)
	var pulls := PackedFloat32Array()
	pulls.resize(cells)
	var live := PackedByteArray()
	live.resize(cells)
	for i in cells:
		frames[i] = _frame(i, t)
		pulls[i] = _spin_pull(i, t)
		live[i] = 1 if _shown_live(i, depths, t) else 0
	# The halo under every live run first: a live branch has to read as light
	# before it reads as cable, which it cannot do if the wire is under it.
	for i in cells:
		if live[i] == 0:
			continue
		_arms(b, i, frames[i], pulls[i], HALO_WIDE, Color(Pal.SUN_RAY, HALO_WIDE_ALPHA))
		_arms(b, i, frames[i], pulls[i], HALO_NEAR, Color(Pal.SUN, HALO_NEAR_ALPHA))
	# Then the wire: every shade first, then every face over the lot, so a
	# neighbour's shade never lands on this cell's cable.
	for pass_i in 2:
		for i in cells:
			var lit := live[i] == 1
			var shade := pass_i == 0
			var col: Color = (Pal.SUN_DEEP if lit else Pal.FLAGSTONE_DEEP) if shade \
				else (Pal.SUN if lit else Pal.FLAGSTONE)
			var drop := Vector2(0.0, SHADE_DROP) if shade else Vector2.ZERO
			_arms(b, i, frames[i], pulls[i], 1.0, col, drop)
			if Gen.degree(state.grid[i]) >= 3:
				b.disc(frames[i] * drop, _cell * WIRE * COLLAR, col)
			if not shade and lit:
				_arms(b, i, frames[i], pulls[i], SHEEN,
					Color(Pal.LANTERN_LIT, SHEEN_ALPHA))
	# The post stands level however its own cell is turning, the way a lantern
	# does: it takes the cell's place, not the cell's turn.
	_post(b, frames[state.post].origin)
	return b.mesh() if not b.verts.is_empty() else null

## Cell `i`'s arms in its own `frame`, `weight` times the wire's width and
## `pull` of their full length, offset by `drop`. An arm runs from the cell's
## middle to its edge when it meets a stub on the other side and stops at
## LOOSE of the way with a round cap when it does not -- which is the whole
## of "a loose end looks loose". The drop rides inside the frame, as the
## mock's own `translate(0, 4)` does, so a piece's lip turns with it.
func _arms(b, i: int, frame: Transform2D, pull: float, weight: float,
		colour: Color, drop := Vector2.ZERO) -> void:
	var m: int = state.grid[i]
	if m == 0:
		return
	var mid := frame * drop
	var half := _cell * 0.5
	for d in 4:
		if m & (1 << d) == 0:
			continue
		var reach := (half if state.matched(i, 1 << d) else half * LOOSE) * pull
		var out := Vector2(float(Gen.DC[d]), float(Gen.DR[d])) * reach
		b.stroke(PackedVector2Array([mid, frame * (drop + out)]),
			_cell * WIRE * weight, colour)

# --- the spin, and the wash behind it ---

## Where cell `i` stands and how far round it is, `t` seconds in: its centre,
## shifted by whatever a refusal is shaking out of it, turned by the spin.
## One frame, read by every pass of the build and by the lantern in its slot.
func _frame(i: int, t: float) -> Transform2D:
	var at := cell_centre(i)
	at.x += Motion.shiver_offset(t - _refuse_at[i], REFUSE_PX)
	return Transform2D(_spin_angle(i, t), at)

## How far cell `i` still has to turn, `t` seconds in. The piece is already
## where the turn put it, so the angle runs from a quarter turn *behind* (or
## ahead, for an anticlockwise undo) home to nothing on `back_out`'s
## overshoot. A spin of several quarters -- a hint's -- takes proportionally
## longer, so the piece does not blur. Zero before it begins, which is what
## lets Reset set every piece spinning at a moment of its own.
func _spin_angle(i: int, t: float) -> float:
	var q: int = _spin_q[i]
	if Motion.reduce or q == 0:
		return 0.0
	var u := clampf((t - _spin_at[i]) / _spin_time(q), 0.0, 1.0)
	if u >= 1.0:
		return 0.0
	return -float(q) * (PI * 0.5) * (1.0 - Motion.back_out(u))

## How far cell `i`'s arms are pulled in, `t` seconds in: ARM_PULL at the
## middle of the turn and nothing at either end, so a full-length arm never
## sweeps through the piece next door.
func _spin_pull(i: int, t: float) -> float:
	if Motion.reduce or _spin_q[i] == 0:
		return 1.0
	var u := clampf((t - _spin_at[i]) / TURN_TIME, 0.0, 1.0)
	if u >= 1.0:
		return 1.0
	return 1.0 - ARM_PULL * sin(PI * u)

static func _spin_time(q: int) -> float:
	return TURN_TIME * (0.7 * maxf(1.0, float(absi(q))) + 0.3)

## Sets cell `i` spinning `q` quarters (negative anticlockwise) from `at`, and
## keeps the card alive until it lands. Nothing under reduce-motion: the
## piece is simply round the other way.
func _spin(i: int, q: int, at: float) -> void:
	if Motion.reduce or q == 0:
		return
	_spin_at[i] = at
	_spin_q[i] = q
	_busy_for(at - _now() + _spin_time(q))

## Whether cell `i` may be *seen* lit at `t`. `depths` is the truth, computed
## fresh by the caller; the moment is only the wash's permission to show it.
## A cell that is live waits for the light to reach it; a cell that has been
## cut off keeps its light until the wave pulls it back.
func _shown_live(i: int, depths: PackedInt32Array, t: float) -> bool:
	if depths[i] >= 0:
		return t >= _live_at[i]
	return t < _out_at[i]

## One step of the wash, or none at all under reduce-motion, where the whole
## live set changes in one frame.
func _step(rings: int) -> float:
	return 0.0 if Motion.reduce else float(maxi(0, rings)) * WAVE_STEP

## How far into a spin the wash sets off, from now.
func _lag() -> float:
	return 0.0 if Motion.reduce else WASH_LAG

## **The wash.** `before` is `state.depths()` as it stood *before* the move;
## the state now holds the move's result. Every cell whose reachability
## changed takes a moment from `at`: a cell just reached lights its own depth
## in steps later, so the light walks out along the wire from the post; a cell
## just cut off goes dark on the same wave **reversed**, the far end first, so
## the light reads as pulled back down the branch rather than switched off.
## Queens' `_settle` with the tree's own depth in place of a queen's sight.
## Nothing derived is stored: only the moments, and the truth is read fresh
## wherever it is wanted.
func _settle(before: PackedInt32Array, at: float) -> void:
	var now_d: PackedInt32Array = state.depths()
	var cells: int = state.n * state.n
	# The far end of what *was* live, which is where a cut-off branch starts
	# going dark from.
	var far := 0
	for i in cells:
		if before[i] > far:
			far = before[i]
	var lanterns: Dictionary = {}
	for i in state.lanterns():
		lanterns[i] = true
	var last := at
	for i in cells:
		var was := before[i] >= 0
		var is_live := now_d[i] >= 0
		if is_live == was:
			continue
		var moment := at + (_step(now_d[i]) if is_live else _step(far - before[i]))
		if is_live:
			_live_at[i] = moment
			if lanterns.has(i):
				# The lantern wakes as the wash reaches it, and its face
				# arrives with the bump: seventeen of them in a ripple rather
				# than together, because each is on its own depth.
				_wake_at[i] = moment
				last = maxf(last, moment + Motion.BUMP_TIME)
		else:
			_out_at[i] = moment
		last = maxf(last, moment)
	# **Never behind a wash still in flight.** `last` covers only the cells
	# *this* settle changed, so a move that changes nothing (a turn on an
	# isolated piece, most of a Reset's stagger) would otherwise drop
	# `_wash_end` back to `at` while a longer wash is still running -- and
	# `win_delay()` and `_on_solved()` both spend this figure as the wash's
	# whole length. Task 4's review measured it behind on 2,757 of 2,880
	# settles, worst by 0.84 s. It only ever grows within a deal;
	# `_clear_clocks()` puts it back to zero when a new board is dealt, and a
	# wash whose end is in the past costs nothing, both readers taking
	# `maxf(0.0, _wash_end - now)`.
	_wash_end = maxf(_wash_end, last)
	_busy_for(last - _now())

## A pinned cell reads as a given, in the language every board in this game
## uses: a pale sun wash under a dotted ring. Word Trail's hint mark.
func _pin(b, i: int) -> void:
	var at := cell_centre(i) - Vector2.ONE * (_cell * 0.5)
	b.fan(Face.Builder.round_rect(at + Vector2.ONE * PIN_INSET,
		Vector2.ONE * (_cell - 2.0 * PIN_INSET), _cell * PIN_RADIUS),
		Color(Pal.SUN_RAY, PIN_ALPHA))
	var ring := Face.Builder.round_rect(at + Vector2.ONE * DASH_INSET,
		Vector2.ONE * (_cell - 2.0 * DASH_INSET), _cell * DASH_RADIUS)
	for dash in _dashes(ring, _cell * DASH_ON, _cell * DASH_OFF):
		b.stroke(dash as PackedVector2Array, DASH_W, Pal.SUN_DEEP)

## The closed outline `pts` cut into dashes of `on` with `off` between them.
## Word Trail's own, which is the mock's `setLineDash`.
static func _dashes(pts: PackedVector2Array, on: float, off: float) -> Array:
	var out: Array = []
	if pts.size() < 2 or on <= 0.0 or off <= 0.0:
		return out
	var cur := PackedVector2Array([pts[0]])
	var lit := true
	var spent := 0.0
	for i in pts.size():
		var a := pts[i]
		var z := pts[(i + 1) % pts.size()]
		var span := a.distance_to(z)
		if span <= 0.001:
			continue
		var walked := 0.0
		while walked < span:
			# Never zero: a dash that ended exactly on a corner would other-
			# wise walk nowhere for ever.
			var want := maxf((on if lit else off) - spent, 0.001)
			if walked + want >= span:
				spent += span - walked
				walked = span
				if lit:
					cur.append(z)
			else:
				walked += want
				var p := a.lerp(z, walked / span)
				if lit:
					cur.append(p)
					if cur.size() >= 2:
						out.append(cur)
					cur = PackedVector2Array()
				else:
					cur = PackedVector2Array([p])
				lit = not lit
				spent = 0.0
	if lit and cur.size() >= 2:
		out.append(cur)
	return out

## The post: the one thing on the board that is never paper and never dark.
## Light Up's `LANTERN` iron, a sun in the glass, and a halo that is always
## on. It has no face, so it is drawn into this mesh rather than seated as a
## Control -- see the header.
func _post(b, at: Vector2) -> void:
	var R := _cell * POST_R
	b.ellipse(at + Vector2(0.0, 1.02) * R, 0.8 * R, 0.2 * R,
		Color(Pal.TEXT, POST_SHADOW_ALPHA))
	_halo(b, at + Vector2(0.0, POST_GLOW_AT) * R, POST_GLOW_INNER * R,
		POST_GLOW_R * R, Color(Pal.SUN, POST_GLOW_ALPHA))
	var iron: Color = Pal.LANTERN
	b.fan(Face.Builder.round_rect(at + Vector2(-0.46, 0.76) * R,
		Vector2(0.92, 0.22) * R, 0.1 * R), iron)
	b.fan(Face.Builder.round_rect(at + Vector2(-0.13, -0.1) * R,
		Vector2(0.26, 0.96) * R, 0.06 * R), iron)
	b.disc(at + Vector2(0.0, -0.42) * R, 0.52 * R, Pal.SUN_DEEP)
	b.disc(at + Vector2(0.0, -0.46) * R, 0.46 * R, Pal.SUN)
	b.disc(at + Vector2(-0.1, -0.56) * R, 0.2 * R,
		Color(Pal.LANTERN_LIT, POST_GLASS_ALPHA))
	b.fan(Face.Builder.round_rect(at + Vector2(-0.34, -1.08) * R,
		Vector2(0.68, 0.24) * R, 0.1 * R), iron)
	b.fan(Face.Builder.round_rect(at + Vector2(-0.08, -1.28) * R,
		Vector2(0.16, 0.24) * R, 0.06 * R), iron)

## A disc of light at `inner` fading to nothing at `outer`, built as two
## rings and the band between them -- what a canvas radial gradient comes to
## once it is triangles. `ui/faces/lantern_face.gd`'s own halo, in the
## board's coordinates rather than a face's.
func _halo(b, at: Vector2, inner: float, outer: float, warm: Color) -> void:
	if warm.a <= 0.0:
		return
	var clear := Color(warm, 0.0)
	var segments: int = LanternFace.GLOW_SEGMENTS
	var centre: int = b.vertex(at, warm)
	var ring_i: int = b.verts.size()
	for i in segments:
		b.vertex(at + Vector2.from_angle(TAU * i / segments) * inner, warm)
	var ring_o: int = b.verts.size()
	for i in segments:
		b.vertex(at + Vector2.from_angle(TAU * i / segments) * outer, clear)
	for i in segments:
		var j := (i + 1) % segments
		b.tri(centre, ring_i + i, ring_i + j)
		b.tri(ring_i + i, ring_o + i, ring_o + j)
		b.tri(ring_i + i, ring_o + j, ring_i + j)

## What each lantern is wearing and where it is standing at `t`: lit and
## smiling once the wash has reached its cell, plain paper while it has not.
## `lit` is snapped to five levels before it reaches the mesh cache, so
## seventeen lanterns cost at most five meshes a paper.
##
## **The slot takes the cell's frame and the paper counter-turns inside it.**
## The slot carries the shiver, the quarter turn and the wake's bump; the
## paper carries the entrance's own pop (a tween) and the turn back, so the
## two hands never write the same property (rule 2) and a hanging thing never
## cartwheels (spec section 7).
func _dress(t: float) -> void:
	if state.n <= 0:
		return
	var depths: PackedInt32Array = state.depths()
	var done := is_done()
	for i in _lanterns:
		var lantern: LanternFace = _lanterns[i]
		var slot: Control = _slots[i]
		var live := _shown_live(i, depths, t)
		var want := 1.0 if live else 0.0
		if lantern.lit != want:
			lantern.lit = want
			# A lit paper is alive and blinks on a clock of its own; an
			# unlit one is plain paper with no eyes to blink. set_idle does
			# nothing under reduce-motion.
			lantern.set_idle(live)
		if lantern.plain != (not live):
			lantern.plain = not live
		var expr := Face.Expr.JOY if done else Face.Expr.HAPPY
		if live and lantern.expression != expr:
			lantern.expression = expr
		var frame := _frame(i, t)
		slot.position = frame.origin
		slot.rotation = frame.get_rotation()
		slot.scale = Vector2.ONE * (Motion.bump_scale(t - _wake_at[i]) if live else 1.0)
		lantern.rotation = -slot.rotation

# --- the moments ---

## The chrome is the host's. The grid's own entrance is one wide pop about
## its centre while it fades in (rule 7), read off the clock in _draw, and
## the lanterns pop in on their cells a beat after it. Then the first wash
## runs out from the post, so the screen opens by showing where the power is
## (spec section 7) -- settled against an all-dark board, which is what makes
## every reached cell a cell "just reached".
func _enter() -> void:
	_opened = _now()
	fx.cue("enter")
	for i in _lanterns:
		Motion.pop_in(_lanterns[i], Motion.POP_IN,
			Motion.ENTER_DELAY + Motion.ENTER_POP + Motion.ENTER_FACE_LAG)
	var dark := PackedInt32Array()
	dark.resize(state.n * state.n)
	dark.fill(-1)
	_settle(dark, _opened + (0.0 if Motion.reduce else Motion.ENTER_DELAY + ENTER_WASH))
	_dress(_now())
	_refresh()

# --- input ---

## One tap, one quarter turn clockwise, and nothing else on the screen. No
## drag, no long press and no second direction.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	if event.pressed:
		return
	var i := _cell_at(event.position)
	if i < 0:
		return
	accept_event()
	_turn(i)

## A tap on cell `i`. A cross is already every way round and a pinned cell is
## a given: neither turns, and a refusal is a line from the sprout and never
## a silence (Hidden Word's rule).
func _turn(i: int) -> void:
	# Taken before the move: what the wash diffs against, and a local of this
	# move rather than anything the board keeps.
	var before: PackedInt32Array = state.depths()
	var now := _now()
	match state.turn(i):
		State.PINNED:
			_refuse(i, now, "A hint pinned that one where it belongs.")
			return
		State.CROSS:
			_refuse(i, now, "A cross is already every way round.")
			return
	fx.cue("place")
	_spin(i, 1, now)
	_settle(before, now + _lag())
	_dress(now)
	_refresh()
	_speak()
	# note_move() counts the turn and ends the board if that was the last
	# loose end; the host raises the win screen after win_delay().
	note_move()

## A move the rules will not take: the piece shivers where it stands and the
## sprout says why, because a refusal is never a silence. Nothing else on
## this board can refuse.
func _refuse(i: int, now: float, line: String) -> void:
	_say(line, Face.Expr.PUZZLED)
	fx.cue("refuse")
	if Motion.reduce:
		return
	_refuse_at[i] = now
	_busy_for(Motion.SHIVER_TIME)

# --- the sprout's line ---

## What is left to do, in the mock's own words: the loose ends first, because
## while there is one the board cannot be finished, and the dark cells after,
## because once there are none it is.
func _left_line() -> String:
	var loose := 0
	var dark := 0
	var depths: PackedInt32Array = state.depths()
	for i in state.n * state.n:
		loose += _bits(state.loose(i))
		if depths[i] < 0:
			dark += 1
	if loose == 0:
		return "No loose ends left -- now reach them all."
	return "One lantern still in the dark." if dark == 1 else "%d still in the dark." % dark

static func _bits(m: int) -> int:
	return (m & 1) + ((m >> 1) & 1) + ((m >> 2) & 1) + ((m >> 3) & 1)

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
	if is_done() or _tip_mood != Face.Expr.HAPPY or state.turns > 0:
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_say(TIPS[_tip_idx], Face.Expr.HAPPY)

## The sprout's own line, rather than Binairo's cycle of broken rules.
func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

# --- the HUD's actions ---

func can_undo() -> bool:
	return not state.history.is_empty()

## Turns the last tapped piece back a quarter turn, in tap order. Counts no
## move, and the wash comes back with it for free -- live is derived, so
## there is no highlight to put back.
func undo() -> bool:
	if is_done() or state.history.is_empty():
		return false
	var before: PackedInt32Array = state.depths()
	var i := state.undo()
	if i < 0:
		return false
	# The same spin the other way round, and the wash runs backwards behind
	# it for free: the diff is symmetric, so a branch that was reached goes
	# dark from its far end exactly as it lit from the post.
	var now := _now()
	_spin(i, -1, now)
	_settle(before, now + _lag())
	_dress(now)
	_refresh()
	_say("Turned back. " + _left_line(), Face.Expr.HAPPY)
	fx.cue("undo")
	moved.emit()
	return true

## Three of them, and the cap is this board's rather than the state's -- the
## state counts what it gave, the board decides how much it may give.
func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Turns the first unsolved cell in reading order to its proven orientation
## and pins it there, so it can never be turned again. Reading order rather
## than anything cleverer, for Word Trail's reason: it is predictable, it
## needs no state, and a hint that guesses what the player wanted can guess
## wrong. A hint also empties the undo log (Shikaku's rule) -- what it
## settled is not a move to take back.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var before: PackedInt32Array = state.depths()
	var grid_before: PackedInt32Array = state.grid.duplicate()
	# -1 is every cell already where the answer wants it. Nothing is spent
	# and nothing is rung: there was no hint to give.
	var at := state.hint()
	if at < 0:
		return false
	hints_used += 1
	var now := _now()
	# However many quarters it needs, in one spin rather than a stutter of
	# them -- the piece turns straight to where the solver proved it goes.
	_spin(at, _quarters(grid_before[at], state.grid[at]), now)
	_settle(before, now + _lag())
	fx.ring(cell_centre(at), _cell * RING_R, Pal.LEAF)
	fx.cue("hint")
	_dress(now)
	_refresh()
	_say("Pinned. That one could only go one way.", Face.Expr.HAPPY)
	moved.emit()
	# A hint can finish the garden, and a finished garden is a win however it
	# was reached.
	check_solved()
	return true

## Every unpinned piece back to the scramble it was dealt. A pinned piece
## stays, because a hint is a given.
func reset_board() -> void:
	var before: PackedInt32Array = state.depths()
	var grid_before: PackedInt32Array = state.grid.duplicate()
	state.reset_board()
	var now := _now()
	# Every piece that moved turns back at once, on the family's corner-out
	# stagger: a cell goes its row plus its column steps after the top-left
	# one. A pinned piece is a given and never moves, so it never spins.
	for i in state.n * state.n:
		if state.pinned[i] == 0 and grid_before[i] != state.grid[i]:
			var wait := 0.0 if Motion.reduce else Motion.stagger(
				i / state.n + i % state.n, Motion.RESET_STAGGER)
			_spin(i, 1, now + wait)
	moves = 0
	_running = true
	_settle(before, now + _lag())
	_dress(now)
	_refresh()
	_say("A fresh tangle. " + _left_line(), Face.Expr.HAPPY)
	fx.cue("reset")

## How many quarter turns clockwise take `from` to `to`; 0 if it is already
## there (which is a hint that only pinned a cell, and spins nothing).
static func _quarters(from: int, to: int) -> int:
	var m := from
	for q in 4:
		if m == to:
			return q
		m = Gen.cw(m)
	return 0

## Solved is the rule and never the answer: every stub meets a stub and every
## cell is live. The `state.n > 0` guard is what keeps an unstarted board
## from reporting itself finished -- both of the state's loops run over no
## cells at all and come back true.
func is_solved() -> bool:
	return state.n > 0 and state.is_solved()

## One glyph a lantern, so a shared board shows how big the garden was and
## never how it was wired.
func share_glyphs() -> String:
	return "🏮".repeat(state.lanterns().size())

# --- the win ---

## Five lit paper lanterns laid across the win screen -- this board's own
## cast, which is the lanterns. `ui/flat/well_done.gd` lays a cast of faces
## and draws no cord, so the cord the mock strings between them is not
## shipped and nobody edits `well_done.gd` for it.
func flat_win() -> Dictionary:
	var faces: Array[Control] = []
	for i in Pal.LANTERN_PAPER.size():
		var lantern := LanternFace.new()
		lantern.hue = i
		lantern.lit = 1.0
		faces.append(lantern)
	return {"faces": faces, "subtitle": "Every lantern is lit."}

## Long enough for the last wash to finish and every lantern to wake, and
## WIN_WAIT after that. It spends the wash's own clock (`_wash_end`, set by
## `_settle`), so the win screen and the wash can never disagree about how
## long the wash is -- Bridges' arrangement. Under reduce-motion there is no
## wash, so the win follows the last turn.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return maxf(0.0, _wash_end - _now()) + WIN_WAIT

## The garden is lit. There is no solve wave of its own here: the wash that
## won it *is* the wave, running out from the post over the branch the last
## turn joined, and every lantern grins as it arrives. The card stays alive
## until the last of them has woken.
func _on_solved() -> void:
	_tip_timer.stop()
	_dress(_now())
	_refresh()
	_say("Every lantern is lit.", Face.Expr.JOY)
	fx.cue("solved")
	_busy_for(maxf(0.0, _wash_end - _now()) + Motion.BUMP_TIME)

# --- odds and ends ---

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
