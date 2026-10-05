extends RefCounted

## Mini Golf's rules, scene-free: the day's course and the card kept on it.
## puzzles/minigolf2d.gd draws this and nothing else decides anything; the
## ball's physics is puzzles/minigolf_sim.gd, one hole at a time.
##
## A course is `holes` mined holes of the band (puzzles/minigolf_gen.gd),
## played in order. Every putt is a stroke on the card, and the day is done
## when the ball is down the last cup: there is nothing to lose on Easy,
## Medium or Hard, only a score to keep under par. Insane (Swing Gates)
## counts strokes: the course's par and a few over, and the card closed
## before the last cup is the loss.

const Sim = preload("res://puzzles/minigolf_sim.gd")
const Gen = preload("res://puzzles/minigolf_gen.gd")

## Hints and hearts by band; Insane counts moves instead
## (docs/agents/flat-screens.md, "Insane counts moves").
const HINTS_BY := [3, 3, 2, 0]
const HEARTS_BY := [0, 0, 0, 0]
const MOVES_SLACK := [0, 0, 0, 3]
## How much of a putt's way the dotted aim shows, in field units.
const GUIDE_BY := [64.0, 52.0, 42.0, 30.0]

var band := 0
var holes: Array = []
var index := 0
## The strokes taken on each hole, 0 on one not yet played.
var card := PackedInt32Array()
## The hole in play.
var sim = Sim.new()
var done := false

static func hints_for(b: int) -> int:
	return HINTS_BY[clampi(b, 0, HINTS_BY.size() - 1)]

static func hearts_for(b: int) -> int:
	return HEARTS_BY[clampi(b, 0, HEARTS_BY.size() - 1)]

static func guide_for(b: int) -> float:
	return GUIDE_BY[clampi(b, 0, GUIDE_BY.size() - 1)]

## The strokes a band that counts moves hands out, 0 on one that does not:
## the course's par and the slack, or a quarter of the par if that is more.
func moves_budget() -> int:
	var slack: int = MOVES_SLACK[clampi(band, 0, MOVES_SLACK.size() - 1)]
	if slack <= 0:
		return 0
	return par_total() + maxi(slack, par_total() / 4)

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	lay(Gen.deal(rng, difficulty), difficulty)

## A course laid by hand (the tutorial's, a probe's).
func lay(course: Array, difficulty: int) -> void:
	band = clampi(difficulty, 0, HINTS_BY.size() - 1)
	holes = course
	restart()

## The course from the first tee, the card blank.
func restart() -> void:
	index = 0
	card = PackedInt32Array()
	card.resize(holes.size())
	done = false
	_tee()

func _tee() -> void:
	sim = Sim.new()
	sim.setup(holes[index])

func par_of(i: int) -> int:
	return int((holes[i] as Dictionary).get("par", 2))

func par() -> int:
	return par_of(index)

func par_total() -> int:
	var n := 0
	for i in holes.size():
		n += par_of(i)
	return n

## Every stroke on the card.
func total() -> int:
	var n := 0
	for k in card:
		n += k
	return n

## The card against par over the holes finished so far.
func over_par() -> int:
	var n := 0
	for i in holes.size():
		if i < index or (i == index and sim.sunk):
			n += card[i] - par_of(i)
	return n

func last_hole() -> bool:
	return index >= holes.size() - 1

func putt(angle: float, power: float) -> bool:
	if done or not sim.putt(angle, power):
		return false
	card[index] = sim.strokes
	return true

## One step of the roll; true while the ball moves. The last cup ends the
## day.
func step(events = null) -> bool:
	var rolling: bool = sim.step(events)
	if sim.sunk and last_hole():
		done = true
	return rolling

## On to the next tee. False on the last hole.
func next_hole() -> bool:
	if not sim.sunk or last_hole():
		return false
	index += 1
	_tee()
	return true

## The ball down the last cup, for a day reopened already played.
func finish() -> void:
	index = holes.size() - 1
	_tee()
	sim.p = sim.cup
	sim.sunk = true
	done = true

func is_solved() -> bool:
	return done
