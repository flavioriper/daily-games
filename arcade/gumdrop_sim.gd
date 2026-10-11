extends RefCounted

## Gumdrop as data (spec
## docs/superpowers/specs/2026-10-10-arcade-gumdrop-design.md): the run,
## the mould, the pots, the dropper and the judge's words. The screen
## (arcade/gumdrop_screen.gd) hands it `pick()`, `aim()`, `squeeze()` and
## `serve()`, calls `step()` at the fixed DT and drains `events`.
##
## The syrup itself is not here since 2026-10-11 (the user: "I want a real
## high volume liquid effect of coloring"): it is a fluid on the GPU
## (arcade/gumdrop_fluid.gd), which the screen drives from this sim's tip
## and squeeze and reads back when a mould is served. This sim says what a
## colour means: a bit of jelly shows the hue of its pigments' shares at
## the strength of their sum (1 - exp(-c / C0), the card's shade at
## C_FULL), deeper than the card past that, and its match to the card is
## how near its colour is as a share of the way from clear to the card's
## colour. The fluid's shaders carry the same maths word for word
## (shaders/gumdrop/fluid.gdshaderinc).
##
## A run is mould after mould with no clock. Served, a mould settles
## SETTLE_T and the sim asks to be judged (`judge` event); the screen
## answers `judge()` with each cell's match and the verdict follows. Under
## the level's mark the run is over. The match is not shown while the
## mould is played.

const Mould = preload("res://arcade/gumdrop_mould.gd")

enum Phase { READY, PLAY, SETTLE, SHOW, OVER }

const DT := 1.0 / 60.0
## Squares a side of the grid that says which cell the tip is over, and
## mould units a square.
const N := 36
const CELL := Mould.SIDE / N
## Concentration: at C0 a bit of jelly is 63% of the way to the card's
## shade, at C_FULL it is the card's shade, and at 2 x C_FULL it is DEEP
## darker.
const C0 := 0.5
const C_FULL := 1.25
const DEEP := 0.3
const NEAR_FREE := 0.1
const NEAR_GONE := 0.8
## Squeezed a second, for the record of what went in.
const RATE := 4.0
## The mark a mould has to be served at: at level 1, a level's more, the top.
const MARK := 60
const MARK_STEP := 2
const MARK_TOP := 80
## At this and over a mould is perfect, and is worth this much more.
const PERFECT := 95
const PERFECT_BONUS := 50
## Seconds: the syrup left to settle before it is judged, and the verdict
## shown.
const SETTLE_T := 0.9
const SHOW_T := 2.4
## The boosters: a kinder mark is this much lower; a softer jelly is the
## fluid's (arcade/gumdrop_fluid.gd).
const KINDER := 10
## The six flavours' colours, in Mould.Flavour's order, and all three
## pigments at once.
const FLAVOURS := [Color("e2495a"), Color("f39237"), Color("f4d44a"), Color("79c94f"), Color("4a86df"), Color("9a62d2")]
const MUD := Color("7a5a48")

var rng := RandomNumberGenerator.new()
var phase := Phase.READY
var phase_t := 0.0
## Seconds played.
var t := 0.0
var level := 1
var score := 0
## Moulds served over the mark, the perfect ones among them, and the last
## verdict: {pct, need, pass, perfect, points}.
var served := 0
var perfects := 0
var verdict := {}
var events: Array = []

var mould := {}
## The pots: {flavour}. They never run dry.
var pots: Array = []
var picked := 0
## The dropper's tip, in mould units, and whether it is being squeezed.
var tip := Vector2(Mould.SIDE, Mould.SIDE) * 0.5
var squeezing := false
## Syrup squeezed into the jelly this mould.
var poured := 0.0
## Which cell each square is in (-1 the tray), and how many squares each
## cell has.
var reg := PackedInt32Array()
var count := PackedInt32Array()
## Each cell's match, 0 to 1, and the whole mould's, as of the last
## `judge()`.
var cell_match := PackedFloat32Array()
var match_all := 0.0
## Cells a tutorial page wants coloured before it starts: {cell, pigment}.
## The screen drains them into the fluid.
var prefill: Array = []
var soft := false
var kinder := 0
var _asked := false

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	deal()
	events.clear()

func is_over() -> bool:
	return phase == Phase.OVER

static func mark_of(lv: int) -> int:
	return mini(MARK + MARK_STEP * (lv - 1), MARK_TOP)

func mark() -> int:
	return maxi(1, mark_of(level) - kinder)

## The boosters (arcade/boosters.gd).
func softer() -> void:
	soft = true

func kind() -> void:
	kinder = KINDER

# --- the colour ---

## The hue of red, yellow and blue pigment in these parts: each flavour
## where it is alone or half and half with its neighbour, and mud in the
## middle, where all three meet.
static func hue(r: float, y: float, b: float) -> Color:
	var top := maxf(r, maxf(y, b))
	if top <= 0.0:
		return Color.WHITE
	r /= top
	y /= top
	b /= top
	var c00: Color = Color.WHITE.lerp(FLAVOURS[0], r)
	var c10: Color = FLAVOURS[2].lerp(FLAVOURS[1], r)
	var c01: Color = FLAVOURS[4].lerp(FLAVOURS[5], r)
	var c11: Color = FLAVOURS[3].lerp(MUD, r)
	return c00.lerp(c10, y).lerp(c01.lerp(c11, y), b)

## How strong a concentration shows: 0 clear, 1 the card's shade.
static func strength(c: float) -> float:
	return minf(1.0, (1.0 - exp(-c / C0)) / (1.0 - exp(-C_FULL / C0)))

## How much deeper than the card a concentration past C_FULL goes, 0 to 1.
static func deep(c: float) -> float:
	return clampf((c - C_FULL) / C_FULL, 0.0, 1.0) * DEEP

## The colour a bit of jelly shows with this pigment in it: the hue at
## its strength, deepened past the card's shade. Alpha is the strength.
static func colour(r: float, y: float, b: float) -> Color:
	var c := r + y + b
	if c <= 0.0:
		return Color(1, 1, 1, 0)
	var s := strength(c)
	var h := hue(r, y, b)
	var d := deep(c)
	if d > 0.0:
		h = h.lerp(h * h, d)
	return Color(h.r, h.g, h.b, s)

## How near a colour is to a flavour's, 1 at it, 0 clear: its distance to
## the flavour against the way from clear to the flavour. NEAR_FREE of
## the way off is still a full match (the eye calls it the same colour),
## at NEAR_GONE of the way off the match is nothing.
static func nearness(col: Color, flavour: int) -> float:
	var want: Color = FLAVOURS[flavour]
	var shown := Color.WHITE.lerp(Color(col.r, col.g, col.b), col.a)
	var way := Vector3(1.0 - want.r, 1.0 - want.g, 1.0 - want.b).length()
	var off := Vector3(shown.r - want.r, shown.g - want.g, shown.b - want.b).length()
	return 1.0 - clampf((off / way - NEAR_FREE) / (NEAR_GONE - NEAR_FREE), 0.0, 1.0)

# --- a mould ---

## A new mould for the level, or `m` laid as it is (a tutorial page's).
func deal(m := {}) -> void:
	mould = m if not m.is_empty() else Mould.deal(level, rng)
	_lay()
	events.append({"type": "deal", "level": level})

func _lay() -> void:
	var cells: Array = mould.cells
	reg.resize(N * N)
	count.resize(cells.size())
	count.fill(0)
	for i in N * N:
		var p := Vector2((i % N) + 0.5, (i / N) + 0.5) * CELL
		var found := -1
		for c in cells.size():
			if Geometry2D.is_point_in_polygon(p, cells[c]):
				found = c
				break
		reg[i] = found
		if found >= 0:
			count[found] += 1
	cell_match.resize(cells.size())
	cell_match.fill(0.0)
	match_all = 0.0
	pots.clear()
	for f: int in mould.pots:
		pots.append({"flavour": f})
	picked = 0
	tip = centre_of(0)
	squeezing = false
	poured = 0.0
	prefill.clear()
	_asked = false

## The square a point of the mould lies in.
static func square(p: Vector2) -> int:
	return clampi(int(p.x / CELL), 0, N - 1) + clampi(int(p.y / CELL), 0, N - 1) * N

static func at(i: int) -> Vector2:
	return Vector2((i % N) + 0.5, (i / N) + 0.5) * CELL

## The cell the tip is over, -1 a wall or the tray: the walls are taken
## out of the cells here, as the fluid's mask has them.
func tip_cell() -> int:
	var c := reg[square(tip)]
	if c < 0:
		return -1
	return c if Geometry2D.is_point_in_polygon(tip, mould.inner[c]) else -1

## The point of a cell furthest from its walls: where a careful hand puts
## the dropper.
func centre_of(c: int) -> Vector2:
	var best := -1
	var far := -1.0
	var poly: PackedVector2Array = mould.inner[c]
	for i in N * N:
		if reg[i] != c:
			continue
		var p := at(i)
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		var near := 1e9
		for k in poly.size():
			near = minf(near, Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()]).distance_squared_to(p))
		if near > far:
			far = near
			best = i
	return at(best) if best >= 0 else poly[0]

## A cell coloured before play, a tutorial page's: `part` of the way to
## the card's shade of a flavour.
func filled(c: int, flavour: int, part: float) -> void:
	var pig: Vector3 = Mould.PIGMENT[flavour]
	prefill.append({"cell": c, "pigment": pig * part * C_FULL})
	poured += part * C_FULL * count[c]
	if phase == Phase.READY:
		phase = Phase.PLAY

# --- the hand ---

func pick(i: int) -> void:
	if i >= 0 and i < pots.size() and (phase == Phase.READY or phase == Phase.PLAY):
		picked = i

func aim(p: Vector2) -> void:
	tip = p.clamp(Vector2.ONE * CELL * 0.5, Vector2.ONE * (Mould.SIDE - CELL * 0.5))

func squeeze(on: bool) -> void:
	if not on or phase == Phase.READY or phase == Phase.PLAY:
		squeezing = on

## Whether anything has been squeezed into the mould.
func wet() -> bool:
	return poured > 0.0

func can_serve() -> bool:
	return phase == Phase.PLAY and wet()

func serve() -> void:
	if not can_serve():
		return
	squeezing = false
	phase = Phase.SETTLE
	phase_t = 0.0
	_asked = false
	events.append({"type": "serve"})

# --- a step ---

func step() -> void:
	phase_t += DT
	match phase:
		Phase.READY, Phase.PLAY:
			if squeezing and tip_cell() >= 0:
				if phase == Phase.READY:
					phase = Phase.PLAY
					phase_t = 0.0
					events.append({"type": "go"})
				poured += RATE * DT
			if phase == Phase.PLAY:
				t += DT
		Phase.SETTLE:
			if phase_t >= SETTLE_T and not _asked:
				_asked = true
				events.append({"type": "judge"})
		Phase.SHOW:
			if phase_t >= SHOW_T:
				_after()

## The answer to a `judge` event: each cell's match, 0 to 1, as the fluid
## measured it. The verdict follows.
func judge(near: PackedFloat32Array, all: float) -> void:
	if phase != Phase.SETTLE:
		return
	for c in mini(near.size(), cell_match.size()):
		cell_match[c] = near[c]
	match_all = clampf(all, 0.0, 1.0)
	var pct := int(round(match_all * 100.0))
	var passed := pct >= mark()
	var perfect := pct >= PERFECT
	# a mould under its mark is worth nothing
	var points := (pct + (PERFECT_BONUS if perfect else 0)) if passed else 0
	verdict = {"pct": pct, "need": mark(), "pass": passed, "perfect": perfect, "points": points}
	score += points
	if passed:
		served += 1
		if perfect:
			perfects += 1
	phase = Phase.SHOW
	phase_t = 0.0
	events.append({"type": "served", "pct": pct, "need": mark(), "pass": passed, "perfect": perfect, "points": points})

func _after() -> void:
	if bool(verdict.get("pass", false)):
		level += 1
		deal()
		phase = Phase.PLAY
		phase_t = 0.0
	else:
		phase = Phase.OVER
		events.append({"type": "over"})

## The Second chance: the mould that ended the run, clear again.
func revive() -> void:
	if phase != Phase.OVER:
		return
	_lay()
	phase = Phase.PLAY
	phase_t = 0.0
	events.append({"type": "revive", "level": level})
