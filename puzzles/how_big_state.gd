extends RefCounted

## How Big?'s rules as the board plays them, scene-free, as every flat
## board's are. The board (puzzles/how_big2d.gd) draws this and nothing else.
##
## A day is a few rounds. In each, one thing stands at a stated size (the
## ruler) and another beside it at a size that is plainly wrong; the player
## sizes the second until the two look right together, and locks. A lock is
## never taken back. The grade is how far off the guess was as a ratio, so
## twice too big and half too small score the same: within 6% is 100, five
## times off is nothing (`CURVE`).
##
## Nothing here can be lost up to Hard: the day ends when the last round is
## locked, and the score is the result. Insane is the Ladder: each thing the
## player sizes becomes the next round's ruler *at the size they gave it*, so
## a wrong rung bends every one after it -- and it has hearts, spent only on
## a lock the player watches miss by more than double (Trestle's reason:
## docs/agents/flat-screens.md, "Insane counts moves"). A rung that costs a
## heart is set straight before the next.

const TABLE := "res://content/how_big.json"
const SHAPES := "res://content/how_big_shapes.json"

const ROUNDS := [5, 5, 5, 7]
const HINTS_BY := [3, 2, 1, 0]
const HEARTS_BY := [0, 0, 0, 2]
## How far apart a round's two things may be, the bigger over the smaller,
## by band: [least, most]. Insane's is a rung of the Ladder.
const SPREAD := [[1.0, 2.0], [1.3, 3.2], [1.8, 4.6], [1.4, 3.2]]
## The grade: [ratio off, points], straight lines between them in the log of
## the ratio. Checked on 2026-10-08 against the game this follows (named in
## docs/agents/boards/how-big.md and nowhere else).
const CURVE := [[1.06, 100.0], [1.12, 90.0], [1.2, 78.0], [1.3333, 62.0], [2.0, 45.0], [3.0, 30.0], [5.0, 0.0]]
## A lock worse than this costs a heart where there are hearts.
const MISS_RATIO := 2.0
## A day this good is stamped: nine in ten of every point there was.
const SHARP := 0.9

# --- how a round is framed ---
## The ruler is never drawn smaller than this across its longer side, nor the
## answer smaller than twice the least the player can drag to.
const REF_MIN := 72.0
const DRAG_MIN := 30.0
## The ruler keeps to this much of the stage.
const REF_ROOM := Vector2(0.58, 0.6)
## The answer leaves at least this much room over it, and at most that much,
## so where the truth sits in the drag says nothing.
const HEAD_MIN := 1.9
const HEAD_MAX := 3.4

static var _items: Array = []
static var _shapes: Dictionary = {}
static var _read := false

var band := 0
## The day's rounds: [{"ref": item, "tgt": item}].
var rounds: Array = []
var index := 0
## What each locked round came to: {"guess", "truth", "score", "ratio", "missed"}.
var results: Array = []
## What the ruler is said to measure this round: its true size, or on the
## Ladder the size the player gave it.
var ref_m := 0.0
var hearts := 0
var hinted := false
var _lot := 0.0

# --- the table ---

static func _load() -> void:
	if _read:
		return
	_read = true
	var doc = JSON.parse_string(FileAccess.get_file_as_string(TABLE)) if FileAccess.file_exists(TABLE) else null
	var shapes = JSON.parse_string(FileAccess.get_file_as_string(SHAPES)) if FileAccess.file_exists(SHAPES) else null
	if not (doc is Dictionary) or not (shapes is Dictionary):
		return
	_shapes = shapes
	for it in doc.get("items", []):
		if it is Dictionary and _shapes.has(str(it.get("id", ""))) and float(it.get("size_m", 0.0)) > 0.0:
			_items.append(it)

static func items() -> Array:
	_load()
	return _items

static func item(id: String) -> Dictionary:
	for it: Dictionary in items():
		if str(it.id) == id:
			return it
	return {}

## {"w", "h", "loops", "tris"} in the shape's own units, y down.
static func shape(id: String) -> Dictionary:
	_load()
	return _shapes.get(id, {})

## The locale key of what `it`'s number measures when that is not simply
## its whole height or length ("at the shoulder" -> HB_WHAT_AT_THE_SHOULDER),
## "" when it is. The table's `what_en` is the English the key was cut from.
static func what_key(it: Dictionary) -> String:
	var what := str(it.get("what_en", "")).strip_edges().to_upper()
	if what == "":
		return ""
	var out := ""
	for ch in what:
		out += ch if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") else "_"
	return "HB_WHAT_" + out

## The locale key of the line about `it` that a reveal shows.
static func fact_key(it: Dictionary) -> String:
	return "HB_FACT_" + str(it.get("id", "")).to_upper()

static func is_tall(it: Dictionary) -> bool:
	return str(it.get("measure", "tall")) == "tall"

## The share of the shape's box the stated measure spans, along its axis.
static func span(it: Dictionary) -> float:
	return maxf(0.05, float(it.get("to", 1.0)) - float(it.get("from", 0.0)))

## The thing's whole box in metres when its measure reads `m`.
static func box_m(it: Dictionary, m: float) -> Vector2:
	var s := shape(str(it.id))
	var w := float(s.get("w", 1000.0))
	var h := float(s.get("h", 1000.0))
	var per_unit := m / (span(it) * (h if is_tall(it) else w))
	return Vector2(w, h) * per_unit

## How big a thing is, for pairing: its box's longer side in metres.
static func bigness(it: Dictionary) -> float:
	var b := box_m(it, float(it.size_m))
	return maxf(b.x, b.y)

# --- the grade ---

## How far off, the bigger over the smaller: 1 is exact.
static func ratio_off(guess: float, truth: float) -> float:
	if guess <= 0.0 or truth <= 0.0:
		return INF
	return maxf(guess / truth, truth / guess)

static func score_for(guess: float, truth: float) -> int:
	var r := ratio_off(guess, truth)
	if r <= float(CURVE[0][0]):
		return 100
	for k in range(1, CURVE.size()):
		if r <= float(CURVE[k][0]):
			var u := (log(r) - log(float(CURVE[k - 1][0]))) / (log(float(CURVE[k][0])) - log(float(CURVE[k - 1][0])))
			return int(round(lerpf(float(CURVE[k - 1][1]), float(CURVE[k][1]), u)))
	return 0

# --- the day ---

func setup(rng: RandomNumberGenerator, difficulty: int) -> void:
	band = clampi(difficulty, 0, 3)
	rounds = _ladder(rng) if band >= 3 else _pairs(rng)
	_lot = rng.randf()
	restart()

## A hand-picked day (the tutorial's pages): rounds as [ruler id, answer id].
func setup_fixed(difficulty: int, ids: Array, lot := 0.5) -> void:
	band = clampi(difficulty, 0, 3)
	rounds = []
	for pair: Array in ids:
		rounds.append({"ref": item(str(pair[0])), "tgt": item(str(pair[1]))})
	_lot = lot
	restart()

## The same day from the top.
func restart() -> void:
	index = 0
	results = []
	hearts = HEARTS_BY[band]
	hinted = false
	if not rounds.is_empty():
		ref_m = float(rounds[0].ref.size_m)

## Rounds of two things each, no thing twice in a day, each pair inside the
## band's spread; which of the two is the ruler is the lot's.
func _pairs(rng: RandomNumberGenerator) -> Array:
	var pool: Array = items().duplicate()
	var out: Array = []
	var want: int = ROUNDS[band]
	var lo: float = SPREAD[band][0]
	var hi: float = SPREAD[band][1]
	for _try in 400:
		if out.size() >= want or pool.size() < 2:
			break
		var a: Dictionary = pool[rng.randi() % pool.size()]
		var fits: Array = []
		for b: Dictionary in pool:
			if b == a:
				continue
			var r := bigness(a) / bigness(b)
			r = maxf(r, 1.0 / r)
			if r >= lo and r <= hi:
				fits.append(b)
		if fits.is_empty():
			continue
		var b2: Dictionary = fits[rng.randi() % fits.size()]
		pool.erase(a)
		pool.erase(b2)
		out.append({"ref": a, "tgt": b2})
	return out

## The Ladder: a climb from something small, each rung bigger than the last
## by the band's spread, found by a walk that backs out of dead ends.
func _ladder(rng: RandomNumberGenerator) -> Array:
	var all: Array = items().duplicate()
	all.sort_custom(func(a, b): return bigness(a) < bigness(b))
	var want: int = ROUNDS[band] + 1
	var starts: Array = all.slice(0, maxi(1, all.size() / 3))
	for _try in 60:
		var chain: Array = [starts[rng.randi() % starts.size()]]
		if _climb(rng, all, chain, want):
			var out: Array = []
			for k in range(1, chain.size()):
				out.append({"ref": chain[k - 1], "tgt": chain[k]})
			return out
	return _pairs(rng)

func _climb(rng: RandomNumberGenerator, all: Array, chain: Array, want: int) -> bool:
	if chain.size() >= want:
		return true
	var last: Dictionary = chain[chain.size() - 1]
	var next: Array = []
	for it: Dictionary in all:
		var r := bigness(it) / bigness(last)
		if r >= float(SPREAD[band][0]) and r <= float(SPREAD[band][1]):
			next.append(it)
	while not next.is_empty():
		var pick: Dictionary = next.pop_at(rng.randi() % next.size())
		chain.append(pick)
		if _climb(rng, all, chain, want):
			return true
		chain.pop_back()
	return false

func round_count() -> int:
	return rounds.size()

func ref() -> Dictionary:
	return rounds[index].ref if index < rounds.size() else {}

func tgt() -> Dictionary:
	return rounds[index].tgt if index < rounds.size() else {}

func truth() -> float:
	return float(tgt().get("size_m", 1.0))

## True once this round's lock is in and the next has not been dealt.
func locked() -> bool:
	return results.size() > index

func is_solved() -> bool:
	return not rounds.is_empty() and results.size() >= rounds.size() and (HEARTS_BY[band] == 0 or hearts > 0)

func total() -> int:
	var sum := 0
	for r: Dictionary in results:
		sum += int(r.score)
	return sum

func best_total() -> int:
	return 100 * rounds.size()

func sharp() -> bool:
	return total() >= int(ceil(SHARP * best_total()))

## Locks `guess` (what the answer's measure reads at the size it was left).
## {"score", "ratio", "missed", "over"}; {} when there is nothing to lock.
func lock(guess: float) -> Dictionary:
	if locked() or index >= rounds.size():
		return {}
	var t := truth()
	var r := ratio_off(guess, t)
	var missed: bool = HEARTS_BY[band] > 0 and r > MISS_RATIO
	if missed:
		hearts = maxi(0, hearts - 1)
	var out := {"guess": guess, "truth": t, "score": score_for(guess, t), "ratio": r,
		"missed": missed, "over": guess > t}
	results.append(out)
	return out

## Deals the next round. On the Ladder the thing just sized is the ruler, at
## the size the player gave it -- or its true one if that lock cost a heart.
func advance() -> bool:
	if not locked() or index + 1 >= rounds.size():
		return false
	var last: Dictionary = results[index]
	index += 1
	hinted = false
	ref_m = float(ref().size_m)
	if band >= 3 and not bool(last.missed):
		ref_m = float(last.guess)
	return true

## Puts a finished day back: the scores of each round, in order.
func finish(scores: Array, guesses: Array = []) -> void:
	restart()
	results = []
	for k in rounds.size():
		var t := float(rounds[k].tgt.size_m)
		var g := float(guesses[k]) if k < guesses.size() else t
		var s := int(scores[k]) if k < scores.size() else score_for(g, t)
		results.append({"guess": g, "truth": t, "score": s, "ratio": ratio_off(g, t), "missed": false, "over": g > t})
	index = maxi(0, rounds.size() - 1)
	ref_m = float(ref().get("size_m", 1.0))
	hearts = maxi(1, hearts)

## The bulb: which way the truth lies from `guess`: 1 bigger, -1 smaller, 0
## when it is already inside the 6% that scores everything.
func nudge(guess: float) -> int:
	hinted = true
	var t := truth()
	if ratio_off(guess, t) <= float(CURVE[0][0]):
		return 0
	return 1 if guess < t else -1

# --- the frame ---

## How the round stands on a stage of `stage` pixels: {"ppm": pixels a metre,
## "ref": the ruler's box in pixels, "max": the widest the answer's box may
## be dragged, "min": the least, "start": where it begins} -- the last three
## are the answer's box's longer side, in pixels.
func frame(stage: Vector2) -> Dictionary:
	var rb := box_m(ref(), ref_m)
	var tb := box_m(tgt(), truth())
	var t_long := maxf(tb.x, tb.y)
	var r_long := maxf(rb.x, rb.y)
	# The answer's longer side when its box fills the stage.
	var full := minf(stage.x / tb.x, stage.y / tb.y) * t_long
	var ppm_hi := minf(minf(stage.x * REF_ROOM.x / rb.x, stage.y * REF_ROOM.y / rb.y), full / (HEAD_MIN * t_long))
	var ppm_lo := maxf(maxf(REF_MIN / r_long, 2.0 * DRAG_MIN / t_long), full / (HEAD_MAX * t_long))
	var ppm := ppm_hi
	if ppm_lo < ppm_hi:
		# Toward the roomy end: a stage of two specks reads as empty.
		ppm = ppm_lo * pow(ppm_hi / ppm_lo, 0.35 + 0.65 * fposmod(_lot + 0.37 * index, 1.0))
	# Two things the same size would start the answer on the truth: begin it
	# well off, the lot's way.
	var start := r_long * ppm
	var true_px := t_long * ppm
	if ratio_off(start, true_px) < 1.25:
		start = true_px * (1.7 if fposmod(_lot * 7.0 + index, 1.0) < 0.5 and true_px * 1.7 < full else 0.55)
	return {"ppm": ppm, "ref": rb * ppm, "max": full, "min": DRAG_MIN,
		"start": clampf(start, DRAG_MIN, full)}

## What the answer's measure reads when its box's longer side is `px`.
func guess_at(px: float, ppm: float) -> float:
	var tb := box_m(tgt(), truth())
	return truth() * px / (maxf(tb.x, tb.y) * ppm)

func share_glyphs() -> String:
	var out := ""
	for r: Dictionary in results:
		var s := int(r.score)
		out += "🟩" if s >= 90 else ("🟨" if s >= 62 else ("🟧" if s >= 30 else "🟥"))
	return out
