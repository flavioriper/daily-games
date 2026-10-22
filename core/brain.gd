class_name Brain
extends RefCounted

## The five skills the daily boards train, and the scores the win's brain
## report shows: worked out from Progress.solve_log() and never stored, as
## PlayerStats is. Spec: docs/superpowers/specs/2026-10-22-brain-skills-design.md.

const Registry = preload("res://ui/registry.gd")

## In the report's order; each wears Pal.CAT[index].
const SKILLS := ["logic", "space", "planning", "focus", "words"]
## Boards whose time says nothing about how well they were played (section 6's
## "T" column): their score is their own measure alone.
const UNTIMED := ["acorn", "how_big", "pearl", "drumbeat", "gumdrop", "minigolf"]
## A solve's score by level: the floor and the span its performance fills.
const BAND_FLOOR := [20.0, 35.0, 50.0, 60.0]
const BAND_SPAN := [40.0, 45.0, 45.0, 40.0]
## The skill score's moving average.
const ALPHA := 0.25
const HINT_COST := 0.15
const HINT_FLOOR := 0.4
## How many first timed solves set a board's starting pace.
const START_SOLVES := 3
## Below this quality, or this far over the usual time, the sharpen tip.
const WEAK_Q := 0.7
const SLOW := 1.25

static func skill_of(id: String) -> String:
	return String(Registry.find(id).get("skill", ""))

## The board's locale prefix ("SD" from "SD_BLURB"), which its tips share.
static func prefix(id: String) -> String:
	return String(Registry.find(id).get("blurb", "")).get_slice("_", 0)

static func icon(skill: String) -> String:
	return "skill_" + skill

## A solve's performance, 0..1, against the board's starting pace `start`
## (seconds; 0 when the board is untimed or has no timed solve).
static func perf(id: String, t: float, hints: int, q: float, start: float) -> float:
	var pt := -1.0
	if not id in UNTIMED and t > 0.0 and start > 0.0:
		pt = clampf(0.5 + 0.5 * log(start / t) / log(2.0), 0.0, 1.0)
	var p := 0.5
	if pt >= 0.0 and q >= 0.0:
		p = 0.5 * pt + 0.5 * q
	elif pt >= 0.0:
		p = pt
	elif q >= 0.0:
		p = q
	return p * maxf(HINT_FLOOR, 1.0 - HINT_COST * hints)

static func solve_score(difficulty: int, p: float) -> float:
	var d := clampi(difficulty, 0, 3)
	return BAND_FLOOR[d] + BAND_SPAN[d] * p

## Every record in the log in the order it was played, each with its date.
static func _ordered(log: Dictionary) -> Array:
	var keys := log.keys()
	keys.sort()
	var out := []
	for k in keys:
		for r in log[k]:
			if r is Dictionary:
				var rec: Dictionary = r.duplicate()
				rec["day"] = int(k)
				out.append(rec)
	return out

static func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var v := values.duplicate()
	v.sort()
	var n := v.size()
	return float(v[n / 2]) if n % 2 == 1 else (float(v[n / 2 - 1]) + float(v[n / 2])) * 0.5

## The report for one solve of `id` at `difficulty`.
## `current` is that solve: {"t", "h", "q"} and, when it was logged,
## "day" (its date key): a logged solve is found in the log and moves the
## skill; an unlogged one (a random New game, a reopened daily) does not.
## Returns: skill, scores (skill -> float, -1 untrained), before, after, gain,
## first (no earlier solve of this board at this level), mean_t, mean_h,
## count (earlier solves at this level), tip (1..4), lowest, suggest.
static func report(log: Dictionary, id: String, difficulty: int, current: Dictionary) -> Dictionary:
	var skill := skill_of(id)
	var ordered := _ordered(log)
	var logged := current.has("day")
	# The current solve's place in the log: the last record of this board and
	# level on its day.
	var at := -1
	if logged:
		for i in ordered.size():
			var r: Dictionary = ordered[i]
			if int(r.day) == int(current.day) and String(r.get("id", "")) == id and int(r.get("d", -1)) == difficulty:
				at = i
	var ema := {}
	var firsts := {}
	var solves_by_board := {}
	var before := -1.0
	var sum_t := 0.0
	var timed := 0
	var sum_h := 0.0
	var count := 0
	var board_solves := 0
	for i in ordered.size():
		var r: Dictionary = ordered[i]
		var rid := String(r.get("id", ""))
		var rd := int(r.get("d", 0))
		var rs := skill_of(rid)
		if rs == "":
			continue
		if i == at:
			before = float(ema.get(skill, -1.0))
		var key := "%s|%d" % [rid, rd]
		var t := float(r.get("t", 0.0))
		var firsts_here: Array = firsts.get_or_add(key, [])
		if t > 0.0 and firsts_here.size() < START_SOLVES:
			firsts_here.append(t)
		var p := perf(rid, t, int(r.get("h", 0)), float(r.get("q", -1.0)), _median(firsts_here))
		var s := solve_score(rd, p)
		ema[rs] = s if not ema.has(rs) else float(ema[rs]) + ALPHA * (s - float(ema[rs]))
		solves_by_board[rid] = int(solves_by_board.get(rid, 0)) + 1
		if i == at:
			continue
		if rid == id:
			board_solves += 1
			if rd == difficulty:
				count += 1
				sum_h += int(r.get("h", 0))
				if t > 0.0:
					sum_t += t
					timed += 1
	if at < 0:
		before = float(ema.get(skill, -1.0))
	var after := float(ema.get(skill, -1.0))
	var scores := {}
	for k in SKILLS:
		scores[k] = float(ema.get(k, -1.0))
	var mean_t := sum_t / timed if timed > 0 else 0.0
	var mean_h := sum_h / count if count > 0 else 0.0
	var out := {
		"skill": skill, "scores": scores, "before": before, "after": after,
		"gain": int(round(after)) - int(round(before)) if before >= 0.0 and at >= 0 else 0,
		"first": count == 0, "mean_t": mean_t, "mean_h": mean_h, "count": count,
	}
	out["tip"] = _tip(id, difficulty, current, mean_t, board_solves)
	var low := _lowest(scores)
	out["lowest"] = low
	out["suggest"] = _suggest(low, solves_by_board) if low != skill else ""
	return out

## Which of the board's four tips (spec section 6's order of rules).
static func _tip(id: String, difficulty: int, current: Dictionary, mean_t: float, board_solves: int) -> int:
	var hints := int(current.get("h", 0))
	var q := float(current.get("q", -1.0))
	var t := float(current.get("t", 0.0))
	if difficulty >= 3 and hints == 0:
		return 4
	if board_solves < 2:
		return 1
	if hints > 0:
		return 2
	var slow := not id in UNTIMED and mean_t > 0.0 and t > mean_t * SLOW
	if (q >= 0.0 and q < WEAK_Q) or slow:
		return 3
	var day := int(current.get("day", Time.get_date_dict_from_system().day))
	return [1, 3, 4][day % 3]

## The untrained skill first in SKILLS order, else the lowest score.
static func _lowest(scores: Dictionary) -> String:
	var low := ""
	var low_s := INF
	for k in SKILLS:
		var s := float(scores[k])
		if s < 0.0:
			return k
		if s < low_s:
			low_s = s
			low = k
	return low

## The least-solved board of `skill`, ties to registry order.
static func _suggest(skill: String, solves_by_board: Dictionary) -> String:
	var best := ""
	var best_n := 1 << 30
	for e in Registry.PUZZLES:
		if String(e.get("skill", "")) != skill:
			continue
		var n := int(solves_by_board.get(String(e.id), 0))
		if n < best_n:
			best_n = n
			best = String(e.id)
	return best
