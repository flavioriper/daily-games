extends RefCounted

## Beeline as pure data (spec
## docs/superpowers/specs/2026-10-09-arcade-beeline-design.md): a bee flown
## along a garden through the gaps in its hedges. A tap is one beat of the
## wings; left alone she sinks. The screen (arcade/beeline_screen.gd) calls
## `flap()` when a finger comes down and `step()` at the fixed DT, and drains
## `events`.
##
## The rules are the tap-to-fly game's, kept whole: a beat sets her rise to
## one fixed speed (it is never added to the last), the pull down is
## constant, the garden passes at one speed for the whole run, the hedges
## stand evenly apart with a gap of one height at a random place, a gap
## passed is one point, and a hedge or the ground touched ends the run. The
## numbers are the common ones of that game's 288 x 512 field (a gap of 100
## in 400 of sky, hedges 52 wide), with two kindnesses of this garden's own:
## the first gaps are wider and close to that size by the twentieth, and a
## gap is never further from the last than a bee can climb or sink between
## them. The sky's top holds her and costs nothing.
##
## Everything is in field units: y runs down from the sky's top (0) to the
## ground (H); x is how far along the garden, and the screen follows `x`.

enum Phase { READY, PLAY, FALL, OVER }

const DT := 1.0 / 120.0
## The sky's height above the ground.
const H := 400.0
## Her pull down, the rise one beat gives, and the fastest she sinks.
const GRAVITY := 900.0
const FLAP_V := -270.0
const MAX_FALL := 300.0
## How fast the garden passes.
const SPEED := 120.0
## A hedge's width, and from one hedge's front to the next's.
const GATE_W := 52.0
const SPACING := 150.0
## The gap's height, wide at first and closing over the first gates.
const GAP := 100.0
const GAP_FIRST := 126.0
const GAP_CLOSES := 20
## A gap's middle keeps this far from the sky's top and from the ground, and
## moves no more than this from the last one's.
const EDGE := 46.0
const MAX_STEP := 80.0
## The bee: where she hovers before the first beat, and the round body the
## hedges are weighed against (smaller than she is drawn, on purpose).
const START_Y := 180.0
const R := 10.0
## The first hedge stands this far ahead of her.
const LEAD := 330.0
## A ribbon at each of these scores.
const RIBBONS := [10, 20, 30, 40]
## The dewdrop (arcade/boosters.gd): after it bursts she passes through
## everything for this long. A Second chance gives the same.
const GHOST := 1.6
## Wide gates (arcade/boosters.gd): this much wider.
const WIDE_BY := 30.0

var rng := RandomNumberGenerator.new()
var phase := Phase.READY
## Seconds in this phase.
var phase_t := 0.0
## Seconds of flight.
var t := 0.0
var x := 0.0
var y := START_Y
var v := 0.0
var score := 0
var flaps := 0
## The ribbons won, 0 to 4.
var ribbons := 0
## Dewdrops held, the gates still to stand wide, and the seconds left of
## passing through things (arcade/boosters.gd).
var dew := 0
var wide := 0
var ghost := 0.0
var events: Array = []
## The hedges ahead and just behind: {x (its front), cy, gap, n, passed}.
var gates: Array = []
var _made := 0
var _last_cy := START_Y

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_grow()
	events.append({"type": "ready"})

func is_over() -> bool:
	return phase == Phase.OVER

## The gap of gate `n` (from 0), before a booster widens it.
static func gap_of(n: int) -> float:
	return lerpf(GAP_FIRST, GAP, clampf(float(n) / GAP_CLOSES, 0.0, 1.0))

## The ribbons a score has earned.
static func ribbons_of(points: int) -> int:
	var n := 0
	for need: int in RIBBONS:
		if points >= need:
			n += 1
	return n

## The next gate she has not passed, or an empty one.
func next_gate() -> Dictionary:
	for g: Dictionary in gates:
		if not g.passed:
			return g
	return {}

## One beat of the wings. The first one of a run sets the garden moving.
func flap() -> void:
	if phase == Phase.READY:
		phase = Phase.PLAY
		phase_t = 0.0
		events.append({"type": "go"})
	if phase != Phase.PLAY:
		return
	v = FLAP_V
	flaps += 1
	events.append({"type": "flap"})

func step() -> void:
	phase_t += DT
	match phase:
		Phase.PLAY:
			_fly()
		Phase.FALL:
			v = minf(v + GRAVITY * DT, MAX_FALL * 1.6)
			y += v * DT
			if y >= H - R:
				y = H - R
				_land()

func _fly() -> void:
	t += DT
	ghost = maxf(0.0, ghost - DT)
	x += SPEED * DT
	v = minf(v + GRAVITY * DT, MAX_FALL)
	y += v * DT
	if y < R:
		y = R
		v = maxf(v, 0.0)
	for g: Dictionary in gates:
		if not g.passed and x - R > g.x + GATE_W:
			g.passed = true
			score += 1
			events.append({"type": "pass", "n": score, "cy": g.cy})
			var won := ribbons_of(score)
			if won > ribbons:
				ribbons = won
				events.append({"type": "ribbon", "tier": won})
	_grow()
	if y >= H - R:
		y = H - R
		if not _saved("ground"):
			_land()
		return
	if ghost > 0.0:
		return
	for g: Dictionary in gates:
		var side := _touch(g)
		if side != "":
			if not _saved(side):
				phase = Phase.FALL
				phase_t = 0.0
				v = -120.0
				events.append({"type": "bump", "side": side})
			return

## Which half of a gate her body is in: "top", "bottom" or "".
func _touch(g: Dictionary) -> String:
	if x + R <= g.x or x - R >= g.x + GATE_W:
		return ""
	var top: float = g.cy - g.gap * 0.5
	var bottom: float = g.cy + g.gap * 0.5
	# the nearest point of each hedge's box to her middle
	var nx := clampf(x, g.x, g.x + GATE_W)
	if Vector2(nx - x, minf(y, top) - y).length() < R:
		return "top"
	if Vector2(nx - x, maxf(y, bottom) - y).length() < R:
		return "bottom"
	return ""

## A dewdrop bursts in place of the bump, and lifts her off the ground.
func _saved(side: String) -> bool:
	if ghost > 0.0 and side != "ground":
		return true
	if dew <= 0 and not (ghost > 0.0 and side == "ground"):
		return false
	if ghost <= 0.0:
		dew -= 1
		ghost = GHOST
		events.append({"type": "dew", "side": side})
	if side == "ground":
		v = FLAP_V
	return true

func _land() -> void:
	v = 0.0
	phase = Phase.OVER
	phase_t = 0.0
	events.append({"type": "land"})
	events.append({"type": "over"})

## The Second chance: the hedge she met is taken away, she hovers level with
## the next gap, and the next beat goes on from there.
func revive() -> void:
	if phase != Phase.OVER and phase != Phase.FALL:
		return
	gates = gates.filter(func(g: Dictionary) -> bool: return g.passed or g.x > x + SPACING * 0.5)
	var g := next_gate()
	y = clampf(float(g.get("cy", START_Y)), EDGE, H - EDGE)
	v = 0.0
	ghost = GHOST
	phase = Phase.READY
	phase_t = 0.0
	events.append({"type": "revive"})

## Wide gates (arcade/boosters.gd): the first `n` hedges stand wider. Asked
## before the first beat, so the hedges already grown are grown again.
func start_wide(n: int) -> void:
	wide = n
	gates.clear()
	_made = 0
	_last_cy = START_Y
	_grow()

## Hedges enough ahead of her, and the ones long behind let go.
func _grow() -> void:
	while gates.is_empty() or float(gates[-1].x) < x + 900.0:
		var gx := x + LEAD if gates.is_empty() else float(gates[-1].x) + SPACING
		var gap := gap_of(_made)
		if wide > 0:
			wide -= 1
			gap += WIDE_BY
		var lo := EDGE + gap * 0.5
		var hi := H - EDGE - gap * 0.5
		var cy := rng.randf_range(maxf(lo, _last_cy - MAX_STEP), minf(hi, _last_cy + MAX_STEP))
		gates.append({"x": gx, "cy": cy, "gap": gap, "n": _made, "passed": false})
		_made += 1
		_last_cy = cy
	while gates.size() > 1 and float(gates[0].x) < x - 500.0:
		gates.pop_front()
