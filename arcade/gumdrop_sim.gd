extends RefCounted

## Gumdrop as pure data (spec
## docs/superpowers/specs/2026-10-10-arcade-gumdrop-design.md): a tray of
## clear jelly in a walled mould, and a dropper of syrup. The screen
## (arcade/gumdrop_screen.gd) hands it `pick()`, `aim()`, `squeeze()` and
## `serve()`, calls `step()` at the fixed DT and drains `events`.
##
## The syrup is a liquid soaking through a jelly (since 2026-10-11; before
## that it stood on the mould as a depth that ran over the walls). A grid of
## N by N squares lies over the mould (arcade/gumdrop_mould.gd) and each
## square is a bit of jelly holding some red, yellow and blue pigment: its
## concentration, with no top to it. The dropper's tip squeezes liquid into
## the jelly under it. The liquid is pressed from square to square down its
## own gradient, as it is through the pores of a gel, carrying the pigment
## with it, and the jelly drinks it as it goes (`SOAK`), so the colour
## blooms from the tip at a steady pace while the button is held and comes
## to rest once it is let go; after that it only diffuses (`DIFF`), soft
## and slow, through its square's neighbours. A wall lets nothing through,
## nor does the rim: the jelly's grain (`perm`) is uneven, so a bloom's
## edge is ragged, never a disc.
##
## More pigment is a stronger colour, with nothing to stop it: a square's
## strength is 1 - exp(-c / C0) (how a dye darkens with its concentration),
## full at C_FULL, the card's own shade, and deeper than the card past it.
## A run is mould after mould with no clock. Each is judged when it is
## served: how near each square's colour is to the card's, as a share of
## the way from clear to it. Under the level's mark the run is over. The
## match is not shown while the mould is played.

const Mould = preload("res://arcade/gumdrop_mould.gd")

enum Phase { READY, PLAY, SETTLE, SHOW, OVER }

const DT := 1.0 / 60.0
## Squares a side, and mould units a square.
const N := 36
const CELL := Mould.SIDE / N
## The liquid: how much of the difference between two squares is pressed
## across in a pass, how much of what a square holds may leave by one side
## in a pass, and how many passes a step.
const FLOW := 0.22
const LEAVE := 0.2
const PASSES := 2
## How much pigment the jelly holds back against the liquid that carries
## it: the colour's front trails the liquid's, dense at the tip and soft at
## its edge.
const HOLD := 0.35
## The share of the liquid the jelly drinks a step: how far a bloom reaches
## while the button is held, and how soon it rests once let go.
const SOAK := 0.02
## Pigment diffusing between neighbouring squares, a share of their
## difference a step: the slow evening out after the liquid has rested.
## Under STILL of it a square of the mould moved in a step the jelly counts
## as still.
const DIFF := 0.06
const STILL := 0.0006
## How uneven the jelly's grain is: a square's permeability is one, more or
## less this much.
const GRAIN := 0.45
## Concentration: at C0 a square is 63% of the way to the card's shade, at
## C_FULL it is the card's shade, and at 2 x C_FULL it is DEEP darker.
const C0 := 0.5
const C_FULL := 1.25
const DEEP := 0.45
## Liquid a second out of the dropper (a square of it is a concentration of
## one), and how many squares from its tip it lands in.
const RATE := 90.0
const TIP := 1.6
## The mark a mould has to be served at: at level 1, a level's more, the top.
const MARK := 60
const MARK_STEP := 2
const MARK_TOP := 80
## At this and over a mould is perfect, and is worth this much more.
const PERFECT := 95
const PERFECT_BONUS := 50
## Seconds: the syrup left to settle before it is judged, and the verdict
## shown.
const SETTLE_T := 0.7
const SHOW_T := 2.4
## The boosters: a softer jelly drinks the liquid this much slower, so a
## bloom reaches further; a kinder mark is this much lower.
const SOFTER := 0.5
const KINDER := 10
## The six flavours' colours, in Mould.Flavour's order, and all three
## pigments at once. The screen's art reads them from here.
const FLAVOURS := [Color("e2495a"), Color("f39237"), Color("f4d44a"), Color("79c94f"), Color("4a86df"), Color("9a62d2")]
const MUD := Color("7a5a48")
## The grain's lattice: this many knots a side, read between.
const KNOTS := 7

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
## Liquid squeezed out this mould, in squares.
var poured := 0.0
## Which cell each square is in (-1 the tray), and how many squares each
## cell has.
var reg := PackedInt32Array()
var count := PackedInt32Array()
## The liquid pressed into each square and not yet drunk, its three
## pigments, and how freely its jelly lets the liquid through.
var liq := PackedFloat32Array()
var red := PackedFloat32Array()
var yel := PackedFloat32Array()
var blu := PackedFloat32Array()
var perm := PackedFloat32Array()
## The pairs of squares side by side in one cell, and how freely the pair
## passes.
var _ea := PackedInt32Array()
var _eb := PackedInt32Array()
var _ek := PackedFloat32Array()
## Each cell's match, 0 to 1, and the whole mould's, as of `measure()`.
var cell_match := PackedFloat32Array()
var match_all := 0.0
## True while anything is still running, and how much moved in the last
## step.
var moving := false
var last_moved := 0.0
var soak := SOAK
var kinder := 0
var _squares := 1

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
	soak = SOAK * SOFTER

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

## The colour a square of jelly shows with this pigment in it: the hue at
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

## How near a square's colour is to a flavour's, 1 at it, 0 clear: its
## distance to the flavour against the way from clear to the flavour.
static func nearness(col: Color, flavour: int) -> float:
	var want: Color = FLAVOURS[flavour]
	var shown := Color.WHITE.lerp(Color(col.r, col.g, col.b), col.a)
	var way := Vector3(1.0 - want.r, 1.0 - want.g, 1.0 - want.b).length()
	var off := Vector3(shown.r - want.r, shown.g - want.g, shown.b - want.b).length()
	return 1.0 - clampf(off / way, 0.0, 1.0)

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
	_squares = 1
	for c in count:
		_squares += c
	liq.resize(N * N)
	liq.fill(0.0)
	red = liq.duplicate()
	yel = liq.duplicate()
	blu = liq.duplicate()
	_grain()
	_ea.clear()
	_eb.clear()
	_ek.clear()
	for i in N * N:
		if reg[i] < 0:
			continue
		if i % N < N - 1 and reg[i + 1] == reg[i]:
			_edge(i, i + 1)
		if i / N < N - 1 and reg[i + N] == reg[i]:
			_edge(i, i + N)
	cell_match.resize(cells.size())
	cell_match.fill(0.0)
	match_all = 0.0
	pots.clear()
	for f: int in mould.pots:
		pots.append({"flavour": f})
	picked = 0
	tip = centre_of(0)
	squeezing = false
	moving = false
	poured = 0.0

func _edge(a: int, b: int) -> void:
	_ea.append(a)
	_eb.append(b)
	var pa := perm[a]
	var pb := perm[b]
	_ek.append(2.0 * pa * pb / (pa + pb))

## The jelly's grain: each square's permeability, read between the knots
## of a lattice of random heights, so it varies smoothly and differs from
## one jelly to the next.
func _grain() -> void:
	var knots := PackedFloat32Array()
	knots.resize(KNOTS * KNOTS)
	for k in knots.size():
		knots[k] = rng.randf()
	perm.resize(N * N)
	for i in N * N:
		var fx := float(i % N) / N * (KNOTS - 1)
		var fy := float(i / N) / N * (KNOTS - 1)
		var x0 := mini(int(fx), KNOTS - 2)
		var y0 := mini(int(fy), KNOTS - 2)
		var u := fx - x0
		var v := fy - y0
		# smoothed, so the grain has no corners
		u = u * u * (3.0 - 2.0 * u)
		v = v * v * (3.0 - 2.0 * v)
		var top := lerpf(knots[x0 + y0 * KNOTS], knots[x0 + 1 + y0 * KNOTS], u)
		var low := lerpf(knots[x0 + (y0 + 1) * KNOTS], knots[x0 + 1 + (y0 + 1) * KNOTS], u)
		perm[i] = 1.0 + (lerpf(top, low, v) - 0.5) * 2.0 * GRAIN

## The square a point of the mould lies in.
static func square(p: Vector2) -> int:
	return clampi(int(p.x / CELL), 0, N - 1) + clampi(int(p.y / CELL), 0, N - 1) * N

static func at(i: int) -> Vector2:
	return Vector2((i % N) + 0.5, (i / N) + 0.5) * CELL

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
	events.append({"type": "serve"})

# --- a step ---

func step() -> void:
	phase_t += DT
	match phase:
		Phase.READY, Phase.PLAY:
			if squeezing:
				_inject()
			if phase == Phase.PLAY:
				t += DT
				_flow()
		Phase.SETTLE:
			_flow()
			if phase_t >= SETTLE_T:
				_judge()
		Phase.SHOW:
			_flow()
			if phase_t >= SHOW_T:
				_after()

## The liquid out of the tip into the jelly under it: the squares of the
## tip's own cell within its reach. Over a wall or the tray nothing is
## squeezed, since there is no jelly there to take it.
func _inject() -> void:
	var home := square(tip)
	var cell := reg[home]
	if cell < 0:
		return
	if phase == Phase.READY:
		phase = Phase.PLAY
		phase_t = 0.0
		events.append({"type": "go"})
	var into := PackedInt32Array()
	var cx := home % N
	var cy := home / N
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= N or y >= N:
				continue
			var i := x + y * N
			if reg[i] == cell and at(i).distance_to(tip) <= TIP * CELL:
				into.append(i)
	if into.is_empty():
		into.append(home)
	var out := RATE * DT
	poured += out
	var each := out / into.size()
	var pig: Vector3 = Mould.PIGMENT[int(pots[picked].flavour)]
	for i in into:
		liq[i] += each
		red[i] += each * pig.x
		yel[i] += each * pig.y
		blu[i] += each * pig.z
	moving = true

func _flow() -> void:
	if not moving:
		return
	var moved := 0.0
	for pass_i in PASSES:
		moved += _flow_once(pass_i == PASSES - 1)
	last_moved = moved
	# the jelly drinks what has not yet been drunk
	var wet_still := 0.0
	var k := 1.0 - soak
	for i in N * N:
		var l := liq[i]
		if l > 0.0:
			l = l * k if l > 0.0002 else 0.0
			liq[i] = l
			wet_still += l
	# the diffusion never quite ends: under this much pigment moved a square
	# of the mould in a step, nothing of it shows, and the jelly is still
	if moved < STILL * _squares and wet_still < 0.01 and not squeezing:
		moving = false

## One pass over every pair of neighbouring squares in a cell: the liquid
## pressed from the wetter to the drier, carrying pigment, and on the last
## pass of a step the pigment diffusing from the stronger to the weaker.
## Returns how much moved.
func _flow_once(diffuse: bool) -> float:
	var moved := 0.0
	for e in _ea.size():
		var a := _ea[e]
		var b := _eb[e]
		var la := liq[a]
		var lb := liq[b]
		var k := _ek[e]
		if la != lb:
			if la < lb:
				var s := a
				a = b
				b = s
				var ls := la
				la = lb
				lb = ls
			# a to b: the wetter to the drier
			var f := minf(FLOW * k * (la - lb), la * LEAVE)
			if f > 0.00002:
				var part := f / (la + HOLD)
				var r := red[a] * part
				var y := yel[a] * part
				var u := blu[a] * part
				red[a] -= r
				yel[a] -= y
				blu[a] -= u
				liq[a] -= f
				red[b] += r
				yel[b] += y
				blu[b] += u
				liq[b] += f
				moved += f
		if not diffuse:
			continue
		var ra := red[a]
		var ya := yel[a]
		var ua := blu[a]
		var rb := red[b]
		var yb := yel[b]
		var ub := blu[b]
		if ra + ya + ua + rb + yb + ub <= 0.0:
			continue
		var d := DIFF * k
		var dr := (ra - rb) * d
		var dy := (ya - yb) * d
		var du := (ua - ub) * d
		red[a] = ra - dr
		red[b] = rb + dr
		yel[a] = ya - dy
		yel[b] = yb + dy
		blu[a] = ua - du
		blu[b] = ub + du
		moved += absf(dr) + absf(dy) + absf(du)
	return moved

## Each cell's match and the mould's whole: `cell_match`, `match_all`. The
## match of a square is how near its colour is to its cell's flavour; a
## cell's is the mean of its squares', the mould's of all of them.
func measure() -> float:
	var cells := count.size()
	var sum := PackedFloat32Array()
	sum.resize(cells)
	sum.fill(0.0)
	var want: Array = mould.want
	for i in N * N:
		var c := reg[i]
		if c < 0:
			continue
		var r := red[i]
		var y := yel[i]
		var b := blu[i]
		if r + y + b <= 0.0:
			continue
		sum[c] += nearness(colour(r, y, b), int(want[c]))
	var total := 0.0
	var squares := 0
	for c in cells:
		squares += count[c]
		cell_match[c] = sum[c] / maxf(1.0, float(count[c]))
		total += sum[c]
	match_all = clampf(total / maxf(1.0, float(squares)), 0.0, 1.0)
	return match_all

## The mean concentration of a cell, and the least of any square in it.
func fill_of(c: int) -> Vector2:
	var sum := 0.0
	var least := 1e9
	for i in N * N:
		if reg[i] != c:
			continue
		var v := red[i] + yel[i] + blu[i]
		sum += v
		least = minf(least, v)
	return Vector2(sum / maxf(1.0, float(count[c])), least if least < 1e9 else 0.0)

func _judge() -> void:
	measure()
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
	events.append({"type": "revive"})
