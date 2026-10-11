extends RefCounted

## Gumdrop as pure data (spec
## docs/superpowers/specs/2026-10-10-arcade-gumdrop-design.md): a tray of
## clear jelly in a walled mould, and a dropper of syrup. The screen
## (arcade/gumdrop_screen.gd) hands it `pick()`, `aim()`, `squeeze()` and
## `serve()`, calls `step()` at the fixed DT and drains `events`.
##
## The syrup is a real one, on a grid of N by N squares laid over the mould
## (arcade/gumdrop_mould.gd). Each square holds a depth of red, yellow and
## blue pigment. Syrup runs from a deeper square to a shallower one beside
## it, carrying its colour, and nothing is moved by rule: it spreads from
## the dropper's tip, piles up there while it is squeezed, blends with what
## it meets, and runs over a wall only once it stands higher than the wall
## does (`wall`), into the next cell or out over the rim onto the tray.
## So a cell squeezed from its middle fills evenly, one squeezed beside a
## wall spills while it is still half empty, and a small cell wants the
## syrup a little at a time.
##
## A run is mould after mould with no clock. Each is judged when it is
## served: how full each cell is and how near its wanted flavour, less what
## lies on the tray. Under the level's mark the run is over.

const Mould = preload("res://arcade/gumdrop_mould.gd")

enum Phase { READY, PLAY, SETTLE, SHOW, OVER }

const DT := 1.0 / 60.0
## Squares a side, and mould units a square.
const N := 36
const CELL := Mould.SIDE / N
## How much of the difference between two squares runs across in a step,
## and how much of what a square holds may leave by one side in a step.
const FLOW := 0.22
const LEAVE := 0.2
## The syrup is run this many times a step: twice, it spreads twice as fast
## as one pass may carry it and stay steady, so the dropper can pour twice
## as fast without piling it over the walls.
const PASSES := 2
## How quickly two colours in touching squares blend.
const BLEND := 0.24
## A wall's height in depths, and the rim's.
const WALL_H := 1.0
const RIM_H := 1.15
## A cell this deep on average is full.
const FULL := 0.85
## Squares of syrup a second out of the dropper, and how many squares from
## its tip they land in.
const RATE := 48.0
const TIP := 1.6
## How much syrup the pots hold against what the mould wants: at level 1,
## what each level takes off, and the least.
const SLACK := 1.6
const SLACK_STEP := 0.04
const SLACK_MIN := 1.2
## The mark a mould has to be served at: at level 1, a level's more, the top.
const MARK := 60
const MARK_STEP := 2
const MARK_TOP := 80
## At this and over a mould is perfect, and is worth this much more.
const PERFECT := 95
const PERFECT_BONUS := 50
## How steeply a wrong colour costs a cell, and what syrup on the tray
## costs against the mould's whole.
const HUE_COST := 1.5
const TRAY_COST := 1.0
## A cell this near what it is wanted as has set.
const SET_AT := 0.9
## Seconds: the syrup left to settle before it is judged, the verdict
## shown, and how long pots all empty wait before the mould serves itself.
const SETTLE_T := 0.7
const SHOW_T := 2.4
const EMPTY_T := 1.6
## The boosters: the pots' more, and the walls' height.
const FULLER := 1.3
const TALLER := 1.3

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
## The pots: {flavour, left, full}.
var pots: Array = []
var picked := 0
## The dropper's tip, in mould units, and whether it is being squeezed.
var tip := Vector2(Mould.SIDE, Mould.SIDE) * 0.5
var squeezing := false
## Which cell each square is in (-1 the tray), and how many squares each
## cell has.
var reg := PackedInt32Array()
var count := PackedInt32Array()
## The depth in each square and its three pigments.
var depth := PackedFloat32Array()
var red := PackedFloat32Array()
var yel := PackedFloat32Array()
var blu := PackedFloat32Array()
## The pairs of squares side by side and the sill between each pair.
var _ea := PackedInt32Array()
var _eb := PackedInt32Array()
var _es := PackedFloat32Array()
## Each cell's match, 0 to 1, the whole mould's, and which cells have set.
var cell_match := PackedFloat32Array()
var match_all := 0.0
var is_set: Array = []
## True while anything is still running.
var moving := false
var wall := WALL_H
var pot_part := 1.0
var _tick := 0
var _spill_at := -10.0
var _empty_for := 0.0

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

static func slack_of(lv: int) -> float:
	return maxf(SLACK - SLACK_STEP * (lv - 1), SLACK_MIN)

func mark() -> int:
	return mark_of(level)

## The boosters (arcade/boosters.gd).
func fuller() -> void:
	pot_part = FULLER
	_fill_pots()

func taller() -> void:
	wall = TALLER
	_sills()

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
	depth.resize(N * N)
	depth.fill(0.0)
	red = depth.duplicate()
	yel = depth.duplicate()
	blu = depth.duplicate()
	_ea.clear()
	_eb.clear()
	for i in N * N:
		if i % N < N - 1:
			_ea.append(i)
			_eb.append(i + 1)
		if i / N < N - 1:
			_ea.append(i)
			_eb.append(i + N)
	_sills()
	cell_match.resize(cells.size())
	cell_match.fill(0.0)
	is_set.resize(cells.size())
	is_set.fill(false)
	match_all = 0.0
	_fill_pots()
	picked = 0
	tip = centre_of(0)
	squeezing = false
	moving = false
	_empty_for = 0.0

func _sills() -> void:
	_es.resize(_ea.size())
	for e in _ea.size():
		var a := reg[_ea[e]]
		var b := reg[_eb[e]]
		_es[e] = 0.0 if a == b else (RIM_H * wall if (a < 0 or b < 0) else wall)

## What the mould wants of each pot, and the pots filled to that and the
## level's slack over it.
func _fill_pots() -> void:
	var want := {}
	for c in count.size():
		var recipe: Dictionary = Mould.recipe(int(mould.want[c]), mould.pots)
		for f: int in recipe:
			want[f] = float(want.get(f, 0.0)) + float(recipe[f]) * count[c] * FULL
	pots.clear()
	for f: int in mould.pots:
		var full: float = float(want.get(f, 0.0)) * slack_of(level) * pot_part
		pots.append({"flavour": f, "left": full, "full": full})

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
		if on and not squeezing and float(pots[picked].left) <= 0.0:
			events.append({"type": "empty", "pot": picked})
		squeezing = on

func wet() -> bool:
	for p: Dictionary in pots:
		if float(p.left) < float(p.full) - 0.01:
			return true
	return false

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
				_watch()
		Phase.SETTLE:
			_flow()
			if phase_t >= SETTLE_T:
				_judge()
		Phase.SHOW:
			_flow()
			if phase_t >= SHOW_T:
				_after()

func _inject() -> void:
	var pot: Dictionary = pots[picked]
	if float(pot.left) <= 0.0:
		return
	if phase == Phase.READY:
		phase = Phase.PLAY
		phase_t = 0.0
		events.append({"type": "go"})
	var home := square(tip)
	var cell := reg[home]
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
	var out := minf(RATE * DT, float(pot.left))
	pot.left = float(pot.left) - out
	var each := out / into.size()
	var pig: Vector3 = Mould.PIGMENT[int(pot.flavour)]
	for i in into:
		depth[i] += each
		red[i] += each * pig.x
		yel[i] += each * pig.y
		blu[i] += each * pig.z
	moving = true
	if float(pot.left) <= 0.0:
		events.append({"type": "empty", "pot": picked})

func _flow() -> void:
	for pass_i in PASSES:
		if moving:
			_flow_once()

func _flow_once() -> void:
	var moved := 0.0
	var spilt := 0.0
	var spilt_at := -1
	var onto_tray := false
	for e in _ea.size():
		var a := _ea[e]
		var b := _eb[e]
		var ha := depth[a]
		var hb := depth[b]
		if ha <= 0.0005 and hb <= 0.0005:
			continue
		var sill := _es[e]
		if ha < hb:
			var s := a
			a = b
			b = s
			var hs := ha
			ha = hb
			hb = hs
		# a to b: the deeper to the shallower, over the sill between them
		var f := 0.0
		if ha > sill:
			f = minf(FLOW * (ha - maxf(hb, sill)), ha * LEAVE)
		if f > 0.00002:
			var part := f / ha
			var r := red[a] * part
			var y := yel[a] * part
			var u := blu[a] * part
			red[a] -= r
			yel[a] -= y
			blu[a] -= u
			depth[a] -= f
			red[b] += r
			yel[b] += y
			blu[b] += u
			depth[b] += f
			moved += f
			if sill > 0.0:
				spilt += f
				spilt_at = b
				onto_tray = onto_tray or reg[b] < 0
		elif sill == 0.0 and hb > 0.01:
			# level with each other: the two colours go on blending
			var k := BLEND * hb
			var ia := 1.0 / ha
			var ib := 1.0 / hb
			var dr := (red[a] * ia - red[b] * ib) * k
			var dy := (yel[a] * ia - yel[b] * ib) * k
			var du := (blu[a] * ia - blu[b] * ib) * k
			red[a] -= dr
			red[b] += dr
			yel[a] -= dy
			yel[b] += dy
			blu[a] -= du
			blu[b] += du
	if spilt > 0.002 and t - _spill_at > 0.6:
		_spill_at = t
		events.append({"type": "spill", "at": at(spilt_at), "tray": onto_tray})
	if moved < 0.0005 and not squeezing:
		moving = false

## Looks the mould over a few times a second while it is played: which
## cells have set, and whether the pots are all empty.
func _watch() -> void:
	_tick += 1
	if _tick % 10 != 0:
		return
	measure()
	for c in is_set.size():
		var now: bool = cell_match[c] >= SET_AT
		if now and not is_set[c]:
			events.append({"type": "set", "cell": c})
		is_set[c] = now
	var dry := true
	for p: Dictionary in pots:
		if float(p.left) > 0.0:
			dry = false
	_empty_for = _empty_for + DT * 10.0 if (dry and not moving) else 0.0
	if _empty_for >= EMPTY_T:
		serve()

## Each cell's match and the mould's whole: `cell_match`, `match_all`.
func measure() -> float:
	var cells := count.size()
	var sum := PackedFloat32Array()
	sum.resize(cells)
	sum.fill(0.0)
	var sr := sum.duplicate()
	var sy := sum.duplicate()
	var sb := sum.duplicate()
	var tray := 0.0
	for i in N * N:
		var d := depth[i]
		if d <= 0.0:
			continue
		var c := reg[i]
		if c < 0:
			tray += d
			continue
		sum[c] += minf(d, 1.0)
		sr[c] += red[i]
		sy[c] += yel[i]
		sb[c] += blu[i]
	var total := 0.0
	var squares := 0
	for c in cells:
		squares += count[c]
		var fill := clampf(sum[c] / (count[c] * FULL), 0.0, 1.0)
		var all := sr[c] + sy[c] + sb[c]
		var m := 0.0
		if all > 0.0:
			var want: Vector3 = Mould.PIGMENT[int(mould.want[c])]
			var off := 0.5 * (absf(sr[c] / all - want.x) + absf(sy[c] / all - want.y) + absf(sb[c] / all - want.z))
			m = fill * maxf(0.0, 1.0 - off * HUE_COST)
		cell_match[c] = m
		total += m * count[c]
	match_all = clampf((total - tray * TRAY_COST) / maxf(1.0, float(squares)), 0.0, 1.0)
	return match_all

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

## The Second chance: the mould that ended the run, clear again and its
## pots full.
func revive() -> void:
	if phase != Phase.OVER:
		return
	_lay()
	phase = Phase.PLAY
	phase_t = 0.0
	events.append({"type": "revive"})
