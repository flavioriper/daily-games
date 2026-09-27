extends RefCounted

## Molehill as pure data (spec
## docs/superpowers/specs/2026-09-27-arcade-molehill-design.md): twelve
## molehills in a garden, three across and four down, and a minute on the
## clock. Moles pop up and sink again; a tap on one that is up whacks it.
## The screen (arcade/molehill_screen.gd) calls `whack()` with the hill a
## finger came down on and `step()` at the fixed DT, and drains `events`.
##
## After the arcade cabinet's rules: the pace rises as the minute runs, each
## mole staying up for less and more of them up at once, and the game ends
## on the clock whatever the score. Kept from the phone versions: a golden
## mole worth five, a mole in a flowerpot that takes two whacks, a rabbit
## that must be left alone, and a streak that multiplies the score and is
## broken by a mole let go, a whack at an empty hill or a whacked rabbit.

enum Kind { MOLE, GOLD, POT, BUNNY }
## A hill's mole: down in the hole, coming up, up, going down, or knocked
## dizzy by a whack (which then sinks).
enum St { EMPTY, RISE, UP, SINK, BONKED }
enum Phase { READY, PLAY, OVER }

const DT := 1.0 / 60.0
const COLS := 3
const ROWS := 4
const HILLS := COLS * ROWS
## The field in its own units, three hills across and four down.
const W := 300.0
const H := 420.0
const ROUND := 60.0
const READY_TIME := 1.8
## The last stretch of the minute, when every whack counts double.
const FRENZY := 10.0
const RISE_TIME := 0.14
const SINK_TIME := 0.16
const BONK_TIME := 0.5
## A hill rests this long after its mole goes down before it can come up.
const REST := 0.35
## A mole whacked in the first part of its time up earns a quick bonus.
const QUICK_PART := 0.4
const QUICK := 5
const POINTS := {Kind.MOLE: 10, Kind.GOLD: 50, Kind.POT: 25}
const BUNNY_COST := 30
## The streak's multiplier steps: x2 at 5, x3 at 12, x4 at 20.
const STEPS := [5, 12, 20]

var rng := RandomNumberGenerator.new()
var phase := Phase.READY
var phase_t := 0.0
## Seconds of the round played.
var t := 0.0
var score := 0
var streak := 0
var best_streak := 0
var whacked := 0
var escaped := 0
var missed := 0
var bunnies := 0
var taps := 0
var golds := 0
var events: Array = []
## One a hill: {kind, st, t (in this state), up (its time up), hp, rest}.
var hills: Array = []
var _next := 0.6

func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for i in HILLS:
		hills.append({"kind": Kind.MOLE, "st": St.EMPTY, "t": 0.0, "up": 1.0, "hp": 1, "rest": 0.0, "hit_t": 0.0, "done": false})
	events.append({"type": "ready"})

func is_over() -> bool:
	return phase == Phase.OVER

func time_left() -> float:
	return maxf(0.0, ROUND - t)

func frenzy() -> bool:
	return phase == Phase.PLAY and time_left() <= FRENZY

## How far through the round, 0 to 1: every pace reads it.
func pace() -> float:
	return clampf(t / ROUND, 0.0, 1.0)

func multiplier() -> int:
	var m := 1
	for s: int in STEPS:
		if streak >= s:
			m += 1
	return m

## Where a hill's hole is, in field units.
static func hill_pos(i: int) -> Vector2:
	var c := i % COLS
	var r := int(i / float(COLS))
	return Vector2(W * (c + 0.5) / COLS, H * (r + 0.7) / ROWS)

## The hill under a point, or -1: a generous box round each hole, taller
## above it where the mole stands.
static func hill_at(p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in HILLS:
		var h := hill_pos(i)
		var d := p - h
		if absf(d.x) > W / COLS * 0.5 or d.y > 34.0 or d.y < -80.0:
			continue
		var dist := d.length_squared()
		if dist < best_d:
			best_d = dist
			best = i
	return best

func step() -> void:
	phase_t += DT
	match phase:
		Phase.READY:
			if phase_t >= READY_TIME:
				phase = Phase.PLAY
				phase_t = 0.0
				events.append({"type": "go"})
		Phase.PLAY:
			var was_left := time_left()
			t += DT
			var left := time_left()
			if was_left > FRENZY and left <= FRENZY:
				events.append({"type": "frenzy"})
			if left < 5.0 and int(ceilf(was_left)) != int(ceilf(left)):
				events.append({"type": "tick", "left": int(ceilf(left))})
			_step_hills()
			_spawn()
			if left <= 0.0:
				phase = Phase.OVER
				phase_t = 0.0
				for h: Dictionary in hills:
					if h.st == St.RISE or h.st == St.UP:
						_put(h, St.SINK)
				events.append({"type": "time_up"})
		Phase.OVER:
			_step_hills()

func _put(h: Dictionary, st: int) -> void:
	h.st = st
	h.t = 0.0

func _step_hills() -> void:
	for i in HILLS:
		var h: Dictionary = hills[i]
		h.t += DT
		match int(h.st):
			St.EMPTY:
				h.rest = maxf(0.0, h.rest - DT)
			St.RISE:
				if h.t >= RISE_TIME:
					_put(h, St.UP)
			St.UP:
				if h.t >= h.up:
					_put(h, St.SINK)
					# A mole let go breaks the streak; a rabbit let go is right.
					if h.kind != Kind.BUNNY and phase == Phase.PLAY:
						escaped += 1
						events.append({"type": "escape", "hill": i})
						_break("escape", i)
			St.SINK:
				if h.t >= SINK_TIME:
					_put(h, St.EMPTY)
					h.rest = REST
			St.BONKED:
				if h.t >= BONK_TIME:
					_put(h, St.SINK)

## How many are up at once, and how often a new one comes, by the pace:
## one at a time and a slow beat at the start, four and a quick beat at
## the end.
func up_most() -> int:
	return 1 + int(pace() * 3.6)

func _spawn() -> void:
	_next -= DT
	if _next > 0.0:
		return
	var p := pace()
	_next = lerpf(0.85, 0.28, p) * rng.randf_range(0.75, 1.25)
	if frenzy():
		_next *= 0.8
	var up := 0
	var free: Array = []
	for i in HILLS:
		var h: Dictionary = hills[i]
		if h.st == St.EMPTY:
			if h.rest <= 0.0:
				free.append(i)
		elif h.st != St.SINK:
			up += 1
	if up >= up_most() or free.is_empty():
		_next = 0.08
		return
	var i: int = free[rng.randi_range(0, free.size() - 1)]
	var h: Dictionary = hills[i]
	var kind := Kind.MOLE
	var roll := rng.randf()
	if t > 8.0 and roll < 0.12 + 0.06 * p:
		kind = Kind.BUNNY
	elif t > 4.0 and roll < 0.19 + 0.06 * p:
		kind = Kind.GOLD
	elif t > 15.0 and roll < 0.34 + 0.08 * p:
		kind = Kind.POT
	var stay := lerpf(1.15, 0.5, p) * rng.randf_range(0.85, 1.15)
	match kind:
		Kind.GOLD:
			stay *= 0.62
		Kind.POT:
			stay *= 1.35
		Kind.BUNNY:
			stay *= 1.1
	h.kind = kind
	h.up = stay
	h.hp = 2 if kind == Kind.POT else 1
	h.hit_t = -1.0
	h.done = false
	_put(h, St.RISE)
	events.append({"type": "up", "hill": i, "kind": kind})

## A whack at hill `i` (-1: somewhere that is no hill). Returns what it
## did: "miss", "hit", "clang" (a pot knocked, not yet off), "bunny".
func whack(i: int) -> String:
	if phase != Phase.PLAY:
		return ""
	taps += 1
	if i < 0 or i >= HILLS:
		missed += 1
		_break("miss", i)
		return "miss"
	var h: Dictionary = hills[i]
	var hittable: bool = not h.done and (h.st == St.RISE or h.st == St.UP or (h.st == St.SINK and h.t < SINK_TIME * 0.5))
	if not hittable:
		missed += 1
		_break("miss", i)
		events.append({"type": "miss", "hill": i})
		return "miss"
	if h.kind == Kind.BUNNY:
		bunnies += 1
		score = maxi(0, score - BUNNY_COST)
		h.done = true
		_put(h, St.BONKED)
		events.append({"type": "bunny", "hill": i, "points": -BUNNY_COST})
		_break("bunny", i)
		return "bunny"
	if h.kind == Kind.POT and h.hp > 1:
		h.hp -= 1
		h.hit_t = 0.0
		# A knocked pot stays up a little longer, for the second whack.
		if h.st == St.SINK:
			_put(h, St.UP)
		h.up = maxf(h.up, h.t + 0.45)
		events.append({"type": "clang", "hill": i})
		return "clang"
	var quick: bool = h.st == St.RISE or (h.st == St.UP and h.t < h.up * QUICK_PART)
	var before := multiplier()
	streak += 1
	best_streak = maxi(best_streak, streak)
	whacked += 1
	if h.kind == Kind.GOLD:
		golds += 1
	var base: int = POINTS[h.kind] + (QUICK if quick else 0)
	var gain := base * multiplier() * (2 if frenzy() else 1)
	score += gain
	h.done = true
	_put(h, St.BONKED)
	events.append({"type": "hit", "hill": i, "kind": h.kind, "points": gain, "quick": quick})
	if multiplier() > before:
		events.append({"type": "combo", "hill": i, "mult": multiplier()})
	return "hit"

func _break(why: String, i: int) -> void:
	if streak >= STEPS[0]:
		events.append({"type": "streak_lost", "hill": i, "why": why, "streak": streak})
	streak = 0

## Up, as a fraction of a mole's height (0 in the hole, 1 standing), for
## drawing: eased on the way up and down, still while it stands or reels.
func rise(i: int) -> float:
	var h: Dictionary = hills[i]
	match int(h.st):
		St.RISE:
			var k := clampf(h.t / RISE_TIME, 0.0, 1.0)
			return 1.0 - (1.0 - k) * (1.0 - k)
		St.UP, St.BONKED:
			return 1.0
		St.SINK:
			var k := clampf(h.t / SINK_TIME, 0.0, 1.0)
			return 1.0 - k * k
	return 0.0
