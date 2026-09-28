extends RefCounted

## Drumbeat's rules, as pure data: one song's chart at one difficulty, judged
## against the song's own clock (spec
## docs/superpowers/specs/2026-09-28-drumbeat-flat-design.md). It has no
## clock of its own. The screen hands it the song's time on every frame
## (`update`) and every tap (`hit`), and reads back the score, the combo, the
## soul gauge and the events.
##
## The rules are the drum-festival family's: a red note is hit on the drum's
## face (don) and a blue one on its rim (ka). A big note hit a second time with
## the same stroke, straight after, scores twice. A drumroll takes any stroke
## as often as the player can, and a balloon takes that many dons before it
## pops. Every note is judged GOOD, OK or BAD by how far from its time it was
## hit; a wrong stroke near a note is a BAD, and a note left to pass is one
## too. A BAD breaks the combo. The soul gauge fills on GOOD, half on OK, and
## drains on BAD; the song is cleared -- the board solved -- when it ends at
## or over the clear line. Nothing ends a song early, and a song that ends
## under the line is simply played again.
##
## Four levels: Easy, Medium and Hard read the song's three charts, and
## Insane reads Hard's with narrower windows and a gauge that wants more.

enum Type { DON, KA, BIG_DON, BIG_KA, ROLL, BIG_ROLL, BALLOON }
enum Grade { GOOD, OK, BAD }
enum St { WAIT, HIT, MISSED }

## The judgement windows, in seconds either side of a note, by difficulty.
## Wider than the arcade's (25/75/108 ms on the web's port), because a phone's
## glass and its audio are both slower than a drum.
const GOOD_WIN := [0.065, 0.05, 0.045, 0.036]
const OK_WIN := [0.12, 0.105, 0.095, 0.08]
const BAD_WIN := [0.15, 0.135, 0.125, 0.11]
## How long after a big note's first stroke the second may land.
const BIG_WIN := 0.07
## Points a note: GOOD, OK. A big note's second stroke scores it again.
const POINTS := [300, 150, 0]
## A note's bonus for the combo standing when it lands: this much for every
## COMBO_STEP, up to COMBO_CAP.
const COMBO_BONUS := 10
const COMBO_STEP := 10
const COMBO_CAP := 100
const ROLL_POINTS := 100
const BIG_ROLL_POINTS := 200
const BALLOON_HIT := 100
const BALLOON_POP := 1000
## Go-Go time's lift on everything scored inside it.
const GOGO := 1.2
## The soul gauge is full after this share of the notes hit GOOD, by
## difficulty; the song is cleared at CLEAR of it.
const FILL := [0.55, 0.65, 0.75, 0.85]
const GAUGE_MAX := 100.0
const CLEAR := 80.0
## The combo is lettered at these counts, and every hundred past the last.
const COMBO_CALLS := [10, 25, 50, 100]

var song: Dictionary
var level := 0
## {t, type, end?, count?, st, grade, hits}
var notes: Array = []
var gogo: Array = []
var length := 0.0
var time := -10.0

var score := 0
var combo := 0
var max_combo := 0
var gauge := 0.0
var goods := 0
var oks := 0
var bads := 0
var rolls := 0
var balloons := 0
var bigs := 0
var in_gogo := false
var done := false
var events: Array = []

## Regular notes (not rolls or balloons), and the gauge a GOOD is worth.
var _regular := 0
var _gain := 1.0
## The first note not yet settled; every note before it is.
var _next := 0
## The big note whose second stroke is still open: {i, kind, until}.
var _big := {}
var _cleared := false
var _full := false

func _init(the_song: Dictionary, the_level: int) -> void:
	song = the_song
	level = clampi(the_level, 0, 3)
	length = float(song.get("length", 60.0))
	gogo = song.get("gogo", [])
	var rows: Array = song.charts[mini(level, 2)]
	for r: Array in rows:
		var n := {"t": float(r[0]), "type": int(r[1]), "st": St.WAIT, "grade": -1, "hits": 0}
		if r.size() > 2:
			n.end = float(r[2])
		if r.size() > 3:
			n.count = int(r[3])
		notes.append(n)
		if n.type <= Type.BIG_KA:
			_regular += 1
	_gain = GAUGE_MAX / maxf(1.0, _regular * FILL[level])

const CHARTS := "res://content/drumbeat.json"

## Every song, as tools/gen_drumbeat.py wrote them.
static func songs() -> Array:
	var f := FileAccess.open(CHARTS, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	return data.songs if data is Dictionary else []

static func is_big(type: int) -> bool:
	return type == Type.BIG_DON or type == Type.BIG_KA

static func is_don(type: int) -> bool:
	return type == Type.DON or type == Type.BIG_DON

static func is_long(type: int) -> bool:
	return type >= Type.ROLL

func cleared() -> bool:
	return gauge >= CLEAR

func full_combo() -> bool:
	return bads == 0 and _regular > 0

func all_good() -> bool:
	return full_combo() and oks == 0

func regular_count() -> int:
	return _regular

## Share of the regular notes judged so far that were GOOD or OK.
func accuracy() -> float:
	var seen := goods + oks + bads
	return (goods + 0.5 * oks) / seen if seen > 0 else 0.0

func gogo_at(t: float) -> bool:
	for g: Array in gogo:
		if t >= float(g[0]) and t < float(g[1]):
			return true
	return false

## The song's clock moved on to `t`: notes let pass are missed, drumrolls
## and balloons that ran out close, Go-Go time turns on and off, and the song
## ends a second after its last note.
func update(t: float) -> void:
	if done:
		return
	time = t
	var ok_win: float = OK_WIN[level]
	if not _big.is_empty() and t > float(_big.until):
		_big = {}
	while _next < notes.size():
		var n: Dictionary = notes[_next]
		if n.st != St.WAIT:
			_next += 1
			continue
		if is_long(n.type):
			if t > float(n.end):
				n.st = St.HIT if n.hits > 0 else St.MISSED
				if n.type == Type.BALLOON and n.hits < int(n.count):
					events.append({"type": "balloon_gone", "i": _next})
				elif n.type != Type.BALLOON and n.hits > 0:
					events.append({"type": "roll_end", "i": _next, "hits": n.hits})
				_next += 1
				continue
			break
		if t - float(n.t) > ok_win:
			_judge(_next, Grade.BAD, true)
			_next += 1
			continue
		break
	var now := gogo_at(t)
	if now != in_gogo:
		in_gogo = now
		events.append({"type": "gogo_on" if now else "gogo_off"})
	var last := float(length) - 1.0
	if not notes.is_empty():
		var tail: Dictionary = notes[notes.size() - 1]
		last = maxf(float(tail.get("end", tail.t)), float(tail.t)) + 1.2
	if t >= last and _next >= notes.size():
		done = true
		events.append({"type": "done"})

## A stroke at song time `t`, on the face (`face`) or the rim. Answers what it
## did: "good", "ok", "bad", "big", "roll", "balloon", "pop" or "" (a stroke
## with nothing to play).
func hit(t: float, face: bool) -> String:
	if done:
		return ""
	time = t
	# a big note's second stroke
	if not _big.is_empty() and t <= float(_big.until) and bool(_big.face) == face:
		var bn: Dictionary = notes[int(_big.i)]
		var pts := _points(int(bn.grade), t)
		score += pts
		bigs += 1
		events.append({"type": "big", "i": int(_big.i), "points": pts, "face": face})
		_big = {}
		return "big"
	# a drumroll or a balloon under the judge line
	for k in range(_next, notes.size()):
		var n: Dictionary = notes[k]
		if float(n.t) - t > float(BAD_WIN[level]):
			break
		if not is_long(n.type) or n.st != St.WAIT:
			continue
		if t < float(n.t) - 0.02 or t > float(n.end):
			continue
		if n.type == Type.BALLOON:
			if not face:
				return ""
			n.hits += 1
			var mult := GOGO if gogo_at(t) else 1.0
			score += int(BALLOON_HIT * mult)
			if n.hits >= int(n.count):
				n.st = St.HIT
				balloons += 1
				score += int(BALLOON_POP * mult)
				events.append({"type": "pop", "i": k, "points": int(BALLOON_POP * mult)})
				return "pop"
			events.append({"type": "balloon", "i": k, "left": int(n.count) - n.hits})
			return "balloon"
		n.hits += 1
		rolls += 1
		var rp := int((BIG_ROLL_POINTS if n.type == Type.BIG_ROLL else ROLL_POINTS) * (GOGO if gogo_at(t) else 1.0))
		score += rp
		events.append({"type": "roll", "i": k, "hits": n.hits, "points": rp, "face": face})
		return "roll"
	# the nearest note waiting within reach
	var best := -1
	var best_dt := INF
	for k in range(_next, notes.size()):
		var n: Dictionary = notes[k]
		var dt := t - float(n.t)
		if dt < -float(BAD_WIN[level]):
			break
		if n.st != St.WAIT or is_long(n.type):
			continue
		if absf(dt) < absf(best_dt):
			best = k
			best_dt = dt
		elif absf(dt) > absf(best_dt):
			break
	if best < 0:
		return ""
	var note: Dictionary = notes[best]
	var ad := absf(best_dt)
	var right := is_don(note.type) == face
	if not right:
		# the wrong stroke only counts against a note it was plainly meant for
		if ad <= float(OK_WIN[level]):
			_judge(best, Grade.BAD, false, best_dt)
			return "bad"
		return ""
	if ad <= float(GOOD_WIN[level]):
		_judge(best, Grade.GOOD, false, best_dt)
	elif ad <= float(OK_WIN[level]):
		_judge(best, Grade.OK, false, best_dt)
	else:
		_judge(best, Grade.BAD, false, best_dt)
		return "bad"
	if is_big(note.type):
		_big = {"i": best, "face": face, "until": t + BIG_WIN}
	return "good" if note.grade == Grade.GOOD else "ok"

func _points(grade: int, t: float) -> int:
	var base: int = POINTS[grade]
	if base == 0:
		return 0
	var bonus := COMBO_BONUS * (mini(combo, COMBO_CAP) / COMBO_STEP)
	return int((base + bonus) * (GOGO if gogo_at(t) else 1.0))

func _judge(i: int, grade: int, passed: bool, dt := 0.0) -> void:
	var n: Dictionary = notes[i]
	n.st = St.MISSED if grade == Grade.BAD else St.HIT
	n.grade = grade
	var pts := 0
	match grade:
		Grade.GOOD:
			goods += 1
			combo += 1
			gauge = minf(GAUGE_MAX, gauge + _gain)
		Grade.OK:
			oks += 1
			combo += 1
			gauge = minf(GAUGE_MAX, gauge + _gain * 0.5)
		Grade.BAD:
			bads += 1
			if combo > 0:
				events.append({"type": "break", "combo": combo})
			combo = 0
			gauge = maxf(0.0, gauge - _gain * 2.0)
	if grade != Grade.BAD:
		pts = _points(grade, float(n.t))
		score += pts
	max_combo = maxi(max_combo, combo)
	events.append({"type": "judge", "i": i, "grade": grade, "points": pts, "passed": passed, "dt": dt,
		"big": is_big(n.type), "don": is_don(n.type)})
	if grade != Grade.BAD and (combo in COMBO_CALLS or (combo > 100 and combo % 100 == 0)):
		events.append({"type": "combo", "n": combo})
	if not _cleared and gauge >= CLEAR:
		_cleared = true
		events.append({"type": "soul_clear"})
	elif _cleared and gauge < CLEAR:
		_cleared = false
		events.append({"type": "soul_lost"})
	if not _full and gauge >= GAUGE_MAX:
		_full = true
		events.append({"type": "soul_full"})
	elif _full and gauge < GAUGE_MAX:
		_full = false
