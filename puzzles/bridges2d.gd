extends "res://core/puzzle_base.gd"

## Bridges as a flat board: a pale sea inset in the card, islets standing on
## it with the number of plank-ends each one wants, and runs of one to three
## planks laid in the lanes between the pairs that face each other. The rules
## live in puzzles/bridges_state.gd, which this only draws.
##
## **The fourth rule is the puzzle.** Every number met is not a solve: the
## islets have to end on one single network, and the board says nothing at
## all about the near-miss where the numbers are all met and the islets stand
## in two rings. Seeing the split network is the thing being solved, and
## Check is the only door to it (spec section 10).
##
## How it is drawn, and it is Word Trail's arrangement wholesale. One
## `ArrayMesh` carries everything with no glyph on it -- the pool, its rim and
## shallow band, the ripples, the hint glows, the planks, the islets and their
## rings -- and the numbers go over the top as `draw_string` commands, because
## a glyph in a mesh cache key multiplies every state by ten. With it comes
## Word Trail's hard-won rule: **a canvas command holds a mesh by RID and not
## by reference**, so the mesh the last `_draw` handed over is kept in
## `_shown` until the next one replaces it, or a harness's `force_draw()`
## photographs a freed RID ("Parameter mesh is null", and an empty card).
##
## **The order is not a preference, because an islet is opaque and a run ends
## under one**: the pool, the ripples, the runs, the islets over them, and the
## numbers last.
##
## Spec: docs/superpowers/specs/2026-09-20-bridges-flat-design.md, sections 6
## and 7. Ported number for number from the canvas mock at
## docs/brainstorm/concepts.html#bridges, which is the reference for every
## measure here.

const State = preload("res://puzzles/bridges_state.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Face = preload("res://ui/faces/face.gd")

# --- the screen, measured (spec section 6) ---
## The sea pool's inset from the card, and the lattice's own inset inside the
## pool. At 1080 wide that is a 1000 card, a 944 pool and a **920 lattice at
## every band**, so the width binds and a cell is 131 / 102 / 84.
const INSET := 28.0
const FIELD_PAD := 12.0
## What those two come to in design space, recorded so a layout that stops
## measuring 920 is caught rather than explained away.
const FIELD := 920.0
## A plank's thickness and the air between two of them, in cells: three planks
## span 0.59 of a cell, wide enough to read as three at 84 px and narrow
## enough to leave water either side.
const PLANK := 0.115
const PLANK_GAP := 0.095
## Three, as every other board gives.
const HINTS := 3
## This board's own two, and the only two it needs: how long the solve wave's
## front takes to cross one run, and how long it rests on an islet. The wave
## itself is the board's signature and lands with the motion pass; `win_delay`
## already spends them, so the win waits exactly as long as the wave will run.
const WAVE_EDGE := 0.14
const WAVE_HOLD := 0.06

# --- the pool, in the mock's own pixels ---
## The pool's corner, the rim it stands on, and the paler band of shallows
## inside that rim: how far in it sits, how thick it is, its corner and how
## far its colour is let through.
const POOL_RADIUS := 34.0
const POOL_EDGE := 9.0
const SHALLOW_INSET := 9.0
const SHALLOW_W := 26.0
const SHALLOW_RADIUS := 26.0
const SHALLOW_ALPHA := 0.85
## The ripples: how many, how thick, how far they are let through, and the
## box they are sown in -- in from the pool's left, down from its top, and
## how much of the pool's width and height they spread over. The span is
## short of the pool by more than a ripple's length on purpose: the mock
## clipped them to the pool and a mesh cannot, so they are sown clear of the
## rim instead of cut at it.
const RIPPLES := 9
const RIPPLE_W := 8.0
const RIPPLE_ALPHA := 0.24
const RIPPLE_AT := Vector2(60.0, 70.0)
const RIPPLE_SPAN := Vector2(190.0, 140.0)
const RIPPLE_LEN := Vector2(40.0, 60.0)
const RIPPLE_BOW := 8.0

# --- an islet, in cells or in fractions of its own radius ---
## The turf disc's radius as a fraction of the cell, and everything else as a
## fraction of that radius: the coloured shadow under it, the sand rim it
## stands on, the turf itself, the sun cap on the turf's shoulder, the ring a
## satisfied islet wears, and where the number sits.
const ISLET_R := 0.40
const SHADOW_AT := 0.30
const SHADOW_RX := 1.02
const SHADOW_RY := 0.40
const SHADOW_ALPHA := 0.30
const SAND_DROP := 0.07
const TURF_R := 0.80
const TURF_DROP := 0.04
const CAP_AT := Vector2(-0.22, -0.34)
const CAP_R := Vector2(0.30, 0.17)
const CAP_ALPHA := 0.55
const RING_R := 1.13
const RING_W := 0.13
const RING_MIN := 4.0
const RING_ALPHA := 0.95
const NUMBER_SIZE := 0.95
const NUMBER_AT := -0.04
## How far a met islet's ink is let down toward the paper: a number that has
## been answered steps back rather than shouting.
const NUMBER_MET := 0.38
## How much wider than the turf a press may land and still take the islet: an
## islet is round and the corners of its cell are water.
const GRAB := 1.25

# --- a plank ---
## Its corner as a fraction of its own thickness, the lip the deck stands on,
## the shadow it throws on the water and where, and the slats across it.
const PLANK_RADIUS := 0.34
const PLANK_EDGE := 4.0
const PLANK_SHADOW := Vector2(3.0, 7.0)
const PLANK_SHADOW_ALPHA := 0.22
const SLAT_STEP := 0.30
const SLAT_ALPHA := 0.28
const SLAT_W := 0.022
const SLAT_MIN := 2.0

# --- the hint's glow, and the check's mark ---
## The halo round a run a hint laid: its pad off the run's own box, its
## corner, how far its gold is let through, and the dashed outline over it.
const GLOW_PAD := 0.13
const GLOW_RADIUS := 1.6
const GLOW_ALPHA := 0.85
const DASH_ON := 0.13
const DASH_OFF := 0.1
const DASH_W := 0.05
const DASH_MIN := 3.0
## How far a run the check marked is carried toward BAD, deck and lip alike.
## It is the mock's flash at its peak, because until the motion pass lands
## there is no flash to ride: the mark simply stands until the next move.
const BAD_MIX := 0.85
const BAD_DEEP_MIX := 0.6
## How far an over-filled islet's turf is washed out (spec section 5): it is
## drawn wrong, never refused.
const OVER_MIX := 0.42

# --- the sea, and everything on it (spec section 7) ---
## **This is the first flat board whose field is not paper**, and every value
## here is a mix of exactly *two* `core/palette.gd` entries. Nothing is
## invented and nothing was added to the palette. Letting `WATER_HI` down into
## **PAPER** rather than into a cool entry is what carries the warmth: the
## paper's red comes up as the blue comes down.
##
## Two of them invert on a pale ground and both are worth writing down: the
## **ripples are darker** than the water they lie on (WATER_HI strokes
## vanished, so the old sea's blue became the new sea's mark), and the
## **shallow band is paler** than the open water, not deeper.
const SEA := 0.46          # WATER_HI into PAPER -- #a4cde6, the open water
const SEA_PALE := 0.74     # WATER_HI into PAPER -- #cfdfe4, the shallows
const SEA_DEEP := 0.20     # WATER_HI into TEXT  -- #5896c2, the pool's edge
const SEA_SHADE := 0.35    # WATER into TEXT     -- #336e99, an islet's shadow
## The islet: turf is BANK on an **ACORN** beach. The beach was STONE in the
## first cut and the islets stopped reading entirely -- STONE is value 237
## against a 230 sea, seven points apart, so the rim disappeared. ACORN sits
## 29 of value below the water and warm against a cool ground.
const BANK_HI := 0.26      # BANK into SURFACE, the turf's sun cap
const BANK_DEEP := 0.28    # BANK into TEXT, the turf's own lip
const SAND_DEEP := 0.22    # ACORN into TEXT, the wet sand at the waterline

## The tip card's resting line. Its two refusal lines land with the finger.
const TIP_REST := "Press an islet and drag at the one facing it."

var state = State.new()

## The mesh the last `_draw` built, and the one it actually handed to the
## canvas item. The first is dropped whenever something changed so the next
## `_draw` rebuilds it; the second is held because a canvas command keeps a
## mesh by RID and not by reference.
var _mesh: ArrayMesh
var _shown: ArrayMesh

## The islet the finger went down on, and where it went down, while a drag is
## live. NOWHERE when nothing is held.
var _from := State.NOWHERE
## The lane the drag is asking for, once the travel has passed half a cell,
## and the direction it took. "" and ZERO until then.
var _aim := ""
var _aim_dir := Vector2i.ZERO
## The laid run the press landed on the water of, for the tap that wipes.
var _on_run := ""
## The islet the last run was laid from: where the solve wave will start.
var _last := State.NOWHERE

## Every lane a hint laid a plank on, so the board can show what was given.
var _given: Dictionary = {}
## Every lane the last Check marked. Cleared by the next move, because until
## the motion pass lands there is no flash to time the mark out.
var _wrong: Dictionary = {}

var _tip_text := TIP_REST
var _tip_mood := Face.Expr.HAPPY

func puzzle_id() -> String: return "bridges"
func title() -> String: return "Bridges"

## The four rules of the spec's section 1, in that order and **connectivity
## last**, because it is the one the reference's own rules card leaves out and
## the one this whole board rests on.
func rules() -> String:
	return "Join the islets with plank bridges.\n" \
		+ "Each islet takes exactly its number of planks.\n" \
		+ "Bridges run across or down only, never over an islet.\n" \
		+ "At most three planks join the same two islets, and no two runs may cross.\n" \
		+ "When you are done, every islet must be joined into one single network."

## Undo, Hint and Check: the plainest shape on the shelf. It picks nothing up,
## so the registry gives it no tray, and it has a real Check, so unlike
## Balance and Untangle it keeps the actions row.
func capabilities() -> Array[String]:
	return ["undo", "hint", "check"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	resized.connect(_refresh)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	state.build(rng, difficulty)
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	_last = State.NOWHERE
	_given = {}
	_wrong = {}
	_say(TIP_REST, Face.Expr.HAPPY)
	_refresh()

# --- the layout, ported from the mock ---

## The sea pool, inset from the card on every side.
func _pool() -> Rect2:
	return Rect2(INSET, INSET, maxf(0.0, size.x - 2.0 * INSET), maxf(0.0, size.y - 2.0 * INSET))

## The largest cell the pool holds, with the lattice's own pad inside it.
## **The width binds at every band** -- 920 of lattice against 1110 of pool
## height at 1080 wide -- because the lattice is square and the slot is tall.
func _cell() -> float:
	if state.n <= 0:
		return 0.0
	var p := _pool()
	return maxf(0.0, minf((p.size.x - 2.0 * FIELD_PAD) / float(state.n),
		(p.size.y - 2.0 * FIELD_PAD) / float(state.n)))

func _field_size() -> float:
	return _cell() * float(state.n)

## The lattice's top-left: centred across the card, and the 214 of pool height
## it does not spend **halved above and below** -- 107 each, which is what
## `card_centred()` says on the card and this says inside the pool.
func _origin() -> Vector2:
	var p := _pool()
	var g := _field_size()
	return Vector2(size.x * 0.5 - g * 0.5, p.position.y + (p.size.y - g) * 0.5)

## Control-local point over the centre of the cell at (row, column) -- the
## name every flat board gives it and the one a harness taps.
func cell_to_local(r: int, c: int) -> Vector2:
	var s := _cell()
	return _origin() + Vector2(float(c) + 0.5, float(r) + 0.5) * s

## The centre of an islet, which is `Vector2i(column, row)` here as it is
## everywhere in this board's state.
func _at(cell: Vector2i) -> Vector2:
	return cell_to_local(cell.y, cell.x)

## The cell under a local point as `Vector2i(column, row)`, or (-1, -1) when
## the point is off the lattice.
func local_to_cell(p: Vector2) -> Vector2i:
	var s := _cell()
	if s <= 0.0:
		return State.NOWHERE
	var q := (p - _origin()) / s
	var at := Vector2i(int(floor(q.x)), int(floor(q.y)))
	if at.x < 0 or at.y < 0 or at.x >= state.n or at.y >= state.n:
		return State.NOWHERE
	return at

func _islet_r() -> float:
	return _cell() * ISLET_R

## Where a run's planks stand: the lane between the two islets' rims, so a
## plank never runs under the turf it ends at.
## Returns {"horiz": bool, "a": Vector2, "b": Vector2}, the two ends of the
## run's centreline.
func _lane_ends(key: String) -> Dictionary:
	var lane: Dictionary = state.lanes[key]
	var a := _at(lane.a)
	var b := _at(lane.b)
	var r := _islet_r()
	var horiz: bool = int(lane.a.y) == int(lane.b.y)
	if horiz:
		var lo := minf(a.x, b.x) + r
		var hi := maxf(a.x, b.x) - r
		return {"horiz": true, "a": Vector2(lo, a.y), "b": Vector2(hi, a.y)}
	var top := minf(a.y, b.y) + r
	var bot := maxf(a.y, b.y) - r
	return {"horiz": false, "a": Vector2(a.x, top), "b": Vector2(a.x, bot)}

## Every pixel it is given: the pool fills the card and the lattice is centred
## in the pool, so the board never hands a slot back.
func card_height(available: float) -> float:
	return available

## True, and the slack it centres is spent inside the pool rather than by the
## host: `card_height()` hands every pixel back, so the host has nothing left
## to halve. It says true because the lattice is square in a tall slot, which
## is the same reason Tents, Light Up and Queens say it.
func card_centred() -> bool:
	return true

## Drops the mesh so the next `_draw` rebuilds it, and asks for that draw. The
## mesh the last `_draw` handed over is still held by `_shown`, so the
## renderer is never left pointing at a freed RID.
func _refresh() -> void:
	_mesh = null
	queue_redraw()

# --- the drawing ---

## One mesh for everything with no glyph on it, then the numbers over the top.
## The order is the only one that works: an islet is opaque and a run ends
## under one.
func _draw() -> void:
	if state.islets.is_empty() or _cell() <= 0.0:
		return
	if _mesh == null:
		_mesh = _build()
	if _mesh != null:
		draw_mesh(_mesh, null)
	_shown = _mesh
	_draw_numbers()

func _build() -> ArrayMesh:
	var b := Face.Builder.new()
	_water(b)
	for key in state.runs:
		_run(b, String(key))
	for cell in state.islets:
		_islet(b, cell)
	return b.mesh() if not b.verts.is_empty() else null

## The pool: its face over a bottom edge in the deeper blue, the paler band of
## shallows inside the rim, and a few ripples over the open water.
func _water(b) -> void:
	var p := _pool()
	var deep: Color = Pal.WATER_HI.lerp(Pal.TEXT, SEA_DEEP)
	var sea: Color = Pal.WATER_HI.lerp(Pal.PAPER, SEA)
	var pale: Color = Pal.WATER_HI.lerp(Pal.PAPER, SEA_PALE)
	b.fan(Face.Builder.round_rect(p.position, p.size, POOL_RADIUS), deep)
	b.fan(Face.Builder.round_rect(p.position, Vector2(p.size.x, p.size.y - POOL_EDGE),
		POOL_RADIUS), sea)
	b.stroke(Face.Builder.round_rect(p.position + Vector2.ONE * SHALLOW_INSET,
		p.size - Vector2.ONE * 2.0 * SHALLOW_INSET, SHALLOW_RADIUS),
		SHALLOW_W, Color(pale, SHALLOW_ALPHA), true)
	var ink := Color(Pal.WATER, RIPPLE_ALPHA)
	for i in RIPPLES:
		var at := p.position + RIPPLE_AT + Vector2(
			_hash(i, 7) * (p.size.x - RIPPLE_SPAN.x),
			_hash(i, 11) * (p.size.y - RIPPLE_SPAN.y))
		var span := RIPPLE_LEN.x + _hash(i, 3) * RIPPLE_LEN.y
		b.stroke(Face.Builder.bezier2(at, at + Vector2(span * 0.5, -RIPPLE_BOW),
			at + Vector2(span, 0.0)), RIPPLE_W, ink)

## One run: the halo if a hint laid it, then a plank per count, each on its
## own coloured shadow. A run the last Check marked is carried toward BAD,
## deck and lip alike.
func _run(b, key: String) -> void:
	var count: int = state.planks(key)
	if count <= 0:
		return
	var s := _cell()
	var g := _lane_ends(key)
	var horiz: bool = g.horiz
	var thick := s * PLANK
	var air := s * PLANK_GAP
	var total := float(count) * thick + float(count - 1) * air
	var bad: bool = _wrong.has(key)
	var face: Color = Pal.DECK.lerp(Pal.BAD, BAD_MIX) if bad else Pal.DECK
	var deep: Color = Pal.WOOD_DEEP.lerp(Pal.BAD, BAD_DEEP_MIX) if bad else Pal.WOOD_DEEP
	if _given.has(key) and not is_done():
		_glow(b, g, total)
	var lo: Vector2 = Vector2(minf(g.a.x, g.b.x), minf(g.a.y, g.b.y))
	var run: float = absf(g.b.x - g.a.x) if horiz else absf(g.b.y - g.a.y)
	for i in count:
		var off := float(i) * (thick + air) - (total - thick) * 0.5
		var at: Vector2
		var box: Vector2
		if horiz:
			at = Vector2(lo.x, g.a.y + off - thick * 0.5)
			box = Vector2(run, thick)
		else:
			at = Vector2(g.a.x + off - thick * 0.5, lo.y)
			box = Vector2(thick, run)
		var r := minf(box.x, box.y) * PLANK_RADIUS
		b.fan(Face.Builder.round_rect(at + PLANK_SHADOW, box, r),
			Color(Pal.TEXT, PLANK_SHADOW_ALPHA))
		_plank(b, at, box, horiz, r, face, deep)

## A plank: WOOD_DEEP under DECK, with a lip along its lower edge and slats
## across it -- the mock's own shape.
func _plank(b, at: Vector2, box: Vector2, horiz: bool, r: float, face: Color, deep: Color) -> void:
	b.fan(Face.Builder.round_rect(at, box, r), deep)
	var lit := Vector2(box.x, box.y - PLANK_EDGE) if horiz else Vector2(box.x - PLANK_EDGE, box.y)
	b.fan(Face.Builder.round_rect(at, lit, r), face)
	var ink := Color(deep, SLAT_ALPHA)
	var wide := maxf(SLAT_MIN, _cell() * SLAT_W)
	var step := _cell() * SLAT_STEP
	var span: float = box.x if horiz else box.y
	var s := step * 0.6
	while s < span - step * 0.3:
		var line := PackedVector2Array()
		if horiz:
			line.append(at + Vector2(s, 2.0))
			line.append(at + Vector2(s, box.y - 5.0))
		else:
			line.append(at + Vector2(2.0, s))
			line.append(at + Vector2(box.x - 5.0, s))
		b.stroke(line, wide, ink)
		s += step

## The halo a hint leaves round a whole run, so a given reads at a glance
## rather than plank by plank: a pale gold box under a dashed gold outline,
## the language every board in this game uses for a given.
func _glow(b, g: Dictionary, total: float) -> void:
	var s := _cell()
	var pad := s * GLOW_PAD
	var at: Vector2
	var box: Vector2
	if bool(g.horiz):
		at = Vector2(minf(g.a.x, g.b.x) - pad, g.a.y - total * 0.5 - pad)
		box = Vector2(absf(g.b.x - g.a.x) + 2.0 * pad, total + 2.0 * pad)
	else:
		at = Vector2(g.a.x - total * 0.5 - pad, minf(g.a.y, g.b.y) - pad)
		box = Vector2(total + 2.0 * pad, absf(g.b.y - g.a.y) + 2.0 * pad)
	var ring := Face.Builder.round_rect(at, box, pad * GLOW_RADIUS)
	b.fan(ring, Color(Pal.SUN_RAY, GLOW_ALPHA))
	for dash in _dashes(ring, s * DASH_ON, s * DASH_OFF):
		b.stroke(dash as PackedVector2Array, maxf(DASH_MIN, s * DASH_W), Pal.SUN_DEEP)

## An islet: a coloured shadow on the water, a sand rim, the turf disc on it
## with a sun cap on its shoulder, and the ring it wears once its number is
## met -- GOOD when it is met exactly, BAD when the finger has pushed it over.
## An over-filled islet is **drawn wrong and never refused** (spec section 5).
func _islet(b, cell: Vector2i) -> void:
	var r := _islet_r()
	var mid := _at(cell)
	var want: int = int(state.need[cell])
	var got: int = state.degree(cell)
	var met := got == want
	var over := got > want
	b.ellipse(mid + Vector2(0.0, r * SHADOW_AT), r * SHADOW_RX, r * SHADOW_RY,
		Color(Pal.WATER.lerp(Pal.TEXT, SEA_SHADE), SHADOW_ALPHA))
	b.disc(mid + Vector2(0.0, r * SAND_DROP), r, Pal.ACORN.lerp(Pal.TEXT, SAND_DEEP))
	b.disc(mid, r, Pal.ACORN)
	b.disc(mid + Vector2(0.0, r * TURF_DROP), r * TURF_R, Pal.BANK.lerp(Pal.TEXT, BANK_DEEP))
	var turf: Color = Pal.BANK.lerp(Pal.BAD, OVER_MIX) if over else Pal.BANK
	b.disc(mid, r * TURF_R, turf)
	b.ellipse(mid + CAP_AT * r, r * CAP_R.x, r * CAP_R.y,
		Color(Pal.BANK.lerp(Pal.SURFACE, BANK_HI), CAP_ALPHA))
	if met or over:
		b.stroke(Face.Builder.ring(mid, r * RING_R, r * RING_R),
			maxf(RING_MIN, r * RING_W),
			Color(Pal.BAD if over else Pal.GOOD, RING_ALPHA), true)

## The numbers, over the mesh: one `draw_string` each, as Nonogram draws its
## clues and Word Trail its letters. A met number steps back toward the paper
## and an over-filled one goes to BAD.
func _draw_numbers() -> void:
	var r := _islet_r()
	var font: Font = CozyTheme.display(700)
	var px := maxi(1, int(round(r * NUMBER_SIZE)))
	for cell in state.islets:
		var want: int = int(state.need[cell])
		var got: int = state.degree(cell)
		var ink: Color = Pal.TEXT
		if got > want:
			ink = Pal.BAD
		elif got == want:
			ink = Pal.TEXT.lerp(Pal.PAPER, NUMBER_MET)
		_glyph(font, px, str(want), ink, _at(cell) + Vector2(0.0, r * NUMBER_AT))

## One glyph centred on `at`, as Nonogram centres a clue number.
func _glyph(font: Font, px: int, text: String, ink: Color, at: Vector2) -> void:
	if ink.a <= 0.0:
		return
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var rise := font.get_height(px) * 0.5 - font.get_descent(px)
	draw_string(font, at + Vector2(-wide * 0.5, rise), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, ink)

## The closed outline `pts` cut into dashes of `on` with `off` between them.
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
			# Never zero: a dash that ended exactly on a corner would otherwise
			# walk nowhere for ever.
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

## A settled number in 0..1 from two ints: what keeps the ripples from lying
## in a comb without a seeded generator in the drawing.
static func _hash(a: int, b: int) -> float:
	return float(posmod(hash(Vector2i(a, b)), 1000)) / 1000.0

# --- the finger ---

## Press an islet, drag at the one facing it, let go: the run cycles
## 0-1-2-3-0. A tap on the water of a laid run wipes it in one go.
##
## The lit lane under the finger, the two refusals and everything they put on
## the tip card land with the rest of the gesture; this is the path the win
## harness drives, and it goes through `state.cycle` exactly as a finger does.
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			if _press(event.position):
				accept_event()
		else:
			if _from != State.NOWHERE or _on_run != "":
				_release()
				accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) \
			and _from != State.NOWHERE:
		_aim_at(event.position)
		accept_event()

## True when the press landed on something this board answers for.
func _press(at: Vector2) -> bool:
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	var cell := local_to_cell(at)
	if cell == State.NOWHERE:
		return false
	if state.is_islet(cell):
		# The disc and a little air round it, not the whole cell: an islet is
		# round and the corners of its cell are water.
		if at.distance_to(_at(cell)) > _islet_r() * GRAB:
			return false
		_from = cell
		return true
	_on_run = _run_over(cell)
	return _on_run != ""

## The laid run whose water covers `cell`, or "".
func _run_over(cell: Vector2i) -> String:
	for key in state.runs:
		if (state.lanes[key].cells as Array).has(cell):
			return String(key)
	return ""

## The drag takes its dominant axis and, once the travel has passed half a
## cell, names the lane to the first islet that way -- so the run the finger
## is asking for is never a guess about which pair was meant.
func _aim_at(at: Vector2) -> void:
	var s := _cell()
	var d := at - _at(_from)
	if absf(d.x) < s * 0.5 and absf(d.y) < s * 0.5:
		if _aim_dir != Vector2i.ZERO:
			_aim = ""
			_aim_dir = Vector2i.ZERO
			_refresh()
		return
	var dir: Vector2i
	if absf(d.y) > absf(d.x):
		dir = Vector2i(0, 1 if d.y > 0.0 else -1)
	else:
		dir = Vector2i(1 if d.x > 0.0 else -1, 0)
	if dir == _aim_dir:
		return
	_aim_dir = dir
	var other := state.facing(_from, dir)
	_aim = "" if other == State.NOWHERE else state.lane_at(_from, other)
	_refresh()

func _release() -> void:
	var from := _from
	var lane := _aim
	var wipe := _on_run
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	if from != State.NOWHERE:
		if lane == "":
			return
		var before: int = state.planks(lane)
		if state.cycle(lane) == before:
			return
		_last = from
		_after_move()
		return
	if wipe != "" and state.clear_run(wipe):
		_after_move()

## Every move clears the last Check's marks -- the board has changed under
## them -- and counts itself, which is what ends the puzzle when the last
## plank lands on one single network.
func _after_move() -> void:
	_wrong = {}
	_refresh()
	note_move()

# --- the sprout's line ---

func tip_line() -> Dictionary:
	return {"text": _tip_text, "mood": _tip_mood}

func _say(text: String, mood: int) -> void:
	_tip_text = text
	_tip_mood = mood
	# The tip card only re-reads a board when the host refreshes it, and the
	# host refreshes on this signal.
	focus_changed.emit()

# --- the HUD's actions ---

func can_undo() -> bool:
	return state.can_undo()

func undo() -> bool:
	if is_done() or not state.undo():
		return false
	_wrong = {}
	_say(TIP_REST, Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	return true

func hints_left() -> int:
	return maxi(0, HINTS - hints_used)

## Lays one plank the answer has and the board lacks -- never an overshoot, so
## a hint can never itself be the thing that pushes an islet over its number.
func hint() -> bool:
	if is_done() or hints_left() <= 0:
		return false
	var key := state.hint()
	if key == "":
		return false
	hints_used += 1
	_given[key] = true
	_wrong = {}
	_say("A plank the answer wants is in.", Face.Expr.HAPPY)
	_refresh()
	moved.emit()
	check_solved()
	return true

## Marks the runs carrying more planks than the answer lays there. **An
## under-laid run is unfinished and not wrong**: marking every lane still
## missing would print the answer, which is the one thing this screen does not
## do (spec section 10). The near-miss -- every number met and the islets in
## two rings -- is left unsignposted on purpose, and this is its only door.
func check() -> int:
	if is_done():
		return 0
	checks += 1
	var wrong: Array = state.wrong_runs()
	_wrong = {}
	for key in wrong:
		_wrong[key] = true
	_say("%d %s in the way." % [wrong.size(), "run is" if wrong.size() == 1 else "runs are"]
		if not wrong.is_empty() else "Nothing you have laid is wrong.",
		Face.Expr.STRAIN if not wrong.is_empty() else Face.Expr.JOY)
	_refresh()
	return wrong.size()

## Every plank goes. The hints a player spent are not refunded, only unpinned.
func reset_board() -> void:
	state.reset_board()
	_from = State.NOWHERE
	_aim = ""
	_aim_dir = Vector2i.ZERO
	_on_run = ""
	_last = State.NOWHERE
	_given = {}
	_wrong = {}
	moves = 0
	_running = true
	_say(TIP_REST, Face.Expr.HAPPY)
	_refresh()

func is_solved() -> bool:
	return state.is_solved()

func share_glyphs() -> String:
	return state.share_glyphs()

# --- the win ---

## The no-cast form Light Up uses: the joined network stays on the card under
## the win screen, because the board *is* the answer and there is nothing
## better to show.
func flat_win() -> Dictionary:
	return {"faces": [], "subtitle": "One network, every islet on it."}

## Long enough for the wave that lights the network, which runs outward from
## the islet the player finished at: `WAVE_EDGE` to cross a run and
## `WAVE_HOLD` on each islet it reaches.
func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return float(_wave_depth()) * (WAVE_EDGE + WAVE_HOLD)

## How many runs deep the network is from the islet the last plank was laid
## at: the number of steps the wave has to take. Breadth-first over the laid
## runs, which is the wave's own order.
func _wave_depth() -> int:
	if state.islets.is_empty():
		return 0
	var start: Vector2i = _last if _last != State.NOWHERE else state.islets[0]
	var seen := {start: 0}
	var queue: Array[Vector2i] = [start]
	var deepest := 0
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		var step: int = int(seen[cell]) + 1
		for key in state.runs:
			if int(state.runs[key]) <= 0:
				continue
			var lane: Dictionary = state.lanes[key]
			var other := State.NOWHERE
			if lane.a == cell:
				other = lane.b
			elif lane.b == cell:
				other = lane.a
			if other == State.NOWHERE or seen.has(other):
				continue
			seen[other] = step
			deepest = maxi(deepest, step)
			queue.append(other)
	return deepest
