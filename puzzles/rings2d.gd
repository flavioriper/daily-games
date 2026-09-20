extends "res://core/puzzle_base.gd"

## Rings as a flat board: eight pegs standing in two rows, twenty-four rings
## dealt three to a peg, and a pale post standing proud of every stack. Lift
## the top ring off a peg and set it down on an empty peg or on a ring of its
## own colour; the rules live in puzzles/rings_state.gd and the deal and its
## proof in puzzles/rings_gen.gd, which this only draws.
##
## **This file draws the board standing still.** The layout, the mesh and the
## registry entry are this task's whole job; lifting, dropping, Undo, Hint,
## Reset and the stuck toast are a later one, on top of this frame. That is
## why capabilities() already advertises "undo" and "hint" while nothing here
## answers either yet -- the base class's defaults (can_undo() false,
## hint() false) are exactly right for a board with no moves logged.
##
## How it is drawn. One mesh: the pegs at rest (their shadow, post, dish and
## rings, bottom-up) and the scenery band at the card's foot, rebuilt in
## _draw while the entrance is still running and kept in _shown until the
## next one replaces it (a canvas command holds a mesh by RID, and a harness
## that calls force_draw() without that photographs a freed one). A station's
## own entrance -- the drop from Motion.DROP above, staggered a peg apart --
## is baked straight into that station's vertices rather than played on a
## node, because Word Trail's and Queens' pieces are drawn rather than built
## of Controls; the whole board's own wide pop about its centre is baked the
## same way, scaling every station's already-offset points toward the
## board's middle.
##
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md, sections 1,
## 4 and 5. Concept page: docs/brainstorm/concepts.html#rings, whose
## drawRing, drawPost, drawStation, scenery, station and slotY are the shapes
## ported here number for number.

const State = preload("res://puzzles/rings_state.gd")
const Gen = preload("res://puzzles/rings_gen.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")

# --- the screen, measured (spec section 4) ---
## The card's inset, and the station a peg stands in.
const INSET := 28.0
const STATION_W := 236.0
const RING_W := 200.0
const RING_H := 92.0
const RING_GAP := 6.0
const POST_W := 30.0
## How far the post stands proud of a **full** stack. It is what tells a player
## at a glance that a peg of three has room for one more.
const POST_UP := 48.0
const BASE_W := 182.0
const BASE_H := 30.0
## CAP * (RING_H + RING_GAP) - RING_GAP, and BASE_H + STACK_H + POST_UP. Written
## out because a `const` initialised from another script's constant does not
## always fold in GDScript; if `Gen.CAP * ...` compiles, prefer the expression.
const STACK_H := 386.0
const STATION_H := 464.0
## The air over the top row is the lift's, not a taste: a ring in hand hovers
## LIFT_H over the post, so anything less and a held ring hangs out of the
## card. Found by shooting the concept tab with a ring up, not by reading it.
const TOP_AIR := 96.0
const MID_GAP := 96.0

# --- this board's own six (spec section 5); everything else the board reads
# is a recipe or a curve reader off core/motion.gd. None of the six is used
# yet -- lifting, dropping and the toast are a later task -- and they are
# declared here so that task adds behaviour and not arithmetic. ---
## How far a lifted ring floats over its post.
const LIFT_H := 40.0
## Its idle breath while it waits to be put down, and how long a breath takes.
const BOB := 5.0
const BOB_CYCLE := 1.9
## The flight from one peg to another.
const ARC_TIME := 0.34
## The little arch it makes on the way.
const ARC_LIFT := 26.0
## How long "Nothing can move" stays up.
const TOAST_HOLD := 2.6
## The customary win wait: every board that plays a solve wave keeps its own
## copy of this name and this number.
const WIN_WAIT := 1.4

## The card's own rounded rect, so the scenery band -- which is cut off flush
## with the card's edges, not inset like a board's usual field -- can be
## clipped to it rather than showing square corners past the round panel.
## Matches ui/flat/flat_host.gd's own board card stylebox radius.
const CARD_RADIUS := 32.0

## The ring colours and the pip count each one wears. core/palette.gd says it
## about Code Break's pegs -- "every peg also carries a pip mark, so colour
## never stands alone" -- and a game whose whole mechanic is matching colour is
## the game that rule was written for. A player who cannot tell the coral from
## the tan can still count.
const RING_COLOURS := [Pal.BERRY, Pal.SUN, Pal.MOON_INK, Pal.ACORN, Pal.FLOWER, Pal.ACCENT]

## One coloured square per ring colour, in RING_COLOURS' own order, for
## share_glyphs() -- the same language Word Trail's green squares speak.
const SHARE_GLYPHS := ["🟥", "🟨", "🟦", "🟫", "🟪", "🟩"]

const TIP_CYCLE := 8.0
const TIPS := [
	"Tap a peg to lift its top ring.",
	"A ring lands on its own colour, or on an empty peg.",
	"Four of a colour fills a peg, and it locks.",
	"Nothing is ever lost here. Undo is right above.",
]

var _state = State.new()

var _opened := 0.0
## The two rows' top y, set by _layout() and read by _station().
var _row_y: Array[float] = [0.0, 0.0]
var _inner_x := 0.0
var _inner_w := 0.0

## The pegs, dishes, rings at rest and the scenery band, one mesh, rebuilt
## whenever the entrance is still running.
var _mesh: ArrayMesh
## The mesh the last _draw actually handed to the canvas item -- kept so a
## harness's force_draw() never draws a freed RID.
var _shown: Array = []

var _tip_timer: Timer
var _tip_idx := 0
var _tip_text := ""
var _tip_mood := Face.Expr.HAPPY

func puzzle_id() -> String: return "rings"
func title() -> String: return "Rings"

func rules() -> String:
	return "Lift the top ring off any peg and set it down on an empty peg or on a ring of its own colour -- nowhere else. Four rings of the same colour fill a peg, and a peg that full locks: nothing ever comes off it again. Nothing here is ever lost, so play freely -- Undo and Reset are always one tap away. The board is done the moment every colour stands alone on a peg of its own."

func capabilities() -> Array[String]:
	return ["undo", "hint"]

func card_height(available: float) -> float:
	return available

## False, and honestly so: card_height() hands back everything it is given, so
## there is no slack to centre.
func card_centred() -> bool:
	return false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_CYCLE
	_tip_timer.timeout.connect(_cycle_tip)
	add_child(_tip_timer)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_state.build(rng, difficulty)
	_layout()
	_enter()
	_tip_idx = 0
	_tip_text = TIPS[0]
	_tip_mood = Face.Expr.HAPPY
	_tip_timer.start()

# --- layout ---

## Rows of four at the hard band, four and three at the medium one, three and
## three at the easy one.
static func _rows_of(peg_count: int) -> Array:
	if peg_count <= 6:
		return [int(ceil(peg_count / 2.0)), int(floor(peg_count / 2.0))]
	return [4, peg_count - 4]

func _layout() -> void:
	_inner_x = INSET
	_inner_w = size.x - 2.0 * INSET
	var r0 := INSET + TOP_AIR
	var r1 := r0 + STATION_H + MID_GAP
	_row_y = [r0, r1]
	_refresh()

## Where peg `i` stands: a short row is centred, so a station is 236 wide and
## a ring 200 whatever the band.
func _station(i: int) -> Dictionary:
	var counts := _rows_of(_state.pegs.size())
	var a: int = counts[0]
	var row := 0 if i < a else 1
	var k := i if row == 0 else i - a
	var n := a if row == 0 else int(counts[1])
	var x := _inner_x + (_inner_w - float(n) * STATION_W) * 0.5 + float(k) * STATION_W
	return {"row": row, "x": x, "cx": x + STATION_W * 0.5, "top": _row_y[row], "ground": _row_y[row] + STATION_H}

## The centre of slot `k` of station `st` (bottom slot is 0).
func _slot_y(st: Dictionary, k: int) -> float:
	return float(st["ground"]) - BASE_H - RING_H * 0.5 - float(k) * (RING_H + RING_GAP)

# --- the frame ---

func _process(delta: float) -> void:
	super(delta)
	if _state.pegs.is_empty():
		return
	if _animating(_now()):
		_refresh()

## The only thing moving yet is the entrance: the card's wide pop, then the
## last station's own staggered drop.
func _animating(t: float) -> bool:
	if Motion.reduce:
		return false
	var entrance := Motion.ENTER_DELAY \
		+ Motion.stagger(maxi(_state.pegs.size() - 1, 0), Motion.ENTER_STAGGER) \
		+ Motion.DROP_TIME
	return t - _opened < entrance

func _refresh() -> void:
	_mesh = null
	queue_redraw()

func _enter() -> void:
	_opened = _now()
	_refresh()

func _draw() -> void:
	if _state.pegs.is_empty():
		return
	var t := _now()
	if _mesh == null:
		_mesh = _build_mesh(t)
	if _mesh != null:
		draw_mesh(_mesh, null)
	_shown = [_mesh]

# --- the mesh ---

func _build_mesh(t: float) -> ArrayMesh:
	var b := Face.Builder.new()
	_build_band(b)
	if not _state.pegs.is_empty():
		var centre := Vector2(size.x * 0.5, (_row_y[0] + _row_y[1] + STATION_H) * 0.5)
		var wide := 1.0
		if not Motion.reduce:
			wide = Motion.wide_pop_scale(t - _opened - Motion.ENTER_DELAY)
		for i in _state.pegs.size():
			_build_station(b, i, t, centre, wide)
	return b.mesh() if not b.verts.is_empty() else null

## One station: the seat shadow, the post (drawn only from its top down to
## the top ring's centre, or to the dish when the peg is empty), the dish,
## then the rings bottom-up. `map` carries this station's own entrance --
## the drop from above and the board's wide pop about `centre` -- into every
## point drawn for it.
func _build_station(b, i: int, t: float, centre: Vector2, wide: float) -> void:
	var st := _station(i)
	var since := t - _opened - Motion.ENTER_DELAY - Motion.stagger(i, Motion.ENTER_STAGGER)
	var seen := 1.0
	var lift := 0.0
	if not Motion.reduce:
		seen = Motion.appear_level(since)
		lift = Motion.drop_in_lift(since)
	if seen <= 0.0:
		return
	var map := func(p: Vector2) -> Vector2:
		return centre + ((p - Vector2(0.0, lift)) - centre) * wide

	var cx: float = st["cx"]
	var ground: float = st["ground"]
	var pegs: Array = _state.pegs[i]

	_fan_mapped(b, Face.Builder.ring(Vector2(cx, ground - 2.0), BASE_W * 0.58, 13.0),
		Color(Pal.TEXT, 0.08 * seen), map)

	var top_y := _slot_y(st, Gen.CAP - 1) - RING_H * 0.5 - POST_UP
	var bot_y := _slot_y(st, pegs.size() - 1) if not pegs.is_empty() else ground - BASE_H + 6.0
	var post: Color = Pal.CHEEK.lerp(Pal.SURFACE, 0.62)
	var post_deep: Color = Pal.CHEEK.lerp(Pal.TEXT, 0.18)
	_slab_mapped(b, Vector2(cx - POST_W * 0.5, top_y), Vector2(POST_W, bot_y - top_y), POST_W * 0.5, 5.0,
		Color(post, seen), Color(post_deep, seen), map)
	var post_hi: Color = post.lerp(Color.WHITE, 0.55)
	_fan_mapped(b, Face.Builder.round_rect(Vector2(cx - POST_W * 0.22, top_y + 8.0),
			Vector2(POST_W * 0.2, maxf(bot_y - top_y - 22.0, 0.0)), POST_W * 0.1),
		Color(post_hi, 0.75 * seen), map)

	_slab_mapped(b, Vector2(cx - BASE_W * 0.5, ground - BASE_H), Vector2(BASE_W, BASE_H), BASE_H * 0.5, 7.0,
		Color(Pal.SURFACE_HI, seen), Color(Pal.LINE, seen), map)

	for k in pegs.size():
		var colour_i: int = pegs[k]
		_append_ring(b, cx, _slot_y(st, k), RING_W, RING_H, RING_COLOURS[colour_i], colour_i + 1, seen, map)

## A rounded card of `box` at `at`: a rim colour under a face colour inset by
## `edge` at the bottom, the soft lip every card on these screens wears.
static func _slab_mapped(b, at: Vector2, box: Vector2, r: float, edge: float,
		face: Color, rim: Color, map: Callable) -> void:
	_fan_mapped(b, Face.Builder.round_rect(at, box, r), rim, map)
	_fan_mapped(b, Face.Builder.round_rect(at, Vector2(box.x, maxf(box.y - edge, 0.0)), r), face, map)

## One ring, `ring_w` by `ring_h`, centred on (cx, cy): the face, its bottom
## rim, the shoulder highlight, the post's dimple and its pips (spec
## section 4's table, ported number for number off drawRing).
static func _append_ring(b, cx: float, cy: float, ring_w: float, ring_h: float,
		colour: Color, pips: int, alpha: float, map: Callable) -> void:
	var face := colour
	var rim := colour.lerp(Pal.TEXT, 0.22)
	var edge := ring_h * (9.0 / 92.0)
	var at := Vector2(cx - ring_w * 0.5, cy - ring_h * 0.5)
	_fan_mapped(b, Face.Builder.round_rect(at, Vector2(ring_w, ring_h), ring_h * 0.5), Color(rim, alpha), map)
	_fan_mapped(b, Face.Builder.round_rect(at, Vector2(ring_w, maxf(ring_h - edge, 0.0)), ring_h * 0.5),
		Color(face, alpha), map)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx - ring_w * 0.22, cy - ring_h * 0.26), ring_w * 0.17, ring_h * 0.11),
		Color(Color.WHITE, 0.26 * alpha), map)
	var dimple := face.lerp(Pal.TEXT, 0.30)
	var post_w := ring_w * (POST_W / RING_W)
	_fan_mapped(b, Face.Builder.ring(Vector2(cx, cy - ring_h * 0.21), post_w * 0.56, ring_h * 0.10),
		Color(dimple, 0.32 * alpha), map)
	var pip_col := Color(dimple, 0.70 * alpha)
	var sp := ring_w * 0.098
	var x0 := -float(pips - 1) * sp * 0.5
	for p in pips:
		_fan_mapped(b, Face.Builder.ring(Vector2(cx + x0 + float(p) * sp, cy + ring_h * 0.17),
			ring_h * 0.075, ring_h * 0.075), pip_col, map)

## `points`, each carried through `map`, as one fan.
static func _fan_mapped(b, points: PackedVector2Array, colour: Color, map: Callable) -> void:
	var mapped := PackedVector2Array()
	mapped.resize(points.size())
	for i in points.size():
		mapped[i] = map.call(points[i])
	b.fan(mapped, colour)

# --- the scenery band at the card's foot ---

## The band the two rows leave at the card's foot: a bank of moss washed
## toward paper, grass blades standing out of it and three bushes on the
## ground line -- Word Trail's precedent, appended to this board's own
## builder instead of a Scenery node, so it stays one draw call. Unlike a
## board whose field sits inset from the card's edges, this band is drawn
## flush with them (the concept tab's own `scenery()`), so every shape here
## is clipped to the card's own rounded rect or a corner would show past it.
func _build_band(b) -> void:
	if _row_y.is_empty():
		return
	var band_top: float = _row_y[1] + STATION_H
	var gy: float = size.y - INSET
	var h: float = gy - band_top
	if h < 40.0:
		return
	var w: float = size.x
	var clip := _clip_rect()

	var bank: Color = Pal.MOSS.lerp(Pal.PAPER, 0.38)
	_clip_polygon(b, Face.Builder.round_rect(Vector2(-40.0, gy - 38.0), Vector2(w + 80.0, 120.0), 40.0), bank, clip)

	for i in 24:
		var bx: float = fmod(float(i * 149 + 37), w)
		var bh: float = 20.0 + float((i * 53) % 16)
		var foot := Vector2(bx, gy - 32.0)
		var tip := Vector2(bx + 2.0, gy - 32.0 - bh)
		var far := Vector2(bx + 9.0, gy - 32.0)
		var pts := Face.Builder.bezier2(foot, Vector2(bx + 4.0, gy - 32.0 - bh * 0.6), tip, 8)
		pts.append_array(Face.Builder.bezier2(tip, Vector2(bx + 8.0, gy - 32.0 - bh * 0.5), far, 8))
		pts.append(far)
		_clip_polygon(b, pts, Pal.MOSS, clip)

	var deep: Color = Pal.LEAF.lerp(Pal.TEXT, 0.12)
	var lit: Color = Pal.LEAF_LIGHT
	var bushes := [[86.0, 32.0], [w - 96.0, 28.0], [w * 0.47, 23.0]]
	for bush in bushes:
		var bx: float = bush[0]
		var br: float = bush[1]
		_clip_polygon(b, Face.Builder.ring(Vector2(bx, gy - 40.0), br, br), deep, clip)
		_clip_polygon(b, Face.Builder.ring(Vector2(bx - br * 0.8, gy - 32.0), br * 0.7, br * 0.7), deep, clip)
		_clip_polygon(b, Face.Builder.ring(Vector2(bx + br * 0.8, gy - 32.0), br * 0.7, br * 0.7), deep, clip)
		_clip_polygon(b, Face.Builder.ring(Vector2(bx - br * 0.3, gy - 52.0), br * 0.28, br * 0.28), lit, clip)

## The card's own rounded rect, a couple of pixels inside its edge so a
## clipped shape never rides over the panel's own border.
func _clip_rect() -> PackedVector2Array:
	var pad := 2.0
	return Face.Builder.round_rect(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0, maxf(CARD_RADIUS - pad, 0.0))

## `points` cut to `clip`, as however many simple polygons the intersection
## takes.
static func _clip_polygon(b, points: PackedVector2Array, colour: Color, clip: PackedVector2Array) -> void:
	for piece in Geometry2D.intersect_polygons(points, clip):
		b.polygon(piece, colour)

# --- the tip card ---

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

func _cycle_tip() -> void:
	if is_done():
		return
	_tip_idx = (_tip_idx + 1) % TIPS.size()
	_tip_text = TIPS[_tip_idx]
	_tip_mood = Face.Expr.HAPPY
	focus_changed.emit()

# --- the state PuzzleBase asks for ---

func is_solved() -> bool:
	return _state.is_solved()

## One coloured square per colour already home. Reads `pegs` fresh, the way
## every other derived thing on this board does; a true "in the order they
## came home" needs the moves a later task logs.
func share_glyphs() -> String:
	var out := ""
	for peg in _state.pegs:
		if Gen.locked(peg):
			out += SHARE_GLYPHS[int(peg[0])]
	return out

# --- the win ---

## The day's colours as rings, one per colour with its own pip count, in
## place of the sun and the moon -- flat_win()'s "characters of the answer".
func flat_win() -> Dictionary:
	var faces: Array = []
	for i in _state.colours:
		var icon := RingIcon.new()
		icon.ring_colour = RING_COLOURS[i]
		icon.pips = i + 1
		faces.append(icon)
	return {"faces": faces, "subtitle": "Every colour on a peg of its own."}

func win_delay() -> float:
	return Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A ring drawn on its own, for the win screen's cast: the same face, rim,
## highlight, dimple and pips as a station's ring, scaled to whatever square
## seat well_done.gd hands it. Nothing is added to ui/faces/ for this -- spec
## section 6 -- so this stands alone rather than joining that family. Its own
## small copy of _append_ring's shapes rather than a call to it: a nested
## class cannot reach the outer script's static functions unqualified, only
## its preloaded consts (GDScript resolves `Face` and `Pal` outward, but not
## a sibling function), and holding a reference back just to call one
## function once is not worth the indirection.
class RingIcon extends Control:
	var ring_colour: Color = Color.WHITE
	var pips: int = 1
	## Set by ui/flat/well_done.gd's set_cast on every face it seats; a ring
	## has no expression of its own, but the property has to exist.
	var expression: int = 0

	func _draw() -> void:
		var ring_w := size.x * 0.88
		var ring_h := ring_w * (RING_H / RING_W)
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		var b := Face.Builder.new()
		var face := ring_colour
		var rim := ring_colour.lerp(Pal.TEXT, 0.22)
		var edge := ring_h * (9.0 / 92.0)
		var at := Vector2(cx - ring_w * 0.5, cy - ring_h * 0.5)
		b.fan(Face.Builder.round_rect(at, Vector2(ring_w, ring_h), ring_h * 0.5), rim)
		b.fan(Face.Builder.round_rect(at, Vector2(ring_w, maxf(ring_h - edge, 0.0)), ring_h * 0.5), face)
		b.ellipse(Vector2(cx - ring_w * 0.22, cy - ring_h * 0.26), ring_w * 0.17, ring_h * 0.11,
			Color(Color.WHITE, 0.26))
		var dimple := face.lerp(Pal.TEXT, 0.30)
		var post_w := ring_w * (POST_W / RING_W)
		b.ellipse(Vector2(cx, cy - ring_h * 0.21), post_w * 0.56, ring_h * 0.10, Color(dimple, 0.32))
		var pip_col := Color(dimple, 0.70)
		var sp := ring_w * 0.098
		var x0 := -float(pips - 1) * sp * 0.5
		for p in pips:
			b.disc(Vector2(cx + x0 + float(p) * sp, cy + ring_h * 0.17), ring_h * 0.075, pip_col)
		var mesh := b.mesh()
		if mesh != null:
			draw_mesh(mesh, null)
