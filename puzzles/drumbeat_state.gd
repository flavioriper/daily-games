extends RefCounted

## Drumbeat's rules, as pure data: one song's chart at one difficulty, judged
## against the song's own clock (spec
## docs/superpowers/specs/2026-10-01-drumbeat-polish-design.md). It has no
## clock of its own. The screen hands it the song's time on every frame
## (`update`), every press and every lift (`press`, `lift`), and reads back
## the score, the combo, the soul gauge, the hearts and the events.
##
## Four drums stand in a row, and the notes come down four lanes to them.
## A note is struck on its own drum: a tap note once, a hold note struck and
## kept down to the end of its tail, a drumroll on its drum as often as the
## player can, a balloon that many strokes before it pops. Two notes at the
## same instant are struck together. Every note is GOOD, OK or BAD by how far
## from its time it was struck; a note let past is a BAD. A BAD breaks the
## combo. The soul gauge fills on GOOD, half on OK, and drains on BAD; the
## song is cleared -- the board solved -- when it ends at or over the line.
##
## Hard and Insane carry hearts (3 and 2): MISS_RUN misses in a row break
## one, and so does a song that ends under the line. Out of hearts, the song
## stops. A stroke on a drum with nothing near it is free on Easy and Medium;
## on Hard and Insane, with a note due on another drum, it is a slip that
## breaks the combo.
##
## Insane is Echo: the bars go in pairs and the second plays the first again
## with its notes hidden (`hidden`), written so by tools/gen_drumbeat.py; the
## rules judge a hidden note like any other.

enum Type { TAP, HOLD, ROLL, BALLOON }
enum Grade { GOOD, OK, BAD }
enum St { WAIT, HIT, MISSED }

const LANES := 4
## The judgement windows, in seconds either side of a note, by difficulty.
## Wider than an arcade cabinet's, because a phone's glass and its audio are
## both slower than a drum.
const GOOD_WIN := [0.07, 0.06, 0.05, 0.045]
const OK_WIN := [0.13, 0.115, 0.1, 0.09]
const BAD_WIN := [0.16, 0.145, 0.13, 0.12]
## A hold let go this close to its end still counts as held to the end.
const HOLD_SLACK := 0.12
## Points a note: GOOD, OK.
const POINTS := [300, 150, 0]
## A note's bonus for the combo standing when it lands: this much for every
## COMBO_STEP, up to COMBO_CAP.
const COMBO_BONUS := 10
const COMBO_STEP := 10
const COMBO_CAP := 100
## A hold pays HOLD_POINTS a tick of HOLD_TICK seconds held, and HOLD_DONE
## when kept to the end.
const HOLD_POINTS := 20
const HOLD_TICK := 0.1
const HOLD_DONE := 200
const ROLL_POINTS := 100
const BALLOON_HIT := 100
const BALLOON_POP := 1000
## Go-Go time's lift on everything scored inside it.
const GOGO := 1.2
## The soul gauge is full after this share of the notes hit GOOD, by
## difficulty; the song is cleared at CLEAR of it.
const FILL := [0.55, 0.65, 0.75, 0.8]
const GAUGE_MAX := 100.0
const CLEAR := 80.0
## The combo is lettered at these counts, and every hundred past the last.
const COMBO_CALLS := [10, 25, 50, 100]
## Hearts by difficulty, and the misses in a row that break one.
const HEARTS := [0, 0, 3, 2]
const MISS_RUN := 3

var song: Dictionary
var level := 0
## {t, lane, type, end, count, hidden, st, grade, hits, held, done_hold}
var notes: Array = []
var gogo: Array = []
var echo: Array = []
var length := 0.0
var time := -10.0

var score := 0
var combo := 0
var max_combo := 0
var gauge := 0.0
var goods := 0
var oks := 0
var bads := 0
var slips := 0
var rolls := 0
var balloons := 0
var holds := 0
var in_gogo := false
var done := false
var hearts := 0
var max_hearts := 0
var out := false
var miss_run := 0
var events: Array = []

## Notes judged as notes (taps and holds), and the gauge a GOOD is worth.
var _regular := 0
var _gain := 1.0
## The first note not yet settled; every note before it is.
var _next := 0
var _cleared := false
var _full := false

func _init(the_song: Dictionary, the_level: int) -> void:
	song = the_song
	level = clampi(the_level, 0, 3)
	length = float(song.get("length", 60.0))
	gogo = song.get("gogo", [])
	echo = song.get("echo", []) if level == 3 else []
	max_hearts = HEARTS[level]
	hearts = max_hearts
	var charts: Array = song.get("charts", [])
	var rows: Array = charts[mini(level, charts.size() - 1)] if not charts.is_empty() else []
	for r: Array in rows:
		var n := {"t": float(r[0]), "lane": int(r[1]), "type": int(r[2]), "end": float(r[3]), "count": int(r[4]),
			"hidden": int(r[5]) == 1, "st": St.WAIT, "grade": -1, "hits": 0, "held": false, "paid": 0.0}
		notes.append(n)
		if n.type <= Type.HOLD:
			_regular += 1
	_gain = GAUGE_MAX / maxf(1.0, _regular * FILL[level])

const CHARTS := "res://content/drumbeat.json"

static func _data() -> Dictionary:
	var f := FileAccess.open(CHARTS, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}

## Every song, as tools/gen_drumbeat.py wrote them.
static func songs() -> Array:
	return _data().get("songs", [])

## The tap-along that tunes the timing: {file, clicks}.
static func calib() -> Dictionary:
	return _data().get("calib", {})

static func is_long(type: int) -> bool:
	return type >= Type.ROLL

func cleared() -> bool:
	return gauge >= CLEAR

func full_combo() -> bool:
	return bads == 0 and slips == 0 and _regular > 0

func all_good() -> bool:
	return full_combo() and oks == 0

func regular_count() -> int:
	return _regular

## Share of the notes judged so far that were GOOD or OK.
func accuracy() -> float:
	var seen := goods + oks + bads
	return (goods + 0.5 * oks) / seen if seen > 0 else 0.0

func gogo_at(t: float) -> bool:
	for g: Array in gogo:
		if t >= float(g[0]) and t < float(g[1]):
			return true
	return false

## Whether `t` falls in one of Echo's hidden bars.
func echo_at(t: float) -> bool:
	for e: Array in echo:
		if t >= float(e[0]) and t < float(e[1]):
			return true
	return false

## The last instant anything happens: a second after the last note ends.
func end_time() -> float:
	if notes.is_empty():
		return length - 1.0
	var last := 0.0
	for n: Dictionary in notes:
		last = maxf(last, maxf(float(n.t), float(n.end)))
	return last + 1.2

## The song's clock moved on to `t`: notes let pass are missed, holds pay
## and end, drumrolls and balloons that ran out close, Go-Go time turns on
## and off, and the song ends a second after its last note.
func update(t: float) -> void:
	if done or out:
		return
	time = t
	var ok_win: float = OK_WIN[level]
	# holds being kept pay as they go, and finish at their end
	for k in range(_next, notes.size()):
		var n: Dictionary = notes[k]
		if float(n.t) > t:
			break
		if n.type == Type.HOLD and n.held:
			_pay_hold(k, minf(t, float(n.end)))
			if t >= float(n.end):
				_finish_hold(k, true)
	# notes let pass, and drumrolls and balloons run out; a hold being kept
	# stays open without holding up the drums beside it
	for k in range(_next, notes.size()):
		var n: Dictionary = notes[k]
		if float(n.t) > t:
			break
		if n.st != St.WAIT or n.held:
			continue
		if is_long(n.type):
			if t > float(n.end):
				n.st = St.HIT if n.hits > 0 else St.MISSED
				if n.type == Type.BALLOON and n.hits < n.count:
					events.append({"type": "balloon_gone", "i": k})
				elif n.type == Type.ROLL and n.hits > 0:
					events.append({"type": "roll_end", "i": k, "hits": n.hits})
			continue
		if t - float(n.t) > ok_win:
			_judge(k, Grade.BAD, true)
			if out:
				return
	while _next < notes.size() and notes[_next].st != St.WAIT and not notes[_next].held:
		_next += 1
	var now := gogo_at(t)
	if now != in_gogo:
		in_gogo = now
		events.append({"type": "gogo_on" if now else "gogo_off"})
	if t >= end_time() and _next >= notes.size():
		done = true
		if max_hearts > 0 and not cleared():
			_break_heart("under")
		events.append({"type": "done"})

## A stroke on drum `lane` at song time `t`. Answers what it did: "good",
## "ok", "bad", "roll", "balloon", "pop", "slip" or "" (a stroke with nothing
## to play, free).
func press(t: float, lane: int) -> String:
	if done or out:
		return ""
	time = t
	var bad_win: float = BAD_WIN[level]
	# a drumroll or a balloon on this drum, under the judge line
	for k in range(_next, notes.size()):
		var n: Dictionary = notes[k]
		if float(n.t) - t > bad_win:
			break
		if n.lane != lane or not is_long(n.type) or n.st != St.WAIT:
			continue
		if t < float(n.t) - 0.03 or t > float(n.end):
			continue
		var mult := GOGO if gogo_at(t) else 1.0
		n.hits += 1
		if n.type == Type.BALLOON:
			score += int(BALLOON_HIT * mult)
			if n.hits >= n.count:
				n.st = St.HIT
				balloons += 1
				score += int(BALLOON_POP * mult)
				events.append({"type": "pop", "i": k, "points": int(BALLOON_POP * mult)})
				return "pop"
			events.append({"type": "balloon", "i": k, "left": n.count - n.hits})
			return "balloon"
		rolls += 1
		var rp := int(ROLL_POINTS * mult)
		score += rp
		events.append({"type": "roll", "i": k, "hits": n.hits, "points": rp})
		return "roll"
	# the nearest note waiting on this drum
	var best := -1
	var best_dt := INF
	for k in range(_next, notes.size()):
		var n: Dictionary = notes[k]
		var dt := t - float(n.t)
		if dt < -bad_win:
			break
		if n.lane != lane or n.st != St.WAIT or is_long(n.type) or n.held:
			continue
		if absf(dt) < absf(best_dt):
			best = k
			best_dt = dt
	if best < 0 or absf(best_dt) > bad_win:
		return _stray(t)
	var note: Dictionary = notes[best]
	var ad := absf(best_dt)
	if ad <= float(GOOD_WIN[level]):
		_judge(best, Grade.GOOD, false, best_dt)
	elif ad <= float(OK_WIN[level]):
		_judge(best, Grade.OK, false, best_dt)
	else:
		_judge(best, Grade.BAD, false, best_dt)
		return "bad"
	if note.type == Type.HOLD:
		note.held = true
		note.paid = float(note.t)
		note.st = St.WAIT
	return "good" if note.grade == Grade.GOOD else "ok"

## The finger on drum `lane` came up at `t`: a hold kept to its end (or near
## enough) is finished, one let go early is dropped -- its tail lost, the
## combo kept.
func lift(t: float, lane: int) -> void:
	if done or out:
		return
	for k in range(_next, notes.size()):
		var n: Dictionary = notes[k]
		if float(n.t) > t:
			break
		if n.lane == lane and n.type == Type.HOLD and n.held:
			_pay_hold(k, minf(t, float(n.end)))
			_finish_hold(k, t >= float(n.end) - HOLD_SLACK)

## A stroke with no note near it on its drum. Free below Hard; on Hard and
## Insane, while a note is due on another drum, a slip.
func _stray(t: float) -> String:
	if level < 2:
		return ""
	var due := false
	for k in range(_next, notes.size()):
		var n: Dictionary = notes[k]
		if float(n.t) - t > float(OK_WIN[level]):
			break
		if n.st == St.WAIT and not n.held and not is_long(n.type) and absf(t - float(n.t)) <= float(OK_WIN[level]):
			due = true
			break
	if not due:
		return ""
	slips += 1
	if combo > 0:
		events.append({"type": "break", "combo": combo})
	combo = 0
	gauge = maxf(0.0, gauge - _gain * 0.5)
	events.append({"type": "slip"})
	_gauge_events()
	return "slip"

func _pay_hold(i: int, upto: float) -> void:
	var n: Dictionary = notes[i]
	var ticks := int(floor((upto - float(n.paid)) / HOLD_TICK))
	if ticks <= 0:
		return
	n.paid = float(n.paid) + ticks * HOLD_TICK
	var pts := int(ticks * HOLD_POINTS * (GOGO if gogo_at(upto) else 1.0))
	score += pts
	events.append({"type": "hold_tick", "i": i, "points": pts})

func _finish_hold(i: int, kept: bool) -> void:
	var n: Dictionary = notes[i]
	n.held = false
	n.st = St.HIT
	if kept:
		holds += 1
		var pts := int(HOLD_DONE * (GOGO if gogo_at(float(n.end)) else 1.0))
		score += pts
		events.append({"type": "hold_done", "i": i, "points": pts})
	else:
		events.append({"type": "hold_drop", "i": i})

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
			miss_run = 0
			gauge = minf(GAUGE_MAX, gauge + _gain)
		Grade.OK:
			oks += 1
			combo += 1
			miss_run = 0
			gauge = minf(GAUGE_MAX, gauge + _gain * 0.5)
		Grade.BAD:
			bads += 1
			miss_run += 1
			if combo > 0:
				events.append({"type": "break", "combo": combo})
			combo = 0
			gauge = maxf(0.0, gauge - _gain * 2.0)
	if grade != Grade.BAD:
		pts = _points(grade, float(n.t))
		score += pts
	max_combo = maxi(max_combo, combo)
	events.append({"type": "judge", "i": i, "grade": grade, "points": pts, "passed": passed, "dt": dt,
		"lane": n.lane, "hidden": n.hidden})
	if grade != Grade.BAD and (combo in COMBO_CALLS or (combo > 100 and combo % 100 == 0)):
		events.append({"type": "combo", "n": combo})
	_gauge_events()
	if grade == Grade.BAD and max_hearts > 0 and miss_run >= MISS_RUN:
		miss_run = 0
		_break_heart("run")

func _gauge_events() -> void:
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

func _break_heart(why: String) -> void:
	if hearts <= 0:
		return
	hearts -= 1
	events.append({"type": "heart", "left": hearts, "why": why})
	if hearts <= 0:
		out = true
		for n: Dictionary in notes:
			n.held = false
		events.append({"type": "out"})

## One more heart: the song picks up again from `from` with a heart. Every
## note from there on waits again, as if never reached.
func revive(from: float) -> void:
	out = false
	done = false
	hearts = 1
	miss_run = 0
	_next = 0
	for k in notes.size():
		var n: Dictionary = notes[k]
		if float(n.t) >= from:
			n.st = St.WAIT
			n.grade = -1
			n.hits = 0
			n.held = false
	while _next < notes.size() and notes[_next].st != St.WAIT:
		_next += 1
