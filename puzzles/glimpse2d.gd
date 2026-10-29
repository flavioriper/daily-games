extends "res://puzzles/pixel_garden2d.gd"

## Glimpse: Pixel Garden from memory. A little picture made for the day
## (puzzles/glimpse_state.gd) is held up big over the pegboard for a few
## seconds, a bar of time running down over it, then set back on the pattern card
## and covered. The player rebuilds it bead for bead on the same pegboard,
## from the same box, with the same iron: once every bead is on the board
## the iron passes, a plate that is right fuses and a bead astray hops home
## -- the only word the board ever says about what was remembered.
##
## The cover is the card's back: an eye and a pip for each look left. A tap
## on it holds the picture up again for PEEK_SHOW seconds and spends a look
## (`LOOKS_BY`); none are left on Insane past its one. No hint and no Check:
## both would read the picture out. Undo and Reset stay.
##
## **Every bead is judged as it goes down** (the made-fun pass, 2026-10-29,
## Memory Matrix's way): a bead the picture does not want on that peg hops
## straight back to its compartment, the peg ringed rose, and counts a miss;
## a right one stays, and right beads in a row climb in pitch, with a word
## every RUN_WORD of them. Three live stars by misses and looks
## (`GL_STARS_CUT`); nothing wrong can stand, so there is no Undo.
##
## Everything else -- the box, the tweezers, the plates, the iron, the
## party, the seal -- is Pixel Garden's own code, run as it is. Its sounds
## are its own set (assets/sfx/glimpse/), Pixel Garden's takes a step off.
## Spec: docs/superpowers/specs/2026-10-22-glimpse-design.md.

const GState = preload("res://puzzles/glimpse_state.gd")

## How long the picture is held up at the start, by band.
const SHOW_BY := [5.0, 6.0, 6.0, 7.0]
## How many times the cover may be lifted, by band, and for how long.
const LOOKS_BY := [3, 2, 1, 1]
const PEEK_SHOW := 1.6
## The last seconds of the first show each pop once.
const COUNT_FROM := 3
## The bar of time over the held picture: its width and how far above.
const TIME_W := 10.0
const TIME_OUT := 22.0
## Each look spent takes this off the solve's quality.
const LOOK_COST := 0.1
## Misses and looks that keep three stars, two (more is one).
const GL_STARS_CUT := [0, 2]
## A word every this many right beads in a row.
const RUN_WORD := 5
const ROSE := Color("e0607e")

## When the picture held up goes back under its cover (INF: it is not held
## up by the board), when that show began, and whether it is the first.
var _show_until := INF
var _show_from := 0.0
var _first_show := false
var _counted := 0
## When the first show is due (INF once it has been). It waits for anything
## the host lays over the board -- the first play's tutorial, the rules, the
## settings -- which hold the board's clock (`clock_held`).
var _first_at := INF
var looks_left := 0
var looks_used := 0
## Beads refused today, the right ones in a row now, and the best run.
var misses := 0
var run := 0
var best_run := 0
## A stroke that missed paints no more pegs.
var _missed_in_stroke := false
## Rose rings on missed pegs: [peg, when].
var _miss_rings: Array = []
var _cover_mesh: ArrayMesh
var _cover_key := ""

func _init() -> void:
	_state = GState.new()

func puzzle_id() -> String: return "glimpse"
func title() -> String: return "Glimpse"

func rules() -> String:
	var out := tr("GL_RULES") % int(SHOW_BY[_state.band])
	out += "\n\n" + tr("GL_RULES_JUDGE")
	out += "\n\n" + tr("PG_RULES_PLATES")
	var n: int = LOOKS_BY[_state.band]
	out += "\n\n" + (tr("GL_RULES_LOOKS_ONE") if n == 1 else tr("GL_RULES_LOOKS_N") % n)
	return out

## The tutorial: the picture shown and covered, then Pixel Garden's own
## lessons on seating, the kit, the plates and Undo.
func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/pixel_garden_tutorial_diagram.gd")
	var band: int = _state.band
	var n: int = LOOKS_BY[band]
	var steps := [
		[Diagram.Lesson.GLIMPSE, "HTP_GL_GLIMPSE", tr("HTP_GL_GLIMPSE_BODY") % int(SHOW_BY[band])],
		[Diagram.Lesson.SEAT, "HTP_PG_SEAT", tr("HTP_PG_SEAT_BODY")],
		[Diagram.Lesson.PLATE, "HTP_PG_PLATE", tr("HTP_GL_PLATE_BODY")],
		[Diagram.Lesson.LOOK, "HTP_GL_LOOK", tr("HTP_GL_LOOK_BODY_ONE") if n == 1 else tr("HTP_GL_LOOK_BODY_N") % n],
	]
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

func capabilities() -> Array[String]:
	return []

func hints_left() -> int:
	return 0

func _zoomable() -> bool:
	return false

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_show_until = INF
	_counted = 0
	looks_left = LOOKS_BY[clampi(difficulty, 0, 3)]
	looks_used = 0
	misses = 0
	run = 0
	best_run = 0
	_missed_in_stroke = false
	_miss_rings = []
	_cover_mesh = null
	super(rng, difficulty)
	# The picture comes up once the board has popped in and nothing lies
	# over it.
	_first_at = _now() + Motion.ENTER_DELAY + Motion.ENTER_POP + 0.15

## Holds the picture up over the board for `seconds`.
func _hold_up(seconds: float, first: bool) -> void:
	_clear_gesture()
	_first_show = first
	_counted = 0
	_peek = true
	_peek_at = _now()
	_show_from = _peek_at
	_show_until = _peek_at + seconds
	_busy_for(PEEK_TIME)
	fx.cue("show")
	queue_redraw()

## The picture back under its cover.
func _put_down() -> void:
	if _show_until == INF:
		return
	_show_until = INF
	_peek = false
	_peek_at = _now()
	_busy_for(PEEK_TIME)
	_cover_mesh = null
	fx.cue("hide")
	queue_redraw()

func _showing() -> bool:
	return _show_until != INF

func _process(delta: float) -> void:
	super(delta)
	var t := _now()
	if _first_at != INF and t >= _first_at and not clock_held:
		_first_at = INF
		if not is_done() and not _won:
			_hold_up(SHOW_BY[_state.band], true)
	if not _showing():
		return
	# A sheet laid over the board mid-show stops its time.
	if clock_held:
		_show_until += delta
		_show_from += delta
		return
	if t >= _show_until:
		_put_down()
		return
	# The last seconds of the first show, a pop each.
	var left := int(ceil(_show_until - t))
	if _first_show and left <= COUNT_FROM and COUNT_FROM - left + 1 > _counted:
		_counted = COUNT_FROM - left + 1
		fx.cue("count", 1.0 + 0.06 * _counted)
	queue_redraw()

func _press(at: Vector2) -> void:
	# A tap while the picture is up puts it down: the player has it.
	if _showing():
		_put_down()
		return
	# Before the first show nothing is played: a tap on the card brings it
	# now, and spends no look.
	if _first_at != INF:
		if _thumb.has_point(at) and not clock_held:
			_first_at = INF
			_hold_up(SHOW_BY[_state.band], true)
		return
	_missed_in_stroke = false
	if _thumb.has_point(at):
		if is_done() or _won:
			return
		if looks_left <= 0:
			fx.cue("refuse")
			_tell("GL_NO_LOOKS")
			return
		looks_left -= 1
		looks_used += 1
		_rate_stars()
		_cover_mesh = null
		_hold_up(PEEK_SHOW, false)
		return
	super(at)

func _release() -> void:
	# The picture goes down on its own clock, never on a finger lifted.
	if _showing():
		return
	super()

## The card is covered: nothing on it to read, and Easy traces nothing.
func _reads_card() -> bool:
	return false

func _slips() -> int:
	return misses + looks_used

func _star_cut() -> Array:
	return GL_STARS_CUT

## A run of right beads climbs higher than a stroke does.
func _climb() -> float:
	return minf(0.3, 0.025 * run)

## A bead is judged as it goes down: the picture's colour for that peg
## stays, any other hops home at once and counts a miss, and the stroke
## that missed paints no more (a run swept one peg too far costs one miss,
## not a row of them).
func _paint(c: int) -> void:
	if _missed_in_stroke:
		_last = c
		return
	var bare: bool = c >= 0 and c < _state.size() and _state.beads[c] == State.EMPTY and _state.locked[c] == 0
	if not _erase and bare and not _painted.has(c) and not _plate_busy(_state.plate_of(c)) \
			and _state.left(brush) > 0 and int(_state.want[c]) != brush:
		_painted[c] = true
		_last = c
		_miss(c)
		return
	var before: int = _state.beads[c] if c >= 0 and c < _state.size() else State.EMPTY
	super(c)
	if not _erase and before == State.EMPTY and c >= 0 and c < _state.size() and _state.beads[c] == brush:
		run += 1
		best_run = maxi(best_run, run)
		if run % RUN_WORD == 0:
			_word(tr("GL_WORD_RUN") % run, _centre(c))
			fx.cue("steady", 1.0 + minf(0.2, 0.02 * run / RUN_WORD))
			if not Motion.reduce and zoom.view.has_point(zoom.to_screen(_centre(c))):
				fx.sparkle(zoom.to_screen(_centre(c)), Pal.SUN)

## Peg `c` refused the colour in hand: the bead drops onto it and hops back
## to its compartment, a rose ring where it tried, a star falling.
func _miss(c: int) -> void:
	var t := _now()
	_missed_in_stroke = true
	misses += 1
	run = 0
	_state.miss(c, brush)
	if not Motion.reduce:
		_flying.append({"from": _centre(c), "to": _home(brush), "colour": _state.colours[brush],
			"at": t + 0.18, "sits": true})
		_miss_rings.append([c, t])
		_busy_for(HOME_TIME + 0.3)
	_shake_at[c] = t
	fx.cue("astray")
	fx.buzz(Haptics.WARN)
	_tell("GL_MISS_FIRST" if misses == 1 else "GL_MISS")
	_rate_stars()
	_refresh()

## The rose rings on missed pegs, into the board's marks.
func _more_marks(b: Face.Builder, t: float) -> void:
	var keep: Array = []
	for m: Array in _miss_rings:
		var u := (t - float(m[1])) / 0.7
		if u >= 1.0:
			continue
		keep.append(m)
		var rr := _cell * (0.42 + 0.12 * u)
		b.stroke(Face.Builder.ring(_centre(int(m[0])), rr, rr), _cell * 0.07, Color(ROSE, 1.0 - u * u), true)
	_miss_rings = keep

func _pinch_began() -> void:
	_cancel_stroke()
	_press_finger = -2

## Nothing is played while the picture is up, or before it first has been.
func _blocked() -> bool:
	return _showing() or _first_at != INF or super()

## The cover over the card, or the picture once the board is won.
func _draw_thumb(xf: Transform2D, seen: float) -> void:
	if _won or is_done():
		super(xf, seen)
		return
	var key := "%d|%s" % [looks_left, str(_thumb.size)]
	if _cover_mesh == null or key != _cover_key:
		var b := Face.Builder.new()
		cover(b, Rect2(Vector2.ZERO, _thumb.size), looks_left, LOOKS_BY[_state.band])
		_cover_mesh = b.mesh()
		_cover_key = key
	draw_mesh(_cover_mesh, null, xf * Transform2D(0.0, _thumb.position), Color(1.0, 1.0, 1.0, seen))

## The held picture, and over it, while the board holds it up, the bar of
## time running down.
func _draw_peek(t: float, shown: Array) -> void:
	super(t, shown)
	if not _showing() or _board.size.x <= 0.0:
		return
	var u := clampf((t - _peek_at) / PEEK_TIME, 0.0, 1.0)
	if u < 1.0 and not Motion.reduce:
		return
	var side := _board.size.x * PEEK_COVER
	var c := _board.get_center()
	var span := maxf(0.01, _show_until - _show_from)
	var k := clampf((_show_until - t) / span, 0.0, 1.0)
	# A bar along the picture's top edge, running down to nothing.
	var w := side
	var y := c.y - side * 0.5 - TIME_OUT
	var x0 := c.x - w * 0.5
	draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(Pal.TEXT, 0.18), TIME_W, true)
	if k > 0.0:
		draw_line(Vector2(x0, y), Vector2(x0 + w * k, y), Pal.SUN, TIME_W, true)

## The card's back, in a rect `r` the size of the pattern card: a wash of
## paper, an eye in the middle (open while looks are left, shut when none
## are), and under it a pip a look, the spent ones hollow.
static func cover(b: Face.Builder, r: Rect2, left: int, most: int) -> void:
	var inner := r.grow(-8.0)
	b.fan(Face.Builder.round_rect(inner.position, inner.size, 13.0), Pal.PG_TRAY.lightened(0.18))
	# A soft lattice of dots, as a card's back has.
	var step := inner.size.x / 6.0
	for y in 6:
		for x in 6:
			if (x + y) % 2 == 0:
				b.disc(inner.position + Vector2(x + 0.5, y + 0.5) * step, step * 0.09, Color(Pal.PG_TRAY_DEEP, 0.35))
	var c := inner.get_center() - Vector2(0.0, inner.size.y * 0.08)
	var ew := inner.size.x * 0.34
	var eh := inner.size.y * 0.17
	var ink := Pal.TEXT
	if left > 0:
		var lid := PackedVector2Array()
		lid.append_array(Face.Builder.bezier2(c + Vector2(-ew, 0.0), c + Vector2(0.0, -eh * 2.0), c + Vector2(ew, 0.0)))
		lid.append_array(Face.Builder.bezier2(c + Vector2(ew, 0.0), c + Vector2(0.0, eh * 2.0), c + Vector2(-ew, 0.0)))
		b.fan(lid, Color.WHITE)
		b.stroke(lid, 5.0, ink, true)
		b.disc(c, eh * 0.95, Pal.CAT[5])
		b.disc(c, eh * 0.45, ink)
		b.disc(c + Vector2(eh * 0.3, -eh * 0.3), eh * 0.18, Color.WHITE)
	else:
		var shut := Face.Builder.bezier2(c + Vector2(-ew, 0.0), c + Vector2(0.0, eh * 1.6), c + Vector2(ew, 0.0))
		b.stroke(shut, 5.0, ink)
		for i in 3:
			var at := c + Vector2((i - 1) * ew * 0.55, eh * 0.62)
			b.stroke(PackedVector2Array([at, at + Vector2((i - 1) * 4.0, eh * 0.55)]), 4.0, ink)
	var pip := inner.size.x * 0.05
	var gap := pip * 3.0
	var y := inner.end.y - inner.size.y * 0.16
	var x0 := inner.get_center().x - gap * (most - 1) * 0.5
	for i in most:
		var at := Vector2(x0 + gap * i, y)
		if i < left:
			b.disc(at, pip, Pal.CAT[5])
		else:
			b.stroke(Face.Builder.ring(at, pip * 0.8, pip * 0.8), 3.0, Color(ink, 0.45), true)

## Flawless is not one miss, without a look.
func _party(span: float) -> void:
	_flawless = looks_used == 0 and misses == 0
	super(span)

## The share of the picture's beads less the misses, each look spent taking
## a little off.
func skill_quality() -> float:
	if _state.target <= 0:
		return -1.0
	var q := 1.0 - float(misses) / float(_state.target)
	return clampf(q - LOOK_COST * looks_used, 0.0, 1.0)

func flat_win() -> Dictionary:
	var line := tr("GL_WIN_ALL") if misses == 0 else (tr("GL_WIN_MISS_ONE") if misses == 1 else tr("GL_WIN_MISS_N") % misses)
	if misses > 0 and best_run >= RUN_WORD:
		line += " " + tr("GL_WIN_RUN") % best_run
	return {"faces": [], "subtitle": tr("GL_WIN") + " " + line}

func completion_record() -> Dictionary:
	var out := super()
	out["looks"] = looks_used
	out["first"] = _state.first_right()
	out["misses"] = misses
	out["run"] = best_run
	return out

## A finished day reopens with the picture shown, never held up again.
func restore_completed_board() -> void:
	_first_at = INF
	_show_until = INF
	_peek = false
	super()
	looks_used = int(completed_record.get("looks", 0))
	misses = int(completed_record.get("misses", 0))
	best_run = int(completed_record.get("run", 0))
