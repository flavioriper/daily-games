extends "res://core/puzzle_base.gd"

## Birdsong (spec docs/superpowers/specs/2026-10-22-birdsong-design.md): a
## memory board. A little bird on the old tree's branch sings a tune on the
## drums standing on the lawn under it; the player plays it back. Each round
## the tune is one note longer, and the day's whole tune played back is the
## solve. The rules are puzzles/birdsong_state.gd's.
##
## **The garden is the whole screen** (`"bleed": true`): the flat host lays
## this board full rect and says what its rows cover (`set_clear`); the
## world (puzzles/birdsong_world.gd) is the board's first child. From the
## top of the span down: the branch with the bird on it, the song's row --
## a ring for each note of the round, a berry in it for each note played
## back, a faint dot for each note still to come in the day -- and the
## drums on the lawn. The drums are Drumbeat's (ui/faces/drumbeat_parts.gd's
## `band_drum`, each with its mark on its skin and its own voice), the bird
## is ui/faces/songbird.gd and the row's berries Drumbeat's too.
##
## A sung or struck drum bumps, rings and sends up a quaver of its colour; a
## slip shivers the drum struck and puzzles the bird, who sings the round
## again. Nothing is ever lost: a slip costs only the round's start and the
## brain report's quality. The bulb has the bird sing the round once more
## (Insane: the whole tune so far). No Undo -- a note heard cannot be
## unheard -- and the bin starts the day over.
##
## The board is also its own tutorial: `demo` set before it enters the tree
## makes it silent, deaf and laid in its own rect, and
## ui/hud/birdsong_tutorial_diagram.gd plays it with `demo_strike`.

const State = preload("res://puzzles/birdsong_state.gd")
const World = preload("res://puzzles/birdsong_world.gd")
const Bird = preload("res://ui/faces/songbird.gd")
const Parts = preload("res://ui/faces/drumbeat_parts.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Fx2D = preload("res://ui/fx2d.gd")
const Haptics = preload("res://core/haptics.gd")
const Rewards = preload("res://arcade/rewards.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const CozyTheme = preload("res://ui/theme.gd")

enum Phase { WAIT, LISTEN, PLAY, PAUSE, DONE }

const HAPTICS := {
	"drum_0": Haptics.TAP, "drum_1": Haptics.TAP, "drum_2": Haptics.TAP, "drum_3": Haptics.TAP,
	"round": Haptics.GOOD,
	"slip": Haptics.WARN,
	"hush": Haptics.TICK,
	"hint": Haptics.GOOD,
	"reset": Haptics.TAP,
	"grow": Haptics.TICK,
	"solved": Haptics.WIN,
}

## The screen the board was drawn on; everything scales with the width.
const W := 1080.0
## Before the first song (once nothing lies over the board), before each
## round's first note, after its last before the player's turn, after a
## round played back and after a slip.
const FIRST_LEAD := 1.1
const LEAD := 0.55
const TURN := 0.35
const AFTER_ROUND := 0.9
const AFTER_SLIP := 1.0
## How long a drum stays lit, a quaver floats up, the bird's beak is open
## and a mood is worn.
const LIT := 0.34
const QUAVER_TIME := 0.8
const QUAVER_RISE := 150.0
const BEAK_TIME := 0.22
const MOOD_TIME := 0.5
const PUZZLED_TIME := 1.0
## The bird's breathing and blinking.
const BREATH := 2.6
const BLINK_EVERY := 3.4
const BLINK_TIME := 0.13
## The win: the drums' wave, how long the board's own win plays.
const WIN_HOLD := 1.3
const WAVE_STEP := 0.09
## A slot's ring and a berry, as shares of a slot's radius.
const RING_W := 0.12
const DOT_R := 0.22
## The words over the row, at W.
const SAY_SIZE := 40
const COUNT_SIZE := 30

## Built silent and deaf for the tutorial's page.
var demo := false

var _st = State.new()
var _band := 0
var _phase := Phase.WAIT
## The board's own clock: it stands while a sheet lies over the board.
var _t := 0.0
## [time, Callable] run when the clock reaches them, in order.
var _queue: Array = []
## Each drum: when it was last sung or struck, when it last slipped, when
## its mood ends and what it is.
var _hit: Array[float] = []
var _miss: Array[float] = []
var _mood: Array[int] = []
var _mood_until: Array[float] = []
var _press_at: Array[float] = []
## The slot of the round lit while it is sung: [index, when].
var _lit_slot := Vector2(-1, -INF)
## When each slot's berry went in, and when the row last grew.
var _bead_at: Array[float] = []
var _grow_at := -INF
## False between a round played back and its new note's ring popping in.
var _grown := true
## Quavers in the air: {at, x, y, kind}.
var _quavers: Array = []
## The bird: when it last sang a note, when it last hopped, its mood and
## until when.
var _sing_at := -INF
var _hop_at := -INF
var _bird_mood := Bird.Mood.REST
var _bird_until := 0.0
var _won_at := -INF
var _enter_at := 0.0
var _say := ""
var _say_at := -INF
var _pressing := -2
## The layout: where the rows let the board be, and what it sets there.
var _clear := Vector2.ZERO
var _won := false
var _bled := false
var _shift := 0.0
var _L := {}
var _from := {}
var _lay_at := -INF
var _world: Control
var _branch: ArrayMesh
var _branch_key := ""
var fx: Node
var _rw: Node

func puzzle_id() -> String: return "birdsong"
func title() -> String: return "Birdsong"

func rules() -> String:
	var out := tr("BS_RULES") % [_st.drums(), int(State.LENGTH[_band])]
	out += "\n\n" + tr("BS_RULES_SLIP")
	if _st.whisper():
		out += "\n\n" + tr("BS_RULES_WHISPER")
	return out

func tutorial_pages() -> Array:
	var Diagram = load("res://ui/hud/birdsong_tutorial_diagram.gd")
	var steps := [
		[Diagram.Lesson.LISTEN, "HTP_BS_LISTEN", tr("HTP_BS_LISTEN_BODY")],
		[Diagram.Lesson.PLAY, "HTP_BS_PLAY", tr("HTP_BS_PLAY_BODY")],
		[Diagram.Lesson.SLIP, "HTP_BS_SLIP", tr("HTP_BS_SLIP_BODY")],
	]
	if _st.whisper():
		steps.append([Diagram.Lesson.WHISPER, "HTP_BS_WHISPER", tr("HTP_BS_WHISPER_BODY")])
	steps.append([Diagram.Lesson.HINT, "HTP_BS_HINT", tr("HTP_BS_HINT_BODY")])
	var pages := []
	for step in steps:
		var d: Control = Diagram.new()
		d.lesson = step[0]
		d.band = _band
		pages.append({"diagram": d, "title": step[1], "body": step[2]})
	return pages

## Only the bulb: a note heard cannot be unplayed, and nothing on the board
## is ever wrong for a Check to find.
func capabilities() -> Array[String]:
	return ["hint"]

func hints_left() -> int:
	return maxi(0, int(State.HINTS[_band]) + hints_extra - hints_used)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if demo else Control.MOUSE_FILTER_STOP
	fx = Fx2D.new()
	fx.name = "Fx"
	fx.haptics = HAPTICS
	if demo:
		fx.buzzes = false
	add_child(fx)
	_rw = Rewards.new()
	add_child(_rw)
	resized.connect(_relayout)
	if demo:
		_make_world()
		_relayout()

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	_band = clampi(difficulty, 0, 3)
	_st.deal(rng, _band)
	_fresh()
	_enter_at = _t
	_cue("enter")
	_after(FIRST_LEAD, _first_song)

## Every drum and slot at rest, the song not begun.
func _fresh() -> void:
	var n: int = _st.drums()
	_hit.clear()
	_miss.clear()
	_mood.clear()
	_mood_until.clear()
	_press_at.clear()
	for d in n:
		_hit.append(-INF)
		_miss.append(-INF)
		_mood.append(Parts.Mood.HAPPY)
		_mood_until.append(0.0)
		_press_at.append(-INF)
	_bead_at.clear()
	for i in _st.tune.size():
		_bead_at.append(-INF)
	_queue.clear()
	_quavers.clear()
	_lit_slot = Vector2(-1, -INF)
	_grown = true
	_phase = Phase.WAIT
	_say = ""
	_relayout()

func day_dict() -> Dictionary:
	if _st.tune.is_empty():
		return {}
	var kinds: Array = []
	for d in _st.drums():
		kinds.append(_st.kind(d))
	return {
		"source": "generator", "kind": "text",
		"payload": {"drums": kinds, "length": _st.tune.size(), "start": int(State.START[_band]), "whisper": _st.whisper()},
		"solution": {"tune": Array(_st.tune)},
		"metrics": {"length": _st.tune.size(), "drums": _st.drums(), "rounds": _st.rounds(),
			"notes_heard": _heard_total(), "gap": _st.gap()},
	}

## How many notes the bird sings over a clean day.
func _heard_total() -> int:
	var total := 0
	for r in range(int(State.START[_band]), _st.tune.size() + 1):
		total += 1 if _st.whisper() and r > int(State.START[_band]) else r
	return total

# --- the song ---

func _after(delay: float, what: Callable) -> void:
	_queue.append([_t + delay, what])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))

func _first_song() -> void:
	if _phase != Phase.WAIT or is_done():
		return
	_listen(false)

## The bird sings the round: the whole of it, or only its new note under
## Whisper (`full` sings all of it whatever the band).
func _listen(full: bool) -> void:
	_queue.clear()
	_phase = Phase.LISTEN
	_say_now("BS_LISTEN")
	var notes: Array[int] = _st.sung(full)
	var first: int = _st.round_len - notes.size()
	for i in notes.size():
		var d: int = notes[i]
		var slot := first + i
		_after(LEAD + i * _st.gap(), func() -> void: _sing(d, slot))
	_after(LEAD + (notes.size() - 1) * _st.gap() + TURN + LIT, _your_turn)

func _sing(d: int, slot: int) -> void:
	_sing_at = _t
	_lit_slot = Vector2(slot, _t)
	_sound_drum(d, false)
	_light(d)

func _your_turn() -> void:
	if _phase != Phase.LISTEN:
		return
	_phase = Phase.PLAY
	_say_now("BS_YOUR_TURN")

## A drum lit: its bump, its ring, a happy face and a quaver going up.
func _light(d: int) -> void:
	_hit[d] = _t
	_mood[d] = Parts.Mood.JOY
	_mood_until[d] = _t + LIT
	var skin := _skin(d)
	_quavers.append({"at": _t, "x": skin.x, "y": skin.y, "kind": _st.kind(d)})

func _sound_drum(d: int, struck: bool) -> void:
	_cue(("drum_%d" if struck else "note_%d") % _st.kind(d))

## The player struck drum `d`.
func _strike(d: int) -> void:
	if is_done() or _won:
		return
	_press_at[d] = _t
	match _phase:
		Phase.WAIT:
			# a tap before the first song starts it now
			if not clock_held:
				_queue.clear()
				_listen(false)
			return
		Phase.LISTEN, Phase.PAUSE:
			# the bird is singing: a little shush, nothing played
			_miss[d] = _t
			_cue("hush")
			return
		Phase.DONE:
			return
	moves += 1
	moved.emit()
	var at: int = _st.pos
	var heard: int = _st.heard(d)
	match heard:
		State.Heard.SLIP:
			_slip(d)
		_:
			_sound_drum(d, true)
			_light(d)
			_bead_at[at] = _t
			_hop_at = _t
			match heard:
				State.Heard.ROUND:
					_round_done()
				State.Heard.SOLVED:
					_solved_now()

func _slip(d: int) -> void:
	_phase = Phase.PAUSE
	_miss[d] = _t
	_mood[d] = Parts.Mood.WORRIED
	_mood_until[d] = _t + MOOD_TIME
	_bird_mood = Bird.Mood.PUZZLED
	_bird_until = _t + PUZZLED_TIME
	for i in _bead_at.size():
		_bead_at[i] = -INF
	_cue("slip")
	if not demo:
		fx.puff(_skin(d), Pal.TEXT_DIM, 6)
	_say_now("BS_AGAIN")
	_after(AFTER_SLIP, func() -> void: _listen(true))

func _round_done() -> void:
	_phase = Phase.PAUSE
	_bird_mood = Bird.Mood.JOY
	_bird_until = _t + AFTER_ROUND
	_after(0.12, func() -> void:
		_cue("round")
		if not demo:
			fx.sparkle(_bird_at() + Vector2(0, -_bird_r() * 1.6), Pal.SUN))
	_grown = false
	_after(AFTER_ROUND * 0.55, func() -> void:
		for i in _bead_at.size():
			_bead_at[i] = -INF
		_grow_at = _t
		_grown = true
		_cue("grow"))
	_after(AFTER_ROUND, func() -> void: _listen(false))
	_say_now("BS_NICE")

func _solved_now() -> void:
	_phase = Phase.DONE
	_queue.clear()
	_won_at = _t
	_bird_mood = Bird.Mood.JOY
	_bird_until = INF
	_say = ""
	for d in _st.drums():
		_after(0.15 + d * WAVE_STEP, func() -> void: _light(d))
	_after(0.1, func() -> void: _cue("solved"))
	if not demo:
		_after(0.5, func() -> void:
			fx.confetti(_bird_at() + Vector2(0, -_bird_r() * 2.0), 26, size.x * 0.7)
			# not one slip all day: the party's toots over the confetti
			_cue("party" if _st.clean >= _st.rounds() else "confetti"))
		_after(1.0, func() -> void: _cue("purr"))
	check_solved()

func is_solved() -> bool:
	return _st.solved()

## The bulb: the bird sings the round again, all of it.
func hint() -> bool:
	if hints_left() <= 0 or not (_phase == Phase.PLAY or _phase == Phase.LISTEN):
		return false
	hints_used += 1
	_st.pos = 0
	for i in _bead_at.size():
		_bead_at[i] = -INF
	_cue("hint")
	_bird_mood = Bird.Mood.SING
	_bird_until = _t + MOOD_TIME
	_listen(true)
	return true

## The bin: the day from its first round.
func reset_board() -> void:
	if is_done():
		return
	_st.restart()
	moves = 0
	_fresh()
	_cue("reset")
	_after(LEAD, func() -> void: _listen(false))

func _say_now(key: String) -> void:
	_say = key
	_say_at = _t

func _cue(name: String, pitch := 1.0) -> void:
	if demo or fx == null:
		return
	fx.cue(name, pitch)

## The tutorial's finger on drum `d`.
func demo_strike(d: int) -> void:
	_strike(clampi(d, 0, _st.drums() - 1))

func phase() -> int:
	return _phase

func round_no() -> int:
	return _st.round_no()

func state():
	return _st

# --- the clock ---

func _process(delta: float) -> void:
	super(delta)
	if clock_held and not demo:
		return
	_t += delta
	while not _queue.is_empty() and float(_queue[0][0]) <= _t:
		var job: Array = _queue.pop_front()
		(job[1] as Callable).call()
	for d in _mood.size():
		if _mood_until[d] > 0.0 and _t >= _mood_until[d]:
			_mood[d] = Parts.Mood.HAPPY
			_mood_until[d] = 0.0
	if _bird_until != INF and _t >= _bird_until:
		_bird_mood = Bird.Mood.REST
	var keep: Array = []
	for q: Dictionary in _quavers:
		if _t - float(q.at) < QUAVER_TIME:
			keep.append(q)
	_quavers = keep
	queue_redraw()

# --- the fingers ---

func _gui_input(event: InputEvent) -> void:
	if demo:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		var finger: int = event.index if event is InputEventScreenTouch else -1
		if event.pressed:
			if _pressing != -2:
				return
			_pressing = finger
			var d := drum_at(event.position)
			if d >= 0:
				_strike(d)
		elif finger == _pressing:
			_pressing = -2

## The drum a finger at `local` means: the nearest across, anywhere under
## the song's row (the nearest action, never a miss for a thumb a little
## off).
func drum_at(local: Vector2) -> int:
	if _L.is_empty() or local.y < float(_L.row_y) + float(_L.bead_r) * 1.4:
		return -1
	var best := -1
	var far := INF
	for d in _st.drums():
		var dx := absf(local.x - _drum_x(d))
		if dx < far:
			far = dx
			best = d
	return best

## Where a finger playing drum `d` goes, in this board's pixels.
func drum_to_local(d: int) -> Vector2:
	return _skin(d)

# --- the layout ---

func _make_world() -> void:
	if _world != null:
		return
	_world = World.new()
	_world.name = "World"
	_world.show_behind_parent = true
	add_child(_world)
	move_child(_world, 0)

## What the host's rows cover, in this board's own pixels (laid full rect).
## On the win the board is not laid out again at once: it eases into the
## win's span.
func set_clear(top: float, bottom: float, won := false) -> void:
	if not _bled:
		_bled = true
		_make_world()
	_clear = Vector2(top, bottom)
	var was := _won
	_won = won
	if won and not was and not _L.is_empty():
		_from = _L.duplicate()
		_lay_at = _t
	_relayout()

func set_shift(x: float, leaving := false) -> void:
	_shift = x
	position.x = x
	if _world != null:
		_world.position.x = -x
		_world.visible = not leaving

func skip_entrance() -> void:
	_enter_at = -10.0

func _relayout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var top := _clear.x if _bled else 0.0
	var bottom := size.y - (_clear.y if _bled else 0.0)
	_L = _layout_for(top, bottom)
	if _world != null:
		_world.position = Vector2(-_shift if _bled else 0.0, 0.0)
		_world.size = size
		_world.set_lines(float(_L.horizon), float(_L.foot))
	queue_redraw()

func _layout_for(top: float, bottom: float) -> Dictionary:
	var w := size.x
	var u := w / W
	var span := maxf(bottom - top, 200.0 * u)
	var n: int = maxi(1, _st.drums())
	var step := minf(w * 0.86 / n, 300.0 * u)
	var drum_r := minf(step * 0.45, 135.0 * u)
	var foot := bottom - maxf(30.0 * u, span * 0.07)
	var branch := top + span * 0.24
	var count: int = maxi(1, _st.tune.size())
	var gap := minf(w * 0.8 / count, 118.0 * u)
	var bead_r := minf(gap * 0.4, 42.0 * u)
	var row := top + span * 0.5
	return {
		"u": u, "top": top, "bottom": bottom,
		"branch": branch, "bird_x": w * 0.56, "bird_r": minf(92.0 * u, span * 0.085),
		"row_y": row, "bead_gap": gap, "bead_r": bead_r,
		"foot": foot, "drum_r": drum_r, "step": step,
		# the row and the drums stand in the room the old tree's trunk leaves
		"mid": w * 0.535 if _world != null else w * 0.5,
		"horizon": foot - drum_r * 2.2,
	}

## A layout value, eased from the play's layout into the win's.
func _l(key: String) -> float:
	var v := float(_L[key])
	if _from.is_empty() or not _from.has(key):
		return v
	var e := (_t - _lay_at) / 0.5
	if e >= 1.0:
		return v
	return lerpf(float(_from[key]), v, Motion.back_out(clampf(e, 0.0, 1.0)))

func _u() -> float:
	return float(_L.get("u", 1.0))

func _drum_x(d: int) -> float:
	var n: int = _st.drums()
	return _l("mid") + (d - (n - 1) * 0.5) * _l("step")

func _drum_foot(d: int) -> Vector2:
	return Vector2(_drum_x(d), _l("foot"))

func _skin(d: int) -> Vector2:
	var kind: int = _st.kind(d)
	return _drum_foot(d) + Vector2(0.0, Parts.skin_y(kind, _l("drum_r")))

func _bird_r() -> float:
	return _l("bird_r")

func _bird_at() -> Vector2:
	return Vector2(_l("bird_x"), _l("branch"))

func _slot_at(i: int) -> Vector2:
	var count: int = _st.tune.size()
	return Vector2(_l("mid") + (i - (count - 1) * 0.5) * _l("bead_gap"), _l("row_y"))

# --- drawing ---

func _draw() -> void:
	if _L.is_empty() or _st.tune.is_empty():
		return
	_draw_branch()
	_draw_bird()
	_draw_row()
	_draw_drums()
	_draw_quavers()
	_draw_say()

## The branch from the old tree's trunk across the sky, its twigs and
## leaves: one cached mesh a layout.
func _draw_branch() -> void:
	var u := _u()
	var y := _l("branch")
	var key := "%d:%d" % [roundi(size.x), roundi(y)]
	if key != _branch_key:
		_branch_key = key
		var b := Face.Builder.new()
		var end := size.x * 0.86
		var pts := PackedVector2Array()
		for i in 25:
			var t := float(i) / 24.0
			pts.append(Vector2(lerpf(-20.0 * u, end, t), y + 10.0 * u + sin(t * PI) * 16.0 * u - t * 26.0 * u))
		b.stroke(_moved(pts, Vector2(0, 8.0 * u)), 34.0 * u, Color(World.TRUNK_DEEP, 0.25))
		# one tapered limb, thick at the trunk and thin at the tip, its lit
		# top a lighter wood
		b.polygon(_limb(pts, 19.0 * u, 6.0 * u), World.TRUNK_DEEP)
		b.polygon(_limb(_moved(pts, Vector2(0, -2.0 * u)), 14.0 * u, 3.5 * u), World.TRUNK)
		b.stroke(_moved(pts.slice(1, 21), Vector2(0, -7.0 * u)), 3.0 * u, Color(World.BARK, 0.7))
		for tw: Array in [[0.3, -1.0], [0.55, 1.0], [0.78, -1.0], [0.97, 1.0]]:
			var root := pts[int(float(tw[0]) * 24.0)]
			var tip := root + Vector2(40.0, 46.0 * float(tw[1]) - 20.0) * u
			b.stroke(PackedVector2Array([root, tip]), 8.0 * u, World.TRUNK)
			_leaf(b, tip, 22.0 * u, float(tw[1]) * 0.6 - 0.4)
			_leaf(b, root.lerp(tip, 0.55), 16.0 * u, -float(tw[1]) * 0.9 - 0.6)
		_branch = b.mesh()
	draw_mesh(_branch, null)

static func _leaf(b: Face.Builder, at: Vector2, s: float, turn: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0 * TAU
		pts.append(at + Vector2(cos(t) * s, sin(t) * s * 0.46).rotated(turn))
	b.polygon(pts, World.CROWN)
	b.stroke(PackedVector2Array([at - Vector2(s * 0.8, 0).rotated(turn), at + Vector2(s * 0.7, 0).rotated(turn)]),
		s * 0.09, Color(World.CROWN_DEEP, 0.8))

## A limb along `pts`, `w0` half wide at its first point narrowing to `w1`
## at its last, its tip rounded.
static func _limb(pts: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var top := PackedVector2Array()
	var low := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, n - 1)]
		var nrm := (b - a).normalized().orthogonal()
		var w := lerpf(w0, w1, float(i) / (n - 1))
		top.append(pts[i] + nrm * w)
		low.append(pts[i] - nrm * w)
	var dir := (pts[n - 1] - pts[n - 2]).normalized()
	var out := top
	out.append(pts[n - 1] + dir * w1)
	low.reverse()
	out.append_array(low)
	return out

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out

func _draw_bird() -> void:
	var r := _bird_r()
	var at := _bird_at()
	var since := _t - _sing_at
	var beak := 0.0
	var wing := 0.0
	var mood: int = _bird_mood
	if since < BEAK_TIME:
		beak = 1.0 - since / BEAK_TIME * 0.5
		wing = 0.5
		if mood == Bird.Mood.REST:
			mood = Bird.Mood.SING
	if mood == Bird.Mood.JOY:
		wing = 1.0 if fmod(_t, 0.3) < 0.15 else 0.5
	elif mood == Bird.Mood.REST and _phase != Phase.DONE and fmod(_t, BLINK_EVERY) < BLINK_TIME:
		mood = Bird.Mood.SLEEP
	var lift := 0.0
	var hop := _t - _hop_at
	if hop < Motion.HOP_TIME:
		lift += Motion.hop_lift(hop, Motion.HOP * 1.6 * _u())
	if _phase == Phase.DONE:
		lift += Motion.hop_lift(fmod(_t - _won_at, 0.6), Motion.SOLVE_HOP * 2.0 * _u(), 0.5)
	elif since < 0.3:
		lift += Motion.hop_lift(since, Motion.HOP * _u(), 0.3)
	var shake := Motion.shiver_offset(_t - (_bird_until - PUZZLED_TIME), 4.0 * _u()) if _bird_mood == Bird.Mood.PUZZLED else 0.0
	var breath := 1.0 + 0.02 * sin(_t * TAU / BREATH) if not Motion.reduce else 1.0
	# the bird drops onto its branch as the board comes in
	var e := _t - _enter_at - Motion.ENTER_DELAY
	if e < 0.0:
		return
	if e < Motion.DROP_TIME:
		lift -= Motion.drop_in_lift(maxf(e, 0.0), Motion.DROP * 2.0 * _u())
	# it faces the drums it sings to while singing, the player while it waits
	var face := -1.0 if _phase == Phase.PLAY else 1.0
	var turn := 0.12 if _phase == Phase.PLAY else 0.0
	draw_mesh(Bird.bird(r, mood, beak, wing), null,
		Transform2D(turn * face, Vector2(face * breath, 1.0 / breath), 0.0, at + Vector2(shake, lift)))

## The song's row: a ring a note of the round, a berry for each one played
## back, the sung note's slot lit while it rings, and a dot for each note
## the day still holds.
func _draw_row() -> void:
	var r := _l("bead_r")
	var count: int = _st.tune.size()
	var round_len: int = mini(_st.round_len, count)
	var grow := _t - _grow_at
	var u := _u()
	for i in count:
		var c := _slot_at(i)
		var won := _phase == Phase.DONE or is_done()
		if won:
			var wave := maxf(0.0, _t - _won_at - i * WAVE_STEP)
			var lift := Motion.hop_lift(wave, Motion.SOLVE_HOP * 1.6 * u, Motion.SOLVE_TIME) if _won_at > -INF else 0.0
			draw_mesh(Parts.berry(_st.kind(_st.tune[i]), r, Parts.Mood.JOY), null, Transform2D(0.0, c + Vector2(0, lift)))
			continue
		if i >= round_len or i == round_len - 1 and not _grown:
			draw_circle(c, r * DOT_R, Color(Pal.TEXT, 0.22))
			continue
		var k := 1.0
		if i == round_len - 1 and grow < Motion.POP_IN:
			k = Motion.pop_in_scale(grow).x
		draw_set_transform(c, 0.0, Vector2.ONE * k)
		draw_circle(Vector2.ZERO, r, Color(Pal.SURFACE, 0.55))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(Pal.TEXT, 0.35), r * RING_W, true)
		draw_set_transform(Vector2.ZERO)
		var lit := int(_lit_slot.x) == i and _t - _lit_slot.y < LIT * 1.4
		if lit:
			var a := Motion.flash_level(_t - _lit_slot.y, 0.06, LIT * 1.3)
			var col: Color = Parts.LANE_BODY[_st.kind(_st.tune[i])]
			draw_mesh(Parts.berry(_st.kind(_st.tune[i]), r, Parts.Mood.HAPPY), null, Transform2D(0.0, c), Color(1, 1, 1, a))
			draw_arc(c, r * 1.25, 0.0, TAU, 40, Color(col, a * 0.8), r * 0.12, true)
		elif i < _st.pos or _bead_at[i] > -INF and _phase != Phase.LISTEN:
			var e := _t - _bead_at[i]
			var s := Motion.pop_in_scale(e).x if e < Motion.POP_IN else 1.0
			draw_mesh(Parts.berry(_st.kind(_st.tune[i]), r, Parts.Mood.HAPPY), null,
				Transform2D(0.0, Vector2.ONE * s, 0.0, c))

func _draw_drums() -> void:
	var r := _l("drum_r")
	var seen := 1.0
	if _won:
		seen = clampf(1.0 - (_t - _lay_at) / 0.4, 0.0, 1.0)
		if seen <= 0.0:
			return
	for d in _st.drums():
		var kind: int = _st.kind(d)
		var foot := _drum_foot(d)
		var hit := _t - _hit[d]
		var miss := _t - _miss[d]
		var e := _t - _enter_at - Motion.ENTER_DELAY - d * Motion.ENTER_STAGGER * 2.0
		var pop := 1.0 if e >= Motion.ENTER_POP else (Motion.wide_pop_scale(maxf(e, 0.0)) if e > 0.0 else 0.0)
		if pop <= 0.0:
			continue
		var bump := Motion.bump_scale(hit, 0.12) if hit < Motion.BUMP_TIME else 1.0
		var held := _t - _press_at[d]
		var press := Motion.press_scale(held, held - 0.08 if held > 0.08 else -1.0) if held < 0.4 else 1.0
		var squash := bump * press
		var shake := Motion.shiver_offset(miss, 6.0 * _u()) if miss < Motion.SHIVER_TIME * 2.0 else 0.0
		var skin := foot + Vector2(shake, Parts.skin_y(kind, r) * squash)
		# lit: a ring of its colour round the skin and a glow under it
		if hit < LIT * 1.5:
			var a := Motion.flash_level(hit, 0.05, LIT * 1.4)
			var col: Color = Parts.LANE_HI[kind]
			draw_set_transform(skin, 0.0, Vector2(1.0, 0.36))
			draw_circle(Vector2.ZERO, r * (1.25 + 0.25 * (1.0 - a)), Color(col, 0.35 * a))
			draw_arc(Vector2.ZERO, r * (1.05 + 0.4 * (1.0 - a)), 0.0, TAU, 48, Color(Parts.CREAM, 0.9 * a), r * 0.08, true)
			draw_set_transform(Vector2.ZERO)
		var mood: int = _mood[d]
		draw_mesh(Parts.band_drum(kind, r, mood), null,
			Transform2D(0.0, Vector2(pop / squash, pop * squash), 0.0, foot + Vector2(shake, 0.0)), Color(1, 1, 1, seen))
		# its mark on its skin, so a drum is named twice (Drumbeat's marks)
		var top := foot + Vector2(shake, Parts.skin_y(kind, r) * pop * squash)
		_draw_mark(kind, top, r * 0.24, Color(Parts.LANE_BODY[kind], 0.95 * seen), 0.34)

## A drum's mark: a dot for the big drum, a triangle for the hand drum, a
## diamond for the jingle drum, a square for the tongue drum (Drumbeat's).
func _draw_mark(kind: int, c: Vector2, s: float, col: Color, flat := 1.0) -> void:
	match kind:
		0:
			draw_set_transform(c, 0.0, Vector2(1.0, flat))
			draw_circle(Vector2.ZERO, s * 0.82, col)
			draw_set_transform(Vector2.ZERO)
		1:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * flat), c + Vector2(s * 0.95, s * 0.72 * flat),
				c + Vector2(-s * 0.95, s * 0.72 * flat)]), col)
		2:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * flat), c + Vector2(s, 0), c + Vector2(0, s * flat),
				c + Vector2(-s, 0)]), col)
		_:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.76, -s * 0.76 * flat), c + Vector2(s * 0.76, -s * 0.76 * flat),
				c + Vector2(s * 0.76, s * 0.76 * flat), c + Vector2(-s * 0.76, s * 0.76 * flat)]), col)

func _draw_quavers() -> void:
	var u := _u()
	for q: Dictionary in _quavers:
		var e := (_t - float(q.at)) / QUAVER_TIME
		var a := clampf(1.0 - e, 0.0, 1.0) * clampf(e * 6.0, 0.0, 1.0)
		var at := Vector2(float(q.x) + sin(e * PI * 2.0) * 14.0 * u, float(q.y) - QUAVER_RISE * u * (1.0 - (1.0 - e) * (1.0 - e)) - 20.0 * u)
		draw_mesh(Bird.quaver(20.0 * u, Parts.LANE_DEEP[int(q.kind)]), null,
			Transform2D(sin(e * 7.0) * 0.2, Vector2.ONE * (0.8 + 0.4 * minf(e * 4.0, 1.0)), 0.0, at), Color(1, 1, 1, a))

## What the bird is doing, over the row, and which round of how many.
func _draw_say() -> void:
	if is_done() or _won:
		return
	var u := _u()
	var font: Font = CozyTheme.display(700)
	var y := _l("row_y") - _l("bead_r") - 34.0 * u
	if _say != "":
		var text := tr(_say)
		var fs := roundi(SAY_SIZE * u)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var k := Motion.pop_in_scale(_t - _say_at, 0.25).x if _t - _say_at < 0.25 else 1.0
		draw_set_transform(Vector2(size.x * 0.5, y), 0.0, Vector2.ONE * k)
		var base := Vector2(-tw * 0.5, 0.0)
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, roundi(10 * u), Color(Pal.SURFACE, 0.9))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)
		draw_set_transform(Vector2.ZERO)
	if demo:
		return
	var count := tr("BS_ROUND") % [_st.round_no(), _st.rounds()]
	var cs := roundi(COUNT_SIZE * u)
	var cw := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
	var cy := _l("row_y") + _l("bead_r") + 50.0 * u
	draw_string_outline(font, Vector2(size.x * 0.5 - cw * 0.5, cy), count, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, roundi(8 * u), Color(Pal.SURFACE, 0.8))
	draw_string(font, Vector2(size.x * 0.5 - cw * 0.5, cy), count, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Pal.TEXT_DIM)

# --- the win ---

func win_delay() -> float:
	if Motion.reduce:
		return Motion.REDUCED_TIME
	return WIN_HOLD

func skill_quality() -> float:
	if _st.tune.is_empty():
		return -1.0
	return _st.quality()

func share_glyphs() -> String:
	return "🐦 " + _st.share_glyphs()

func flat_win() -> Dictionary:
	var line := tr("BS_WIN_ALL") if _st.clean >= _st.rounds() else tr("BS_WIN_CLEAN") % [_st.clean, _st.rounds()]
	return {"faces": [], "subtitle": tr("BS_WIN") + " " + line}

func completion_record() -> Dictionary:
	return {"history": Array(_st.history)}

## A finished day reopens with the whole tune in its row, the bird content.
func restore_completed_board() -> void:
	_queue.clear()
	_st.finish(completed_record.get("history", []) as Array)
	_phase = Phase.DONE
	_bird_mood = Bird.Mood.JOY
	_bird_until = INF
	_say = ""
	queue_redraw()
